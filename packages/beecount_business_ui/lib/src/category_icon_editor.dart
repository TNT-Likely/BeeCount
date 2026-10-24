import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

enum BeeCategoryIconSource { preset, custom }

class BeeCategoryIconGroup {
  const BeeCategoryIconGroup(
      {required this.id, required this.label, required this.items});
  final String id, label;
  final List<BeeIconChoice<String>> items;
}

/// Controlled icon/source selection. Image picking, cropping, files and saving
/// remain in the App; opening a group never changes the selected icon.
class BeeCategoryIconEditor extends StatefulWidget {
  const BeeCategoryIconEditor({
    super.key,
    required this.source,
    required this.value,
    required this.groups,
    required this.commonItems,
    required this.presetLabel,
    required this.customLabel,
    required this.commonLabel,
    required this.imageHint,
    required this.chooseImageLabel,
    required this.onSourceChanged,
    required this.onChanged,
    required this.onChooseImage,
    this.preview,
    this.loading = false,
    this.enabled = true,
  });
  final BeeCategoryIconSource source;
  final String value;
  final List<BeeCategoryIconGroup> groups;
  final List<BeeIconChoice<String>> commonItems;
  final String presetLabel,
      customLabel,
      commonLabel,
      imageHint,
      chooseImageLabel;
  final ValueChanged<BeeCategoryIconSource> onSourceChanged;
  final ValueChanged<String> onChanged;
  final VoidCallback onChooseImage;
  final Widget? preview;
  final bool loading, enabled;

  @override
  State<BeeCategoryIconEditor> createState() => _BeeCategoryIconEditorState();
}

class _BeeCategoryIconEditorState extends State<BeeCategoryIconEditor> {
  String group = '';
  @override
  void initState() {
    super.initState();
    if (!widget.commonItems.any((item) => item.value == widget.value)) {
      for (final candidate in widget.groups) {
        if (candidate.items.any((item) => item.value == widget.value)) {
          group = candidate.id;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = [
      BeeCategoryIconGroup(
          id: '', label: widget.commonLabel, items: widget.commonItems),
      ...widget.groups
    ];
    final active =
        all.firstWhere((g) => g.id == group, orElse: () => all.first);
    final enabled = widget.enabled && !widget.loading;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (final source in BeeCategoryIconSource.values) ...[
          if (source == BeeCategoryIconSource.custom) const SizedBox(width: 8),
          Expanded(
              child: BeeChoiceChip(
                  label: source == BeeCategoryIconSource.preset
                      ? widget.presetLabel
                      : widget.customLabel,
                  selected: source == widget.source,
                  onSelected:
                      enabled ? (_) => widget.onSourceChanged(source) : null))
        ]
      ]),
      const SizedBox(height: 12),
      if (widget.source == BeeCategoryIconSource.preset) ...[
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final candidate in all)
                Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: BeeChoiceChip(
                        compact: true,
                        label: candidate.label,
                        selected: active.id == candidate.id,
                        onSelected: enabled
                            ? (_) => setState(() => group = candidate.id)
                            : null))
            ])),
        const SizedBox(height: 8),
        LayoutBuilder(
            builder: (context, size) => BeeIconChoiceGrid<String>(
                items: active.items
                    .map((item) => BeeIconChoice<String>(
                        value: item.value,
                        label: item.label,
                        icon: item.icon,
                        enabled: enabled && item.enabled))
                    .toList(),
                value: widget.value,
                columns: ((size.maxWidth + 6) / 50).floor().clamp(1, 6),
                showLabels: false,
                onChanged: widget.onChanged))
      ] else ...[
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: BeeCardTheme.of(context).soft,
                borderRadius: BorderRadius.circular(13)),
            child: Row(children: [
              SizedBox(
                  width: 72,
                  height: 72,
                  child: widget.loading
                      ? const Center(
                          child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : widget.preview ??
                          const Center(
                              child: BeeLineIcon('ImagePlus', size: 28))),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(widget.imageHint,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: Theme.of(context).hintColor)))
            ])),
        const SizedBox(height: 12),
        BeeButton(
            label: widget.chooseImageLabel,
            icon: const BeeLineIcon('ImagePlus', size: 18),
            kind: BeeButtonKind.secondary,
            onPressed: enabled ? widget.onChooseImage : null)
      ]
    ]);
  }
}
