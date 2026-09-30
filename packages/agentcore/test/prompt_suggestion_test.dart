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
}
