import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'tag.dart';
import '../../transactions/transaction_presentation.dart';

/// Draft selection stays local unless the host supplies a controlled selection.
/// The host provides recent ordering, permissions and resource loading states.
class BeeTagPicker extends StatefulWidget {
  const BeeTagPicker(
      {super.key,
      required this.tags,
      required this.initial,
      required this.searchLabel,
      required this.clearLabel,
      required this.confirmLabel,
      required this.countLabel,
      required this.emptyLabel,
      required this.onConfirm,
      this.onCreate,
      this.createLabel,
      this.selectionLabel,
      this.selection,
      this.onSelectionChanged,
      this.recent = const [],
      this.recentLabel,
      this.allLabel,
      this.placeholder,
      this.footer,
      this.confirmEnabled = true,
      this.disabledIds = const {},
      this.compact = false});
  final List<BeeTagData> tags, recent;
  final Set<String> initial;
  final Set<String> disabledIds;
  final Set<String>? selection;
  final String searchLabel, clearLabel, confirmLabel, emptyLabel;
  final String Function(int) countLabel;
  final ValueChanged<Set<String>> onConfirm;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final VoidCallback? onCreate;
  final String? createLabel, selectionLabel, recentLabel, allLabel;
  final Widget? placeholder, footer;
  final bool confirmEnabled, compact;
  @override
  State<BeeTagPicker> createState() => _BeeTagPickerState();
}

class _BeeTagPickerState extends State<BeeTagPicker> {
  late Set<String> _localSelection = {...(widget.selection ?? widget.initial)};
  Set<String> get selected => _localSelection;
  String query = '';
  @override
  void didUpdateWidget(covariant BeeTagPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selection != null) _localSelection = {...widget.selection!};
  }

  void _change(Set<String> next) {
    setState(() => _localSelection = next);
    widget.onSelectionChanged?.call(Set.unmodifiable(next));
  }

  Widget _group(List<BeeTagData> items, String? label) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (label != null)
          Padding(
              padding: const EdgeInsets.only(top: 9, bottom: 10),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).hintColor))),
        Wrap(
            spacing: 6,
            runSpacing: 0,
            children: items
                .map((t) => BeeTag(
                    tag: t,
                    selected: selected.contains(t.id),
                    choice: true,
                    enabled: !widget.disabledIds.contains(t.id),
                    onTap: () {
                      final next = {...selected};
                      if (!next.remove(t.id)) next.add(t.id);
                      _change(next);
                    }))
                .toList()),
      ]);
  @override
  Widget build(BuildContext context) {
    final items = widget.tags
        .where(
            (t) => t.label.toLowerCase().contains(query.trim().toLowerCase()))
        .toList();
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BeeSearchField(
              hint: widget.searchLabel,
              onChanged: (v) => setState(() => query = v)),
          SizedBox(height: widget.compact ? 6 : 13),
          Row(children: [
            if (widget.selectionLabel != null)
              Expanded(
                  child: Text(widget.selectionLabel!,
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).hintColor))),
            Text(widget.countLabel(selected.length),
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor)),
          ]),
          SizedBox(height: widget.compact ? 6 : 14),
          Flexible(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 270),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(3),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            widget.placeholder ??
                                (items.isEmpty
                                    ? BeeEmptyState(title: widget.emptyLabel)
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                            if (query.trim().isEmpty &&
                                                widget.recent.isNotEmpty)
                                              _group(widget.recent,
                                                  widget.recentLabel),
                                            _group(items, widget.allLabel),
                                          ])),
                            if (widget.compact) ..._footer,
                          ])))),
          SizedBox(height: widget.compact ? 8 : 21),
          Row(children: [
            Expanded(
                flex: 10,
                child: BeeButton(
                    label: widget.clearLabel,
                    kind: BeeButtonKind.secondary,
                    onPressed: () => _change({}))),
            const SizedBox(width: 8),
            Expanded(
                flex: 17,
                child: BeeButton(
                    label: widget.confirmLabel,
                    onPressed: widget.confirmEnabled
                        ? () => widget.onConfirm(Set.unmodifiable(selected))
                        : null)),
          ]),
          if (!widget.compact) ..._footer,
        ]);
  }

  List<Widget> get _footer => [
        if (widget.onCreate != null)
          BeeMenuRow(
              title: widget.createLabel ?? '',
              leading: const BeeLineIcon('Plus'),
              onTap: widget.onCreate),
        if (widget.footer != null) widget.footer!,
      ];
}
