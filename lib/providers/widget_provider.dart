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
    );
  } catch (e) {
    // Silently fail to avoid disrupting the app
  }
}
