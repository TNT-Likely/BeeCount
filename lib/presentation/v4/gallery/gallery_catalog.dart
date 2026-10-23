import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

/// Flat, state-preserving debug catalog. The pinned directory scrolls to a
/// section; it never replaces the samples. isolatedCase is for focused QA shots.
class GalleryCatalog extends StatefulWidget {
  const GalleryCatalog(
      {super.key,
      required this.id,
      required this.title,
      required this.labels,
      required this.event,
      required this.sampleBuilder,
      this.isolatedCase});
  final String id, title, event;
  final List<String> labels;
  final Widget Function(int index) sampleBuilder;
  final int? isolatedCase;
  @override
  State<GalleryCatalog> createState() => _GalleryCatalogState();
}

class _GalleryCatalogState extends State<GalleryCatalog> {
  final scroll = ScrollController();
  late final anchors = List.generate(widget.labels.length, (_) => GlobalKey());
  int selected = 0;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void locate(int index) {
    setState(() => selected = index);
    final target = anchors[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(target,
        alignment: 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic);
  }

  Future<void> openDirectory() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final value = await showBeeSheet<int>(context,
        title: '快速定位 · ${widget.title}',
        child: SingleChildScrollView(
            key: ValueKey('${widget.id}-directory-scroll'),
            child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                    widget.labels.length,
                    (index) => BeeButton(
                        label:
                            '${(index + 1).toString().padLeft(2, '0')} · ${widget.labels[index]}',
                        kind: BeeButtonKind.secondary,
                        onPressed: () => Navigator.pop(context, index))))));
    if (mounted && value != null) locate(value);
  }

  Widget section(int index) => Container(
      key: widget.isolatedCase == null ? anchors[index] : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 14),
            child: Text(
                '${(index + 1).toString().padLeft(2, '0')} · ${widget.labels[index]}',
                key: ValueKey('${widget.id}-section-$index'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600))),
        widget.sampleBuilder(index),
        const SizedBox(height: 26),
        if (index < widget.labels.length - 1) const Divider(height: 1),
      ]));
  @override
  Widget build(BuildContext context) {
    if (widget.isolatedCase != null) {
      return SingleChildScrollView(
          padding: const EdgeInsets.all(17),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.event,
                key: ValueKey('${widget.id}-event'),
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 12),
            section(widget.isolatedCase!),
          ]));
    }
    return Column(children: [
      Material(
          color: BeeCardTheme.of(context).canvas,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 8, 17, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                        key: ValueKey('${widget.id}-case'),
                        onTap: openDirectory,
                        borderRadius: BorderRadius.circular(13),
                        child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                                color: BeeCardTheme.of(context).surface,
                                borderRadius: BorderRadius.circular(13)),
                            child: Row(children: [
                              const BeeLineIcon('Grid2x2', size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('快速定位 · ${widget.title}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                Theme.of(context).hintColor)),
                                    Text(widget.labels[selected],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13)),
                                  ])),
                              const BeeLineIcon('ChevronDown', size: 16)
                            ]))),
                    const SizedBox(height: 7),
                    Text('${widget.labels.length} 组组件 · 全部平铺',
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).hintColor)),
                    Tooltip(
                        message: widget.event,
                        child: Text(widget.event,
                            key: ValueKey('${widget.id}-event'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: Theme.of(context).hintColor))),
                  ]))),
      Expanded(
          child: Scrollbar(
              controller: scroll,
              child: SingleChildScrollView(
                  key: ValueKey('${widget.id}-catalog-scroll'),
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(17, 4, 17, 24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children:
                          List.generate(widget.labels.length, section))))),
    ]);
  }
}
