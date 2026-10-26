import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeConfigurationChoice {
  const BeeConfigurationChoice(
      {required this.id, required this.label, this.detail});
  final String id, label;
  final String? detail;
}

/// Controlled options; parsing, secrets and the actual transfer stay in the App.
class BeeConfigurationOptions extends StatelessWidget {
  const BeeConfigurationOptions(
      {super.key,
      required this.items,
      required this.selected,
      required this.onChanged});
  final List<BeeConfigurationChoice> items;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        for (final item in items)
          BeeCheckTile(
              label: item.label,
              subtitle: item.detail,
              value: selected.contains(item.id),
              onChanged: (value) {
                final next = {...selected};
                value ? next.add(item.id) : next.remove(item.id);
                onChanged(next);
              })
      ]);
}

/// Selectable YAML preview with bounded height inside the standard dialog.
class BeeConfigurationPreview extends StatelessWidget {
  const BeeConfigurationPreview(
      {super.key,
      required this.content,
      required this.label,
      this.maxHeight = 220});
  final String content, label;
  final double maxHeight;
  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: BeeCardTheme.of(context).soft,
              borderRadius: BorderRadius.circular(13)),
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
              child: SelectableText(content,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11, height: 1.6)))));
}
