import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../../providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/biz/bee_icon.dart';
import '../../../widgets/biz/format_money.dart';
import '../../../widgets/biz/home_budget_summary.dart';
import '../../../utils/format_utils.dart';
import '../../../utils/currencies.dart';

final homeBrandVisibleProvider = StateProvider<bool>((ref) => false);

/// Real monthly totals and cached reload values remain in the App adapter.
class HomeOverview extends ConsumerWidget {
  const HomeOverview(
      {super.key,
      required this.onLedgerTap,
      required this.onMonthTap,
      required this.actions,
      this.jumping = false});
  final VoidCallback onLedgerTap, onMonthTap;
  final List<Widget> actions;
  final bool jumping;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = ref.watch(currentLedgerIdProvider);
    final ledger = ref.watch(currentLedgerProvider).valueOrNull;
    final month = ref.watch(selectedMonthProvider);
    final params = (ledgerId: id, month: month);
    ref.watch(monthlyTotalsProvider(params));
    final (income, expense) =
        ref.watch(lastMonthlyTotalsProvider(params)) ?? (0.0, 0.0);
    final hidden = ref.watch(hideAmountsProvider);
    final currency = ledger?.currency ?? 'CNY';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
          height: 48,
          child: BeeHomeIdentity(
              name: l10n.homeAppTitle,
              ledger: ledger == null
                  ? l10n.ledgersNew
                  : translateLedgerName(context, ledger.name),
              logo: BeeIcon(
                  size: 28, color: Theme.of(context).colorScheme.primary),
              onLedgerTap: onLedgerTap,
              actions: actions,
              showBrand: ref.watch(homeBrandVisibleProvider))),
      const SizedBox(height: 8),
      BeeSummaryCard(
        title:
            '${l10n.homeYear(month.year)} · ${l10n.homeMonth('${month.month}')} ${jumping ? '…' : ''}',
        amountLabel: l10n.homeExpense,
        amount: formatMoneyCompact(expense),
        prefix: getCurrencySymbol(currency),
        currencyLabel: currency,
        expenseLabel: l10n.homeBalance,
        expense: formatMoneyCompact(income - expense),
        incomeLabel: l10n.homeIncome,
        income: formatMoneyCompact(income),
        hidden: hidden,
        onContextTap: jumping ? null : onMonthTap,
        privacyLabel: l10n.mineCurrentBalance,
        onPrivacyTap: () =>
            ref.read(hideAmountsProvider.notifier).state = !hidden,
        budget: const HomeBudgetSummary(),
      ),
    ]);
  }
}
