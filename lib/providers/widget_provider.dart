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
      glanceTitleLabel: l10n.widgetGalleryGlanceTitle,
      quickAddTitleLabel: l10n.widgetGalleryQuickAddTitle,
      recentTitleLabel: l10n.widgetRecentTransactions,
      dashboardTitleLabel: l10n.widgetDashboardTitle,
      monthSuffix: l10n.widgetMonthSuffix,
      todayLabel: l10n.widgetToday,
      todayExpenseLabel: l10n.widgetTodayExpense,
      todayIncomeLabel: l10n.widgetTodayIncome,
      monthExpenseLabel: l10n.widgetMonthExpense,
      monthIncomeLabel: l10n.widgetMonthIncome,
      baseCurrency: baseCurrency,
      // 净资产视图文案:这里是唯一真正有 BuildContext 的调用点,直接用
      // AppLocalizations.of(context) 最准确;其余调用点(main.dart/app.dart/
      // providers/theme_providers.dart/pages/main/ledgers_page_new.dart)
      // 均走 WidgetManager.updateAllWidgetsLocalized(靠 languageProvider
      // 还原 locale),见 widget_manager.dart updateAllWidgets 文档。
      netWorthLabel: l10n.accountTotalBalance,
      totalAssetsLabel: l10n.totalAssets,
      totalLiabilitiesLabel: l10n.totalLiabilities,
      noAccountsLabel: l10n.widgetNoAccounts,
      quickAddLabel: l10n.widgetQuickAddLabel,
      budgetLabel: l10n.budgetMonthlyBudget,
      budgetUsedLabel: l10n.budgetUsed,
      budgetTotalLabel: l10n.widgetBudgetTotal,
      budgetRemainingLabel: l10n.widgetBudgetRemaining,
      noBudgetLabel: l10n.widgetNoBudget,
      uncategorizedLabel: l10n.commonUncategorized,
      noTransactionsLabel: l10n.widgetNoTransactions,
      dashboardRecentLabel: l10n.widgetRecentTransactions,
      consumptionRhythmTitleLabel: l10n.widgetConsumptionRhythmTitle,
      consumptionRhythmRangeLabel: l10n.widgetConsumptionRhythmRange,
      consumptionRhythmStableLabel: l10n.widgetConsumptionRhythmStable,
      consumptionRhythmIncreaseLabel: l10n.widgetConsumptionRhythmIncrease,
      consumptionRhythmDecreaseLabel: l10n.widgetConsumptionRhythmDecrease,
      consumptionRhythmEmptyLabel: l10n.widgetConsumptionRhythmEmpty,
      beeTrailTitleLabel: l10n.widgetBeeTrailTitle,
      beeTrailStreakSuffix: l10n.widgetBeeTrailStreakSuffix,
      beeTrailCompletionLabel: l10n.widgetBeeTrailCompletion,
      beeTrailEmptyLabel: l10n.widgetBeeTrailEmpty,
    );
  } catch (e) {
    // Silently fail to avoid disrupting the app
  }
}
