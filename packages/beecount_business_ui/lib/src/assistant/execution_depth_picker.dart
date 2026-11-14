import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

class BeeExecutionDepthOption {
  const BeeExecutionDepthOption(
      {required this.turns, required this.label, required this.description});
  final int turns;
  final String label, description;
}

/// Controlled execution policy choices; runtime limits and persistence stay in App.
class BeeExecutionDepthPicker extends StatelessWidget {
  const BeeExecutionDepthPicker(
      {super.key,
      required this.options,
      required this.selected,
      required this.onChanged});
  final List<BeeExecutionDepthOption> options;
  final int selected;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        for (final option in options)
          BeeRadioTile<int>(
              label: option.label,
              subtitle: option.description,
              value: option.turns,
              groupValue: selected,
              onChanged: onChanged)
      ]);
}
