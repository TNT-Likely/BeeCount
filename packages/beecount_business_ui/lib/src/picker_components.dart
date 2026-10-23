import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
export 'package:beecount_ui/beecount_ui.dart'
    show BeeChoice, BeeChoicePicker, BeeValidatedInput, BeeDateWheels;
import 'finance_components.dart';

/// Draft selection is owned here. Dismiss/cancel does not call onConfirm.
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
      this.selectionLabel});
  final List<BeeTagData> tags;
  final Set<String> initial;
  final String searchLabel, clearLabel, confirmLabel, emptyLabel;
  final String Function(int) countLabel;
  final ValueChanged<Set<String>> onConfirm;
  final VoidCallback? onCreate;
  final String? createLabel, selectionLabel;
  @override
  State<BeeTagPicker> createState() => _BeeTagPickerState();
}

class _BeeTagPickerState extends State<BeeTagPicker> {
  late Set<String> selected = {...widget.initial};
  String query = '';
  @override
  Widget build(BuildContext context) {
    final items = widget.tags
        .where((t) => t.label.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BeeSearchField(
              hint: widget.searchLabel,
              onChanged: (v) => setState(() => query = v)),
          const SizedBox(height: 13),
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
          const SizedBox(height: 14),
          Flexible(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 270),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(3),
                      child: items.isEmpty
                          ? BeeEmptyState(title: widget.emptyLabel)
                          : Wrap(
                              spacing: 9,
                              runSpacing: 9,
                              children: items
                                  .map((t) => BeeTag(
                                      tag: t,
                                      selected: selected.contains(t.id),
                                      onTap: () => setState(() =>
                                          selected.contains(t.id)
                                              ? selected.remove(t.id)
                                              : selected.add(t.id))))
                                  .toList())))),
          const SizedBox(height: 21),
          Row(children: [
            BeeButton(
                label: widget.clearLabel,
                kind: BeeButtonKind.quiet,
                onPressed: () => setState(selected.clear)),
            const SizedBox(width: 8),
            Expanded(
                child: BeeButton(
                    label: widget.confirmLabel,
                    onPressed: () =>
                        widget.onConfirm(Set.unmodifiable(selected))))
          ]),
          if (widget.onCreate != null)
            BeeMenuRow(
                title: widget.createLabel ?? '',
                leading: const BeeLineIcon('Plus'),
                onTap: widget.onCreate),
        ]);
  }
}

/// Currency labels, common grouping and rate hints are provided by the host.
class BeeCurrencyChoice {
  const BeeCurrencyChoice(
      {required this.code,
      required this.name,
      required this.symbol,
      this.rateHint,
      this.common = false});
  final String code, name, symbol;
  final String? rateHint;
  final bool common;
}

class BeeCurrencyPicker extends StatelessWidget {
  const BeeCurrencyPicker(
      {super.key,
      required this.currencies,
      required this.selected,
      required this.searchLabel,
      required this.emptyLabel,
      required this.onSelected,
      this.loading = false,
      this.error,
      this.onRetry,
      this.retryLabel});
  final List<BeeCurrencyChoice> currencies;
  final String selected, searchLabel, emptyLabel;
  final ValueChanged<String> onSelected;
  final bool loading;
  final String? error, retryLabel;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final sorted = [...currencies]
      ..sort((a, b) => (b.common ? 1 : 0).compareTo(a.common ? 1 : 0));
    return BeeChoicePicker<String>(
        items: sorted
            .map((c) => BeeChoice(
                value: c.code,
                title: '${c.name} (${c.code})',
                subtitle: c.rateHint,
                searchText: c.symbol,
                leading: Text(c.symbol)))
            .toList(),
        selected: selected,
        searchLabel: searchLabel,
        emptyLabel: emptyLabel,
        onSelected: onSelected,
        loading: loading,
        error: error,
        onRetry: onRetry,
        retryLabel: retryLabel);
  }
}
