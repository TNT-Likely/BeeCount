import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/budget_providers.dart';
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
final homeBrandPreferenceInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  ref.read(homeBrandVisibleProvider.notifier).state =
      prefs.getBool('v4_home_show_brand') ?? false;
});
Future<void> setHomeBrandVisible(WidgetRef ref, bool value) async {
  await ref.read(homeBrandPreferenceInitProvider.future);
  if (!ref.context.mounted) return;
  ref.read(homeBrandVisibleProvider.notifier).state = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('v4_home_show_brand', value);
}

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
    ref.watch(homeBrandPreferenceInitProvider);
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
          height: 64,
          child: BeeHomeIdentity(
              name: l10n.homeAppTitle,
              pageTitle: l10n.tabHome,
              ledger: ledger == null
                  ? l10n.ledgersNew
                  : translateLedgerName(context, ledger.name),
              logo: BeeIcon(
                  size: 28, color: Theme.of(context).colorScheme.primary),
              onLedgerTap: onLedgerTap,
              actions: actions,
              showBrand: ref.watch(homeBrandVisibleProvider))),
      const SizedBox(height: 5),
      BeeSummaryCard(
        title:
            '${l10n.homeYear(month.year)} ${l10n.homeMonth('${month.month}')}${jumping ? ' …' : ''}',
        amountLabel: l10n.v4HomeMonthExpense,
        amount: formatMoneyCompact(expense),
        prefix: getCurrencySymbol(currency),
        currencyLabel: '${getCurrencyName(currency, context)} · $currency',
        expenseLabel: l10n.v4HomeMonthBalance,
        expense: formatMoneyCompact(income - expense),
        incomeLabel: l10n.v4HomeMonthIncome,
        income: formatMoneyCompact(income),
        hidden: hidden,
        onContextTap: jumping ? null : onMonthTap,
        privacyLabel: hidden ? l10n.v4AmountsShow : l10n.v4AmountsHide,
        onPrivacyTap: () =>
            ref.read(hideAmountsProvider.notifier).state = !hidden,
        budget: ref.watch(homeBudgetCardEnabledProvider) &&
                ref.watch(budgetOverviewProvider).valueOrNull?.totalBudget !=
                    null
            ? const HomeBudgetSummary()
            : null,
      ),
    ]);
  }
}
