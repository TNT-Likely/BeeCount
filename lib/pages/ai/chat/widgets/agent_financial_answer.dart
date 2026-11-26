import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../agent/tools/ledger_query_snapshot.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers.dart';
import '../../../../styles/tokens.dart';
import '../../../../utils/category_utils.dart';
import '../../../../utils/currencies.dart';
import '../../../../utils/format_money.dart';
import 'ledger_evidence_label.dart';

enum _CardKind { total, overview, accounts, comparison }

enum _MetricKind { income, expense, previous }

typedef _Selection = ({_CardKind kind, List<_Scope> scopes});
typedef _Line = ({String label, int count, double amount, _MetricKind kind});
typedef _CardData = ({
  String title,
  String range,
  double value,
  String currency,
  List<_Line> rows,
  String? note
});

/// A validated projection of one answer's immutable ledger snapshots. The
/// live reply, saved reply and evidence sheet can reuse this same selection.
final class AgentFinancialPresentation {
  AgentFinancialPresentation._(this._selection);
  final _Selection _selection;
  _Scope get _primary => _selection.scopes.first;
  static const _metrics = {'expense', 'income', 'balance', 'overview'};

  static AgentFinancialPresentation? select(
      List<Map<String, Object?>> queries) {
    final selected = AgentFinancialAnswer._select(queries);
    return selected == null ? null : AgentFinancialPresentation._(selected);
  }

  bool get isCompact => _selection.kind == _CardKind.total;
  String? get metric {
    final value = _primary.query['answerMetric'];
    return (_selection.kind == _CardKind.overview || isCompact) &&
            value is String &&
            _metrics.contains(value)
        ? value
        : null;
  }

  bool get hasDeclaredMetric => metric != null;
  String? get flow => switch (metric) {
        'income' => 'income',
        'expense' => 'expense',
        _
            when _selection.kind == _CardKind.accounts ||
                _selection.kind == _CardKind.comparison =>
          'expense',
        _ => null,
      };
  int get count =>
      flow == null ? _primary.snapshot['count'] as int : _primary.count(flow!);
  DateTime get start => _primary.start;
  DateTime get end => _primary.end;
  Map<String, Object?> get filters => _primary.filters;
  String countLabel(AppLocalizations l) =>
      l.agentQueryFlowCount(count, flowLabel(l));
  String flowLabel(AppLocalizations l) => switch (flow) {
        'expense' => l.homeExpense,
        'income' => l.homeIncome,
        _ => l.agentQueryIncomeAndExpense,
      };
  String rangeLabel(BuildContext context) => hasDeclaredMetric
      ? ledgerEvidenceDateRange(context, start, end)
      : _primary.range(context);

  /// Display-only projections. Replaying a query still uses its unmodified
  /// frozen filters, including the original exclusive end.
  late final List<Map<String, Object?>> evidence = [
    for (final s in _selection.scopes)
      if (hasDeclaredMetric || _selection.kind == _CardKind.comparison)
        {
          ...s.query,
          if (flow != null) 'displayFlow': flow,
          if (hasDeclaredMetric) 'displayMetric': metric,
        }
      else
        s.query
  ];
}

/// Builds cards solely from the local tool attachment.
class AgentFinancialAnswer extends ConsumerWidget {
  const AgentFinancialAnswer(
      {super.key, required this.presentation, required this.onEvidence});
  final AgentFinancialPresentation presentation;
  final ValueChanged<List<Map<String, Object?>>> onEvidence;

  static Widget? fromQueries({
    required List<Map<String, Object?>> queries,
    required ValueChanged<List<Map<String, Object?>>> onEvidence,
  }) {
    final selected = AgentFinancialPresentation.select(queries);
    return selected == null
        ? null
        : AgentFinancialAnswer(presentation: selected, onEvidence: onEvidence);
  }

  static String? copyText(
      BuildContext context, List<Map<String, Object?>> queries,
      {bool accountsEnabled = true}) {
    final selected = AgentFinancialPresentation.select(queries);
    if (selected == null) return null;
    final data = _describe(context, selected, accountsEnabled);
    final l = AppLocalizations.of(context);
    final symbol = getDistinctCurrencySymbol(data.currency);
    String money(double amount) =>
        '$symbol${formatMoneyCompact(amount, trimZeros: false)}';
    return [
      selected.isCompact ? data.title : '${data.title} · ${data.range}',
      money(data.value),
      for (final row in data.rows)
        '${row.label} · ${money(row.amount)} · ${l.agentEvidenceCount(row.count)}',
      selected.hasDeclaredMetric
          ? selected.countLabel(l)
          : l.agentEvidenceCount(selected.count),
      if (data.note != null) data.note!,
    ].join('\n');
  }

  static _Selection? _select(List<Map<String, Object?>> queries) {
    if (queries.isEmpty ||
        queries.any((q) => q['ledgerId'] != queries.first['ledgerId'])) {
      return null;
    }
    final declared = queries
        .where((q) =>
            q['tool'] == 'get_period_overview' &&
            AgentFinancialPresentation._metrics.contains(q['answerMetric']))
        .toList();
    if (declared.length == 1) {
      final primary = _Scope.read(declared.single);
      if (primary == null) return null;
      final metric = primary.query['answerMetric'];
      final isFlow = metric == 'expense' || metric == 'income';
      if (isFlow && (primary.flow == null || primary.flow == metric)) {
        return (kind: _CardKind.total, scopes: [primary]);
      }
      if (!isFlow &&
          primary.flow == null &&
          primary.snapshot['count'] ==
              primary.count('income') + primary.count('expense')) {
        return (
          kind: metric == 'balance' ? _CardKind.total : _CardKind.overview,
          scopes: [primary]
        );
      }
      return null;
    }
    if (declared.length > 1 &&
        !declared.every((q) => q['answerMetric'] == 'expense')) {
      return null;
    }
    if (queries.length == 1 &&
        queries.single['tool'] == 'get_period_overview' &&
        queries.single.containsKey('answerMetric')) {
      return null;
    }
    final scopes = queries.map(_Scope.read).whereType<_Scope>().toList();
    if (scopes.length != queries.length) return null;
    final overviews = scopes
        .where((s) =>
            s.tool == 'get_period_overview' &&
            !s.query.containsKey('answerMetric') &&
            s.flow == null &&
            !s.hasEntityFilters &&
            s.snapshot['count'] == s.count('income') + s.count('expense'))
        .toList();
    // A monthly review often also fetches a category chart, an annual trend,
    // budgets and recurring rules. Its single unrestricted overview owns the
    // net figure, even when the supporting chart looks back further.
    if (overviews.length == 1 && declared.isEmpty) {
      return (kind: _CardKind.overview, scopes: overviews);
    }
    final candidates = <_Scope>[];
    for (final scope in scopes) {
      if (scope.tool == 'query_transactions' ||
          scope.flow == 'income' ||
          scope.flow == 'transfer') {
        continue;
      }
      if (!candidates.any((other) =>
          other.sameFilters(scope) &&
          other.start == scope.start &&
          other.end == scope.end)) {
        candidates.add(scope);
      }
    }
    if (candidates.length == 2) {
      candidates.sort((a, b) => b.start.compareTo(a.start));
      final [now, previous] = candidates;
      if (now.sameFilters(previous) && now.comparableTo(previous)) {
        return (kind: _CardKind.comparison, scopes: [now, previous]);
      }
    }
    final categories = scopes
        .where((s) =>
            s.singleCategory &&
            s.flow != 'income' &&
            s.flow != 'transfer' &&
            s.count('income') == 0 &&
            s.count('transfer') == 0 &&
            s.count('expense') == s.snapshot['count'] &&
            s.accounts.isNotEmpty &&
            s.filters['includeExcludedFromStats'] != true &&
            !s.filters.containsKey('accountIds') &&
            !s.filters.containsKey('accountNames'))
        .toList();
    // Independent category/date scopes are not one account breakdown.
    if (categories.isNotEmpty &&
        scopes.every((s) =>
            s.singleCategory &&
            s.start == categories.first.start &&
            s.end == categories.first.end &&
            const DeepCollectionEquality().equals(
                s.categorySelector, categories.first.categorySelector))) {
      return (kind: _CardKind.accounts, scopes: [categories.first]);
    }
    return null;
  }

  static _CardData _describe(BuildContext context,
      AgentFinancialPresentation presentation, bool accountsEnabled,
      {bool hidden = false}) {
    final (kind: kind, scopes: scopes) = presentation._selection;
    final scope = scopes.first;
    final l = AppLocalizations.of(context);
    final income = scope.amount('income'), expense = scope.amount('expense');
    final rows = <_Line>[];
    late String title;
    late double value;
    String? note;
    switch (kind) {
      case _CardKind.total:
        final metric = presentation.metric;
        final label =
            metric == 'balance' ? l.homeBalance : presentation.flowLabel(l);
        final qualifiers = ledgerEvidenceFilterLabels(context, scope.filters,
            accountsEnabled: accountsEnabled,
            hideAmounts: hidden,
            flow: presentation.flow);
        title = qualifiers.isEmpty
            ? scope.totalTitle(context, label)
            : [presentation.rangeLabel(context), ...qualifiers, label]
                .join(' · ');
        value = switch (metric) {
          'income' => income,
          'expense' => expense,
          _ => income - expense,
        };
      case _CardKind.overview:
        final nextMonth = DateTime(scope.start.year, scope.start.month + 1);
        final heading = scope.start.day == 1 && !scope.end.isAfter(nextMonth)
            ? l.agentAnswerMonthBalance(
                DateFormat.MMM(l.localeName).format(scope.start))
            : l.homeBalance;
        title = [
          if (presentation.hasDeclaredMetric)
            ...ledgerEvidenceFilterLabels(context, scope.filters,
                accountsEnabled: accountsEnabled, hideAmounts: hidden),
          heading
        ].join(' · ');
        value = income - expense;
        rows.addAll([
          (
            label: l.homeIncome,
            count: scope.count('income'),
            amount: income,
            kind: _MetricKind.income
          ),
          (
            label: l.homeExpense,
            count: scope.count('expense'),
            amount: expense,
            kind: _MetricKind.expense
          )
        ]);
        if (scope.count('transfer') > 0 && !presentation.hasDeclaredMetric) {
          note = l.agentAnswerTransferNote(scope.count('transfer'));
        }
      case _CardKind.accounts:
        final category = scope.categoryName;
        title = [
          if (category != null)
            CategoryUtils.getDisplayName(category, context, kind: 'expense'),
          accountsEnabled ? l.agentAnswerAccountBreakdown : l.homeExpense
        ].join(' · ');
        value = expense;
        if (accountsEnabled) {
          final accounts = scope.accounts;
          final shown = accounts.take(5);
          for (final account in shown) {
            rows.add((
              label:
                  account['name'] as String? ?? l.agentAnswerUnassignedAccount,
              count: account['count'] as int,
              amount: (account['amount'] as num).toDouble(),
              kind: _MetricKind.expense
            ));
          }
          final remaining = accounts.skip(5);
          if (remaining.isNotEmpty) {
            rows.add((
              label: l.commonOther,
              count:
                  remaining.fold<int>(0, (sum, a) => sum + (a['count'] as int)),
              amount: remaining.fold<double>(
                  0, (sum, a) => sum + (a['amount'] as num).toDouble()),
              kind: _MetricKind.expense
            ));
          }
        }
      case _CardKind.comparison:
        final prior = scopes.last;
        final delta = ((expense - prior.amount('expense')) * 100).round() / 100;
        title = delta == 0
            ? l.agentAnswerEqualExpense
            : delta < 0
                ? l.agentAnswerLowerExpense
                : l.agentAnswerHigherExpense;
        value = delta.abs();
        for (final s in [prior, scope]) {
          rows.add((
            label: s.dates(context),
            count: s.count('expense'),
            amount: s.amount('expense'),
            kind: s == scope ? _MetricKind.expense : _MetricKind.previous
          ));
        }
    }
    return (
      title: title,
      range: presentation.rangeLabel(context),
      value: value,
      currency: scope.currency,
      rows: rows,
      note: note,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentLedgerIdProvider) !=
        presentation._primary.query['ledgerId']) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final hidden = ref.watch(hideAmountsProvider);
    final accountsEnabled =
        ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
    final data =
        _describe(context, presentation, accountsEnabled, hidden: hidden);
    final kind = presentation._selection.kind,
        rows = data.rows,
        note = data.note;
    final style = Theme.of(context).textTheme;
    final surface = BeeCardTheme.of(context);
    final symbol = getDistinctCurrencySymbol(data.currency);
    final max = rows.fold<double>(0, (n, r) => r.amount > n ? r.amount : n);
    final divisor = kind == _CardKind.accounts ? data.value : max;
    Color color(_MetricKind line) => switch (line) {
          _MetricKind.income => BeeTokens.incomeColor(context, ref),
          _MetricKind.expense => BeeTokens.expenseColor(context, ref),
          _MetricKind.previous => Theme.of(context).hintColor,
        };
    final amount = BeeMoney(
        amount: formatMoneyCompact(data.value, trimZeros: false),
        prefix: symbol,
        size: presentation.isCompact ? 36 : 31,
        hidden: hidden,
        alignment: Alignment.centerLeft);
    final bills = TextButton(
        onPressed: () => onEvidence(presentation.evidence),
        style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            minimumSize: const Size(44, 44),
            foregroundColor: Theme.of(context).colorScheme.onSurface),
        child: Row(
            mainAxisSize:
                presentation.isCompact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              BeeLineIcon('ReceiptText',
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Flexible(
                  fit: presentation.isCompact ? FlexFit.loose : FlexFit.tight,
                  child: Text(presentation.hasDeclaredMetric
                      ? l.agentQueryOpenBills(presentation.countLabel(l))
                      : l.agentEvidenceBills)),
              if (!presentation.hasDeclaredMetric)
                Text(l.agentEvidenceCount(presentation.count),
                    style: style.labelSmall),
              const SizedBox(width: 4),
              BeeLineIcon('ChevronRight',
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)
            ]));
    if (presentation.isCompact) {
      return Column(
          key: ValueKey('financial-answer-${presentation.metric}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.title, style: style.bodyLarge),
            const SizedBox(height: 5),
            amount,
            const SizedBox(height: 5),
            bills
          ]);
    }
    return Container(
        key: ValueKey('financial-answer-${kind.name}'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 4),
        decoration: BoxDecoration(
            color: surface.surface,
            border: Border.all(color: surface.divider),
            borderRadius: BorderRadius.circular(18)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 3,
              children: [
                Text(data.title,
                    style: style.labelMedium
                        ?.copyWith(color: BeeTokens.textSecondary(context))),
                Text(data.range,
                    style: style.labelSmall
                        ?.copyWith(color: BeeTokens.textSecondary(context))),
              ]),
          const SizedBox(height: 4),
          amount,
          if (kind == _CardKind.accounts)
            for (final row in rows)
              Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: _Metric(
                      label: row.label,
                      count: row.count,
                      amount: row.amount,
                      symbol: symbol,
                      color: color(row.kind),
                      divisor: divisor,
                      hidden: hidden,
                      compact: true))
          else
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, row) in rows.indexed) ...[
                        if (i > 0) const SizedBox(width: 14),
                        Expanded(
                            child: _Metric(
                                label: row.label,
                                count: row.count,
                                amount: row.amount,
                                symbol: symbol,
                                color: color(row.kind),
                                divisor: divisor,
                                showBar: !presentation.hasDeclaredMetric,
                                hidden: hidden)),
                      ]
                    ])),
          if (note != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(note,
                    style: style.bodySmall
                        ?.copyWith(color: BeeTokens.textSecondary(context)))),
          const SizedBox(height: 4),
          const Divider(height: 1),
          bills,
        ]));
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label,
      required this.count,
      required this.amount,
      required this.color,
      required this.symbol,
      required this.divisor,
      required this.hidden,
      this.showBar = true,
      this.compact = false});
  final String label, symbol;
  final int count;
  final double amount, divisor;
  final Color color;
  final bool hidden, compact, showBar;
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    final heading = Text(
        '$label · ${AppLocalizations.of(context).agentEvidenceCount(count)}',
        style: style.labelSmall
            ?.copyWith(color: BeeTokens.textSecondary(context)));
    final price = Text(
        hidden
            ? '••••'
            : '$symbol${formatMoneyCompact(amount, trimZeros: false)}',
        style: style.titleSmall
            ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (compact)
        Row(children: [
          Expanded(child: heading),
          const SizedBox(width: 8),
          price
        ])
      else ...[heading, const SizedBox(height: 2), price],
      if (!hidden && showBar) ...[
        const SizedBox(height: 4),
        ExcludeSemantics(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                    minHeight: 3,
                    color: color,
                    backgroundColor: BeeCardTheme.of(context).soft,
                    value: divisor == 0 ? 0 : (amount / divisor).clamp(0, 1))))
      ],
    ]);
  }
}

class _Scope {
  _Scope(this.query, this.snapshot, this.filters, this.start, this.end);
  final Map<String, Object?> query;
  final Map snapshot;
  final Map<String, Object?> filters;
  final DateTime start, end;
  static _Scope? read(Map<String, Object?> q) {
    final ledger = q['ledgerId'];
    final snap = q['snapshot'];
    if (ledger is! int ||
        q['ref'] is! String ||
        (q['ref'] as String).isEmpty ||
        !LedgerQuerySnapshot.valid(snap, ledger) ||
        q['tool'] is! String ||
        q['filters'] is! Map) {
      return null;
    }
    final s = snap as Map, filters = q['filters'] as Map;
    for (final total in (s['totals'] as Map).values) {
      if (total is! Map ||
          total['amount'] is! num ||
          !(total['amount'] as num).isFinite ||
          total['count'] is! int ||
          (total['count'] as int) < 0) {
        return null;
      }
    }
    if (!filters.keys.every((key) => key is String) ||
        !const {null, 'income', 'expense', 'transfer'}
            .contains(filters['flowType'])) {
      return null;
    }
    final start = DateTime.tryParse(s['start']?.toString() ?? '')?.toLocal();
    final end = DateTime.tryParse(s['end']?.toString() ?? '')?.toLocal();
    if (start == null || end == null || !start.isBefore(end)) return null;
    final selectedStart =
        DateTime.tryParse(filters['start']?.toString() ?? '')?.toLocal();
    final selectedEnd =
        DateTime.tryParse(filters['end']?.toString() ?? '')?.toLocal();
    if (start != selectedStart || end != selectedEnd) return null;
    for (final a in s['accounts'] as List) {
      if (a is! Map ||
          a['amount'] is! num ||
          a['count'] is! int ||
          (a['name'] != null && a['name'] is! String)) {
        return null;
      }
    }
    return _Scope(q, s, filters.cast<String, Object?>(), start, end);
  }

  String get currency => snapshot['currency'] as String;
  String? get flow => filters['flowType'] as String?;
  String? get tool => query['tool'] as String?;
  Object? get categorySelector =>
      filters['categoryNames'] ?? filters['categoryIds'];
  String? get categoryName => switch (filters['categoryNames']) {
        final List names => names.whereType<String>().firstOrNull,
        _ => null,
      };
  bool get singleCategory =>
      categorySelector is List && (categorySelector as List).length == 1;
  bool get hasEntityFilters => filters.keys.any((k) => !const {
        'start',
        'end',
        'period',
        'includeExcludedFromStats'
      }.contains(k));
  List<Map> get accounts =>
      (snapshot['accounts'] as List).whereType<Map>().toList();
  double amount(String type) =>
      ((snapshot['totals'] as Map)[type]['amount'] as num).toDouble();
  int count(String type) => (snapshot['totals'] as Map)[type]['count'] as int;
  String dates(BuildContext context) {
    final dates = MaterialLocalizations.of(context);
    if (start.day == 1 && end == DateTime(start.year, start.month + 1)) {
      return dates.formatMonthYear(start);
    }
    return '${dates.formatShortDate(start)}–${dates.formatShortDate(end.subtract(const Duration(microseconds: 1)))}';
  }

  String range(BuildContext context) {
    final dates = MaterialLocalizations.of(context);
    return '${dates.formatCompactDate(start)}–${dates.formatCompactDate(end.subtract(const Duration(microseconds: 1)))}';
  }

  String totalTitle(BuildContext context, String label) {
    final today = DateTime.now();
    final asOf = DateTime.tryParse(query['asOf']?.toString() ?? '')?.toLocal();
    if (query['answerPeriod'] == 'current_month' &&
        asOf != null &&
        start == DateTime(asOf.year, asOf.month) &&
        end == DateTime(asOf.year, asOf.month, asOf.day + 1) &&
        asOf.year == today.year &&
        asOf.month == today.month) {
      final l = AppLocalizations.of(context);
      return l.agentQueryTotalByDate(
          DateFormat.MMMd(l.localeName).format(asOf), label);
    }
    return '${ledgerEvidenceDateRange(context, start, end)} · $label';
  }

  bool sameFilters(_Scope other) {
    Map comparable(Map filters) => Map.of(filters)
      ..removeWhere((k, _) => const {'start', 'end', 'period'}.contains(k));
    return currency == other.currency &&
        const DeepCollectionEquality.unordered()
            .equals(comparable(filters), comparable(other.filters));
  }

  bool comparableTo(_Scope earlier) {
    if (start.isBefore(earlier.end) ||
        start.month + start.year * 12 !=
            earlier.start.month + earlier.start.year * 12 + 1) {
      return false;
    }
    final a = end.subtract(const Duration(microseconds: 1));
    final b = earlier.end.subtract(const Duration(microseconds: 1));
    final wholeMonths = start.day == 1 &&
        earlier.start.day == 1 &&
        end == DateTime(start.year, start.month + 1) &&
        earlier.end == DateTime(earlier.start.year, earlier.start.month + 1);
    return wholeMonths ||
        (start.day == earlier.start.day &&
            a.day == b.day &&
            a.month == start.month &&
            b.month == earlier.start.month &&
            start.hour == earlier.start.hour &&
            start.minute == earlier.start.minute &&
            end.hour == earlier.end.hour &&
            end.minute == earlier.end.minute);
  }
}
