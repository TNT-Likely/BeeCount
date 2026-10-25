import 'package:beecount_business_ui/recurring_editor.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../services/data/recurring_transaction_service.dart';
import '../../../services/system/logger_service.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/currencies.dart';
import '../../../widgets/biz/category_selector_dialog.dart';
import '../../../widgets/biz/ledger_selector_dialog.dart';
import '../../../widgets/currency/currency_flag.dart';
import '../../../widgets/currency/currency_picker_sheet.dart';
import 'page_scaffold.dart';
import 'recording_category_icon.dart';
import 'recurring_editor_pickers.dart';

part 'recurring_editor_actions.dart';

String recurringEditorFrequencyLabel(
        AppLocalizations l, RecurringFrequency value) =>
    switch (value) {
      RecurringFrequency.daily => l.recurringTransactionDaily,
      RecurringFrequency.weekly => l.recurringTransactionWeekly,
      RecurringFrequency.monthly => l.recurringTransactionMonthly,
      RecurringFrequency.yearly => l.recurringTransactionYearly,
    };

String recurringEditorIntervalLabel(
        AppLocalizations l, RecurringFrequency value, int interval) =>
    switch (value) {
      RecurringFrequency.daily => l.recurringTransactionEveryNDays(interval),
      RecurringFrequency.weekly => l.recurringTransactionEveryNWeeks(interval),
      RecurringFrequency.monthly =>
        l.recurringTransactionEveryNMonths(interval),
      RecurringFrequency.yearly => l.recurringTransactionEveryNYears(interval),
    };

class RecurringEditorControls extends ConsumerStatefulWidget {
  const RecurringEditorControls({super.key, this.recurring});
  final RecurringTransaction? recurring;
  @override
  ConsumerState<RecurringEditorControls> createState() =>
      _RecurringEditorControlsState();
}

class _RecurringEditorControlsState
    extends ConsumerState<RecurringEditorControls>
    with _RecurringEditorActions {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), currency = _effectiveCurrency();
    final values = <BeeRecurringEditorField, BeeRecurringEditorValue>{
      BeeRecurringEditorField.ledger: BeeRecurringEditorValue(
          label: l.ledgerSelectTitle,
          value: _ledgerName ?? l.ledgerSelect,
          icon: 'BookOpen',
          error: _getLedgerErrorText(),
          onSelect: _selectLedger),
      BeeRecurringEditorField.currency: BeeRecurringEditorValue(
          label: l.txCurrencyLabel,
          value: displayCurrency(currency, context),
          icon: 'Coins',
          leading:
              currencyFlag(context, currency, width: 22, height: 16, radius: 4),
          onSelect: _selectCurrency),
      BeeRecurringEditorField.category: BeeRecurringEditorValue(
          label: l.categoryTitle,
          value: _selectedCategory == null
              ? l.commonSearch
              : CategoryUtils.getDisplayName(_selectedCategory!.name, context),
          icon: 'Shapes',
          leading: _selectedCategory == null
              ? null
              : RecordingCategoryIcon(category: _selectedCategory!, size: 22),
          error: _getCategoryErrorText(),
          onSelect: _selectCategory),
      BeeRecurringEditorField.account: BeeRecurringEditorValue(
          label: _type == 'transfer'
              ? l.transferFromAccount
              : l.accountSelectTitle,
          value: _accountName ?? l.accountNone,
          icon: 'Wallet',
          error: _getAccountErrorText(true),
          onSelect: () => _selectAccount(isFromAccount: true)),
      BeeRecurringEditorField.toAccount: BeeRecurringEditorValue(
          label: l.transferToAccount,
          value: _toAccountName ?? l.accountNone,
          icon: 'ArrowRightLeft',
          error: _getAccountErrorText(false),
          onSelect: () => _selectAccount(isFromAccount: false)),
      BeeRecurringEditorField.frequency: BeeRecurringEditorValue(
          label: l.recurringTransactionFrequency,
          value: recurringEditorFrequencyLabel(l, _frequency),
          icon: 'Repeat2',
          onSelect: _pickFrequency),
      BeeRecurringEditorField.interval: BeeRecurringEditorValue(
          label: l.recurringTransactionInterval,
          value: recurringEditorIntervalLabel(l, _frequency, _interval),
          icon: 'Clock',
          onSelect: _pickInterval),
      BeeRecurringEditorField.dayOfMonth: BeeRecurringEditorValue(
          label: l.recurringTransactionDayOfMonth,
          value: '${_dayOfMonth ?? 1}',
          icon: 'CalendarDays',
          onSelect: _pickDayOfMonth),
      BeeRecurringEditorField.startDate: BeeRecurringEditorValue(
          label: l.recurringTransactionStartDate,
          value: DateFormat.yMd().format(_startDate),
          icon: 'Calendar',
          onSelect: () => _selectDate(context, true)),
      BeeRecurringEditorField.endDate: BeeRecurringEditorValue(
          label: l.recurringTransactionEndDate,
          value: _endDate == null
              ? l.recurringTransactionNoEndDate
              : DateFormat.yMd().format(_endDate!),
          icon: 'CalendarCheck',
          onSelect: () => _selectDate(context, false),
          onClear:
              _endDate == null ? null : () => setState(() => _endDate = null)),
    };
    return V4PageScaffold(
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeePageHeader(
          title: _isEditing
              ? l.recurringTransactionEdit
              : l.recurringTransactionAdd,
          leading: const BackButton(),
          actions: [
            if (_isEditing)
              BeeIconButton(
                  label: l.commonDelete,
                  icon: const BeeLineIcon('Trash2'),
                  onPressed: _saving || _initializing
                      ? null
                      : _deleteRecurringTransaction),
          ]),
      Expanded(
          child: _initializing
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? BeeEmptyState(
                      title: '${l.commonError}: $_loadError',
                      action: BeeButton(
                          label: l.v4RecordingRetry, onPressed: _initialize))
                  : Form(
                      key: _formKey,
                      child: BeePageBody(eager: true, children: [
                        BeeRecurringEditorForm(
                            amountController: _amountController,
                            noteController: _noteController,
                            type: _type,
                            types: [
                              BeeSegment('expense', l.categoryExpense),
                              BeeSegment('income', l.categoryIncome),
                              BeeSegment('transfer', l.transferTitle)
                            ],
                            values: values,
                            amountLabel: l.importFieldAmount,
                            noteLabel: l.commonNoteHint,
                            clearLabel: l.commonRemove,
                            showInterval:
                                _frequency != RecurringFrequency.daily,
                            showDayOfMonth:
                                _frequency == RecurringFrequency.monthly,
                            enabled: !_saving,
                            onType: _selectType,
                            amountValidator: (value) => value == null ||
                                    value.isEmpty ||
                                    double.tryParse(value) == null
                                ? l.commonError
                                : null),
                        if (_writeError != null)
                          BeeStatus(
                              label: '${l.commonError}: $_writeError',
                              tone: BeeTone.error),
                      ]))),
      SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
              child: BeeButton(
                  key: const ValueKey('recurring-editor-save'),
                  label: l.commonSave,
                  icon: const BeeLineIcon('Check', size: 18),
                  loading: _saving,
                  onPressed: _saving ||
                          _initializing ||
                          _loadError != null ||
                          !_isFormValid()
                      ? null
                      : _saveRecurringTransaction))),
    ]));
  }
}
