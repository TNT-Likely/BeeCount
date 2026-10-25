import 'package:beecount_business_ui/recurring_editor.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../services/data/recurring_transaction_service.dart';
import '../../../utils/category_utils.dart';
import 'recurring_editor_controls.dart';

final _recurringEditorPreviewProvider = FutureProvider.autoDispose<
    (
      RecurringTransaction?,
      Ledger?,
      Category?,
      Account?,
      Account?
    )>((ref) async {
  final rows = await ref.watch(allRecurringTransactionsProvider.future);
  if (rows.isEmpty) return (null, null, null, null, null);
  final rule = rows.first, repo = ref.read(repositoryProvider);
  return (
    rule,
    await repo.getLedgerById(rule.ledgerId),
    rule.categoryId == null
        ? null
        : await repo.getCategoryById(rule.categoryId!),
    rule.accountId == null ? null : await repo.getAccount(rule.accountId!),
    rule.toAccountId == null ? null : await repo.getAccount(rule.toAccountId!)
  );
});

/// Real repository projection, with all selection and write actions disabled.
class RecurringEditorPreview extends ConsumerWidget {
  const RecurringEditorPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        data = ref.watch(_recurringEditorPreviewProvider);
    return data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => BeeStatus(
            label: '${l.commonError}: $error',
            tone: BeeTone.error,
            action: BeeButton(
                label: l.v4RecordingRetry,
                onPressed: () =>
                    ref.invalidate(_recurringEditorPreviewProvider))),
        data: (row) => row.$1 == null
            ? BeeEmptyState(title: l.recurringTransactionEmpty)
            : _ReadonlyEditor(key: ValueKey(row), data: row));
  }
}

class _ReadonlyEditor extends StatefulWidget {
  const _ReadonlyEditor({super.key, required this.data});
  final (RecurringTransaction?, Ledger?, Category?, Account?, Account?) data;
  @override
  State<_ReadonlyEditor> createState() => _ReadonlyEditorState();
}

class _ReadonlyEditorState extends State<_ReadonlyEditor> {
  late final amount = TextEditingController(
          text: widget.data.$1!.amount.toStringAsFixed(2)),
      note = TextEditingController(text: widget.data.$1!.note ?? '');
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        row = widget.data,
        rule = row.$1!,
        frequency = RecurringFrequency.fromString(row.$1!.frequency);
    BeeRecurringEditorValue field(String label, String value, String icon) =>
        BeeRecurringEditorValue(label: label, value: value, icon: icon);
    return BeeRecurringEditorForm(
        amountController: amount,
        noteController: note,
        type: rule.type,
        types: [
          BeeSegment('expense', l.categoryExpense),
          BeeSegment('income', l.categoryIncome),
          BeeSegment('transfer', l.transferTitle)
        ],
        values: {
          BeeRecurringEditorField.ledger: field(
              l.ledgerSelectTitle, row.$2?.name ?? l.ledgerSelect, 'BookOpen'),
          BeeRecurringEditorField.currency: field(
              l.txCurrencyLabel,
              (rule.currencyCode ?? row.$2?.currency ?? 'CNY').toUpperCase(),
              'Coins'),
          BeeRecurringEditorField.category: field(
              l.categoryTitle,
              row.$3 == null
                  ? l.commonSearch
                  : CategoryUtils.getDisplayName(row.$3!.name, context),
              'Shapes'),
          BeeRecurringEditorField.account: field(
              rule.type == 'transfer'
                  ? l.transferFromAccount
                  : l.accountSelectTitle,
              row.$4?.name ?? l.accountNone,
              'Wallet'),
          BeeRecurringEditorField.toAccount: field(l.transferToAccount,
              row.$5?.name ?? l.accountNone, 'ArrowRightLeft'),
          BeeRecurringEditorField.frequency: field(
              l.recurringTransactionFrequency,
              recurringEditorFrequencyLabel(l, frequency),
              'Repeat2'),
          BeeRecurringEditorField.interval: field(
              l.recurringTransactionInterval,
              recurringEditorIntervalLabel(l, frequency, rule.interval),
              'Clock'),
          BeeRecurringEditorField.dayOfMonth: field(
              l.recurringTransactionDayOfMonth,
              '${rule.dayOfMonth ?? 1}',
              'CalendarDays'),
          BeeRecurringEditorField.startDate: field(
              l.recurringTransactionStartDate,
              DateFormat.yMd().format(rule.startDate),
              'Calendar'),
          BeeRecurringEditorField.endDate: field(
              l.recurringTransactionEndDate,
              rule.endDate == null
                  ? l.recurringTransactionNoEndDate
                  : DateFormat.yMd().format(rule.endDate!),
              'CalendarCheck'),
        },
        amountLabel: l.importFieldAmount,
        noteLabel: l.commonNoteHint,
        clearLabel: l.commonRemove,
        showInterval: frequency != RecurringFrequency.daily,
        showDayOfMonth: frequency == RecurringFrequency.monthly,
        enabled: false);
  }
}
