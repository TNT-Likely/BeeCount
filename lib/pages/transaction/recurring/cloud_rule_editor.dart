import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_business_ui/recurring_editor.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart'
    show RecurringRuleException;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../cloud/recurring/cloud_recurring_rules.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../services/data/recurring_transaction_service.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/currencies.dart';
import '../../category/editor/bindings/category_line_icon_names.dart';
import '../../shared/currency/currency_flag.dart';
import '../../shared/selectors/currency_picker_sheet.dart';
import '../../shared/selectors/ledger_selector_dialog.dart';
import 'bindings/recurring_editor_controls.dart';
import 'bindings/recurring_editor_pickers.dart';
import 'bindings/recurring_editor_scaffold.dart';
import 'cloud_recurring_page.dart' show cloudRuleError;

class CloudRuleEditor extends ConsumerStatefulWidget {
  const CloudRuleEditor({super.key, required this.book, this.row, this.draft});
  final CloudRuleBook book;
  final CloudRule? row;
  final RuleJson? draft;
  @override
  ConsumerState<CloudRuleEditor> createState() => _CloudRuleEditorState();
}

class _CloudRuleEditorState extends ConsumerState<CloudRuleEditor> {
  late RuleJson rule;
  RuleJson? base;
  CloudRule? concurrent;
  RuleJson get tx => rule['transaction'] as RuleJson;
  late final TextEditingController amount, note;
  late final String clientId;
  String? recordId, error;
  int? revision;
  bool busy = false;
  bool storedDraft = false;
  late CloudRuleBook book;
  Timer? _previewDelay;
  Object? _previewToken;
  List<String>? _previewDates;
  AppLocalizations get l => AppLocalizations.of(context);
  String get draftKey => '${book.draftKey}.${recordId ?? clientId}';

  @override
  void initState() {
    super.initState();
    book = widget.book;
    final draft = widget.draft;
    storedDraft = draft != null;
    final source = draft?['data'] as RuleJson? ?? widget.row?.config;
    rule = source == null
        ? {
            'transaction': <String, dynamic>{'tx_type': 'expense', 'amount': 0},
            'time_zone': book.zone,
            'starts_at': ruleDate(todayIn(book.zone)),
            'frequency': 'monthly',
            'interval': 1,
            'day_of_month': todayIn(book.zone).day,
            'enabled': true,
          }
        : {
            ...source,
            'transaction': RuleJson.from(source['transaction'] as Map)
          };
    if (draft?['derive_name'] == true) rule.remove('name');
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
    amount = TextEditingController(
        text: source == null ? '' : tx['amount'].toString());
    amount.addListener(amountChanged);
    note = TextEditingController(text: tx['note'] as String?);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) queuePreview();
    });
  }

  @override
  void dispose() {
    _previewDelay?.cancel();
    amount.removeListener(amountChanged);
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  String get type => tx['tx_type'] as String;
  RecurringFrequency get frequency =>
      RecurringFrequency.fromString(rule['frequency'] as String);
  int get interval => rule['interval'] as int;
  DateTime get startDate => civilDate(rule['starts_at'] as String);
  DateTime? get endDate =>
      rule['ends_at'] == null ? null : civilDate(rule['ends_at'] as String);
  String get sourceKey => type == 'transfer' ? 'from_account' : 'account';
  int get monthlyDay => rule['day_of_month'] as int? ?? startDate.day;
  String? get currency => book.currencyFor(tx);

  tz.TZDateTime? ruleInstant(String value) {
    final instant = DateTime.parse(value);
    if (!instant.isUtc) return null;
    try {
      return tz.TZDateTime.from(
          instant, tz.getLocation(rule['time_zone'] as String));
    } on tz.LocationNotFoundException {
      return null;
    }
  }

  DateTime civilDate(String value) {
    final local = ruleInstant(value);
    return local == null
        ? DateTime.parse(value.substring(0, 10))
        : RecurringTransactionService.dateOnly(local);
  }

  String withCivilDate(String? old, DateTime day) {
    if (old == null || old.length == 10) return ruleDate(day);
    if (DateUtils.isSameDay(civilDate(old), day)) return old;
    final local = ruleInstant(old);
    if (local == null) return ruleDate(day) + old.substring(10);
    return tz.TZDateTime(
            local.location,
            day.year,
            day.month,
            day.day,
            local.hour,
            local.minute,
            local.second,
            local.millisecond,
            local.microsecond)
        .toIso8601String();
  }

  DateTime todayIn(String zone) {
    DateTime now;
    try {
      now = tz.TZDateTime.now(tz.getLocation(zone));
    } on tz.LocationNotFoundException {
      now = DateTime.now();
    }
    return RecurringTransactionService.dateOnly(now);
  }

  RuleJson? resource(String key, String group) => book.resource(tx, key, group);

  void setRef(String key, String? id) {
    tx['${key}_id'] = id;
    tx[key] = null;
    if (key == 'from_account') {
      tx['account_id'] = null;
      tx['account'] = null;
    }
  }

  void updateDraft(VoidCallback update) {
    setState(update);
    queuePreview();
  }

  void amountChanged() {
    if (mounted && !busy) updateDraft(() {});
  }

  Future<void> selectCategory() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final entries =
        book.options('categories').where((r) => r['kind'] == type).toList();
    final ids = entries.map((r) => r['id']).toSet();
    BeeCategoryChoice choice(RuleJson entry, {bool includeChildren = false}) {
      final children = includeChildren
          ? entries
              .where((r) => r['parent_id'] == entry['id'])
              .map((r) => choice(r))
              .toList()
          : <BeeCategoryChoice>[];
      return BeeCategoryChoice(
        id: entry['id'] as String,
        label:
            CategoryUtils.displayName(entry['name'] as String, l, kind: type),
        icon: BeeLineIcon(categoryLineIconNames[entry['icon']] ?? 'Shapes',
            size: 18),
        enabled: children.isEmpty,
        children: children,
      );
    }

    final selected = await showBeeDialog<String>(
      context,
      title: type == 'income' ? l.categoryIncome : l.categoryExpense,
      child: SizedBox(
        width: double.maxFinite,
        height: math.min(
            440,
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewPaddingOf(context).vertical) *
                .62),
        child: BeeCategoryPicker(
          items: entries
              .where((r) => !ids.contains(r['parent_id']))
              .map((r) => choice(r, includeChildren: true))
              .toList(),
          selected: resource('category', 'categories')?['id'] as String?,
          immediate: true,
          searchLabel: l.searchCategoryHint,
          emptyLabel: l.categoryEmpty,
          confirmLabel: l.commonConfirm,
          cancelLabel: l.commonCancel,
          onCancel: () => Navigator.pop(context),
          onConfirm: (id) => Navigator.pop(context, id),
        ),
      ),
    );
    if (selected != null && mounted) {
      updateDraft(() => setRef('category', selected));
    }
  }

  Future<void> selectAccount(String key, String title) async {
    final source = resource('from_account', 'accounts')?['id'];
    final code = currency;
    final entries = book.options('accounts').where((r) =>
        (code == null ||
            (r['currency'] ?? book.ledger.currency).toString().toUpperCase() ==
                code) &&
        (key != 'to_account' || r['id'] != source));
    final selected = await showBeeDialog<String>(context,
        title: title,
        child: SingleChildScrollView(
            child: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (key != 'to_account')
              BeeMenuRow(
                  title: l.accountNone,
                  onTap: () => Navigator.pop(context, '')),
            for (final entry in entries)
              BeeMenuRow(
                  title: entry['name'] as String,
                  selected: entry['id'] == resource(key, 'accounts')?['id'],
                  onTap: () => Navigator.pop(context, entry['id'])),
            if (entries.isEmpty && key == 'to_account') Text(l.commonEmpty),
          ]),
        )));
    if (selected == null || !mounted) return;
    updateDraft(() {
      setRef(key, selected.isEmpty ? null : selected);
      if (key == 'from_account' &&
          selected == resource('to_account', 'accounts')?['id']) {
        setRef('to_account', null);
      }
    });
  }

  Future<void> selectLedger() async {
    final active = book;
    final candidates = (await ref.read(repositoryProvider).getAllLedgers())
        .where((r) =>
            r.syncId != null && const {'owner', 'editor'}.contains(r.myRole))
        .toList();
    if (!mounted || busy || storedDraft) return;
    final selected = await showLedgerSelector(context,
        currentLedgerId: active.ledger.id, candidates: candidates);
    if (!mounted ||
        busy ||
        storedDraft ||
        selected == null ||
        selected == active.ledger.id) {
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });
    try {
      final target = await ref.read(cloudRuleBookProvider(selected).future);
      if (!target.canCreate) throw StateError(l.cloudRecurringSyncFirst);
      if (mounted) {
        updateDraft(() {
          book = target;
          rule['time_zone'] = target.zone;
          for (final key in [
            'category',
            'account',
            'from_account',
            'to_account'
          ]) {
            setRef(key, null);
          }
          tx['native_amount'] = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = cloudRuleError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> selectCurrency() async {
    final selected = await showCurrencyPickerSheet(context,
        selected: currency ?? book.ledger.currency,
        primaryColor: ref.read(primaryColorProvider),
        title: l.txCurrencyPickerTitle,
        rateBase: book.ledger.currency);
    if (selected == null || !mounted || selected.toUpperCase() == currency) {
      return;
    }
    updateDraft(() {
      tx['currency'] =
          selected.toUpperCase() == book.ledger.currency.toUpperCase()
              ? null
              : selected.toUpperCase();
      tx['native_amount'] = null;
      for (final key in ['account', 'from_account', 'to_account']) {
        setRef(key, null);
      }
    });
  }

  Future<void> selectFrequency() async {
    final selected = await showRecurringEditorWheel<RecurringFrequency>(context,
        initial: frequency,
        items: RecurringFrequency.values,
        labelBuilder: (value) => recurringEditorFrequencyLabel(l, value),
        title: l.recurringTransactionFrequency);
    if (selected == null || !mounted || selected == frequency) return;
    updateDraft(() {
      rule['frequency'] = selected.value;
      if (selected == RecurringFrequency.daily) rule['interval'] = 1;
      rule['day_of_month'] =
          selected == RecurringFrequency.monthly ? startDate.day : null;
      rule['month_of_year'] = null;
      rule['day_of_week'] = null;
    });
  }

  Future<void> pickDate(String key) async {
    final old = rule[key] as String?;
    final today = todayIn(rule['time_zone'] as String);
    final choosingStart = key == 'starts_at';
    final minimum = choosingStart ? today : startDate;
    final date = await showRecurringEditorDatePicker(context,
        initial: old == null ? minimum : civilDate(old),
        minDate: minimum,
        maxDate: DateTime(2100));
    if (date == null || !mounted) return;
    updateDraft(() {
      rule[key] = withCivilDate(old, date);
      if (choosingStart && endDate?.isBefore(date) == true) {
        rule['ends_at'] = ruleDate(date);
      }
    });
  }

  String derivedName() {
    final type = tx['tx_type'] as String;
    final memo = note.text.trim();
    final category = (resource('category', 'categories')?['name'] as String? ??
            recurringReference(tx, 'category'))
        ?.trim();
    final label = switch (type) {
      'transfer' => l.transferTitle,
      _ when category != null && category.isNotEmpty =>
        CategoryUtils.displayName(category, l, kind: type),
      'income' => l.categoryIncome,
      _ => l.categoryExpense,
    };
    return recurringRuleTitle(memo.isEmpty ? label : memo);
  }

  double? get validAmount {
    final value = double.tryParse(amount.text);
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  bool get canSave {
    if (validAmount == null) return false;
    if (type != 'transfer') {
      // Cloud can already hold rules created without a category from Web or MCP.
      return recordId != null || resource('category', 'categories') != null;
    }
    final from = resource('from_account', 'accounts')?['id'];
    final to = resource('to_account', 'accounts')?['id'];
    return from != null && to != null && from != to;
  }

  String? get savedName {
    final value = rule['name'] as String?;
    return value == null || value.trim().isEmpty ? null : value;
  }

  RuleJson changePayload() {
    final value = validAmount!;
    final transaction = <String, dynamic>{
      ...tx,
      'amount': value,
      'note': note.text.isEmpty ? null : note.text,
    };
    if (tx['native_amount'] != null &&
        tx['amount'] != 0 &&
        value != tx['amount']) {
      transaction['native_amount'] =
          (tx['native_amount'] as num) * value / (tx['amount'] as num);
    }
    return {
      'action': recordId == null ? 'create' : 'update',
      'client_id': clientId,
      if (recordId != null) ...{
        'record_id': recordId,
        'expected_revision': revision
      },
      'data': {
        ...rule,
        'name': savedName ?? derivedName(),
        'transaction': transaction
      }
    };
  }

  void queuePreview() {
    _previewDelay?.cancel();
    final token = Object();
    _previewToken = token;
    _previewDates = null;
    if (book.offline || !canSave || rule['enabled'] != true) return;
    _previewDelay = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted || busy) return;
      try {
        final result =
            await book.change({...changePayload(), 'confirm': false});
        final dates = (result['next_occurrences'] as List).cast<String>();
        if (mounted && _previewToken == token) {
          setState(() => _previewDates = dates);
        }
      } catch (_) {
        // The retained date preview still renders while a request is unavailable.
      }
    });
  }

  Future<void> save() async {
    if (busy || !canSave) return;
    final change = changePayload();
    rule['transaction'] = (change['data'] as RuleJson)['transaction'];
    _previewDelay?.cancel();
    _previewToken = null;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          draftKey,
          jsonEncode({
            ...change,
            'base': base,
            if (savedName == null) 'derive_name': true,
          }));
      storedDraft = true;
      if (!book.offline) {
        await book.change({...change, 'confirm': true});
        await prefs.remove(draftKey);
      }
      if (mounted) Navigator.pop(context, book.ledger.id);
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
    updateDraft(() {
      rule = merged;
      base = current;
      revision = latest.revision;
      concurrent = null;
      error = null;
      amount.text = tx['amount'].toString();
      note.text = tx['note'] as String? ?? '';
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
      if (mounted) Navigator.pop(context, book.ledger.id);
    } catch (e) {
      if (mounted) setState(() => error = cloudRuleError(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  BeeRecurringSchedulePreviewData schedulePreview() {
    if (rule['enabled'] != true) {
      return BeeRecurringSchedulePreviewData(
          title: l.v4RecurringPreviewTitle,
          emptyMessage: l.v4RecurringPreviewPausedHint);
    }
    final today = todayIn(rule['time_zone'] as String);
    final last = widget.row?.json['last_generated_local_date'] as String?;
    final historical = last == null ? null : civilDate(last);
    final dates = _previewDates;
    final preview = dates == null
        ? RecurringTransactionService.previewUpcomingOccurrences(
            RecurringScheduleSpec(
                frequency: frequency,
                interval: interval,
                startDate: startDate,
                endDate: endDate,
                lastGeneratedDate: historical,
                dayOfMonth: rule['day_of_month'] as int?,
                dayOfWeek: rule['day_of_week'] as int?,
                monthOfYear: rule['month_of_year'] as int?),
            now: today)
        : [
            for (final instant in dates.take(3))
              RecurringOccurrencePreview(
                date: civilDate(instant),
                daysFromToday: RecurringTransactionService.calendarDaysBetween(
                    civilDate(instant), today),
                adjustedForMonthEnd: frequency == RecurringFrequency.monthly &&
                    civilDate(instant).day < monthlyDay,
              ),
          ];
    final localeName = Localizations.localeOf(context).toString();
    final items = <BeeRecurringPreviewItem>[];
    for (final occurrence in preview) {
      final days = occurrence.daysFromToday;
      final when = days <= 0
          ? l.calendarToday
          : days == 1
              ? l.v4RecurringPreviewTomorrow
              : l.v4RecurringPreviewInDays(days);
      items.add(BeeRecurringPreviewItem(
        index: items.length + 1,
        dateText: DateFormat('yyyy/MM/dd').format(occurrence.date),
        weekdayText: DateFormat.E(localeName).format(occurrence.date),
        badgeText: occurrence.adjustedForMonthEnd
            ? l.v4RecurringPreviewMonthEndTag(when)
            : when,
        badgeTone: occurrence.adjustedForMonthEnd
            ? BeeRecurringPreviewBadgeTone.warning
            : days <= 0
                ? BeeRecurringPreviewBadgeTone.highlight
                : BeeRecurringPreviewBadgeTone.neutral,
      ));
    }
    return BeeRecurringSchedulePreviewData(
      title: l.v4RecurringPreviewTitle,
      items: items,
      subtitle: items.isEmpty ? null : l.v4RecurringPreviewCount(items.length),
      emptyMessage: items.isEmpty ? l.v4RecurringPreviewEmptyEnded : null,
      footnote: historical != null && !startDate.isAfter(historical)
          ? l.v4RecurringPreviewPreservedNote(
              DateFormat('yyyy/MM/dd').format(historical))
          : frequency == RecurringFrequency.monthly && monthlyDay >= 29
              ? l.v4RecurringPreviewMonthEndNote(monthlyDay)
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    BeeRecurringEditorValue field(String label, String value, String icon,
            {VoidCallback? select, VoidCallback? clear, Widget? leading}) =>
        BeeRecurringEditorValue(
            label: label,
            value: value,
            icon: icon,
            leading: leading,
            onSelect: select,
            onClear: clear);
    final category = resource('category', 'categories');
    final categoryTitle =
        (category?['name'] as String?) ?? recurringReference(tx, 'category');
    String accountValue(String key) =>
        (resource(key, 'accounts')?['name'] as String?) ??
        recurringReference(tx, key) ??
        l.accountNone;
    final sourceTitle =
        type == 'transfer' ? l.transferFromAccount : l.accountSelectTitle;
    final end = endDate;
    final dateFormat = DateFormat.yMd();
    final code = currency;

    return RecurringEditorScaffold(
      editing: recordId != null,
      saving: busy,
      onSave: canSave ? save : null,
      onDelete: book.offline ? null : remove,
      saveLabel: book.offline ? l.cloudRecurringSaveDraft : null,
      editor: BeePageBody(eager: true, children: [
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
              BeeRecurringEditorField.ledger: field(
                  l.ledgerSelectTitle, book.ledger.name, 'BookOpen',
                  select: recordId == null && !book.offline && !storedDraft
                      ? selectLedger
                      : null),
              BeeRecurringEditorField.currency: field(l.txCurrencyLabel,
                  code == null ? '—' : displayCurrency(code, context), 'Coins',
                  select: selectCurrency,
                  leading: code == null
                      ? null
                      : currencyFlag(context, code,
                          width: 22, height: 16, radius: 4)),
              BeeRecurringEditorField.category: field(
                  l.categoryTitle,
                  categoryTitle == null
                      ? l.commonSearch
                      : CategoryUtils.displayName(categoryTitle, l, kind: type),
                  'Shapes',
                  select: selectCategory,
                  leading: category == null
                      ? null
                      : BeeLineIcon(
                          categoryLineIconNames[category['icon']] ?? 'Shapes',
                          size: 22)),
              BeeRecurringEditorField.account: field(
                  sourceTitle, accountValue(sourceKey), 'Wallet',
                  select: () => selectAccount(sourceKey, sourceTitle)),
              BeeRecurringEditorField.toAccount: field(l.transferToAccount,
                  accountValue('to_account'), 'ArrowRightLeft',
                  select: () =>
                      selectAccount('to_account', l.transferToAccount)),
              BeeRecurringEditorField.frequency: field(
                  l.recurringTransactionFrequency,
                  frequency == RecurringFrequency.daily && interval > 1
                      ? recurringEditorIntervalLabel(l, frequency, interval)
                      : recurringEditorFrequencyLabel(l, frequency),
                  'Repeat2',
                  select: selectFrequency),
              BeeRecurringEditorField.interval: field(
                  l.recurringTransactionInterval,
                  recurringEditorIntervalLabel(l, frequency, interval),
                  'Clock', select: () async {
                final selected = await showRecurringEditorWheel<int>(context,
                    initial: interval,
                    items: List.generate(math.max(interval, 12), (i) => i + 1),
                    labelBuilder: (v) =>
                        recurringEditorIntervalLabel(l, frequency, v),
                    title: l.recurringTransactionInterval);
                if (selected != null && mounted) {
                  updateDraft(() => rule['interval'] = selected);
                }
              }),
              BeeRecurringEditorField.dayOfMonth: field(
                  l.recurringTransactionDayOfMonth,
                  monthlyDay.toString(),
                  'CalendarDays', select: () async {
                final selected = await showRecurringEditorWheel<int>(context,
                    initial: monthlyDay,
                    items: List.generate(31, (i) => i + 1),
                    labelBuilder: (v) => v.toString(),
                    title: l.recurringTransactionDayOfMonth);
                if (selected != null && mounted) {
                  updateDraft(() => rule['day_of_month'] = selected);
                }
              }),
              BeeRecurringEditorField.startDate: field(
                  l.recurringTransactionStartDate,
                  dateFormat.format(startDate),
                  'Calendar',
                  select: () => pickDate('starts_at')),
              BeeRecurringEditorField.endDate: field(
                  l.recurringTransactionEndDate,
                  end == null
                      ? l.recurringTransactionNoEndDate
                      : dateFormat.format(end),
                  'CalendarCheck',
                  select: () => pickDate('ends_at'),
                  clear: end == null
                      ? null
                      : () => updateDraft(() => rule['ends_at'] = null)),
            },
            amountLabel: l.importFieldAmount,
            noteLabel: l.commonNoteHint,
            clearLabel: l.commonRemove,
            schedulePreview: schedulePreview(),
            showInterval: frequency != RecurringFrequency.daily,
            showDayOfMonth: frequency == RecurringFrequency.monthly,
            enabled: !busy,
            onType: (value) {
              if (value == type) return;
              updateDraft(() {
                tx['tx_type'] = value;
                for (final key in [
                  'category',
                  'account',
                  'to_account',
                  'from_account'
                ]) {
                  setRef(key, null);
                }
                tx['native_amount'] = null;
              });
            }),
        if (concurrent != null)
          BeeButton(
              label: l.cloudRecurringConflictDraft,
              onPressed: busy ? null : resolveConflict),
        if (error != null) BeeStatus(label: error!, tone: BeeTone.error),
      ]),
    );
  }
}
