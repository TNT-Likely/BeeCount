import 'dart:convert';

import 'contracts.dart';

/// Parses the deliberately small JSON protocol used between an Agent model and
/// the local tool runtime. The parser accepts data only; it never executes a
/// tool or assigns permissions.
final class AgentTurnParser {
  const AgentTurnParser({required this.allowedToolNames});

  final Set<String> allowedToolNames;

  AgentTurn parse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const AgentParseFailure('invalid_json');
    }

    if (decoded is! Map) {
      throw const AgentParseFailure('response_must_be_an_object');
    }
    final object = Map<String, Object?>.from(decoded);
    final kind = object['kind'];
    if (kind is! String) throw const AgentParseFailure('missing_kind');

    return switch (kind) {
      'final' => _parseFinal(object),
      'tool_calls' => _parseToolCalls(object),
      _ => throw const AgentParseFailure('unsupported_kind'),
    };
  }

  AgentFinalTextTurn _parseFinal(Map<String, Object?> object) {
    _requireExactKeys(object, const {'kind', 'text'});
    final text = object['text'];
    if (text is! String || text.trim().isEmpty) {
      throw const AgentParseFailure('invalid_final_text');
    }
    return AgentFinalTextTurn(text);
  }

  AgentToolCallsTurn _parseToolCalls(Map<String, Object?> object) {
    _requireExactKeys(object, const {'kind', 'calls'});
    final rawCalls = object['calls'];
    if (rawCalls is! List || rawCalls.isEmpty) {
      throw const AgentParseFailure('invalid_calls');
    }

    final calls = <AgentToolCall>[];
    for (final rawCall in rawCalls) {
      if (rawCall is! Map) throw const AgentParseFailure('invalid_call');
      final call = Map<String, Object?>.from(rawCall);
      _requireExactKeys(call, const {'id', 'name', 'arguments'});
      final id = call['id'];
      final name = call['name'];
      final arguments = call['arguments'];
      if (id is! String || id.trim().isEmpty) {
        throw const AgentParseFailure('invalid_call_id');
      }
      if (name is! String || !allowedToolNames.contains(name)) {
        throw const AgentParseFailure('unknown_tool');
      }
      if (arguments is! Map) {
        throw const AgentParseFailure('invalid_arguments');
      }
      calls.add(
        AgentToolCall(
          id: id,
          name: name,
          arguments: Map<String, Object?>.from(arguments),
        ),
      );
    }
    return AgentToolCallsTurn(calls);
  }

  void _requireExactKeys(Map<String, Object?> object, Set<String> expected) {
    if (object.length != expected.length ||
        !object.keys.toSet().containsAll(expected)) {
      throw const AgentParseFailure('unexpected_fields');
    }
  }
}

final class AgentParseFailure implements Exception {
  const AgentParseFailure(this.reason);

  final String reason;

  @override
  String toString() => 'AgentParseFailure($reason)';
}
