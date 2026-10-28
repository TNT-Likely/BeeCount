import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/category_utils.dart';
import '../../../widgets/biz/category_selector_dialog.dart';
import '../../../widgets/ui/wheel_date_picker.dart';
import 'transaction_search.dart';

/// Isolated draft: closing the popup never applies partially entered filters.
class TransactionSearchFilterDialog extends StatefulWidget {
  const TransactionSearchFilterDialog(
      {super.key,
      required this.initial,
      required this.accounts,
      required this.tags,
      this.ledgerId,
      required this.currency});
  final TransactionSearchFilter initial;
  final List<Account> accounts;
  final List<Tag> tags;
  final String currency;
  final int? ledgerId;
  @override
  State<TransactionSearchFilterDialog> createState() => _FilterState();
}

class _FilterState extends State<TransactionSearchFilterDialog> {
  late Category? category = widget.initial.category;
  late int? account = widget.initial.accountId, tag = widget.initial.tagId;
  late String? kind = widget.initial.kind;
  late DateTime? start = widget.initial.start, end = widget.initial.end;
  late SearchAmountBasis basis = widget.initial.basis;
  late final minimum =
      TextEditingController(text: widget.initial.minimum?.toString() ?? '');
  late final maximum =
      TextEditingController(text: widget.initial.maximum?.toString() ?? '');
  String? error;
  @override
  void dispose() {
    minimum.dispose();
    maximum.dispose();
    super.dispose();
  }

  String _date(DateTime? date, AppLocalizations l) => date == null
      ? l.searchNotSet
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  Future<void> _pickDate(bool first) async {
    final date = await showWheelDatePicker(context,
        initial: (first ? start : end) ?? DateTime.now(),
        mode: WheelDatePickerMode.ymd,
        minDate: DateTime(2000),
        maxDate: DateTime.now());
    if (date != null && mounted) {
      setState(() {
        if (first) {
          start = date;
        } else {
          end = date;
        }
      });
    }
  }

  void _submit() {
    final min = double.tryParse(minimum.text),
        max = double.tryParse(maximum.text);
    if ((minimum.text.trim().isNotEmpty &&
            (min == null || !min.isFinite || min < 0)) ||
        (maximum.text.trim().isNotEmpty &&
            (max == null || !max.isFinite || max < 0)) ||
        (min != null && max != null && min > max) ||
        (start != null && end != null && start!.isAfter(end!))) {
      setState(() => error = AppLocalizations.of(context).v4SearchInvalidRange);
      return;
    }
    Navigator.pop(
        context,
        TransactionSearchFilter(
            category: category,
            accountId: account,
            tagId: tag,
            kind: kind,
            minimum: min,
            maximum: max,
            start: start,
            end: end,
            basis: basis));
  }

  Widget _select<T>(String label, T? value, Map<T, String> choices,
          ValueChanged<T?> onChanged) =>
      BeeSelectField<T?>(
          label: label,
          value: value,
          items: [
            BeeSegment<T?>(null, AppLocalizations.of(context).v4SearchAll),
            ...choices.entries.map((e) => BeeSegment<T?>(e.key, e.value))
          ],
          onChanged: onChanged);
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeDialog(
        title: Text(l.searchFilterTitle),
        stackActions: true,
        content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              BeeMenuRow(
                  title: l.searchCategoryFilter,
                  subtitle: category == null
                      ? l.v4SearchAll
                      : CategoryUtils.getDisplayName(category!.name, context,
                          kind: category!.kind),
                  trailing: category == null
                      ? const BeeLineIcon('ChevronRight', size: 16)
                      : BeeIconButton(
                          label: l.commonRemove,
                          icon: const BeeLineIcon('X', size: 16),
                          onPressed: () => setState(() => category = null)),
                  onTap: () async {
                    final picked = await showCategorySelector(context,
                        type: 'all',
                        currentCategoryId: category?.id,
                        includeParentCategories: true,
                        ledgerId: widget.ledgerId,
                        expandChildrenByDefault: true,
                        title: l.searchCategoryFilter);
                    if (picked != null && mounted) {
                      setState(() => category = picked);
                    }
                  }),
              const SizedBox(height: 12),
              BeeSelectField<SearchAmountBasis>(
                  value: basis,
                  label: l.searchAmountFilter,
                  items: [
                    BeeSegment(
                        SearchAmountBasis.original, l.v4SearchOriginalAmount),
                    BeeSegment(SearchAmountBasis.ledger,
                        '${l.v4SearchLedgerAmount} · ${widget.currency}')
                  ],
                  onChanged: (v) => setState(() => basis = v!)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: minimum,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            InputDecoration(labelText: l.searchMinAmount))),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('—')),
                Expanded(
                    child: TextField(
                        controller: maximum,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            InputDecoration(labelText: l.searchMaxAmount))),
              ]),
              const SizedBox(height: 12),
              for (final first in [true, false])
                BeeMenuRow(
                    title: first ? l.searchStartDate : l.searchEndDate,
                    subtitle: _date(first ? start : end, l),
                    leading: const BeeLineIcon('CalendarDays', size: 18),
                    onTap: () => _pickDate(first),
                    trailing: (first ? start : end) == null
                        ? null
                        : BeeIconButton(
                            label: l.commonRemove,
                            icon: const BeeLineIcon('X', size: 16),
                            onPressed: () => setState(() {
                                  if (first) {
                                    start = null;
                                  } else {
                                    end = null;
                                  }
                                }))),
              const SizedBox(height: 12),
              _select<int>(
                  l.exportCsvHeaderAccount,
                  account,
                  {for (final a in widget.accounts) a.id: a.name},
                  (v) => setState(() => account = v)),
              const SizedBox(height: 12),
              _select<int>(
                  l.exportCsvHeaderTags,
                  tag,
                  {for (final t in widget.tags) t.id: t.name},
                  (v) => setState(() => tag = v)),
              const SizedBox(height: 12),
              _select<String>(
                  l.exportCsvHeaderType,
                  kind,
                  {
                    'expense': l.exportTypeExpense,
                    'income': l.exportTypeIncome,
                    'transfer': l.transferTitle
                  },
                  (v) => setState(() => kind = v)),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.commonCancel)),
          TextButton(
              onPressed: () => setState(() {
                    category = null;
                    account = null;
                    tag = null;
                    kind = null;
                    start = null;
                    end = null;
                    minimum.clear();
                    maximum.clear();
                    error = null;
                  }),
              child: Text(l.searchClearFilter)),
          FilledButton(onPressed: _submit, child: Text(l.commonConfirm)),
        ]);
  }
}
