import 'package:flutter/material.dart';
import '../beecount_ui.dart';

/// Owns a controller only when the host does not provide one.
class BeeSearchField extends StatefulWidget {
  const BeeSearchField(
      {super.key,
      required this.hint,
      required this.onChanged,
      this.controller,
      this.clearLabel,
      this.enabled = true,
      this.onSubmitted});
  final String hint;
  final String? clearLabel;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  @override
  State<BeeSearchField> createState() => _BeeSearchFieldState();
}

class _BeeSearchFieldState extends State<BeeSearchField> {
  TextEditingController? owned;
  TextEditingController get controller =>
      widget.controller ?? (owned ??= TextEditingController());
  @override
  void dispose() {
    owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
              controller: controller,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                  hintText: widget.hint,
                  filled: true,
                  fillColor: BeeCardTheme.of(context).soft,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none),
                  prefixIcon: const Padding(
                      padding: EdgeInsets.all(14),
                      child: BeeLineIcon('Search', size: 18)),
                  suffixIcon: widget.clearLabel != null && value.text.isNotEmpty
                      ? BeeIconButton(
                          label: widget.clearLabel!,
                          icon: const BeeLineIcon('X', size: 18),
                          onPressed: widget.enabled
                              ? () {
                                  controller.clear();
                                  widget.onChanged('');
                                }
                              : null)
                      : null)));
}

class BeeToggleRow extends StatelessWidget {
  const BeeToggleRow(
      {super.key,
      required this.title,
      required this.value,
      required this.onChanged,
      this.subtitle});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 11)),
      value: value,
      onChanged: onChanged);
}

class BeeCheckTile extends StatelessWidget {
  const BeeCheckTile(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.subtitle,
      this.mixed = false});
  final bool mixed;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => CheckboxListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 11)),
      value: mixed ? null : value,
      tristate: mixed,
      onChanged: onChanged == null
          ? null
          : (v) => onChanged!(mixed ? true : v ?? false));
}

class BeeAvatar extends StatelessWidget {
  const BeeAvatar({super.key, required this.label, this.image, this.size = 48});
  final String label;
  final ImageProvider? image;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      image: true,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(size * .35),
          child: Container(
              width: size,
              height: size,
              color: BeeCardTheme.of(context).soft,
              child: image == null
                  ? const Center(child: BeeLineIcon('Baby'))
                  : Image(
                      image: image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) =>
                          const Center(child: BeeLineIcon('Baby'))))));
}

class BeeSkeleton extends StatelessWidget {
  const BeeSkeleton({super.key, required this.label, this.rows = 3});
  final String label;
  final int rows;
  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
          child: Column(
              children: List.generate(
                  rows,
                  (i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                                color: BeeCardTheme.of(context).soft,
                                borderRadius: BorderRadius.circular(12))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              FractionallySizedBox(
                                  widthFactor: .7,
                                  child: Container(
                                      height: 12,
                                      color: BeeCardTheme.of(context).soft)),
                              const SizedBox(height: 7),
                              FractionallySizedBox(
                                  widthFactor: .4,
                                  child: Container(
                                      height: 8,
                                      color: BeeCardTheme.of(context).soft))
                            ]))
                      ]))))));
}
