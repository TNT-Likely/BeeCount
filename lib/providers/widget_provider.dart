import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../widget/widget_manager.dart';
import '../providers.dart';

/// Provider for widget manager
final widgetManagerProvider = Provider<WidgetManager>((ref) {
  return WidgetManager();
});

/// Function to update widget data
/// Call this after any transaction change (add/edit/delete)
Future<void> updateAppWidget(WidgetRef ref, BuildContext context) async {
  try {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(repositoryProvider);
    final currentLedgerId = ref.read(currentLedgerIdProvider);
    final primaryColor = ref.read(primaryColorProvider);
    final redForIncome = ref.read(incomeExpenseColorSchemeProvider);
    final baseCurrency = ref.read(baseCurrencyProvider);

    final widgetManager = ref.read(widgetManagerProvider);
    await widgetManager.updateAllWidgets(
      repository,
      currentLedgerId,
      primaryColor,
      redForIncome: redForIncome,
      appName: l10n.appTitle,
      monthSuffix: l10n.widgetMonthSuffix,
      todayExpenseLabel: l10n.widgetTodayExpense,
      todayIncomeLabel: l10n.widgetTodayIncome,
      monthExpenseLabel: l10n.widgetMonthExpense,
      monthIncomeLabel: l10n.widgetMonthIncome,
      baseCurrency: baseCurrency,
      // 净资产视图文案:三个 key 均已有对应 arb,这里是唯一有 l10n 可用的
      // 调用点,其余调用点(app.dart/main.dart/theme_providers.dart/
      // ledgers_page_new.dart)沿用 WidgetManager 默认值兜底。
      netWorthLabel: l10n.accountTotalBalance,
      totalAssetsLabel: l10n.totalAssets,
      totalLiabilitiesLabel: l10n.totalLiabilities,
    );
  } catch (e) {
    // Silently fail to avoid disrupting the app
  }
}
