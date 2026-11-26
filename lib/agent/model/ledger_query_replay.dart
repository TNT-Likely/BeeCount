import 'package:agentcore/agentcore.dart';

import '../tools/local_agent_tool_catalog.dart';

/// Reruns a saved financial answer through the normal permissioned tool loop.
/// Only query definitions are accepted. The model receives fresh observations.
final class LedgerQueryReplay implements AgentModel, AgentRunFinalizer {
  LedgerQueryReplay(this.model, this.calls);
  final AgentModel model;
  final List<AgentToolCall> calls;
  bool _started = false;

  static const _options = <String, Set<String>>{
    'get_period_overview': {},
    'get_spending_trend': {'interval', 'comparison'},
    'get_category_breakdown': {'categoryLevel', 'limit'},
    'query_transactions': {'limit', 'cursor'},
  };

  static List<Map<String, Object?>> definitions(
      Iterable<Map<String, Object?>> queries, int ledgerId) {
    if (queries.isEmpty || queries.length > 12) return const [];
    final result = <Map<String, Object?>>[];
    for (final q in queries) {
      final tool = q['tool'];
      final options = q['options'];
      final filters = q['filters'];
      final metric = q['answerMetric'];
      if (q['ledgerId'] != ledgerId ||
          q['ref'] is! String ||
          !_options.containsKey(tool) ||
          (q.containsKey('answerMetric') &&
              (tool != 'get_period_overview' ||
                  !LocalAgentToolCatalog.answerMetrics.contains(metric))) ||
          options is! Map ||
          filters is! Map ||
          !options.keys.every(_options[tool]!.contains) ||
          filters['period'] != 'custom' ||
          DateTime.tryParse(filters['start']?.toString() ?? '') == null ||
          DateTime.tryParse(filters['end']?.toString() ?? '') == null) {
        return const [];
      }
      result.add({
        'ledgerId': ledgerId,
        'ref': q['ref'],
        'tool': tool,
        if (metric != null) 'answerMetric': metric,
        if (q['answerPeriod'] is String) 'answerPeriod': q['answerPeriod'],
        if (q['asOf'] is String) 'asOf': q['asOf'],
        'filters': Map<String, Object?>.from(filters),
        'options': Map<String, Object?>.from(options)
      });
    }
    return result;
  }

  static List<AgentToolCall> callsFor(List<Map<String, Object?>> definitions) =>
      [
        for (final (i, q) in definitions.indexed)
          AgentToolCall(
              id: 'repeat_${i + 1}',
              name: q['tool'] as String,
              arguments: {
                'baseQuery': q['ref'],
                if (q['answerMetric'] != null)
                  'answerMetric': q['answerMetric'],
                ...q['options'] as Map<String, Object?>
              }),
      ];

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    if (!_started) {
      _started = true;
      return AgentTurn.toolCalls(calls);
    }
    final answer = await model.nextTurn(AgentRequest(
      text: request.text,
      scope: request.scope,
      context: {...request.context, 'recheckedResults': request.toolData},
      availableToolNames: const {},
      allowToolCalls: false,
    ));
    if (answer is! AgentFinalTextTurn) {
      throw const FormatException(
          'A repeated query must finish with an answer');
    }
    return answer;
  }

  @override
  void disposeRun(String runId) {
    if (model case final AgentRunFinalizer finalizer) {
      finalizer.disposeRun(runId);
    }
  }
}
