import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'workflow_components.dart';

/// Lazy preview library. Files/bytes and metadata loading are host supplied.
class BeeAttachmentLibrary extends StatelessWidget {
  const BeeAttachmentLibrary(
      {super.key,
      required this.items,
      required this.emptyLabel,
      required this.onOpen,
      this.selectedId,
      this.metadataBuilder,
      this.imageBuilder,
      this.controller,
      this.physics,
      this.shrinkWrap = false,
      this.loading = false,
      this.loadingLabel = ''});
  final List<BeeAttachment> items;
  final String emptyLabel;
  final String? selectedId;
  final ValueChanged<int>? onOpen;
  final Widget Function(int)? metadataBuilder, imageBuilder;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool loading;
  final String loadingLabel;
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        if (loadingLabel.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(loadingLabel)
        ]
      ]));
    }
    if (items.isEmpty) {
      return BeeEmptyState(
          title: emptyLabel, icon: const BeeLineIcon('Images', size: 36));
    }
    return GridView.builder(
        primary: false,
        controller: controller,
        physics: physics,
        shrinkWrap: shrinkWrap,
        padding: const EdgeInsets.all(17),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index], selected = item.id == selectedId;
          return Semantics(
              container: true,
              label: '${index + 1} / ${items.length} · ${item.label}',
              button: true,
              selected: selected,
              enabled: onOpen != null,
              onTap: onOpen == null ? null : () => onOpen!(index),
              child: ExcludeSemantics(
                  child: Opacity(
                      opacity: onOpen == null ? .45 : 1,
                      child: Material(
                          color: BeeCardTheme.of(context).soft,
                          borderRadius: BorderRadius.circular(13),
                          child: InkWell(
                              onTap:
                                  onOpen == null ? null : () => onOpen!(index),
                              borderRadius: BorderRadius.circular(13),
                              child: Container(
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(13),
                                      border: selected
                                          ? Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              width: 2)
                                          : null),
                                  child: Stack(fit: StackFit.expand, children: [
                                    imageBuilder?.call(index) ??
                                        Image(
                                            image: item.image,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, error, stack) =>
                                                const Center(
                                                    child: BeeLineIcon(
                                                        'ImageOff',
                                                        size: 28))),
                                    Positioned(
                                        right: 5,
                                        left: 5,
                                        bottom: 5,
                                        child: Align(
                                            alignment: Alignment.bottomRight,
                                            child:
                                                metadataBuilder?.call(index) ??
                                                    BeeAttachmentFileMetadata(
                                                        sizeText: item.info)))
                                  ])))))));
        });
  }
}

/// Same actual dimensions and byte size in the grid and the read-only dialog.
class BeeAttachmentFileMetadata extends StatelessWidget {
  const BeeAttachmentFileMetadata(
      {super.key,
      required this.sizeText,
      this.dimensionsText,
      this.fileName,
      this.badge = true});
  final String sizeText;
  final String? dimensionsText, fileName;
  final bool badge;
  @override
  Widget build(BuildContext context) {
    if (sizeText.isEmpty && dimensionsText == null && fileName == null) {
      return const SizedBox.shrink();
    }
    final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            badge ? CrossAxisAlignment.end : CrossAxisAlignment.center,
        children: [
          if (fileName != null) ...[
            Text(fileName!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            const SizedBox(height: 4)
          ],
          if (dimensionsText != null)
            Text(dimensionsText!,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                maxLines: 1),
          if (sizeText.isNotEmpty)
            Text(sizeText,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                maxLines: 1)
        ]);
    if (!badge) return content;
    return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomRight,
        child: DecoratedBox(
            decoration: BoxDecoration(
                color: Colors.black54, borderRadius: BorderRadius.circular(5)),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: content)));
  }
}
