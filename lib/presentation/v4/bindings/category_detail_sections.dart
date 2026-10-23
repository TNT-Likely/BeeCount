import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart' show Category;
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/currencies.dart';
import '../../../widgets/biz/format_money.dart';
import 'category_detail.dart';
import 'recording_category_icon.dart';
import 'transaction_tile.dart';

/// Real model -> reusable detail components. Transactions remain lazily built.
class CategoryDetailSections extends ConsumerWidget {
  const CategoryDetailSections(
      {super.key,
      required this.data,
      required this.allLedgers,
      required this.showAll,
      required this.onShowAll,
      required this.onChild,
      required this.onSort,
      required this.onRecord,
      required this.onDelete,
      this.periodLabel});
  final CategoryDetailController data;
  final bool allLedgers, showAll;
  final String? periodLabel;
  final VoidCallback onShowAll, onRecord;
  final ValueChanged<Category> onChild;
  final ValueChanged<CategoryDetailSort> onSort;
  final Future<void> Function(int transactionId, int ledgerId) onDelete;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = data, l = AppLocalizations.of(context), category = c.category!;
    final current = ref.watch(currentLedgerProvider).valueOrNull;
    final hide = ref.watch(hideAmountsProvider);
    final accounts =
        ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
    final currency = current?.currency ?? 'CNY',
        symbol = getDistinctCurrencySymbol(current?.currency ?? 'CNY');
    String number(double value) =>
        hide ? '••••' : formatMoneyCompact(value, trimZeros: false);
    String money(double value) => hide ? '••••' : '$symbol${number(value)}';
    String name(Category cat) =>
        CategoryUtils.getDisplayName(cat.name, context, kind: cat.kind);
    final scope = allLedgers ? l.syncHealthGroupAll : current?.name ?? '';
    final period = switch (c.period) {
      CategoryDetailPeriod.month => l.v4DetailMonth,
      CategoryDetailPeriod.year => l.v4DetailYear,
      CategoryDetailPeriod.all => l.v4DetailCumulative,
      CategoryDetailPeriod.custom => periodLabel ?? l.v4DetailCustom,
    };
    final kind = category.kind == 'income'
        ? l.exportTypeIncome
        : category.kind == 'transfer'
            ? l.transferTitle
            : l.exportTypeExpense;
    final metricLabel = allLedgers ? scope : currency;
    final rows = showAll ? c.rows : c.rows.take(4).toList();
    final days = <DateTime, ({double expense, double income})>{};
    for (final row in c.rows) {
      final date = DateUtils.dateOnly(row.t.happenedAt);
      final old = days[date] ?? (expense: 0.0, income: 0.0);
      final value = row.t.nativeAmount ?? row.t.amount;
      days[date] = (
        expense: old.expense + (row.t.type == 'expense' ? value : 0),
        income: old.income + (row.t.type == 'income' ? value : 0)
      );
    }
    final header =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c.parent != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TextButton.icon(
                onPressed: () => onChild(c.parent!),
                icon: const BeeLineIcon('ChevronLeft', size: 14),
                label: Text(name(c.parent!),
                    style: const TextStyle(fontSize: 12)))),
      BeeResourceHero(
          title: name(category),
          caption:
              '${c.parent == null ? l.v4DetailCategoryChildren(c.children.length) : name(c.parent!)} · $scope',
          icon: RecordingCategoryIcon(category: category, size: 22),
          amountLabel: l.v4DetailAmountLabel(period, kind),
          prefix: hide ? '' : symbol,
          amount: number(c.amount),
          metrics: [
            BeeResourceMetric(
                label: l.categoryDetailTotalCount,
                value: l.tagTransactionCount(c.count)),
            BeeResourceMetric(
                label: l.categoryDetailAverageAmount, value: money(c.average)),
            BeeResourceMetric(
                label: l.v4DetailShare,
                value:
                    hide ? '••••' : '${(c.share * 100).toStringAsFixed(1)}%'),
          ]),
      const SizedBox(height: 12),
      if (c.children.isNotEmpty) ...[
        BeeSurface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(l.categorySubCategoryTitle,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              BeeResourceBreakdown(
                  items: c.children.map((child) {
                    final value = c.childAmounts[child.id] ?? 0;
                    final count = c.rows
                        .where((row) => row.category?.id == child.id)
                        .length;
                    final fraction = c.amount == 0 ? 0.0 : value / c.amount;
                    return BeeResourceBreakdownItem(
                        id: '${child.id}',
                        label: name(child),
                        amount: money(value),
                        detail:
                            '${l.tagTransactionCount(count)} · ${hide ? '••••' : '${(fraction * 100).toStringAsFixed(1)}%'}',
                        fraction: fraction,
                        icon: RecordingCategoryIcon(category: child, size: 18));
                  }).toList(),
                  onSelected: (id) => onChild(
                      c.children.singleWhere((child) => '${child.id}' == id))),
            ])),
        const SizedBox(height: 12),
      ],
      BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(l.v4DetailTrend,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600))),
          Text(metricLabel,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
        ]),
        const SizedBox(height: 16),
        BeeResourceTrend(
            values: hide ? const [] : c.trend,
            label: l.v4DetailTrend,
            axisLabels: hide || c.trendDates.isEmpty
                ? const []
                : [
                    c.trendDates.first,
                    c.trendDates[c.trendDates.length ~/ 2],
                    c.trendDates.last
                  ]
                    .map((d) => c.period == CategoryDetailPeriod.month
                        ? '${d.month}.${d.day.toString().padLeft(2, "0")}'
                        : '${d.year}.${d.month.toString().padLeft(2, "0")}')
                    .toList()),
        const SizedBox(height: 6),
      ])),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final value in CategoryDetailSort.values)
          BeeChoiceChip(
              compact: true,
              label: switch (value) {
                CategoryDetailSort.timeAsc => l.categoryDetailSortTimeAsc,
                CategoryDetailSort.timeDesc => l.categoryDetailSortTimeDesc,
                CategoryDetailSort.amountAsc => l.categoryDetailSortAmountAsc,
                CategoryDetailSort.amountDesc => l.categoryDetailSortAmountDesc
              },
              selected: c.sort == value,
              onSelected: (_) => onSort(value))
      ]),
      const SizedBox(height: 8),
      BeeTransactionStreamHeader(
          title: l.v4DetailRecent,
          count: l.tagTransactionCount(c.count),
          actions: const []),
      if (rows.isEmpty)
        BeeEmptyState(
            title: l.categoryDetailNoTransactions,
            message: l.categoryDetailNoTransactionsSubtext),
    ]);
    return ListView.builder(
        padding: const EdgeInsets.fromLTRB(17, 4, 17, 24),
        itemCount: rows.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return header;
          if (index == rows.length + 1) {
            return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (c.rows.length > 4)
                        TextButton(
                            onPressed: onShowAll,
                            child: Text(showAll
                                ? l.v4DetailCollapse
                                : l.v4DetailAllTransactions(c.rows.length))),
                      BeeButton(
                          label: category.kind == 'transfer'
                              ? l.transferTitle
                              : l.v4DetailRecord(name(category)),
                          icon: const BeeLineIcon('Plus', size: 18),
                          onPressed: onRecord),
                    ]));
          }
          final i = index - 1,
              row = rows[i],
              date = DateUtils.dateOnly(rows[index - 1].t.happenedAt);
          final first =
              i == 0 || DateUtils.dateOnly(rows[i - 1].t.happenedAt) != date;
          final totals = days[date]!;
          return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: BeeCardTheme.of(context).surface,
                  borderRadius: BorderRadius.vertical(
                      top: i == 0 ? const Radius.circular(22) : Radius.zero,
                      bottom: i == rows.length - 1
                          ? const Radius.circular(22)
                          : Radius.zero)),
              child: Column(children: [
                if (first)
                  BeeTransactionDayHeader(
                      title: MaterialLocalizations.of(context)
                          .formatMediumDate(date),
                      date: '',
                      totals: [
                        if (totals.expense != 0)
                          '${l.searchSummaryExpense} ${money(totals.expense)}',
                        if (totals.income != 0)
                          '${l.searchSummaryIncome} ${money(totals.income)}'
                      ]),
                TransactionTileBinding(
                    key: ValueKey('category-transaction-${row.t.id}'),
                    row: row,
                    tags: c.tags[row.t.id] ?? const [],
                    attachmentCount: c.attachments[row.t.id] ?? 0,
                    accountsEnabled: accounts,
                    allLedgers: allLedgers,
                    allowCategoryNavigation: row.category?.id != c.categoryId,
                    ledgerName:
                        allLedgers ? c.ledgers[row.t.ledgerId]?.name : null,
                    baseCurrency: c.ledgers[row.t.ledgerId]?.currency,
                    onDelete: () => onDelete(row.t.id, row.t.ledgerId),
                    onReturned: () => unawaited(c.refreshResources())),
                if (i < rows.length - 1) const Divider(height: 1, indent: 46),
              ]));
        });
  }
}
