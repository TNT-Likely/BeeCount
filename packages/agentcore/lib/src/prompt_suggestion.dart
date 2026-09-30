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
}
