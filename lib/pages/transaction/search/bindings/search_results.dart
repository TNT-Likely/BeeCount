import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers.dart';
import '../../../../utils/currencies.dart';
import '../../../../utils/format_money.dart';
import '../../../shared/transactions/bindings/transaction_tile.dart';
import 'transaction_search.dart';

/// Lazy rows retain the original list's behavior for large ledgers.
class SearchResults extends ConsumerWidget {
  const SearchResults(
      {super.key,
      required this.data,
      required this.writing,
      required this.onScope,
      required this.onQuery,
      required this.onRetry});
  final TransactionSearchController data;
  final bool writing;
  final VoidCallback onScope, onRetry;
  final ValueChanged<String> onQuery;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), c = data;
    final ledger = ref.watch(currentLedgerProvider).valueOrNull;
    final hidden = ref.watch(hideAmountsProvider);
    final accounts =
        ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
    String money(double value) => hidden
        ? '••••'
        : '${getDistinctCurrencySymbol(ledger?.currency ?? 'CNY')}${formatMoneyCompact(value, trimZeros: false)}';
    if (c.loading) return const Center(child: CircularProgressIndicator());
    if (c.error != null) {
      return Center(
          child: BeeStatus(
              label: l.commonError,
              tone: BeeTone.error,
              action:
                  BeeButton(label: l.v4RecordingRetry, onPressed: onRetry)));
    }
    final header =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c.batch) ...[
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
                '${ledger?.name ?? ''} · ${l.searchResultsCount(c.results.length)}',
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor))),
        BeeBatchSelection(
            label: l.v4SearchSelected(c.selected.length),
            total:
                '${l.v4RecordingConvertedLabel(ledger?.currency ?? 'CNY')} ${money(c.selectedTotal)}',
            actions: [
              for (final a in [
                (
                  c.selected.length == c.results.length && c.results.isNotEmpty
                      ? l.searchDeselectAll
                      : l.searchSelectAll,
                  c.selectAll
                ),
                (l.v4SearchInvert, c.invert),
                (l.v4SearchScope, onScope)
              ])
                BeeChoiceChip(
                    compact: true,
                    label: a.$1,
                    selected: false,
                    onSelected: writing ? null : (_) => a.$2()),
            ]),
      ] else if (c.hasQuery)
        BeeSearchSummary(
            title: l.searchResultsCount(c.results.length),
            expenseLabel: l.searchSummaryExpense,
            expense: money(c.expense),
            incomeLabel: l.searchSummaryIncome,
            income: money(c.income),
            actionLabel: l.searchBatchMode,
            onAction: c.results.isEmpty
                ? null
                : () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    unawaited(c.remember());
                    c.toggleBatch();
                  })
      else ...[
        if (c.history.isNotEmpty)
          BeeSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l.v4SearchRecent,
                          style: const TextStyle(fontSize: 13)),
                      TextButton(
                          onPressed: c.clearHistory,
                          child: Text(l.v4SearchClearHistory,
                              style: const TextStyle(fontSize: 11)))
                    ]),
                Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: c.history
                        .map((q) => BeeChoiceChip(
                            compact: true,
                            label: q,
                            selected: false,
                            onSelected: (_) => onQuery(q)))
                        .toList())
              ])),
        BeeEmptyState(
            title: l.searchNoInput,
            icon: const BeeLineIcon('Search', size: 36)),
      ],
      if (c.hasQuery && c.results.isEmpty)
        BeeEmptyState(
            title: l.searchNoResults,
            icon: const BeeLineIcon('SearchX', size: 36)),
      const SizedBox(height: 12),
    ]);
    return ListView.builder(
        padding: const EdgeInsets.fromLTRB(17, 0, 17, 24),
        itemCount: c.results.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return header;
          final i = index - 1, row = c.results[index - 1];
          final day = !c.batch &&
              (i == 0 ||
                  DateUtils.dateOnly(c.results[i - 1].t.happenedAt) !=
                      DateUtils.dateOnly(row.t.happenedAt));
          return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: BeeCardTheme.of(context).surface,
                  borderRadius: BorderRadius.vertical(
                      top: i == 0 ? const Radius.circular(22) : Radius.zero,
                      bottom: i == c.results.length - 1
                          ? const Radius.circular(22)
                          : Radius.zero)),
              child: Column(children: [
                if (day)
                  BeeTransactionDayHeader(
                      title: MaterialLocalizations.of(context)
                          .formatMediumDate(row.t.happenedAt),
                      date: '',
                      totals: const []),
                TransactionTileBinding(
                    fullDate: true,
                    row: row,
                    tags: c.tags[row.t.id] ?? const [],
                    attachmentCount: c.attachments[row.t.id] ?? 0,
                    batch: c.batch,
                    selected: c.selected.contains(row.t.id),
                    accountsEnabled: accounts,
                    onSelect: writing ? null : () => c.toggle(row.t.id),
                    onReturned: () => unawaited(c.refresh())),
                if (i < c.results.length - 1)
                  const Divider(height: 1, indent: 46),
              ]));
        });
  }
}
