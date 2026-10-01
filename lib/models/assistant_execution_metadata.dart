import 'dart:convert';

import 'package:flutter_agent_ui/flutter_agent_ui.dart';

/// Optional, bounded display snapshots. No schema change or raw tool payloads.
/// Historical messages without snapshots simply have no execution disclosure.
final class AssistantExecutionMetadata {
  const AssistantExecutionMetadata._();

  static Map<String, Object?> encode(List<AgentActivityStep> steps) =>
      steps.isEmpty
          ? const {}
          : {
              'executionDisplayVersion': 1,
              'executionDisplaySteps':
                  steps.take(24).map((step) => step.toJson()).toList(),
            };

  static List<AgentActivityStep> decode(String? metadata) {
    if (metadata == null) return const [];
    try {
      final json = jsonDecode(metadata);
      if (json is! Map ||
          json['executionDisplayVersion'] != 1 ||
          json['executionDisplaySteps'] is! List) {
        return const [];
      }
      return List.unmodifiable((json['executionDisplaySteps'] as List)
          .take(24)
          .map(AgentActivityStep.tryFromJson)
          .whereType<AgentActivityStep>()
          .where((step) =>
              step.status == AgentActivityStatus.completed ||
              step.status == AgentActivityStatus.failed));
    } on Object {
      return const [];
    }
  }
}
