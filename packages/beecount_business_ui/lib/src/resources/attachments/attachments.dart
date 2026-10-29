import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

/// The host owns permissions, platform pickers and attachment persistence.
class BeeAttachmentSources extends StatelessWidget {
  const BeeAttachmentSources(
      {super.key,
      required this.cameraLabel,
      required this.galleryLabel,
      required this.onCamera,
      required this.onGallery});
  final String cameraLabel, galleryLabel;
  final VoidCallback onCamera, onGallery;

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        BeeMenuRow(
            title: cameraLabel,
            leading: const BeeLineIcon('Camera', size: 21),
            divider: true,
            onTap: onCamera),
        BeeMenuRow(
            title: galleryLabel,
            leading: const BeeLineIcon('ImagePlus', size: 21),
            onTap: onGallery),
      ]);
}

class BeeAttachment {
  const BeeAttachment(
      {required this.id,
      required this.image,
      required this.label,
      required this.info});
  final String id, label, info;
  final ImageProvider image;
}

class BeeAttachments extends StatelessWidget {
  const BeeAttachments(
      {super.key,
      required this.items,
      required this.onOpen,
      this.title,
      this.countLabel});
  final List<BeeAttachment> items;
  final String? title, countLabel;
  final ValueChanged<int> onOpen;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final columns = items.length == 1
        ? 1
        : items.length == 2
            ? 2
            : 3;
    final grid = GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: items.length == 1 ? 1.8 : 1),
        itemBuilder: (_, i) => Semantics(
            label: items[i].label,
            button: true,
            child: InkWell(
                onTap: () => onOpen(i),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(fit: StackFit.expand, children: [
                      Image(
                          image: items[i].image,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, e, s) =>
                              const Center(child: BeeLineIcon('ImagePlus'))),
                      Positioned(
                          right: 6,
                          bottom: 6,
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: BeeCardTheme.of(context).surface,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Padding(
                                  padding: const EdgeInsets.all(5.5),
                                  child: BeeLineIcon('Expand', size: 13))))
                    ])))));
    if (title == null) return grid;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text(title!,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600))),
        if (countLabel != null)
          Text(countLabel!,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
      ]),
      const SizedBox(height: 14),
      grid
    ]);
  }
}

class BeeAttachmentViewer extends StatefulWidget {
  const BeeAttachmentViewer(
      {super.key,
      required this.items,
      this.initialIndex = 0,
      this.currentIndex,
      this.onIndexChanged,
      this.fullScreen = false,
      this.onClose,
      this.onImageTap,
      this.metadataBuilder,
      this.showHeaderLabel = true,
      this.actions = const [],
      this.busy = false,
      this.emptyLabel = '',
      this.errorLabel,
      this.placeholder,
      this.maxScale = 5});
  final List<BeeAttachment> items;
  final int initialIndex;
  final int? currentIndex;
  final ValueChanged<int>? onIndexChanged;
  final bool fullScreen, busy;
  final VoidCallback? onClose, onImageTap;
  final Widget Function(int)? metadataBuilder;
  final bool showHeaderLabel;
  final List<Widget> actions;
  final String emptyLabel;
  final String? errorLabel;
  final Widget? placeholder;
  final double maxScale;
  @override
  State<BeeAttachmentViewer> createState() => _BeeAttachmentViewerState();
}

class _BeeAttachmentViewerState extends State<BeeAttachmentViewer> {
  late int index = _bounded(widget.currentIndex ?? widget.initialIndex);
  late final PageController pages = PageController(initialPage: index);
  int _bounded(int value) =>
      value.clamp(0, widget.items.isEmpty ? 0 : widget.items.length - 1);
  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BeeAttachmentViewer old) {
    super.didUpdateWidget(old);
    final next = _bounded(widget.currentIndex ?? index);
    if (next != index || old.items.length != widget.items.length) {
      index = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pages.hasClients && widget.items.isNotEmpty) {
          pages.jumpToPage(index);
        }
      });
    }
  }

  void _changed(int value) {
    setState(() => index = value);
    widget.onIndexChanged?.call(value);
  }

  Widget _error(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        BeeLineIcon('ImageOff',
            size: 40, color: widget.fullScreen ? Colors.white54 : null),
        if (widget.errorLabel != null) ...[
          const SizedBox(height: 8),
          Text(widget.errorLabel!,
              style: TextStyle(
                  fontSize: 12,
                  color: widget.fullScreen
                      ? Colors.white54
                      : Theme.of(context).hintColor))
        ],
      ]);
  Widget _viewport(BuildContext context) => widget.items.isEmpty
      ? Center(
          child: widget.placeholder ??
              Text(widget.emptyLabel,
                  style: TextStyle(
                      color: widget.fullScreen ? Colors.white70 : null)))
      : GestureDetector(
          onTap: widget.onImageTap,
          child: PageView.builder(
              controller: pages,
              itemCount: widget.items.length,
              onPageChanged: _changed,
              itemBuilder: (context, i) => InteractiveViewer(
                  key: ValueKey('${widget.items[i].id}-$i'),
                  minScale: .5,
                  maxScale: widget.maxScale,
                  child: Center(
                      child: Image(
                          image: widget.items[i].image,
                          fit: BoxFit.contain,
                          errorBuilder: (_, e, s) => _error(context))))));
  Widget _thumbnails(BuildContext context) {
    if (widget.fullScreen) {
      return SizedBox(
          key: const ValueKey('attachment-viewer-thumbnails'),
          height: 55,
          width: double.infinity,
          child: Center(
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => Semantics(
                      selected: i == index,
                      button: true,
                      label:
                          '${i + 1} / ${widget.items.length} · ${widget.items[i].label}',
                      child: InkWell(
                          onTap: () => pages.animateToPage(i,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut),
                          child: Container(
                              width: 55,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                  color: const Color(0xff222222),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                      width: 2,
                                      color: i == index
                                          ? Colors.white
                                          : Colors.transparent)),
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: Image(
                                      image: widget.items[i].image,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topCenter,
                                      errorBuilder: (_, a, b) =>
                                          const BeeLineIcon('ImageOff', color: Colors.white54)))))))));
    }
    return _inlineThumbnails(context);
  }

  Widget _inlineThumbnails(BuildContext context) => SizedBox(
      height: 64,
      child: ListView(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: widget.items
              .asMap()
              .entries
              .map((e) => Semantics(
                  selected: e.key == index,
                  button: true,
                  label:
                      '${e.key + 1} / ${widget.items.length} · ${e.value.label}',
                  child: InkWell(
                      onTap: () => pages.animateToPage(e.key,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut),
                      child: Container(
                          width: 56,
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  width: 2,
                                  color: e.key == index
                                      ? widget.fullScreen
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary
                                      : Colors.transparent)),
                          clipBehavior: Clip.antiAlias,
                          child: Image(
                              image: e.value.image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, a, b) => BeeLineIcon('ImageOff',
                                  color: widget.fullScreen
                                      ? Colors.white54
                                      : null))))))
              .toList()));

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) {
      return ColoredBox(
          color: const Color(0xff050505),
          child: AbsorbPointer(
              absorbing: widget.busy,
              child: SafeArea(
                  minimum: const EdgeInsets.all(20),
                  child: Stack(children: [
                    Column(
                        key: const ValueKey('attachment-viewer-frame'),
                        children: [
                          SizedBox(
                              key: const ValueKey('attachment-viewer-toolbar'),
                              height: 56,
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Row(children: [
                                    SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: widget.onClose == null
                                            ? null
                                            : BeeIconButton(
                                                label: MaterialLocalizations.of(
                                                        context)
                                                    .closeButtonTooltip,
                                                icon: const BeeLineIcon('X',
                                                    color: Colors.white),
                                                onPressed: widget.onClose)),
                                    Expanded(
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                          if (widget.items.isNotEmpty &&
                                              widget.showHeaderLabel) ...[
                                            Text(widget.items[index].label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    height: 1.5,
                                                    color: Color(0xffaaaaaa))),
                                            const SizedBox(height: 3),
                                          ],
                                          FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                  widget.items.isEmpty
                                                      ? widget.emptyLabel
                                                      : '${index + 1} / ${widget.items.length}',
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      height: 1.5,
                                                      color: Colors.white))),
                                        ])),
                                    if (widget.actions.isEmpty)
                                      const SizedBox(width: 44)
                                    else
                                      ...widget.actions.map((action) =>
                                          SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: action)),
                                  ]))),
                          Expanded(
                              child: SizedBox.expand(
                                  key:
                                      const ValueKey('attachment-viewer-stage'),
                                  child: _viewport(context))),
                          if (widget.items.isNotEmpty)
                            Padding(
                                key: const ValueKey('attachment-viewer-footer'),
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 16),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.metadataBuilder != null)
                                        widget.metadataBuilder!(index)
                                      else if (widget
                                          .items[index].info.isNotEmpty)
                                        Text(widget.items[index].info,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                height: 1.5,
                                                color: Color(0xffbbbbbb))),
                                      if (widget.items.length > 1) ...[
                                        const SizedBox(height: 8),
                                        _thumbnails(context),
                                      ],
                                    ])),
                        ]),
                    if (widget.busy)
                      const Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)),
                  ]))));
    }
    if (widget.items.isEmpty) {
      return widget.placeholder ?? const SizedBox.shrink();
    }
    final item = widget.items[index];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${index + 1} / ${widget.items.length} · ${item.label}'),
      const SizedBox(height: 8),
      Flexible(child: _viewport(context)),
      const SizedBox(height: 8),
      widget.metadataBuilder?.call(index) ??
          Text(item.info, style: const TextStyle(fontSize: 11)),
      _thumbnails(context),
    ]);
  }
}
