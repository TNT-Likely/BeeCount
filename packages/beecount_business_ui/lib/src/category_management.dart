import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

/// The host resolves category names, images, counts and mutations.
class BeeManagedCategory {
  const BeeManagedCategory(
      {required this.id,
      required this.name,
      required this.icon,
      required this.detail,
      this.children = const [],
      this.isDefault = false});
  final String id, name, detail;
  final Widget icon;
  final List<BeeManagedCategory> children;
  final bool isDefault;
}

class BeeCategoryManagementList extends StatefulWidget {
  const BeeCategoryManagementList(
      {super.key,
      required this.items,
      required this.onEdit,
      required this.onManageChildren,
      required this.onReorder,
      required this.manageLabel,
      this.footer});
  final List<BeeManagedCategory> items;
  final ValueChanged<String> onEdit, onManageChildren;
  final ReorderCallback onReorder;
  final String manageLabel;
  final Widget? footer;
  @override
  State<BeeCategoryManagementList> createState() =>
      _BeeCategoryManagementListState();
}

class _BeeCategoryManagementListState extends State<BeeCategoryManagementList> {
  final _expanded = <String>{};
  @override
  Widget build(BuildContext context) => ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(
          17, 8, 17, 24 + MediaQuery.paddingOf(context).bottom),
      buildDefaultDragHandles: false,
      itemCount: widget.items.length,
      onReorder: widget.onReorder,
      footer: widget.footer,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final expanded = _expanded.contains(item.id);
        final color = Theme.of(context).colorScheme.onSurface;
        return Padding(
            key: ValueKey(item.id),
            padding: EdgeInsets.zero,
            child: BeeSurface(
                borderRadius: BorderRadius.vertical(
                    top: index == 0 ? const Radius.circular(22) : Radius.zero,
                    bottom: index == widget.items.length - 1
                        ? const Radius.circular(22)
                        : Radius.zero),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                    color: BeeCardTheme.of(context).soft,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Center(child: item.icon)))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: InkWell(
                            onTap: item.children.isEmpty
                                ? () => widget.onEdit(item.id)
                                : () => setState(() => expanded
                                    ? _expanded.remove(item.id)
                                    : _expanded.add(item.id)),
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Flexible(
                                            child: Text(item.name,
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    color: color))),
                                        if (item.children.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          BeeLineIcon(
                                              expanded
                                                  ? 'ChevronUp'
                                                  : 'ChevronDown',
                                              size: 14)
                                        ]
                                      ]),
                                      const SizedBox(height: 3),
                                      Text(item.detail,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  Theme.of(context).hintColor)),
                                    ])))),
                    if (item.isDefault) const BeeLineIcon('Check', size: 15),
                    IconButton(
                        onPressed: () => widget.onEdit(item.id),
                        icon: const BeeLineIcon('ChevronRight', size: 17)),
                  ]),
                  if (expanded)
                    Padding(
                        padding: const EdgeInsets.fromLTRB(42, 0, 0, 10),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(spacing: 6, runSpacing: 6, children: [
                              ...item.children.map((child) => Material(
                                  color: BeeCardTheme.of(context).soft,
                                  borderRadius: BorderRadius.circular(11),
                                  child: InkWell(
                                      onTap: () => widget.onEdit(child.id),
                                      borderRadius: BorderRadius.circular(11),
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 9),
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                    width: 15,
                                                    height: 15,
                                                    child: child.icon),
                                                const SizedBox(width: 6),
                                                Text(child.name,
                                                    style: const TextStyle(
                                                        fontSize: 12))
                                              ]))))),
                              TextButton.icon(
                                  onPressed: () =>
                                      widget.onManageChildren(item.id),
                                  icon:
                                      const BeeLineIcon('Settings2', size: 15),
                                  label: Text(widget.manageLabel)),
                            ]))),
                  if (index < widget.items.length - 1)
                    Padding(
                        padding: const EdgeInsets.only(left: 46),
                        child: Divider(
                            height: 1,
                            thickness: .6,
                            color: Theme.of(context).dividerColor)),
                ])));
      });
}
