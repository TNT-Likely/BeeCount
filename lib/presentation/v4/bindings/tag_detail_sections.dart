import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart' as db;
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/currencies.dart';
import '../../../widgets/biz/format_money.dart';
import 'recording_category_icon.dart';
import 'tag_detail.dart';
import 'detail_currency_notice.dart';
import 'transaction_tile.dart';

class TagDetailSections extends ConsumerWidget {
  const TagDetailSections(
      {super.key,
      required this.tag,
      required this.stats,
      required this.data,
      required this.allLedgers,
      required this.onCategory,
      required this.onRecord,
      required this.onDelete,
      required this.onReturned,
      required this.onRetry});
  final db.Tag tag;
  final AsyncValue<TagDetailStats> stats;
  final AsyncValue<TagDetailRows> data;
  final bool allLedgers;
  final ValueChanged<db.Category> onCategory;
  final VoidCallback onRecord, onReturned, onRetry;
  final Future<void> Function(int id, int ledgerId) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        book = ref.watch(currentLedgerProvider).valueOrNull;
    final hide = ref.watch(hideAmountsProvider);
    final accounts =
        ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
    final resource = data.valueOrNull, rows = resource?.rows ?? [];
    final totals = stats.valueOrNull;
    final color =
        tagDetailColor(tag.color, Theme.of(context).colorScheme.primary);
    final projection = resource?.currency;
    final complete =
        projection?.complete == true && !data.isLoading && !stats.isLoading;
    final symbol = getDistinctCurrencySymbol(
        projection?.targetCurrency ?? book?.currency ?? '—');
    String number(double value) => hide
        ? '••••'
        : complete
            ? formatMoneyCompact(value, trimZeros: false)
            : '—';
    String money(double value) => hide
        ? '••••'
        : complete
            ? '$symbol${number(value)}'
            : '—';
    final categories = {
      for (final row in rows)
        if (row.category != null) row.category!.id: row.category!
    };
    final breakdown = <int, ({double amount, int count})>{};
    for (final row in rows) {
      if (row.category == null ||
          row.t.type != 'expense' ||
          row.t.excludeFromStats) {
        continue;
      }
      final id = row.category!.id, old = breakdown[row.category!.id];
      breakdown[id] = (
        amount: (old?.amount ?? 0) + (projection?.amounts[row.t.id] ?? 0),
        count: (old?.count ?? 0) + 1
      );
    }
    final sorted = breakdown.keys.toList()
      ..sort((a, b) => breakdown[b]!.amount.compareTo(breakdown[a]!.amount));
    final expense =
        breakdown.values.fold(0.0, (sum, part) => sum + part.amount);
    final days = <DateTime, ({double expense, double income})>{};
    for (final row in rows) {
      final day = DateUtils.dateOnly(row.t.happenedAt.toLocal()),
          old = days[DateUtils.dateOnly(row.t.happenedAt.toLocal())] ??
              (expense: 0.0, income: 0.0);
      final amount = projection?.amounts[row.t.id] ?? 0;
      // Keep the original daily grouping and daily totals, including flags.
      days[day] = (
        expense: old.expense + (row.t.type == 'expense' ? amount : 0),
        income: old.income + (row.t.type == 'income' ? amount : 0)
      );
    }
    final header =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeResourceHero(
          title: tag.name,
          titleWidget: Align(
              alignment: Alignment.centerLeft,
              child: BeeTag(
                  tag: BeeTagData('${tag.id}', tag.name, color),
                  compact: true)),
          caption: allLedgers ? l.syncHealthGroupAll : book?.name ?? '',
          icon: BeeLineIcon('Tag', color: color),
          amountLabel: l.tagDetailTotalExpense,
          amount: totals == null ? '—' : number(totals.expense),
          prefix: hide || totals == null || !complete ? '' : symbol,
          metrics: [
            BeeResourceMetric(
                label: l.tagDetailTotalIncome,
                value: totals == null ? '—' : money(totals.income)),
            BeeResourceMetric(
                label: l.v4TagCategories,
                value: resource == null ? '—' : '${categories.length}'),
            BeeResourceMetric(
                label: l.tagDetailTotalCount,
                value:
                    totals == null ? '—' : l.tagTransactionCount(totals.count))
          ]),
      if (projection != null &&
          (allLedgers || !complete || projection.hasForeignSources))
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: detailCurrencyNotice(context, projection)),
      if (stats.hasError || data.hasError)
        BeeStatus(
            label: l.commonError,
            tone: BeeTone.error,
            action: BeeButton(label: l.v4RecordingRetry, onPressed: onRetry)),
      if (sorted.isNotEmpty) ...[
        const SizedBox(height: 12),
        BeeSurface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(l.v4TagDistribution,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              BeeResourceBreakdown(items: [
                for (final id in sorted)
                  BeeResourceBreakdownItem(
                      id: '$id',
                      label: CategoryUtils.getDisplayName(
                          categories[id]!.name, context,
                          kind: categories[id]!.kind),
                      amount: money(breakdown[id]!.amount),
                      detail: l.tagTransactionCount(breakdown[id]!.count),
                      fraction: hide || !complete || expense == 0
                          ? 0
                          : breakdown[id]!.amount / expense,
                      icon: RecordingCategoryIcon(
                          category: categories[id]!, size: 18))
              ], onSelected: (id) => onCategory(categories[int.parse(id)]!))
            ])),
      ],
      const SizedBox(height: 12),
      BeeTransactionStreamHeader(
          title: l.tagDetailTransactionList,
          count: totals == null ? '—' : l.tagTransactionCount(totals.count),
          actions: const []),
      if (data.isLoading)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator())),
      if (!data.isLoading && !data.hasError && rows.isEmpty)
        BeeEmptyState(
            title: l.tagDetailNoTransactions,
            message: l.tagDetailNoTransactionsHint),
    ]);
    return ListView.builder(
        padding: const EdgeInsets.fromLTRB(17, 4, 17, 24),
        itemCount: rows.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return header;
          if (index == rows.length + 1) {
            return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: BeeButton(
                    label: l.v4TagRecord,
                    icon: const BeeLineIcon('Plus', size: 18),
                    onPressed: onRecord));
          }
          final i = index - 1,
              row = rows[index - 1],
              date = DateUtils.dateOnly(rows[index - 1].t.happenedAt.toLocal());
          final first = i == 0 ||
              DateUtils.dateOnly(rows[i - 1].t.happenedAt.toLocal()) != date;
          final total = days[date]!;
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
                        if (!complete || total.expense != 0)
                          '${l.searchSummaryExpense} ${money(total.expense)}',
                        if (!complete || total.income != 0)
                          '${l.searchSummaryIncome} ${money(total.income)}'
                      ]),
                TransactionTileBinding(
                    key: ValueKey('tag-transaction-${row.t.id}'),
                    row: row,
                    tags: resource!.tags[row.t.id] ?? const [],
                    attachmentCount: resource.attachments[row.t.id] ?? 0,
                    accountsEnabled: accounts,
                    allLedgers: allLedgers,
                    ledgerName: allLedgers
                        ? resource.ledgers[row.t.ledgerId]?.name
                        : null,
                    baseCurrency: resource.ledgers[row.t.ledgerId]?.currency,
                    onDelete: () => onDelete(row.t.id, row.t.ledgerId),
                    onReturned: onReturned),
                if (i < rows.length - 1) const Divider(height: 1, indent: 46)
              ]));
        });
  }
}
