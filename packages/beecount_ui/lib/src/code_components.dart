import 'package:flutter/material.dart';
import '../beecount_ui.dart';

/// Selectable, wrapping source text; callers own content and persistence.
class BeeCodeBlock extends StatelessWidget {
  const BeeCodeBlock({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: BeeCardTheme.of(context).soft,
          borderRadius: BorderRadius.circular(13)),
      child: SelectableText(text,
          style: const TextStyle(
              fontSize: 13, height: 1.5, fontFamily: 'monospace')));
}

/// Multi-line template/source input, with an external accessible label.
class BeeCodeEditor extends StatelessWidget {
  const BeeCodeEditor(
      {super.key,
      required this.label,
      required this.controller,
      this.hint,
      this.onChanged,
      this.minLines = 10,
      this.maxLines = 20,
      this.readOnly = false});
  final String label;
  final String? hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int minLines, maxLines;
  final bool readOnly;
  @override
  Widget build(BuildContext context) => BeeField(
      label: label,
      showLabel: false,
      controller: controller,
      hint: hint,
      minLines: minLines,
      maxLines: maxLines,
      readOnly: readOnly,
      onChanged: onChanged,
      keyboardType: TextInputType.multiline,
      textStyle:
          const TextStyle(fontSize: 13, height: 1.5, fontFamily: 'monospace'));
}
