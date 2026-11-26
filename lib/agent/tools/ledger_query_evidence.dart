import 'package:agentcore/agentcore.dart';

import '../../utils/month_range.dart';
import 'local_agent_tool_catalog.dart';

/// Replayable filters and immutable on-device display evidence are kept apart.
/// Only the former may be used as model context on a subsequent turn.
final class LedgerQueryEvidence {
  LedgerQueryEvidence(this.scope,
      {this.previous = const [], this.view = const {}});
  final AgentScope scope;
  final List<Map<String, Object?>> previous;
  final Map<String, Object?> view;
  final current = <Map<String, Object?>>[];
  final snapshots = <String, Map<String, Object?>>{};
  final _pending = Map<AgentToolCall, Map<String, Object?>>.identity();

  bool hasSnapshot(AgentToolCall call) => _pending.containsKey(call);
  void capture(AgentToolCall call, Map<String, Object?> snapshot) =>
      _pending.putIfAbsent(call, () => snapshot);

  static const filterKeys = {
    'start',
    'end',
    'period',
    'categoryIds',
    'categoryNames',
    'accountIds',
    'accountNames',
    'tagIds',
    'tagNames',
    'flowType',
    'minAmount',
    'maxAmount',
    'amountBasis',
    'currency',
    'includeExcludedFromStats',
    'exclude',
  };

  Map<String, Object?>? _reference(Object? id) {
    for (final item in [...current.reversed, ...previous.reversed]) {
      if (item['ref'] == id &&
          item['ledgerId'] == scope.ledgerId &&
          item['filters'] is Map) {
        return item;
      }
    }
    return null;
  }

  static String? _matchingAsOf(Object? value, Object? exclusiveEnd) {
    if (value is! String || exclusiveEnd is! String) return null;
    final end = DateTime.tryParse(exclusiveEnd)?.toLocal();
    if (end == null || end != DateTime(end.year, end.month, end.day)) {
      return null;
    }
    final lastDay = DateTime(end.year, end.month, end.day - 1);
    return lastDay.toIso8601String().split('T').first == value ? value : null;
  }

  Future<Map<String, Object?>> execute(AgentToolCall call,
      Future<Map<String, Object?>> Function(AgentToolCall) run) async {
    final args = Map.of(call.arguments)..remove('exclude');
    final base = args.remove('baseQuery');
    final excluded = args.remove('excludeQuery');
    final original = base == null ? null : _reference(base);
    final excludedScope =
        excluded == null ? null : _reference(excluded)?['filters'] as Map?;
    if ((base != null && original == null) ||
        (excluded != null && excludedScope == null)) {
      return {
        'error': 'unknown_query_reference',
        'retryable': true,
        'message':
            'Select a reference from the current ledger or specify the filters again.'
      };
    }
    final originalFilters = original?['filters'] as Map? ?? const {};
    final originalAsOf =
        _matchingAsOf(original?['asOf'], originalFilters['end']);
    final inherited = <String, Object?>{
      for (final key in filterKeys)
        if (originalFilters.containsKey(key)) key: originalFilters[key],
    };
    final metric = args['answerMetric'];
    if (args.containsKey('answerMetric') &&
        (call.name != 'get_period_overview' ||
            !LocalAgentToolCatalog.answerMetrics.contains(metric))) {
      return {
        'error': 'invalid_answer_metric',
        'retryable': true,
        'message':
            'For get_period_overview select expense, income, balance, overview, or unspecified.'
      };
    }
    if (args.containsKey('rangeMode') &&
        !const {'to_date', 'full_period'}.contains(args['rangeMode'])) {
      return {
        'error': 'invalid_range_mode',
        'retryable': true,
        'message': 'Use to_date or full_period.'
      };
    }
    if (excludedScope != null && inherited.containsKey('exclude')) {
      return {
        'error': 'already_excluded',
        'retryable': true,
        'message':
            'Combine the exclusions into one selection before subtracting it.'
      };
    }
    var depth = 0;
    Object? nested = excludedScope;
    while (nested is Map) {
      depth++;
      nested = nested['exclude'];
    }
    if (depth > 4) {
      return {'error': 'exclusion_depth', 'retryable': true};
    }
    final overridesDates = ['period', 'start', 'end'].any(args.containsKey);
    if (overridesDates) {
      for (final key in ['period', 'start', 'end']) {
        inherited.remove(key);
      }
    } else if (originalAsOf != null && args['rangeMode'] == 'full_period') {
      // A follow-up may expand the saved month after the calendar has moved on.
      // Anchor it to the original accounting period, even across fiscal years.
      final start =
          DateTime.tryParse(inherited['start']?.toString() ?? '')?.toLocal();
      if (start != null) {
        final end = switch (original?['answerPeriod']) {
          'current_month' =>
            periodForLabel(start.year, start.month, start.day).end,
          'current_year' => yearRangeFor(start.year, start.day).end,
          _ => null,
        };
        if (end != null) inherited['end'] = end.toIso8601String();
      }
    }
    for (final entity in ['category', 'account', 'tag']) {
      if (args.containsKey('${entity}Ids') ||
          args.containsKey('${entity}Names')) {
        inherited.remove('${entity}Ids');
        inherited.remove('${entity}Names');
      }
    }
    final effective = {
      ...inherited,
      ...args,
      if (excludedScope != null) 'exclude': excludedScope
    };
    for (final key in ['start', 'end']) {
      if (effective.containsKey(key) &&
          DateTime.tryParse(effective[key]?.toString() ?? '') == null) {
        return {
          'error': 'invalid_range',
          'retryable': true,
          'message': 'Supply valid ISO dates.'
        };
      }
    }
    if (effective.containsKey('start') && effective.containsKey('end')) {
      effective['period'] = 'custom';
    }
    if (!effective.containsKey('period') &&
        !effective.containsKey('start') &&
        !effective.containsKey('end') &&
        view['ledgerId'] == scope.ledgerId &&
        view['start'] is String &&
        view['end'] is String) {
      effective.addAll(
          {'period': 'custom', 'start': view['start'], 'end': view['end']});
      if (metric != null && metric != 'unspecified') {
        effective.putIfAbsent('rangeMode', () => 'to_date');
      }
    }
    // An overview returns all three totals. A flow-specific chart or list inherits
    // the selected Insights tab unless the user/model supplied another flow.
    if (base == null &&
        !effective.containsKey('flowType') &&
        view['ledgerId'] == scope.ledgerId &&
        (view['flow'] == 'income' || view['flow'] == 'expense') &&
        call.name != 'get_period_overview') {
      effective['flowType'] = view['flow'];
    }
    if (metric != null &&
        metric != 'unspecified' &&
        effective['flowType'] != null &&
        effective['flowType'] != metric) {
      return {
        'error': 'answer_metric_flow_mismatch',
        'retryable': true,
        'message':
            'Use the matching flow for a single metric. Balance and overview require both income and expense.'
      };
    }
    if (effective['amountBasis'] == 'original' &&
        (effective['minAmount'] != null || effective['maxAmount'] != null) &&
        (effective['currency'] is! String ||
            (effective['currency'] as String).trim().isEmpty)) {
      return {'error': 'original_currency_required', 'retryable': true};
    }
    if (effective['minAmount'] case final num minimum) {
      if (effective['maxAmount'] case final num maximum
          when minimum > maximum) {
        return {'error': 'invalid_amount_range', 'retryable': true};
      }
    }
    if (effective['period'] == 'custom') {
      final start = DateTime.tryParse(effective['start']?.toString() ?? '');
      final end = DateTime.tryParse(effective['end']?.toString() ?? '');
      if (start == null || end == null || !start.isBefore(end)) {
        return {
          'error': 'invalid_range',
          'retryable': true,
          'message': 'Supply a start before the exclusive end.'
        };
      }
    }
    final effectiveCall =
        AgentToolCall(id: call.id, name: call.name, arguments: effective);
    late Map<String, Object?> result;
    Map<String, Object?>? snapshot;
    try {
      result = await run(effectiveCall);
    } finally {
      snapshot = _pending.remove(effectiveCall);
    }
    if (result.containsKey('error') ||
        result['matchStatus'] == 'ambiguous' ||
        result['matchStatus'] == 'unmatched') {
      return result;
    }
    final filters = {
      for (final k in filterKeys)
        if (effective.containsKey(k)) k: effective[k],
      if (result['flowType'] != null) 'flowType': result['flowType'],
      if (result['periodStart'] != null && result['periodEnd'] != null) ...{
        'start': result['periodStart'],
        'end': result['periodEnd'],
        'period': 'custom'
      },
      'includeExcludedFromStats': effective['includeExcludedFromStats'] ??
          (call.name == 'query_transactions')
    };
    final reference = '${scope.id}/${current.length + 1}';
    final limit = effective['limit'] is int ? effective['limit'] as int : 20;
    final inheritedPeriod =
        original != null && !overridesDates && !args.containsKey('rangeMode');
    final asOf = _matchingAsOf(
        result['asOf'] ?? (inheritedPeriod ? originalAsOf : null),
        filters['end']);
    final evidence = <String, Object?>{
      'ref': reference,
      'ledgerId': scope.ledgerId,
      'tool': call.name,
      'filters': filters,
      if (call.name == 'get_period_overview') ...{
        'answerMetric': metric ?? 'unspecified',
        'answerPeriod': (inheritedPeriod ? original['answerPeriod'] : null) ??
            result['answerPeriod'] ??
            result['period'],
      },
      if (asOf is String) 'asOf': asOf,
      'options': switch (call.name) {
        'query_transactions' => {
            'limit': limit.clamp(1, 20),
            if (effective['cursor'] is String) 'cursor': effective['cursor'],
          },
        'get_category_breakdown' => {
            'limit': limit.clamp(1, 50),
            'categoryLevel': result['categoryLevel'],
          },
        'get_spending_trend' => {
            'interval': result['interval'],
            'comparison': result['comparison'],
          },
        _ => <String, Object?>{},
      },
    };
    current.add(evidence);
    if (snapshot != null) snapshots[reference] = snapshot;
    return {
      for (final entry in result.entries)
        if (entry.key != 'asOf') entry.key: entry.value,
      if (metric != null) 'answerMetric': metric,
      if (asOf != null) 'asOf': asOf,
      'queryRef': reference,
      'filters': filters
    };
  }
}
