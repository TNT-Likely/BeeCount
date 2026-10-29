import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/calendar_providers.dart';
import '../../../utils/transaction_edit_utils.dart';
import '../../shared/transactions/transaction_list_item.dart';
import '../../shared/resources/category_icon_adapter.dart';

class CalendarTransactions extends ConsumerWidget {
  const CalendarTransactions(
      {super.key,
      required this.ledgerId,
      required this.date,
      required this.onAdd});
  final int ledgerId;
  final DateTime date;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        locale = Localizations.localeOf(context).toString(),
        key = (ledgerId: ledgerId, date: date),
        rows = ref.watch(
            transactionsByDateProvider((ledgerId: ledgerId, date: date)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeCalendarDayHeading(
          title: DateFormat.MMMMd(locale).format(date),
          weekday: DateFormat.E(locale).format(date),
          addLabel: l.calendarAddTransaction,
          onAdd: onAdd),
      const SizedBox(height: 10),
      BeeSurface(
          padding: EdgeInsets.zero,
          child: rows.when(
              skipLoadingOnReload: true,
              loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator())),
              error: (error, _) => BeeEmptyState(
                  title: 'Error: $error',
                  action: BeeButton(
                      label: l.v4RecordingRetry,
                      onPressed: () =>
                          ref.invalidate(transactionsByDateProvider(key)))),
              data: (items) => items.isEmpty
                  ? BeeEmptyState(title: l.calendarNoTransactions)
                  : Column(children: [
                      for (final item in items)
                        TransactionListItem(
                            icon: getCategoryIconData(
                                category: item.category,
                                categoryName: item.category?.name ??
                                    l.commonUncategorized),
                            category: item.category,
                            title: item.t.note?.isNotEmpty == true
                                ? item.t.note!
                                : item.t.type == 'transfer'
                                    ? l.transferTitle
                                    : item.category?.name ??
                                        l.commonUncategorized,
                            categoryName: item.t.type != 'transfer' &&
                                    item.t.note?.isNotEmpty == true
                                ? item.category?.name ?? l.commonUncategorized
                                : null,
                            amount: item.t.amount,
                            currencyCode: item.t.currencyCode,
                            nativeAmount: item.t.nativeAmount,
                            isExpense: item.t.type == 'expense',
                            isTransfer: item.t.type == 'transfer',
                            happenedAt: item.t.happenedAt,
                            accountName: item.account?.name,
                            tags: item.tags.isEmpty
                                ? null
                                : item.tags
                                    .map((t) => (
                                          id: t.id,
                                          name: t.name,
                                          color: t.color
                                        ))
                                    .toList(),
                            attachmentCount: item.attachments.length,
                            excludeFromStats: item.t.excludeFromStats,
                            excludeFromBudget: item.t.excludeFromBudget,
                            onTap: () async {
                              await TransactionEditUtils.editTransaction(
                                  context, ref, item.t, item.category);
                              if (context.mounted) {
                                ref
                                    .read(calendarRefreshProvider.notifier)
                                    .state++;
                              }
                            })
                    ])))
    ]);
  }
}
