import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

/// Currency labels, common grouping and rate hints are provided by the host.
class BeeCurrencyChoice {
  const BeeCurrencyChoice(
      {required this.code,
      required this.name,
      required this.symbol,
      this.rateHint,
      this.common = false,
      this.icon});
  final String code, name, symbol;
  final String? rateHint;
  final bool common;
  final Widget? icon;
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
    final ordered = currencies.asMap().entries.toList()
      ..sort((a, b) {
        final group =
            (b.value.common ? 1 : 0).compareTo(a.value.common ? 1 : 0);
        return group == 0 ? a.key.compareTo(b.key) : group;
      });
    final sorted = ordered.map((entry) => entry.value);
    return BeeChoicePicker<String>(
        items: sorted
            .map((c) => BeeChoice(
                value: c.code,
                title: '${c.name} (${c.code})',
                subtitle: c.rateHint,
                searchText: c.symbol,
                leading: c.icon ?? Text(c.symbol)))
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
