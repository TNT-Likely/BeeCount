import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class WheelTimePicker extends StatefulWidget {
  const WheelTimePicker({super.key, required this.initial});
  final TimeOfDay initial;
  @override
  State<WheelTimePicker> createState() => _WheelTimePickerState();
}

class _WheelTimePickerState extends State<WheelTimePicker> {
  late TimeOfDay value = widget.initial;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BeeTimeWheels(
                value: value, onChanged: (v) => setState(() => value = v)),
            const SizedBox(height: 16),
            BeeButton(
                label: AppLocalizations.of(context).commonConfirm,
                onPressed: () => Navigator.pop(context, value)),
          ]);
}

Future<TimeOfDay?> showWheelTimePicker(BuildContext context,
        {required TimeOfDay initial}) =>
    showBeeSheet<TimeOfDay>(context,
        title: AppLocalizations.of(context).commonSelectTime,
        child: WheelTimePicker(initial: initial));
