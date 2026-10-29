import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../utils/currencies.dart';
import '../../../utils/format_money.dart';
import '../../../pages/shared/currency/bindings/detail_currency_notice.dart';
import '../../../pages/shared/currency/bindings/detail_currency_totals.dart';
import '../../../pages/transaction/search/bindings/transaction_search.dart';

final _detailCurrencyPreviewRowsProvider =
    StreamProvider.autoDispose<List<SearchTransaction>>(
        (ref) => ref.watch(repositoryProvider).transactionsWithCategoryAll());

/// Uses only the existing local repository stream and read-only quote context.
/// Visiting the catalog never fetches rates, performs sync or writes a record.
class LiveDetailCurrencyPreview extends ConsumerWidget {
  const LiveDetailCurrencyPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rows = ref.watch(_detailCurrencyPreviewRowsProvider);
    final currency = ref.watch(detailCurrencyContextProvider);
    final hidden = ref.watch(hideAmountsProvider);
    if (rows.hasError || currency.hasError) {
      return BeeStatus(label: l.commonError, tone: BeeTone.error);
    }
    if (rows.isLoading || currency.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final transactions = rows.requireValue.map((row) => row.t).toList();
    final projection =
        projectDetailCurrencyTransactions(currency.requireValue, transactions);
    String total(String kind) {
      if (hidden) return '••••';
      if (!projection.complete) return '—';
      final value = projection.total(transactions.where((transaction) =>
          transaction.type == kind && !transaction.excludeFromStats));
      return value == null
          ? '—'
          : '${getDistinctCurrencySymbol(projection.targetCurrency!)}${formatMoneyCompact(value, trimZeros: false)}';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实汇总币种（只读）'),
      const SizedBox(height: 8),
      BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.tagTransactionCount(transactions.length)),
        const SizedBox(height: 8),
        Text('${l.tagDetailTotalExpense} ${total('expense')}'),
        const SizedBox(height: 4),
        Text('${l.tagDetailTotalIncome} ${total('income')}'),
      ])),
      const SizedBox(height: 8),
      detailCurrencyNotice(context, projection),
    ]);
  }
}
