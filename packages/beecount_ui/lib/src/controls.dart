import 'dart:async';
import 'package:flutter/material.dart';
import '../beecount_ui.dart';

class BeeMenuAction<T> {
  const BeeMenuAction(
      {required this.value,
      required this.label,
      this.icon,
      this.enabled = true,
      this.danger = false});
  final T value;
  final String label;
  final Widget? icon;
  final bool enabled, danger;
}

Future<T?> showBeeContextMenu<T>(BuildContext context,
    {required Offset anchor, required List<BeeMenuAction<T>> items}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final point = overlay.globalToLocal(anchor);
  return showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(point.dx, point.dy,
          overlay.size.width - point.dx, overlay.size.height - point.dy),
      color: BeeCardTheme.of(context).surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: items
          .map((item) => PopupMenuItem<T>(
              value: item.value,
              enabled: item.enabled,
              height: 44,
              child: Row(children: [
                if (item.icon != null) ...[
                  SizedBox(width: 20, child: item.icon),
                  const SizedBox(width: 10)
                ],
                Flexible(
                    child: Text(item.label,
                        style: TextStyle(
                            fontSize: 13,
                            color: item.danger
                                ? Theme.of(context).colorScheme.error
                                : null)))
              ])))
          .toList());
}

class BeeMenuButton<T> extends StatelessWidget {
  const BeeMenuButton(
      {super.key,
      required this.label,
      required this.items,
      required this.onSelected});
  final String label;
  final List<BeeMenuAction<T>> items;
  final ValueChanged<T> onSelected;
  @override
  Widget build(BuildContext context) => Builder(
      builder: (context) => BeeIconButton(
          label: label,
          icon: const BeeLineIcon('Ellipsis'),
          onPressed: () async {
            final box = context.findRenderObject()! as RenderBox;
            final value = await showBeeContextMenu<T>(context,
                anchor:
                    box.localToGlobal(Offset(box.size.width, box.size.height)),
                items: items);
            if (value != null) onSelected(value);
          }));
}

/// Transient, non-blocking feedback. Persistent errors use BeeStatus + retry.
/// Matches the feedback spec: inverse surface, 14 radius, 20 icon, 13 text.
class BeeToast extends StatelessWidget {
  const BeeToast(
      {super.key, required this.message, this.tone = BeeTone.neutral});
  final String message;
  final BeeTone tone;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xff262829) : Colors.white;
    final semantic = switch (tone) {
      BeeTone.success =>
        dark ? const Color(0xff38845c) : const Color(0xff9bd8b5),
      BeeTone.error => dark ? const Color(0xffb54242) : const Color(0xffffb3b3),
      BeeTone.warning =>
        dark ? const Color(0xff88620c) : const Color(0xfff5d580),
      _ => ink,
    };
    return Semantics(
        liveRegion: true,
        child: Material(
            color: dark ? const Color(0xfff0f1ed) : const Color(0xff262829),
            borderRadius: BorderRadius.circular(14),
            elevation: 4,
            shadowColor: Colors.black26,
            child: Container(
                constraints: const BoxConstraints(minHeight: 44, maxWidth: 340),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (tone == BeeTone.busy)
                    SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: ink))
                  else
                    BeeLineIcon(
                        switch (tone) {
                          BeeTone.success => 'CircleCheck',
                          BeeTone.error => 'CircleAlert',
                          _ => 'Info'
                        },
                        size: 20,
                        color: semantic),
                  const SizedBox(width: 8),
                  Flexible(
                      child: Text(message,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: ink, fontSize: 13, height: 1.5))),
                ]))));
  }
}

final _activeToasts = Expando<VoidCallback>('bee-toast');

/// One toast per overlay; the returned dismiss function is idempotent.
VoidCallback showBeeToast(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 2),
    BeeTone tone = BeeTone.neutral}) {
  final overlay = Overlay.of(context);
  // Capture inherited themes now; the caller may leave before the toast expires.
  final themes = InheritedTheme.capture(from: context, to: overlay.context);
  return _showBeeToast(
      overlay, themes.wrap(BeeToast(message: message, tone: tone)), duration);
}

/// Global services can use the navigator overlay without a descendant context.
VoidCallback showBeeToastOnOverlay(OverlayState overlay, String message,
    {Duration duration = const Duration(seconds: 2),
    BeeTone tone = BeeTone.neutral,
    Brightness? brightness}) {
  final theme = Theme.of(overlay.context);
  return _showBeeToast(
      overlay,
      Theme(
          data: brightness == null
              ? theme
              : theme.copyWith(brightness: brightness),
          child: BeeToast(message: message, tone: tone)),
      duration);
}

VoidCallback _showBeeToast(
    OverlayState overlay, Widget toast, Duration duration) {
  _activeToasts[overlay]?.call();
  var closed = false;
  Timer? timer;
  late OverlayEntry entry;
  void close() {
    if (closed) return;
    closed = true;
    timer?.cancel();
    if (identical(_activeToasts[overlay], close)) _activeToasts[overlay] = null;
    entry.remove();
    entry.dispose();
  }

  entry = OverlayEntry(
      builder: (_) => Positioned.fill(
          child: IgnorePointer(
              child: SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Align(
                          alignment: Alignment.topCenter, child: toast))))));
  overlay.insert(entry);
  _activeToasts[overlay] = close;
  timer = Timer(duration, close);
  return close;
}

class BeeRadioTile<T> extends StatelessWidget {
  const BeeRadioTile(
      {super.key,
      required this.label,
      required this.value,
      required this.groupValue,
      required this.onChanged,
      this.subtitle});
  final String label;
  final String? subtitle;
  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  @override
  Widget build(BuildContext context) => RadioListTile<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged == null
          ? null
          : (v) {
              if (v != null) onChanged!(v);
            },
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 11)),
      activeColor: Theme.of(context).colorScheme.primary);
}

class BeeSliderField extends StatelessWidget {
  const BeeSliderField(
      {super.key,
      required this.label,
      required this.value,
      required this.valueLabel,
      required this.onChanged,
      this.min = 0,
      this.max = 1,
      this.divisions});
  final String label, valueLabel;
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(valueLabel, style: const TextStyle(fontSize: 12))
        ]),
        Slider(
            value: value.isFinite ? value.clamp(min, max) : min,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged)
      ]);
}

class BeeAccordion extends StatelessWidget {
  const BeeAccordion(
      {super.key,
      required this.title,
      required this.child,
      this.subtitle,
      this.initiallyExpanded = false});
  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 11)),
      children: [child]);
}

class BeeFilterBar extends StatelessWidget {
  const BeeFilterBar(
      {super.key,
      required this.filters,
      required this.onSelected,
      this.selected});
  final List<String> filters;
  final String? selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
          children: filters
              .map((v) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                      label: Text(v, style: const TextStyle(fontSize: 12)),
                      selected: selected == v,
                      selectedColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .16),
                      backgroundColor: BeeCardTheme.of(context).surface,
                      side: BorderSide(
                          color: selected == v
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                      onSelected: (_) => onSelected(v))))
              .toList()));
}

class BeeSelectField<T> extends StatelessWidget {
  const BeeSelectField(
      {super.key,
      required this.label,
      required this.items,
      required this.value,
      required this.onChanged,
      this.error});
  final String label;
  final List<BeeSegment<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? error;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: error),
      items: items
          .map((item) => DropdownMenuItem(
              value: item.value,
              child: Text(item.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: onChanged);
}
