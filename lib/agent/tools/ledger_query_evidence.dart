import 'package:agentcore/agentcore.dart';

/// Keeps query definitions, never a durable copy of the amounts. Every follow-up
/// executes against the current database and the active ledger.
final class LedgerQueryEvidence {
  LedgerQueryEvidence(this.scope,
      {this.previous = const [], this.view = const {}});
  final AgentScope scope;
  final List<Map<String, Object?>> previous;
  final Map<String, Object?> view;
  final current = <Map<String, Object?>>[];
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

  Map<String, Object?>? lookup(Object? id) {
    for (final item in [...current.reversed, ...previous.reversed]) {
      if (item['ref'] == id &&
          item['ledgerId'] == scope.ledgerId &&
          item['filters'] is Map) {
        return Map<String, Object?>.from(item['filters'] as Map);
      }
    }
    return null;
  }

  Future<Map<String, Object?>> execute(AgentToolCall call,
      Future<Map<String, Object?>> Function(AgentToolCall) run) async {
    final args = Map.of(call.arguments)..remove('exclude');
    final base = args.remove('baseQuery');
    final excluded = args.remove('excludeQuery');
    final inherited = base == null ? <String, Object?>{} : lookup(base);
    final excludedScope = excluded == null ? null : lookup(excluded);
    if (inherited == null || (excluded != null && excludedScope == null)) {
      return {
        'error': 'unknown_query_reference',
        'retryable': true,
        'message':
            'Select a reference from the current ledger or specify the filters again.'
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
    if (args.containsKey('period') ||
        args.containsKey('start') ||
        args.containsKey('end')) {
      for (final key in ['period', 'start', 'end']) {
        inherited.remove(key);
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
    final result = await run(
        AgentToolCall(id: call.id, name: call.name, arguments: effective));
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
    final evidence = <String, Object?>{
      'ref': reference,
      'ledgerId': scope.ledgerId,
      'tool': call.name,
      'filters': filters
    };
    current.add(evidence);
    return {...result, 'queryRef': reference, 'filters': filters};
  }
}
