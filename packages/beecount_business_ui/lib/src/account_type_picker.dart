import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// The app supplies localized labels, brand icons and edit restrictions.
class BeeAccountTypeGroup {
  const BeeAccountTypeGroup(
      {required this.id, required this.label, required this.choices});
  final String id, label;
  final List<BeeIconChoice<String>> choices;
}

/// Browsing a different group does not change the selected account type.
class BeeAccountTypePicker extends StatelessWidget {
  const BeeAccountTypePicker(
      {super.key,
      required this.groups,
      required this.group,
      required this.value,
      required this.onGroupChanged,
      required this.onChanged});

  final List<BeeAccountTypeGroup> groups;
  final String group, value;
  final ValueChanged<String> onGroupChanged, onChanged;

  @override
  Widget build(BuildContext context) {
    final active = groups.singleWhere((item) => item.id == group);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      BeeSegmented<String>(
          items: groups
              .map((item) => BeeSegment<String>(item.id, item.label))
              .toList(),
          value: group,
          onChanged: onGroupChanged),
      const SizedBox(height: 12),
      LayoutBuilder(
          builder: (context, bounds) => BeeIconChoiceGrid<String>(
              items: active.choices,
              value: value,
              columns: bounds.maxWidth < 300 ? 3 : 4,
              onChanged: onChanged))
    ]);
  }
}
