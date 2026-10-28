import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Controlled account-transaction filter. Queries and apply/cancel remain App-owned.
class BeeAccountFlowFilter extends StatelessWidget {
  const BeeAccountFlowFilter(
      {super.key,
      required this.flow,
      required this.flows,
      required this.sort,
      required this.sortLabel,
      required this.sorts,
      required this.onFlowChanged,
      required this.onSortChanged,
      required this.confirmLabel,
      required this.onConfirm});
  final String flow, sort, sortLabel, confirmLabel;
  final List<BeeSegment<String>> flows, sorts;
  final ValueChanged<String> onFlowChanged, onSortChanged;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BeeCompactTabs<String>(
                value: flow,
                items: flows,
                onChanged: onFlowChanged,
                trackHeight: 32,
                tapHeight: 44),
            const SizedBox(height: 12),
            BeeSelectField<String>(
                label: sortLabel,
                items: sorts,
                value: sort,
                onChanged: (v) {
                  if (v != null) onSortChanged(v);
                }),
            const SizedBox(height: 16),
            BeeButton(label: confirmLabel, onPressed: onConfirm),
          ]);
}

/// Account-scoped search draft. Keep the controller alive through sheet dismissal.
class BeeAccountTransactionSearch extends StatefulWidget {
  const BeeAccountTransactionSearch(
      {super.key,
      required this.initialQuery,
      required this.hint,
      required this.confirmLabel,
      required this.clearLabel,
      required this.onConfirm});
  final String initialQuery, hint, confirmLabel, clearLabel;
  final ValueChanged<String> onConfirm;
  @override
  State<BeeAccountTransactionSearch> createState() => _AccountSearchState();
}

class _AccountSearchState extends State<BeeAccountTransactionSearch> {
  late final text = TextEditingController(text: widget.initialQuery);
  bool submitted = false;
  void submit() {
    if (submitted) return;
    submitted = true;
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onConfirm(text.text);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            BeeSearchField(
                controller: text,
                hint: widget.hint,
                autofocus: true,
                clearLabel: widget.clearLabel,
                onChanged: (_) {},
                onSubmitted: (_) => submit()),
            const SizedBox(height: 16),
            BeeButton(label: widget.confirmLabel, onPressed: submit),
          ]));
}

/// Compact applied filters and consistent separation from the transaction list.
class BeeAccountTransactionTools extends StatelessWidget {
  const BeeAccountTransactionTools(
      {super.key,
      required this.title,
      required this.searchLabel,
      required this.filterLabel,
      required this.query,
      required this.onSearch,
      required this.onFilter,
      required this.onClearQuery,
      required this.onClearFlow,
      this.flowLabel,
      this.sortLabel});
  final String title, searchLabel, filterLabel, query;
  final String? flowLabel, sortLabel;
  final VoidCallback onSearch, onFilter, onClearQuery, onClearFlow;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600))),
          BeeIconButton(
              label: searchLabel,
              icon: const BeeLineIcon('Search'),
              onPressed: onSearch),
          BeeIconButton(
              label: filterLabel,
              icon: const BeeLineIcon('SlidersHorizontal'),
              onPressed: onFilter),
        ]),
        if (query.isNotEmpty || flowLabel != null || sortLabel != null)
          Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 12),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                if (sortLabel != null)
                  BeeChoiceChip(
                      key: const ValueKey('account-filter-sort'),
                      label: sortLabel!,
                      compact: true,
                      selected: false,
                      leading: const BeeLineIcon('ArrowDownUp', size: 12),
                      onSelected: (_) => onFilter()),
                if (query.isNotEmpty)
                  BeeChoiceChip(
                      key: const ValueKey('account-filter-query'),
                      label: query,
                      compact: true,
                      selected: true,
                      onSelected: (_) => onClearQuery()),
                if (flowLabel != null)
                  BeeChoiceChip(
                      key: const ValueKey('account-filter-flow'),
                      label: flowLabel!,
                      compact: true,
                      selected: true,
                      onSelected: (_) => onClearFlow()),
              ]))
        else
          const SizedBox(height: 10),
      ]);
}
