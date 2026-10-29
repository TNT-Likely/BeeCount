import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../recording/recording_components.dart';
import '../../recording/subcategory_grid.dart';
import 'category_choice.dart';

/// Controlled hierarchy. The host supplies permission/eligibility decisions and
/// real counts; immediate selection is available for the original parent picker.
class BeeCategoryPicker extends StatefulWidget {
  const BeeCategoryPicker(
      {super.key,
      required this.items,
      required this.selected,
      required this.searchLabel,
      required this.emptyLabel,
      required this.confirmLabel,
      required this.cancelLabel,
      required this.onConfirm,
      required this.onCancel,
      this.immediate = false,
      this.expandAllChildren = false});
  final List<BeeCategoryChoice> items;
  final String? selected;
  final String searchLabel, emptyLabel, confirmLabel, cancelLabel;
  final ValueChanged<String> onConfirm;
  final VoidCallback onCancel;
  final bool immediate, expandAllChildren;
  @override
  State<BeeCategoryPicker> createState() => _BeeCategoryPickerState();
}

class _BeeCategoryPickerState extends State<BeeCategoryPicker> {
  late String? draft = widget.selected;
  String query = '';
  @override
  void didUpdateWidget(covariant BeeCategoryPicker old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) draft = widget.selected;
  }

  void choose(BeeCategoryChoice item, {bool direct = false}) {
    if (!item.enabled && item.children.isEmpty) return;
    if (widget.immediate) {
      if (!direct && item.children.isNotEmpty) {
        setState(() => draft = item.id);
      } else if (item.enabled) {
        widget.onConfirm(item.id);
      }
    } else {
      setState(() => draft = item.id);
    }
  }

  Widget tile(BeeCategoryChoice item) {
    final selected =
        item.id == draft || item.children.any((c) => c.id == draft);
    final navigable = item.enabled || item.children.isNotEmpty;
    return Semantics(
        enabled: navigable,
        child: Opacity(
            opacity: navigable ? 1 : .4,
            child: Column(children: [
              RecordingCategoryTile(
                  label: item.label,
                  icon: item.icon,
                  selected: selected,
                  onTap: navigable ? () => choose(item) : null),
              if (item.detail != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(item.detail!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10, color: Theme.of(context).hintColor)))
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visible = widget.items
        .where((i) =>
            i.label.toLowerCase().contains(q) ||
            i.children.any((c) => c.label.toLowerCase().contains(q)))
        .toList();
    final parent = visible
            .where((i) => i.id == draft || i.children.any((c) => c.id == draft))
            .firstOrNull ??
        visible.firstOrNull;
    final valid = widget.items.any((i) =>
        (i.id == draft && i.enabled) ||
        i.children.any((c) => c.id == draft && c.enabled));
    List<BeeCategoryChoice> childrenOf(BeeCategoryChoice parent) =>
        parent.children
            .where((c) =>
                q.isEmpty ||
                parent.label.toLowerCase().contains(q) ||
                c.label.toLowerCase().contains(q))
            .toList();
    List<Widget> childBlock(BeeCategoryChoice group) => [
          if (childrenOf(group).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: BeeCardTheme.of(context).soft,
                    borderRadius: BorderRadius.circular(14)),
                child: RecordingSubcategoryGrid(
                    items: [group, ...childrenOf(group)],
                    selected: draft,
                    onSelected: (id) => choose(
                        id == group.id
                            ? group
                            : group.children.firstWhere((c) => c.id == id),
                        direct: true)))
          ]
        ];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      BeeSearchField(
          hint: widget.searchLabel,
          onChanged: (v) => setState(() => query = v)),
      const SizedBox(height: 8),
      Expanded(
          child: visible.isEmpty
              ? BeeEmptyState(title: widget.emptyLabel)
              : SingleChildScrollView(
                  child: BeeSurface(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LayoutBuilder(builder: (context, constraints) {
                              Widget grid(List<BeeCategoryChoice> row) => Wrap(
                                  children: row
                                      .map((i) => SizedBox(
                                          width: constraints.maxWidth / 4,
                                          child: tile(i)))
                                      .toList());
                              if (widget.expandAllChildren) {
                                return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      grid(visible),
                                      for (final group in visible)
                                        ...childBlock(group),
                                    ]);
                              }
                              final rows = <Widget>[];
                              for (var start = 0;
                                  start < visible.length;
                                  start += 4) {
                                final row =
                                    visible.skip(start).take(4).toList();
                                rows.add(grid(row));
                                // Keep expansion beside the tapped grid row,
                                // even when many later parents fill the popup.
                                if (parent != null && row.contains(parent)) {
                                  rows.addAll(childBlock(parent));
                                }
                              }
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: rows);
                            }),
                          ])))),
      if (!widget.immediate) ...[
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: BeeButton(
                  label: widget.cancelLabel,
                  kind: BeeButtonKind.secondary,
                  onPressed: () {
                    setState(() => draft = widget.selected);
                    widget.onCancel();
                  })),
          const SizedBox(width: 8),
          Expanded(
              child: BeeButton(
                  label: widget.confirmLabel,
                  onPressed: valid ? () => widget.onConfirm(draft!) : null))
        ])
      ]
    ]);
  }
}
