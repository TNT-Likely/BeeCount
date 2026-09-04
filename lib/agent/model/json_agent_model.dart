import 'package:agentcore/agentcore.dart';

import '../../ai/providers/ai_provider_factory.dart';
import 'agent_prompt_builder.dart';

typedef AgentChatTransport = Future<String> Function({
  required String prompt,
  String? systemPrompt,
  double temperature,
  String? logTag,
});

/// Adapts the selected existing text provider to the strict Agent JSON protocol.
/// At most one protocol-repair request is sent for a model turn.
final class JsonAgentModel implements AgentModel {
  JsonAgentModel({
    AgentChatTransport? transport,
    AgentPromptBuilder promptBuilder = const AgentPromptBuilder(),
    AgentTurnParser parser = const AgentTurnParser(),
  })  : _transport = transport ?? _defaultTransport,
        _promptBuilder = promptBuilder,
        _parser = parser;

  final AgentChatTransport _transport;
  final AgentPromptBuilder _promptBuilder;
  final AgentTurnParser _parser;

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    final raw = await _request(_promptBuilder.build(request));
    try {
      return _parser.parse(raw);
    } on AgentParseFailure catch (firstFailure) {
      final repaired = await _request(_promptBuilder.repair(raw, firstFailure));
      try {
        return _parser.parse(repaired);
      } on AgentParseFailure catch (secondFailure) {
        throw AgentModelProtocolException(secondFailure.reason);
      }
    }
  }

  Future<String> _request(String prompt) => _transport(
        prompt: prompt,
        systemPrompt: AgentPromptBuilder.jsonFallbackSystemPrompt,
        temperature: 0.1,
        logTag: 'AgentModel',
      );

  static Future<String> _defaultTransport({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.1,
    String? logTag,
  }) =>
      AIProviderFactory.chat(
        prompt,
        systemPrompt: systemPrompt,
        temperature: temperature,
        logTag: logTag,
      );
}

final class AgentModelProtocolException implements Exception {
  const AgentModelProtocolException(this.reason);

  final String reason;

  @override
  String toString() => 'AgentModelProtocolException($reason)';
}
