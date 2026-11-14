import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers.dart';
import '../../../../providers/budget_providers.dart';
import '../../../budget/budget_page.dart';
import '../../../../utils/currencies.dart';
import '../../../../utils/format_money.dart';

/// Cached budget usage remains in the App; the strip receives formatted values.
class HomeBudgetSummary extends ConsumerWidget {
  const HomeBudgetSummary({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(budgetOverviewProvider).valueOrNull;
    final usage = overview?.totalBudget;
    if (!ref.watch(homeBudgetCardEnabledProvider) || usage == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final hidden = ref.watch(hideAmountsProvider);
    final symbol = getCurrencySymbol(ref.watch(currentLedgerCurrencyProvider));
    String amount(double value) => hidden
        ? '••••'
        : '$symbol${formatMoneyCompact(value, trimZeros: false)}';
    return BeeBudgetStrip(
        label: '${l10n.budgetMonthlyBudget} ${amount(usage.budget)}',
        remaining: '${l10n.budgetRemaining} ${amount(usage.remaining)}',
        progress: usage.rate,
        exceeded: usage.rate >= 1,
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BudgetPage())));
  }
}
