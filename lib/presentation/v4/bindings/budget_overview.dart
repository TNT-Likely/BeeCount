import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/budget/budget_edit_page.dart';
import '../../../providers.dart';
import '../../../providers/budget_providers.dart';
import '../../../utils/category_utils.dart';
import 'category_line_icon_names.dart';
import 'recording_category_icon.dart';

bool canEditLedgerBudget(WidgetRef ref) {
  final ledger = ref.read(currentLedgerProvider).asData?.value;
  return ledger == null || !ledger.isShared || ledger.myRole == 'owner';
}

BeeBudgetTone budgetTone(BudgetUsage usage) => switch (usage.status) {
      'warning' => BeeBudgetTone.warning,
      'danger' => BeeBudgetTone.danger,
      'exceeded' => BeeBudgetTone.exceeded,
      _ => BeeBudgetTone.normal,
    };
Future<void> openBudgetEditor(BuildContext context, WidgetRef ref,
    {int? budgetId, bool category = false, bool total = false}) async {
  if (!canEditLedgerBudget(ref)) return;
  if (budgetId == null && !total) {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => BudgetEditPage(isCategory: category)));
    return;
  }
  try {
    final budget = total
        ? await ref.read(totalBudgetProvider.future)
        : (await ref.read(allBudgetsProvider.future))
            .where((b) => b.id == budgetId)
            .firstOrNull;
    if (budget != null && context.mounted && canEditLedgerBudget(ref)) {
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => BudgetEditPage(budget: budget)));
    }
  } catch (error) {
    if (context.mounted) {
      showBeeToast(context, error.toString(), tone: BeeTone.error);
    }
  }
}

class BudgetOverviewContent extends ConsumerWidget {
  const BudgetOverviewContent(
      {super.key,
      required this.overview,
      required this.symbol,
      required this.canEdit,
      this.showHomeSetting = true});
  final BudgetOverview overview;
  final String symbol;
  final bool canEdit, showHomeSetting;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), total = overview.totalBudget!;
    final used = '$symbol${total.used.toStringAsFixed(2)}',
        remaining = '$symbol${total.remaining.toStringAsFixed(2)}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeBudgetOverview(
          title: l.budgetMonthlyBudget,
          totalLabel: l.budgetTypeTotalLabel,
          amount: '$symbol${total.budget.toStringAsFixed(2)}',
          usedLabel: l.budgetUsed,
          used: used,
          remainingLabel: l.budgetRemaining,
          remaining: remaining,
          daysLabel: l.budgetDaysRemaining(overview.daysRemaining),
          dailyLabel: l.budgetDailyAvailable(
              '$symbol${overview.dailyAvailable.toStringAsFixed(0)}'),
          progress: total.rate,
          progressLabel: '${(total.rate * 100).toStringAsFixed(0)}%',
          tone: budgetTone(total),
          negativeRemaining: total.remaining < 0,
          editLabel: l.commonEdit,
          onEdit: canEdit
              ? () => openBudgetEditor(context, ref, total: true)
              : null),
      if (overview.categoryBudgets.isNotEmpty) ...[
        const SizedBox(height: 12),
        BeeSurface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(children: [
                    Expanded(
                        child: Text(l.budgetCategoryBudgets,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600))),
                    if (canEdit)
                      TextButton(
                          style: TextButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          onPressed: () =>
                              openBudgetEditor(context, ref, category: true),
                          child: Text(l.commonAdd))
                  ])),
              for (final item in overview.categoryBudgets)
                BeeBudgetCategoryRow(
                    name: CategoryUtils.getDisplayName(
                        item.categoryName, context),
                    amounts:
                        '$symbol${item.usage.used.toStringAsFixed(0)} / $symbol${item.usage.budget.toStringAsFixed(0)}',
                    percent: '${(item.usage.rate * 100).toStringAsFixed(0)}%',
                    progress: item.usage.rate,
                    tone: budgetTone(item.usage),
                    icon: item.category == null
                        ? BeeLineIcon(
                            categoryLineIconNames[item.categoryIcon] ??
                                'Shapes',
                            size: 20)
                        : RecordingCategoryIcon(
                            category: item.category!, size: 20),
                    onTap: canEdit
                        ? () => openBudgetEditor(context, ref,
                            budgetId: item.budgetId)
                        : null)
            ]))
      ],
      if (showHomeSetting) ...[
        const SizedBox(height: 12),
        BeeSurface(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: BeeToggleRow(
                title: l.budgetShowOnHome,
                leading: const BeeLineIcon('Eye', size: 20),
                value: ref.watch(homeBudgetCardEnabledProvider),
                onChanged: (value) => ref
                    .read(homeBudgetCardEnabledProvider.notifier)
                    .toggle(value)))
      ]
    ]);
  }
}
