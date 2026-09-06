import 'package:beecount/widgets/ai/agent_markdown_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders assistant content with MarkdownBody', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AgentMarkdownText(data: '**本月支出**：`80 元`'),
        ),
      ),
    );

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.data, '**本月支出**：`80 元`');
  });
}
