import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../shared/action_menu.dart';

class BeeQuickAdd extends StatelessWidget {
  const BeeQuickAdd(
      {super.key,
      required this.actions,
      required this.onSelected,
      required this.cancelLabel,
      required this.onCancel});
  final List<BeeAction> actions;
  final ValueChanged<String> onSelected;
  final String cancelLabel;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: actions
                .map((a) => SizedBox(
                    width: 86,
                    child: BeeButton(
                        label: a.label,
                        icon: a.icon,
                        kind: BeeButtonKind.secondary,
                        onPressed: () => onSelected(a.id))))
                .toList()),
        const SizedBox(height: 12),
        BeeButton(
            label: cancelLabel, kind: BeeButtonKind.quiet, onPressed: onCancel)
      ]);
}
