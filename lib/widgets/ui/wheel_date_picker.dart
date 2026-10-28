import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

enum WheelDatePickerMode { y, ym, ymd }

/// App adapter: localized labels and result/cancellation stay here; wheels live in beecount_ui.
class WheelDatePicker extends StatefulWidget {
  const WheelDatePicker(
      {super.key,
      required this.initial,
      this.mode = WheelDatePickerMode.ymd,
      this.minDate,
      this.maxDate,
      this.confirmLabel});
  final DateTime initial;
  final WheelDatePickerMode mode;
  final DateTime? minDate, maxDate;
  final String? confirmLabel;
  @override
  State<WheelDatePicker> createState() => _WheelDatePickerState();
}

class _WheelDatePickerState extends State<WheelDatePicker> {
  late DateTime date = _clamp(widget.initial);
  DateTime _clamp(DateTime value) {
    final lo = widget.minDate ?? DateTime(2000);
    final hi = widget.maxDate ?? DateTime(2100, 12, 31);
    return value.isBefore(lo)
        ? lo
        : value.isAfter(hi)
            ? hi
            : value;
  }

  DateTime get result => _clamp(switch (widget.mode) {
        WheelDatePickerMode.y => DateTime(date.year),
        WheelDatePickerMode.ym => DateTime(date.year, date.month),
        WheelDatePickerMode.ymd => DateTime(date.year, date.month, date.day)
      });
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BeeDateWheels(
                value: date,
                minYear: 2000,
                maxYear: 2100,
                minimum: widget.minDate,
                maximum: widget.maxDate,
                showMonth: widget.mode != WheelDatePickerMode.y,
                showDay: widget.mode == WheelDatePickerMode.ymd,
                onChanged: (v) => setState(() => date = v)),
            const SizedBox(height: 16),
            BeeButton(
                label: widget.confirmLabel ??
                    AppLocalizations.of(context).commonConfirm,
                onPressed: () => Navigator.pop(context, result)),
          ]);
}

Future<DateTime?> showWheelDatePicker(BuildContext context,
        {required DateTime initial,
        WheelDatePickerMode mode = WheelDatePickerMode.ymd,
        DateTime? minDate,
        DateTime? maxDate,
        String? confirmLabel}) =>
    showBeeSheet<DateTime>(context,
        title: AppLocalizations.of(context).homeSelectDate,
        child: WheelDatePicker(
            initial: initial,
            mode: mode,
            minDate: minDate,
            maxDate: maxDate,
            confirmLabel: confirmLabel));

/// Preserve the original two-step, second-precision workflow and cancel semantics.
Future<DateTime?> showWheelDateTimePicker(BuildContext context,
    {required DateTime initial, DateTime? maxDate}) async {
  final date = await showWheelDatePicker(context,
      initial: initial,
      maxDate: maxDate,
      confirmLabel: AppLocalizations.of(context).commonNext);
  if (date == null || !context.mounted) return null;
  var time = TimeOfDay.fromDateTime(initial);
  var second = initial.second;
  final clock = await showBeeSheet<DateTime>(context,
      title: AppLocalizations.of(context).commonSelectTime,
      child: StatefulBuilder(
          builder: (ctx, update) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BeeTimeWheels(
                        value: time,
                        second: second,
                        onChanged: (v) => update(() => time = v),
                        onSecondChanged: (v) => update(() => second = v)),
                    const SizedBox(height: 16),
                    BeeButton(
                        label: AppLocalizations.of(ctx).commonConfirm,
                        onPressed: () => Navigator.pop(
                            ctx,
                            DateTime(date.year, date.month, date.day, time.hour,
                                time.minute, second))),
                  ])));
  return clock;
}
