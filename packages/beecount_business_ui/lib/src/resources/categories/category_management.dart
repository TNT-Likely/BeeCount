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
      required this.reorderLabel,
      this.empty,
      this.footer});
  final List<BeeManagedCategory> items;
  final ValueChanged<String> onEdit, onManageChildren;
  final ReorderCallback onReorder;
  final String manageLabel, reorderLabel;
  final Widget? empty, footer;
  @override
  State<BeeCategoryManagementList> createState() =>
      _BeeCategoryManagementListState();
}

class _BeeCategoryManagementListState extends State<BeeCategoryManagementList> {
  final _expanded = <String>{};
  Widget _chip(BuildContext context, String label, Widget icon,
          VoidCallback onTap) =>
      Semantics(
          button: true,
          label: label,
          onTap: onTap,
          child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: onTap,
              child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: ExcludeSemantics(
                          child: Material(
                              color: BeeCardTheme.of(context).soft,
                              borderRadius: BorderRadius.circular(11),
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 9),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                            width: 15, height: 15, child: icon),
                                        const SizedBox(width: 6),
                                        Flexible(
                                            child: Text(label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12)))
                                      ]))))))));

  @override
  Widget build(BuildContext context) => ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(
          17, 8, 17, 24 + MediaQuery.paddingOf(context).bottom),
      buildDefaultDragHandles: false,
      itemCount: widget.items.length,
      onReorder: widget.onReorder,
      header: widget.items.isEmpty ? widget.empty : null,
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
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                                color: BeeCardTheme.of(context).soft,
                                borderRadius: BorderRadius.circular(12)),
                            child: Center(child: item.icon))),
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
                    Semantics(
                        label: '${widget.reorderLabel} ${item.name}',
                        child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: ReorderableDragStartListener(
                                key: ValueKey('category-reorder-${item.id}'),
                                index: index,
                                // The complete trailing area accepts a drag.
                                // Do not add a long-press Tooltip here: it
                                // competes with holding and moving the handle.
                                child: SizedBox(
                                    width: 48,
                                    height: 60,
                                    child: ColoredBox(
                                        color: Colors.transparent,
                                        child: Center(
                                            child: Container(
                                                width: 32,
                                                height: 38,
                                                decoration: BoxDecoration(
                                                    color:
                                                        BeeCardTheme.of(context)
                                                            .soft,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                child: Center(
                                                    child: BeeLineIcon(
                                                        'GripVertical',
                                                        size: 20,
                                                        color: Theme.of(context)
                                                            .hintColor))))))))),
                  ]),
                  if (expanded)
                    Padding(
                        padding: const EdgeInsets.fromLTRB(42, 0, 0, 10),
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(spacing: 6, runSpacing: 6, children: [
                              ...item.children.map((child) => _chip(
                                  context,
                                  child.name,
                                  child.icon,
                                  () => widget.onEdit(child.id))),
                              _chip(
                                  context,
                                  widget.manageLabel,
                                  const BeeLineIcon('Settings2', size: 15),
                                  () => widget.onManageChildren(item.id)),
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

/// The host owns parent actions and the dialog scroll boundary.
/// All child names, original/custom icons, counts and edit callbacks are supplied.
class BeeCategoryChildrenGrid extends StatelessWidget {
  const BeeCategoryChildrenGrid({
    super.key,
    required this.items,
    required this.emptyLabel,
    required this.onEdit,
  });
  final List<BeeManagedCategory> items;
  final String emptyLabel;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final scaler = MediaQuery.textScalerOf(context);
        final height = 51 + scaler.scale(12) * 2.8 + scaler.scale(10) * 1.4;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          if (items.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(emptyLabel,
                    style: TextStyle(
                        fontSize: 13, color: Theme.of(context).hintColor)))
          else
            GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: bounds.maxWidth < 300 ? 3 : 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: height),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Semantics(
                      button: true,
                      label: '${item.name}，${item.detail}',
                      child: InkWell(
                          onTap: () => onEdit(item.id),
                          borderRadius: BorderRadius.circular(13),
                          child: ExcludeSemantics(
                              child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Column(children: [
                                    Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                            color:
                                                BeeCardTheme.of(context).soft,
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        padding: const EdgeInsets.all(8),
                                        child: item.icon),
                                    const SizedBox(height: 5),
                                    Text(item.name,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12, height: 1.4)),
                                    Text(item.detail,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 10,
                                            height: 1.4,
                                            color: Theme.of(context).hintColor))
                                  ])))));
                }),
        ]);
      });
}
