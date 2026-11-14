import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeAction {
  const BeeAction(
      {required this.id,
      required this.label,
      required this.icon,
      this.danger = false});
  final String id, label;
  final Widget icon;
  final bool danger;
}

class BeeActionMenu extends StatelessWidget {
  const BeeActionMenu(
      {super.key, required this.actions, required this.onSelected});
  final List<BeeAction> actions;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: actions
          .map((a) => BeeMenuRow(
              title: a.label,
              leading: a.icon,
              danger: a.danger,
              onTap: () => onSelected(a.id)))
          .toList());
}
