import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/budget/budget_edit_page.dart';
import '../../../providers.dart';
import '../../../providers/budget_providers.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/currencies.dart';
import '../../../pages/shared/resources/bindings/recording_category_icon.dart';

final _budgetEditorPreview =
    FutureProvider.autoDispose<(Budget?, Category?)>((ref) async {
  final repo = ref.watch(repositoryProvider),
      future = ref.watch(allBudgetsProvider.future);
  final budgets = await future, categories = await repo.getAllCategories();
  final budget = budgets.firstOrNull;
  return (
    budget,
    categories.where((c) => c.id == budget?.categoryId).firstOrNull
  );
});

class LiveBudgetEditorPreview extends ConsumerWidget {
  const LiveBudgetEditorPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        value = ref.watch(_budgetEditorPreview),
        ledger = ref.watch(currentLedgerProvider).asData?.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实预算编辑预览（只读）'),
      const SizedBox(height: 8),
      value.when(
          loading: () => const Text('正在读取真实预算'),
          error: (_, __) => Text(l.commonError),
          data: (pair) => pair.$1 == null
              ? Text(l.budgetEmptyHint)
              : _ReadonlyBudgetDraft(
                  key: ValueKey(
                      (pair.$1!.id, pair.$1!.amount, pair.$1!.categoryId)),
                  budget: pair.$1!,
                  category: pair.$2,
                  symbol: getCurrencySymbol(ledger?.currency ?? 'CNY'))),
      const SizedBox(height: 12),
      BeeButton(
          label: '打开真实预算编辑',
          onPressed: value.asData == null
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          BudgetEditPage(budget: value.asData?.value.$1))))
    ]);
  }
}

class _ReadonlyBudgetDraft extends StatefulWidget {
  const _ReadonlyBudgetDraft(
      {super.key,
      required this.budget,
      required this.category,
      required this.symbol});
  final Budget budget;
  final Category? category;
  final String symbol;
  @override
  State<_ReadonlyBudgetDraft> createState() => _ReadonlyBudgetDraftState();
}

class _ReadonlyBudgetDraftState extends State<_ReadonlyBudgetDraft> {
  late final amount =
      TextEditingController(text: widget.budget.amount.toString());
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeBudgetEditorForm(
        amountController: amount,
        type: widget.budget.type,
        totalLabel: l.budgetTypeTotalLabel,
        categoryTypeLabel: l.budgetTypeCategoryLabel,
        categoryLabel: l.budgetCategoryLabel,
        categoryHint: l.budgetCategoryHint,
        amountLabel: l.budgetAmountLabel,
        amountHint: l.budgetAmountHint,
        symbol: widget.symbol,
        categoryName: widget.category == null
            ? null
            : CategoryUtils.getDisplayName(widget.category!.name, context),
        categoryIcon: widget.category == null
            ? null
            : RecordingCategoryIcon(category: widget.category!, size: 24),
        editing: true,
        enabled: false);
  }
}
