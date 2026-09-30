/// A discoverable user question, not a tool command or preloaded-data task.
/// The host submits [prompt] unchanged through its normal conversation entry
/// and persists it as the visible user message. Labels and wording belong to
/// the host; this contract has no business, UI or storage dependency.
final class AgentPromptSuggestion {
  const AgentPromptSuggestion({
    required this.id,
    required this.title,
    required this.prompt,
  });

  final String id;
  final String title;
  final String prompt;

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'prompt': prompt};

  factory AgentPromptSuggestion.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    final prompt = json['prompt'];
    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        prompt is! String ||
        prompt.trim().isEmpty) {
      throw const FormatException('Invalid prompt suggestion');
    }
    return AgentPromptSuggestion(id: id, title: title, prompt: prompt);
  }
}

/// Host-ranked selection without model requests or business-specific rules.
/// Hosts decide eligibility; disabled contexts produce no recommendations.
final class AgentPromptSuggestionSelector {
  const AgentPromptSuggestionSelector({this.maximumCount = 3});

  final int maximumCount;

  List<AgentPromptSuggestion> select(
    Iterable<AgentPromptSuggestion> candidates, {
    bool enabled = true,
    String currentPrompt = '',
    Iterable<String> recentPrompts = const [],
  }) {
    if (!enabled || maximumCount <= 0) return const [];
    final usedPrompts = {
      for (final prompt in [currentPrompt, ...recentPrompts]) _normalize(prompt)
    };
    final usedIds = <String>{};
    final selected = <AgentPromptSuggestion>[];
    for (final item in candidates) {
      final normalized = _normalize(item.prompt);
      if (item.id.trim().isEmpty ||
          item.title.trim().isEmpty ||
          normalized.isEmpty ||
          usedIds.contains(item.id) ||
          usedPrompts.contains(normalized)) continue;
      usedIds.add(item.id);
      usedPrompts.add(normalized);
      selected.add(item);
      if (selected.length == maximumCount) break;
    }
    return List.unmodifiable(selected);
  }

  static String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Successful tool evidence supplied by the host, not inferred from prose.
/// Domain-specific interpretation and recommendation wording stay in the host.
final class AgentSuggestionEvidence {
  AgentSuggestionEvidence(
      {required this.toolName,
      required Map<String, Object?> arguments,
      required Map<String, Object?> result})
      : arguments = Map.unmodifiable(arguments),
        result = Map.unmodifiable(result);

  final String toolName;
  final Map<String, Object?> arguments;
  final Map<String, Object?> result;
}
