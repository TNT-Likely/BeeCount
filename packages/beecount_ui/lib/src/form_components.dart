import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../beecount_ui.dart';

/// Keep IME preedit intact. Normalize unambiguous full stops on commit;
/// range/precision validation belongs to the host form.
class BeeDecimalInputFormatter extends TextInputFormatter {
  const BeeDecimalInputFormatter({this.maxFractionDigits})
      : assert(maxFractionDigits == null || maxFractionDigits >= 0);
  final int? maxFractionDigits;
  static String normalize(String text) =>
      text.replaceAll('。', '.').replaceAll('．', '.');
  static final _digits = FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'));
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final normalized = _digits.formatEditUpdate(
        oldValue, newValue.copyWith(text: normalize(newValue.text)));
    if (maxFractionDigits == null) return normalized;
    return FilteringTextInputFormatter.allow(
            RegExp('^\\d+\\.?\\d{0,$maxFractionDigits}'))
        .formatEditUpdate(oldValue, normalized);
  }
}

/// Owns a controller only when the host does not provide one.
class BeeSearchField extends StatefulWidget {
  const BeeSearchField(
      {super.key,
      required this.hint,
      required this.onChanged,
      this.controller,
      this.clearLabel,
      this.enabled = true,
      this.autofocus = false,
      this.onSubmitted});
  final String hint;
  final String? clearLabel;
  final bool enabled, autofocus;
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
          builder: (context, value, _) => Semantics(
              container: true,
              child: TextField(
                  controller: controller,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                      hintText: widget.hint,
                      filled: true,
                      fillColor: BeeCardTheme.of(context).soft,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide.none),
                      disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.2)),
                      prefixIcon: const Padding(
                          padding: EdgeInsets.all(14),
                          child: BeeLineIcon('Search', size: 18)),
                      suffixIcon:
                          widget.clearLabel != null && value.text.isNotEmpty
                              ? BeeIconButton(
                                  label: widget.clearLabel!,
                                  icon: const BeeLineIcon('X', size: 18),
                                  onPressed: widget.enabled
                                      ? () {
                                          controller.clear();
                                          widget.onChanged('');
                                        }
                                      : null)
                              : null))));
}

class BeeToggleRow extends StatelessWidget {
  const BeeToggleRow(
      {super.key,
      required this.title,
      required this.value,
      required this.onChanged,
      this.subtitle,
      this.leading});
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), cards = BeeCardTheme.of(context);
    final accent = theme.colorScheme.primary;
    final ink = theme.colorScheme.onPrimary;
    const scale = 36 / 52;
    return MergeSemantics(
        child: Semantics(
            toggled: value,
            enabled: onChanged != null,
            child: Opacity(
                opacity: onChanged == null ? .4 : 1,
                child: InkWell(
                    onTap: onChanged == null ? null : () => onChanged!(!value),
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(children: [
                          if (leading != null) ...[
                            SizedBox(width: 28, child: leading!),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(title,
                                    style: const TextStyle(
                                        fontSize: 14, height: 1.4)),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(subtitle!,
                                      style: TextStyle(
                                          fontSize: 11,
                                          height: 1.5,
                                          color: theme.hintColor))
                                ]
                              ])),
                          const SizedBox(width: 12),
                          SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                  child: Transform.scale(
                                      scale: scale,
                                      child: Switch(
                                          value: value,
                                          onChanged: onChanged,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          trackOutlineWidth:
                                              WidgetStatePropertyAll(1 / scale),
                                          trackOutlineColor:
                                              WidgetStatePropertyAll(value
                                                  ? accent
                                                  : theme.hintColor),
                                          trackColor: WidgetStatePropertyAll(
                                              value ? accent : cards.soft),
                                          thumbColor:
                                              const WidgetStatePropertyAll(
                                                  Colors.transparent),
                                          thumbIcon: WidgetStatePropertyAll(
                                              Icon(Icons.circle,
                                                  size: 14 / scale,
                                                  color: value
                                                      ? ink
                                                      : theme.hintColor))))))
                        ]))))));
  }
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
