import 'package:agentcore/agentcore.dart';
import 'package:test/test.dart';

void main() {
  test('suggestion keeps stable identity, display title and full user prompt',
      () {
    const suggestion = AgentPromptSuggestion(
      id: 'example',
      title: 'Short title',
      prompt: 'A complete question?',
    );
    expect(suggestion.id, 'example');
    expect(suggestion.title, 'Short title');
    expect(suggestion.prompt, 'A complete question?');
  });
  test('suggestion JSON round trips without losing the full question', () {
    const item = AgentPromptSuggestion(
        id: 'a', title: 'Label', prompt: 'Full question?');
    final restored = AgentPromptSuggestion.fromJson(item.toJson());
    expect(restored.toJson(), item.toJson());
    for (final json in [
      <String, Object?>{},
      {'id': 'a', 'title': 1, 'prompt': 'Q'},
      {'id': '', 'title': 'T', 'prompt': 'Q'},
      {'id': 'a', 'title': 'T', 'prompt': ' '},
    ]) {
      expect(() => AgentPromptSuggestion.fromJson(json), throwsFormatException);
    }
  });

  const a = AgentPromptSuggestion(id: 'a', title: 'A', prompt: 'Question A');
  const b = AgentPromptSuggestion(id: 'b', title: 'B', prompt: 'Question B');
  const c = AgentPromptSuggestion(id: 'c', title: 'C', prompt: 'Question C');
  const d = AgentPromptSuggestion(id: 'd', title: 'D', prompt: 'Question D');
  const selector = AgentPromptSuggestionSelector();
  test('selection is bounded, ordered and immutable', () {
    final items = selector.select([a, b, c, d]);
    expect(items.map((item) => item.id), ['a', 'b', 'c']);
    expect(() => items.add(d), throwsUnsupportedError);
  });
  test('selection removes repeated questions, IDs, current and recent prompts',
      () {
    expect(
        selector
            .select(
                [
                  a,
                  b,
                  b,
                  c,
                  d,
                  const AgentPromptSuggestion(
                      id: 'extra',
                      title: 'Another label',
                      prompt: ' QUESTION   D '),
                ],
                currentPrompt: 'question a',
                recentPrompts: ['  Question B  '])
            .map((item) => item.id),
        ['c', 'd']);
    expect(
        selector.select([
          a,
          const AgentPromptSuggestion(
              id: 'a', title: 'Other', prompt: 'Other question')
        ]),
        [a]);
  });
  test('disabled contexts and invalid candidates do not produce suggestions',
      () {
    expect(selector.select([a], enabled: false), isEmpty);
    expect(const AgentPromptSuggestionSelector(maximumCount: 0).select([a]),
        isEmpty);
    expect(
        selector.select([
          const AgentPromptSuggestion(id: '', title: 'A', prompt: 'Q'),
          const AgentPromptSuggestion(id: 'a', title: ' ', prompt: 'Q'),
          const AgentPromptSuggestion(id: 'b', title: 'B', prompt: ' '),
        ]),
        isEmpty);
  });
  test('evidence copies top-level maps and cannot be modified', () {
    final args = <String, Object?>{'period': 'test'};
    final result = <String, Object?>{'amount': 1};
    final evidence = AgentSuggestionEvidence(
        toolName: 'read', arguments: args, result: result);
    args.clear();
    result.clear();
    expect(evidence.arguments, {'period': 'test'});
    expect(evidence.result, {'amount': 1});
    expect(() => evidence.result.clear(), throwsUnsupportedError);
  });
}
