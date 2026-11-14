import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import 'overview/bindings/budget_overview.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import '../shared/resources/bindings/recording_category_icon.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/category_utils.dart';
import '../../utils/currencies.dart';
part 'editor/bindings/budget_editor_actions.dart';

class BudgetEditPage extends ConsumerStatefulWidget {
  const BudgetEditPage({super.key, this.budget, this.isCategory = false});
  final Budget? budget;
  final bool isCategory;
  @override
  ConsumerState<BudgetEditPage> createState() => _BudgetEditPageState();
}

class _BudgetEditPageState extends ConsumerState<BudgetEditPage>
    with _BudgetEditorActions {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        ledger = ref.watch(currentLedgerProvider).asData?.value;
    final permitted = canEditLedgerBudget(ref);
    return V4PageScaffold(
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeePageHeader(
          title: widget.budget == null ? l.budgetAddTitle : l.budgetEditTitle,
          leading: BackButton(
              onPressed: _saving ? null : () => Navigator.maybePop(context)),
          actions: [
            if (widget.budget != null && permitted)
              BeeIconButton(
                  label: l.commonDelete,
                  icon: const BeeLineIcon('Trash2'),
                  onPressed: _saving || _loading ? null : _delete)
          ]),
      Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? BeeEmptyState(
                      title: '${l.commonError}: $_loadError',
                      action: BeeButton(
                          label: l.v4RecordingRetry, onPressed: _load))
                  : BeePageBody(eager: true, children: [
                      BeeBudgetEditorForm(
                          amountController: _amount,
                          type: _type,
                          totalLabel: l.budgetTypeTotalLabel,
                          categoryTypeLabel: l.budgetTypeCategoryLabel,
                          categoryLabel: l.budgetCategoryLabel,
                          categoryHint: l.budgetCategoryHint,
                          amountLabel: l.budgetAmountLabel,
                          amountHint: l.budgetAmountHint,
                          symbol: getCurrencySymbol(ledger?.currency ?? 'CNY'),
                          categoryName: _selected == null
                              ? null
                              : CategoryUtils.getDisplayName(
                                  _selected!.name, context),
                          categoryIcon: _selected == null
                              ? null
                              : RecordingCategoryIcon(
                                  category: _selected!, size: 24),
                          amountError: _amountError,
                          editing: widget.budget != null,
                          totalUnavailable: _totalUnavailable,
                          enabled: !_saving && permitted,
                          onType: (value) => setState(() => _type = value),
                          onCategory: _pickCategory,
                          onAmountChanged: (_) {
                            if (_amountError != null) {
                              setState(() => _amountError = null);
                            }
                          })
                    ])),
      SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
              child: BeeButton(
                  label: l.commonSave,
                  icon: const BeeLineIcon('Check', size: 18),
                  loading: _saving,
                  onPressed:
                      _saving || _loading || _loadError != null || !permitted
                          ? null
                          : _save)))
    ]));
  }
}
