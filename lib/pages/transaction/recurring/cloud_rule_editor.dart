import 'dart:convert';

import 'package:beecount_business_ui/recurring_editor.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart'
    show RecurringRuleException;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../cloud/recurring/cloud_recurring_rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/data/recurring_transaction_service.dart';
import '../../shared/scaffold/widgets/page_scaffold.dart';
import '../../shared/selectors/currency_picker_sheet.dart';
import 'bindings/recurring_editor_controls.dart';
import 'bindings/recurring_editor_pickers.dart';
import 'cloud_recurring_page.dart' show cloudRuleError;

class CloudRuleEditor extends StatefulWidget {
  const CloudRuleEditor({super.key, required this.book, this.row, this.draft});
  final CloudRuleBook book;
  final CloudRule? row;
  final RuleJson? draft;
  @override
  State<CloudRuleEditor> createState() => _CloudRuleEditorState();
}

class _CloudRuleEditorState extends State<CloudRuleEditor> {
  late RuleJson rule;
  RuleJson? base;
  CloudRule? concurrent;
  RuleJson get tx => rule['transaction'] as RuleJson;
  late final TextEditingController name, amount, note, zone;
  late final String clientId;
  String? recordId, error;
  int? revision;
  bool busy = false;
  AppLocalizations get l => AppLocalizations.of(context);
  CloudRuleBook get book => widget.book;
  String get draftKey => '${book.draftKey}.${recordId ?? clientId}';

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    final source = draft?['data'] as RuleJson? ?? widget.row?.config;
    rule = source == null
        ? {
            'transaction': <String, dynamic>{'tx_type': 'expense', 'amount': 0},
            'name': '',
            'time_zone': book.zone,
            'starts_at': ruleDate(DateTime.now()),
            'frequency': 'monthly',
            'interval': 1,
            'enabled': true,
          }
        : {
            ...source,
            'transaction': RuleJson.from(source['transaction'] as Map)
          };
    if (draft == null && widget.row != null) {
      rule['enabled'] = widget.row!.status != 'paused';
    }
    base = draft?['base'] as RuleJson? ??
        (widget.row == null
            ? null
            : {
                ...widget.row!.config,
                'enabled': widget.row!.status != 'paused',
              });
    recordId = draft?['record_id'] as String? ?? widget.row?.id;
    revision = draft?['expected_revision'] as int? ?? widget.row?.revision;
    clientId = draft?['client_id'] as String? ?? const Uuid().v4();
    name = TextEditingController(text: rule['name'] as String?);
    amount = TextEditingController(
        text: source == null ? '' : tx['amount'].toString());
    note = TextEditingController(text: tx['note'] as String?);
    zone = TextEditingController(text: rule['time_zone'] as String?);
  }

  @override
  void dispose() {
    for (final c in [name, amount, note, zone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick(String title, List<({String id, String label})> options,
      void Function(String) apply) async {
    final selected = await showBeeDialog<String>(context,
        title: title,
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final option in options)
            BeeMenuRow(
                title: option.label,
                onTap: () => Navigator.pop(context, option.id))
        ])));
    if (selected != null && mounted) setState(() => apply(selected));
  }

  void pickRef(String key, String title, String resource) {
    final opts = book
        .options(resource)
        .where((r) => resource != 'categories' || r['kind'] == tx['tx_type']);
    pick(title, [
      if (key != 'to_account' && key != 'from_account')
        (id: '', label: l.accountNone),
      for (final r in opts) (id: r['id'] as String, label: r['name'] as String)
    ], (v) {
      tx['${key}_id'] = v.isEmpty ? null : v;
      tx[key] = null;
    });
  }

  String refName(String key, String resource) {
    final id = tx['${key}_id'];
    return (book
                .options(resource)
                .where((r) => r['id'] == id)
                .firstOrNull?['name'] ??
            tx[key] ??
            id ??
            l.accountNone)
        .toString();
  }

  String weekdayName(int n) =>
      DateFormat.EEEE(Localizations.localeOf(context).toString())
          .format(DateTime(2024, 1, n));

  Future<void> pickDate(String key) async {
    final old = rule[key] as String?;
    final date = await showRecurringEditorDatePicker(context,
        initial: DateTime.tryParse(old ?? '') ?? DateTime.now(),
        minDate: DateTime(1970),
        maxDate: DateTime(2100, 12, 31));
    if (date != null && mounted) {
      setState(() => rule[key] = ruleDate(date) +
          (old != null && old.length > 10 ? old.substring(10) : ''));
    }
  }

  Future<void> save() async {
    if (busy) return;
    final value = double.tryParse(amount.text);
    if (value == null ||
        !value.isFinite ||
        value <= 0 ||
        name.text.trim().isEmpty ||
        zone.text.trim().isEmpty) {
      setState(() => error = l.commonError);
      return;
    }
    if (tx['native_amount'] != null &&
        tx['amount'] != 0 &&
        value != tx['amount']) {
      tx['native_amount'] =
          (tx['native_amount'] as num) * value / (tx['amount'] as num);
    }
    tx['amount'] = value;
    tx['note'] = note.text;
    rule['name'] = name.text.trim();
    rule['time_zone'] = zone.text.trim();
    final change = <String, dynamic>{
      'action': recordId == null ? 'create' : 'update',
      'client_id': clientId,
      if (recordId != null) ...{
        'record_id': recordId,
        'expected_revision': revision
      },
      'data': rule
    };
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(draftKey, jsonEncode({...change, 'base': base}));
      if (book.offline) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final preview = await book.change({...change, 'confirm': false});
      if (!mounted) return;
      final dates =
          (preview['next_occurrences'] as List? ?? []).take(3).join('\n');
      if (await showBeeConfirm(context,
              title: l.v4RecurringPreviewTitle,
              message:
                  '${l.cloudRecurringConfirm}\n${dates.isEmpty ? l.v4RecurringStatusCompleted : dates}',
              confirmLabel: l.commonSave,
              cancelLabel: l.commonCancel) !=
          true) {
        return;
      }
      await book.change({...change, 'confirm': true});
      await prefs.remove(draftKey);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (e is RecurringRuleException && e.status == 409 && recordId != null) {
        try {
          final fresh = await book.readCurrent();
          concurrent = (fresh['items'] as List)
              .cast<RuleJson>()
              .map(CloudRule.new)
              .where((r) => r.id == recordId && r.canEdit)
              .firstOrNull;
        } catch (_) {
          concurrent = null;
        }
      }
      if (mounted) setState(() => error = cloudRuleError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resolveConflict() async {
    final latest = concurrent!;
    final current = {...latest.config, 'enabled': latest.status != 'paused'};
    final original = base;
    final merged = <String, dynamic>{
      ...current,
      'transaction': RuleJson.from(current['transaction'] as Map)
    };
    final differences = <String>[];
    void merge(
        RuleJson source, RuleJson draft, RuleJson remote, RuleJson target) {
      for (final key in draft.keys.where((key) => key != 'transaction')) {
        if (draft[key] == source[key] ||
            (draft[key] is List &&
                jsonEncode(draft[key]) == jsonEncode(source[key]))) {
          continue;
        }
        target[key] = draft[key];
        differences.add(
            '${fieldLabel(key)} · ${remote[key] ?? '—'} → ${draft[key] ?? '—'}');
      }
    }

    if (original != null) {
      merge(original, rule, current, merged);
      merge(
          original['transaction'] as RuleJson,
          tx,
          current['transaction'] as RuleJson,
          merged['transaction'] as RuleJson);
    }
    final apply = await showBeeConfirm(context,
        title: l.cloudRecurringDraftChanges,
        message: differences.isEmpty
            ? l.cloudRecurringConflictDraft
            : differences.join('\n'),
        confirmLabel: l.commonOk,
        cancelLabel: l.commonCancel);
    if (apply != true || !mounted) return;
    setState(() {
      rule = merged;
      base = current;
      revision = latest.revision;
      concurrent = null;
      error = null;
      name.text = rule['name'] as String;
      amount.text = tx['amount'].toString();
      note.text = tx['note'] as String? ?? '';
      zone.text = rule['time_zone'] as String;
    });
  }

  String fieldLabel(String key) =>
      <String, String>{
        'name': l.cloudRecurringName,
        'amount': l.importFieldAmount,
        'note': l.importFieldNote,
        'frequency': l.recurringTransactionFrequency,
        'interval': l.recurringTransactionInterval,
        'day_of_month': l.recurringTransactionDayOfMonth,
        'time_zone': l.cloudRecurringZone,
        'currency': l.txCurrencyLabel,
        'category_id': l.categoryTitle,
        'account_id': l.accountSelectTitle,
        'to_account_id': l.transferToAccount,
        'from_account_id': l.transferFromAccount,
        'day_of_week': l.cloudRecurringWeekDay,
        'month_of_year': l.cloudRecurringYearMonth,
        'starts_at': l.recurringTransactionStartDate,
        'ends_at': l.recurringTransactionEndDate,
      }[key] ??
      key;

  Future<void> remove() async {
    if (busy || book.offline) return;
    if (await showBeeConfirm(context,
                title: l.commonDelete,
                message: l.recurringTransactionDeleteConfirm,
                confirmLabel: l.commonDelete,
                cancelLabel: l.commonCancel) !=
            true ||
        !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await book.change({
        'action': 'delete',
        'record_id': recordId,
        'expected_revision': revision,
        'confirm': true
      });
      await (await SharedPreferences.getInstance()).remove(draftKey);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = cloudRuleError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = tx['tx_type'] as String;
    final frequency =
        RecurringFrequency.fromString(rule['frequency'] as String);
    final interval = rule['interval'] as int;
    BeeRecurringEditorValue field(String label, String value, String icon,
            [VoidCallback? select, VoidCallback? clear]) =>
        BeeRecurringEditorValue(
            label: label,
            value: value,
            icon: icon,
            onSelect: busy ? null : select,
            onClear: busy ? null : clear);
    final source = type == 'transfer' ? 'from_account' : 'account';
    final start = rule['starts_at'] as String;
    final day =
        rule['day_of_month'] as int? ?? int.parse(start.substring(8, 10));
    final currency = (tx['currency'] ?? book.ledger.currency).toString();
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: recordId == null
              ? l.recurringTransactionAdd
              : l.recurringTransactionEdit,
          leading: const BackButton(),
          actions: [
            if (recordId != null)
              BeeIconButton(
                  label: l.commonDelete,
                  icon: const BeeLineIcon('Trash2'),
                  onPressed: busy || book.offline ? null : remove)
          ]),
      Expanded(
          child: BeePageBody(eager: true, children: [
        TextField(
            controller: name,
            enabled: !busy,
            maxLength: 255,
            decoration: InputDecoration(
                labelText: l.cloudRecurringName, counterText: '')),
        BeeRecurringEditorForm(
            amountController: amount,
            noteController: note,
            type: type,
            types: [
              BeeSegment('expense', l.categoryExpense),
              BeeSegment('income', l.categoryIncome),
              BeeSegment('transfer', l.transferTitle)
            ],
            values: {
              BeeRecurringEditorField.ledger:
                  field(l.ledgerSelectTitle, book.ledger.name, 'BookOpen'),
              BeeRecurringEditorField.currency:
                  field(l.txCurrencyLabel, currency, 'Coins', () async {
                final v = await showCurrencyPickerSheet(context,
                    selected: currency,
                    primaryColor: Theme.of(context).colorScheme.primary,
                    title: l.txCurrencyPickerTitle,
                    rateBase: book.ledger.currency);
                if (v != null && mounted) {
                  setState(() {
                    tx['currency'] = v;
                    tx['native_amount'] = null;
                  });
                }
              }),
              BeeRecurringEditorField.category: field(
                  l.categoryTitle,
                  refName('category', 'categories'),
                  'Shapes',
                  () => pickRef('category', l.categoryTitle, 'categories')),
              BeeRecurringEditorField.account: field(
                  type == 'transfer'
                      ? l.transferFromAccount
                      : l.accountSelectTitle,
                  refName(source, 'accounts'),
                  'Wallet',
                  () => pickRef(source, l.accountSelectTitle, 'accounts')),
              BeeRecurringEditorField.toAccount: field(
                  l.transferToAccount,
                  refName('to_account', 'accounts'),
                  'ArrowRightLeft',
                  () => pickRef('to_account', l.transferToAccount, 'accounts')),
              BeeRecurringEditorField.frequency: field(
                  l.recurringTransactionFrequency,
                  recurringEditorFrequencyLabel(l, frequency),
                  'Repeat2',
                  () => pick(l.recurringTransactionFrequency, [
                        for (final f in RecurringFrequency.values)
                          (
                            id: f.value,
                            label: recurringEditorFrequencyLabel(l, f)
                          )
                      ], (v) {
                        rule['frequency'] = v;
                        for (final k in [
                          'day_of_month',
                          'month_of_year',
                          'day_of_week'
                        ]) {
                          rule[k] = null;
                        }
                      })),
              BeeRecurringEditorField.interval: field(
                  l.recurringTransactionInterval, interval.toString(), 'Clock',
                  () async {
                final v = await showRecurringEditorWheel<int>(context,
                    initial: interval,
                    items: List.generate(365, (i) => i + 1),
                    labelBuilder: (v) =>
                        recurringEditorIntervalLabel(l, frequency, v),
                    title: l.recurringTransactionInterval);
                if (v != null && mounted) setState(() => rule['interval'] = v);
              }),
              if (frequency == RecurringFrequency.weekly)
                BeeRecurringEditorField.dayOfWeek: field(
                    l.cloudRecurringWeekDay,
                    weekdayName(rule['day_of_week'] as int? ??
                        DateTime.parse(start).weekday),
                    'Calendar',
                    () => pick(
                        l.cloudRecurringWeekDay,
                        [
                          for (var d = 1; d <= 7; d++)
                            (id: d.toString(), label: weekdayName(d))
                        ],
                        (v) => rule['day_of_week'] = int.parse(v))),
              if (frequency == RecurringFrequency.yearly)
                BeeRecurringEditorField.monthOfYear: field(
                    l.cloudRecurringYearMonth,
                    (rule['month_of_year'] ?? int.parse(start.substring(5, 7)))
                        .toString(),
                    'Calendar',
                    () => pick(
                        l.cloudRecurringYearMonth,
                        [
                          for (var m = 1; m <= 12; m++)
                            (id: m.toString(), label: m.toString())
                        ],
                        (v) => rule['month_of_year'] = int.parse(v))),
              BeeRecurringEditorField.dayOfMonth: field(
                  l.recurringTransactionDayOfMonth,
                  day.toString(),
                  'CalendarDays', () async {
                final v = await showRecurringEditorWheel<int>(context,
                    initial: day,
                    items: List.generate(31, (i) => i + 1),
                    labelBuilder: (v) => v.toString(),
                    title: l.recurringTransactionDayOfMonth);
                if (v != null && mounted) {
                  setState(() => rule['day_of_month'] = v);
                }
              }),
              BeeRecurringEditorField.startDate: field(
                  l.recurringTransactionStartDate,
                  start,
                  'Calendar',
                  () => pickDate('starts_at')),
              BeeRecurringEditorField.endDate: field(
                  l.recurringTransactionEndDate,
                  rule['ends_at'] as String? ?? l.recurringTransactionNoEndDate,
                  'CalendarCheck',
                  () => pickDate('ends_at'),
                  rule['ends_at'] == null
                      ? null
                      : () => setState(() => rule['ends_at'] = null)),
            },
            amountLabel: l.importFieldAmount,
            noteLabel: l.commonNoteHint,
            clearLabel: l.commonRemove,
            schedulePreview: BeeRecurringSchedulePreviewData(
                title: l.v4RecurringPreviewTitle,
                emptyMessage: l.cloudRecurringConfirm),
            showInterval: true,
            showDayOfMonth: frequency == RecurringFrequency.monthly ||
                frequency == RecurringFrequency.yearly,
            enabled: !busy,
            onType: (v) => setState(() {
                  tx['tx_type'] = v;
                  for (final k in [
                    'category',
                    'account',
                    'to_account',
                    'from_account'
                  ]) {
                    tx[k] = null;
                    tx['${k}_id'] = null;
                  }
                })),
        TextField(
            controller: zone,
            enabled: !busy,
            decoration: InputDecoration(labelText: l.cloudRecurringZone)),
        if (concurrent != null)
          BeeButton(
              label: l.cloudRecurringConflictDraft,
              onPressed: busy ? null : resolveConflict),
        if (error != null) BeeStatus(label: error!, tone: BeeTone.error),
      ])),
      SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: BeeButton(
                  label:
                      book.offline ? l.cloudRecurringSaveDraft : l.commonSave,
                  loading: busy,
                  onPressed: busy ? null : save)))
    ]));
  }
}
