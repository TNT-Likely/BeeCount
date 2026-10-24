import 'package:flutter/material.dart';
import '../beecount_ui.dart';

class BeeColorOption<T> {
  const BeeColorOption(
      {required this.value, required this.color, required this.label});
  final T value;
  final Color color;
  final String label;
}

/// A controlled palette with a stable 44px target. Color identity and labels are
/// supplied by the host; neither selection nor disabled state changes the hue.
class BeeColorPalette<T> extends StatelessWidget {
  const BeeColorPalette(
      {super.key,
      required this.items,
      required this.value,
      required this.onChanged,
      this.showLabels = false});
  final List<BeeColorOption<T>> items;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool showLabels;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, box) => Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in items)
              Semantics(
                  label: item.label,
                  selected: item.value == value,
                  button: true,
                  enabled: onChanged != null,
                  child: ExcludeSemantics(
                      child: Tooltip(
                          message: item.label,
                          child: Opacity(
                              opacity: onChanged == null ? .42 : 1,
                              child: InkWell(
                                  borderRadius: BorderRadius.circular(13),
                                  onTap: onChanged == null
                                      ? null
                                      : () => onChanged!(item.value),
                                  child: SizedBox(
                                      width: showLabels
                                          ? (box.maxWidth - 16) / 3
                                          : 44,
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                                width: 44,
                                                height: 44,
                                                child: Center(
                                                    child: Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration: BoxDecoration(
                                                            color: item.color,
                                                            shape:
                                                                BoxShape.circle,
                                                            border: item.value ==
                                                                    value
                                                                ? Border.all(
                                                                    color: Theme.of(context)
                                                                        .colorScheme
                                                                        .onSurface,
                                                                    width: 2)
                                                                : null),
                                                        child: item.value == value
                                                            ? Icon(Icons.check,
                                                                size: 20,
                                                                color: item.color
                                                                            .computeLuminance() >
                                                                        .5
                                                                    ? Colors
                                                                        .black
                                                                    : Colors
                                                                        .white)
                                                            : null))),
                                            if (showLabels)
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          3, 4, 3, 8),
                                                  child: Text(item.label,
                                                      textAlign:
                                                          TextAlign.center,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 12))),
                                          ])))))))
          ]));
}

class BeeChoice<T> {
  const BeeChoice(
      {required this.value,
      required this.title,
      this.subtitle,
      this.leading,
      this.searchText = ''});
  final T value;
  final String title, searchText;
  final String? subtitle;
  final Widget? leading;
}

class BeeChoicePicker<T> extends StatefulWidget {
  const BeeChoicePicker(
      {super.key,
      required this.items,
      required this.selected,
      required this.searchLabel,
      required this.emptyLabel,
      required this.onSelected,
      this.loading = false,
      this.error,
      this.onRetry,
      this.retryLabel});
  final List<BeeChoice<T>> items;
  final T? selected;
  final String searchLabel, emptyLabel;
  final ValueChanged<T> onSelected;
  final bool loading;
  final String? error, retryLabel;
  final VoidCallback? onRetry;
  @override
  State<BeeChoicePicker<T>> createState() => _BeeChoicePickerState<T>();
}

class _BeeChoicePickerState<T> extends State<BeeChoicePicker<T>> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where((i) => '${i.title} ${i.subtitle ?? ''} ${i.searchText}'
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      BeeSearchField(
          hint: widget.searchLabel,
          onChanged: (v) => setState(() => query = v)),
      const SizedBox(height: 8),
      if (widget.loading)
        const Padding(
            padding: EdgeInsets.all(24), child: CircularProgressIndicator())
      else if (widget.error != null)
        BeeStatus(
            label: widget.error!,
            tone: BeeTone.error,
            action: widget.onRetry == null
                ? null
                : BeeButton(
                    label: widget.retryLabel ?? '', onPressed: widget.onRetry))
      else
        Flexible(
            child: items.isEmpty
                ? BeeEmptyState(title: widget.emptyLabel)
                : ListView(
                    shrinkWrap: true,
                    children: items
                        .map((i) => BeeMenuRow(
                            title: i.title,
                            subtitle: i.subtitle,
                            leading: i.leading,
                            selected: i.value == widget.selected,
                            onTap: () => widget.onSelected(i.value),
                            divider: true))
                        .toList())),
    ]);
  }
}

class BeeValidatedInput extends StatefulWidget {
  const BeeValidatedInput(
      {super.key,
      required this.label,
      required this.initial,
      required this.confirmLabel,
      required this.cancelLabel,
      required this.validate,
      required this.onConfirm,
      required this.onCancel,
      this.helper,
      this.keyboardType,
      this.maxLength});
  final String label, initial, confirmLabel, cancelLabel;
  final String? helper;
  final String? Function(String) validate;
  final ValueChanged<String> onConfirm;
  final VoidCallback onCancel;
  final TextInputType? keyboardType;
  final int? maxLength;
  @override
  State<BeeValidatedInput> createState() => _BeeValidatedInputState();
}

class _BeeValidatedInputState extends State<BeeValidatedInput> {
  late final controller = TextEditingController(text: widget.initial);
  bool touched = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.validate(controller.text.trim());
    return Column(mainAxisSize: MainAxisSize.min, children: [
      BeeField(
          label: widget.label,
          controller: controller,
          helper: widget.helper,
          error: touched ? error : null,
          keyboardType: widget.keyboardType,
          maxLength: widget.maxLength,
          onChanged: (_) => setState(() => touched = true)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
            child: BeeButton(
                label: widget.cancelLabel,
                kind: BeeButtonKind.secondary,
                onPressed: widget.onCancel)),
        const SizedBox(width: 8),
        Expanded(
            child: BeeButton(
                label: widget.confirmLabel,
                onPressed: error == null
                    ? () => widget.onConfirm(controller.text.trim())
                    : null))
      ])
    ]);
  }
}

class BeeDateWheels extends StatelessWidget {
  const BeeDateWheels(
      {super.key,
      required this.value,
      required this.onChanged,
      this.minYear = 1970,
      this.maxYear = 2100,
      this.showDay = true,
      this.showTime = false});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final int minYear, maxYear;
  final bool showDay, showTime;
  void change({int? year, int? month, int? day, int? hour, int? minute}) {
    final y = year ?? value.year, m = month ?? value.month;
    final d = (day ?? value.day).clamp(1, DateUtils.getDaysInMonth(y, m));
    onChanged(DateTime(y, m, d, hour ?? value.hour, minute ?? value.minute));
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            flex: 3,
            child: BeeWheel<int>(
                values:
                    List.generate(maxYear - minYear + 1, (i) => minYear + i),
                value: value.year,
                label: (v) => '$v',
                onChanged: (v) => change(year: v))),
        Expanded(
            flex: 2,
            child: BeeWheel<int>(
                values: List.generate(12, (i) => i + 1),
                value: value.month,
                label: (v) => '$v',
                onChanged: (v) => change(month: v))),
        if (showDay)
          Expanded(
              flex: 2,
              child: BeeWheel<int>(
                  values: List.generate(
                      DateUtils.getDaysInMonth(value.year, value.month),
                      (i) => i + 1),
                  value: value.day,
                  label: (v) => '$v',
                  onChanged: (v) => change(day: v))),
        if (showTime) ...[
          Expanded(
              flex: 2,
              child: BeeWheel<int>(
                  values: List.generate(24, (i) => i),
                  value: value.hour,
                  label: (v) => v.toString().padLeft(2, '0'),
                  onChanged: (v) => change(hour: v))),
          Expanded(
              flex: 2,
              child: BeeWheel<int>(
                  values: List.generate(60, (i) => i),
                  value: value.minute,
                  label: (v) => v.toString().padLeft(2, '0'),
                  onChanged: (v) => change(minute: v)))
        ],
      ]);
}

class BeeIconChoice<T> {
  const BeeIconChoice(
      {required this.value,
      required this.label,
      required this.icon,
      this.enabled = true});
  final T value;
  final String label;
  final Widget icon;
  final bool enabled;
}

/// Compact icon selection for account types and icon libraries.
class BeeIconChoiceGrid<T> extends StatelessWidget {
  const BeeIconChoiceGrid(
      {super.key,
      required this.items,
      required this.value,
      required this.onChanged,
      this.columns = 4,
      this.showLabels = true});
  final List<BeeIconChoice<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  final int columns;
  final bool showLabels;
  @override
  Widget build(BuildContext context) => GridView.count(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: showLabels ? 1.05 : 1,
      children: items
          .map((item) => Semantics(
              label: showLabels ? null : item.label,
              selected: item.value == value,
              enabled: item.enabled,
              button: true,
              child: Opacity(
                  opacity: item.enabled ? 1 : .4,
                  child: Material(
                      color: item.value == value
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: .12)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                          side: BorderSide(
                              color: item.value == value
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent)),
                      child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap:
                              item.enabled ? () => onChanged(item.value) : null,
                          child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: item.icon),
                                    if (showLabels) const SizedBox(height: 5),
                                    if (showLabels)
                                      Flexible(
                                          child: Text(item.label,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 11))),
                                  ])))))))
          .toList());
}

/// A controlled 24-hour picker. The host owns its draft and confirm/cancel;
/// changing either wheel never persists preferences or schedules a reminder.
class BeeTimeWheels extends StatelessWidget {
  const BeeTimeWheels(
      {super.key, required this.value, required this.onChanged});
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: BeeWheel<int>(
                values: List.generate(24, (i) => i),
                value: value.hour,
                label: (v) => v.toString().padLeft(2, '0'),
                onChanged: (v) =>
                    onChanged(TimeOfDay(hour: v, minute: value.minute)))),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(':',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
        Expanded(
            child: BeeWheel<int>(
                values: List.generate(60, (i) => i),
                value: value.minute,
                label: (v) => v.toString().padLeft(2, '0'),
                onChanged: (v) =>
                    onChanged(TimeOfDay(hour: value.hour, minute: v)))),
      ]);
}
