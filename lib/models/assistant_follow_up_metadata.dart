import 'dart:convert';

import 'package:agentcore/agentcore.dart';

/// Optional message metadata, no schema migration. Never reuse questions under
/// another ledger; malformed/old metadata simply has no follow-ups.
final class AssistantFollowUpMetadata {
  const AssistantFollowUpMetadata._();

  /// Older successful text messages can offer the generic catalog. New runs
  /// explicitly opt out after cancellation, authorization denial or failure.
  static bool allowsAnalysisTemplates(String? metadata) {
    if (metadata == null) return true;
    try {
      final json = jsonDecode(metadata);
      return json is Map && json['analysisTemplatesAllowed'] != false;
    } on Object {
      return false;
    }
  }

  static Map<String, Object?> encode(List<AgentPromptSuggestion> suggestions,
          {required int ledgerId}) =>
      {
        'followUpVersion': 1,
        'followUpLedgerId': ledgerId,
        'followUps': suggestions.map((item) => item.toJson()).toList(),
      };

  static List<AgentPromptSuggestion> decode(String? metadata,
      {required int ledgerId}) {
    if (metadata == null) return const [];
    try {
      final json = jsonDecode(metadata);
      if (json is! Map ||
          json['followUpVersion'] != 1 ||
          json['followUpLedgerId'] != ledgerId ||
          json['followUps'] is! List) {
        return const [];
      }
      final candidates = <AgentPromptSuggestion>[];
      for (final raw in (json['followUps'] as List).take(12)) {
        if (raw is! Map) continue;
        try {
          candidates.add(
              AgentPromptSuggestion.fromJson(Map<String, Object?>.from(raw)));
        } on Object {
          // One malformed suggestion does not invalidate the whole message.
        }
      }
      return const AgentPromptSuggestionSelector().select(candidates);
    } on Object {
      return const [];
    }
  }
}
