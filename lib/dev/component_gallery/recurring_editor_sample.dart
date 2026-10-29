import 'package:beecount_business_ui/recurring_editor.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

import '../../utils/app_localizations_resolver.dart';

/// Local draft only. These selectors never open a real editor or write data.
class RecurringEditorSample extends StatefulWidget {
  const RecurringEditorSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<RecurringEditorSample> createState() => _RecurringEditorSampleState();
}

class _RecurringEditorSampleState extends State<RecurringEditorSample> {
  final amount = TextEditingController(text: '18.00'),
      note = TextEditingController(text: 'QA synthetic recurring draft');
  String type = 'expense', frequency = 'monthly', event = 'QA local sample';
  bool busy = false;
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    BeeRecurringEditorValue field(String label, String value, String icon,
            [VoidCallback? onSelect]) =>
        BeeRecurringEditorValue(
            label: label,
            value: value,
            icon: icon,
            onSelect: onSelect ?? () => setState(() => event = 'QA · $label'));
    final values = <BeeRecurringEditorField, BeeRecurringEditorValue>{
      BeeRecurringEditorField.ledger:
          field(l.ledgerSelectTitle, 'QA current ledger · CNY', 'BookOpen'),
      BeeRecurringEditorField.currency:
          field(l.txCurrencyLabel, 'USD', 'Coins'),
      BeeRecurringEditorField.category:
          field(l.categoryTitle, 'QA coffee', 'Coffee'),
      BeeRecurringEditorField.account: field(
          type == 'transfer' ? l.transferFromAccount : l.accountSelectTitle,
          'QA USD cash',
          'Wallet'),
      BeeRecurringEditorField.toAccount:
          field(l.transferToAccount, 'QA USD bank', 'ArrowRightLeft'),
      BeeRecurringEditorField.frequency: field(
          l.recurringTransactionFrequency,
          frequency == 'daily'
              ? l.recurringTransactionDaily
              : l.recurringTransactionMonthly,
          'Repeat2',
          () => setState(
              () => frequency = frequency == 'daily' ? 'monthly' : 'daily')),
      BeeRecurringEditorField.interval: field(l.recurringTransactionInterval,
          l.recurringTransactionEveryNMonths(2), 'Clock'),
      BeeRecurringEditorField.dayOfMonth:
          field(l.recurringTransactionDayOfMonth, '31', 'CalendarDays'),
      BeeRecurringEditorField.startDate:
          field(l.recurringTransactionStartDate, '2050/1/1', 'Calendar'),
      BeeRecurringEditorField.endDate: field(l.recurringTransactionEndDate,
          l.recurringTransactionNoEndDate, 'CalendarCheck'),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSurface(child: Text(event)),
      const SizedBox(height: 12),
      BeeRecurringEditorForm(
          amountController: amount,
          noteController: note,
          type: type,
          types: [
            BeeSegment('expense', l.categoryExpense),
            BeeSegment('income', l.categoryIncome),
            BeeSegment('transfer', l.transferTitle)
          ],
          values: values,
          amountLabel: l.importFieldAmount,
          noteLabel: l.commonNoteHint,
          clearLabel: l.commonRemove,
          showInterval: frequency != 'daily',
          showDayOfMonth: frequency == 'monthly',
          enabled: !busy,
          onType: (value) => setState(() => type = value)),
      const SizedBox(height: 12),
      BeeButton(
          label: l.commonSave,
          loading: busy,
          onPressed: () => setState(
              () => event = 'QA local draft saved; no repository write')),
      const SizedBox(height: 8),
      BeeButton(
          label: 'QA busy / ready',
          kind: BeeButtonKind.secondary,
          onPressed: () => setState(() => busy = !busy)),
      if (widget.liveData != null) ...[
        const SizedBox(height: 16),
        widget.liveData!
      ],
    ]);
  }
}
