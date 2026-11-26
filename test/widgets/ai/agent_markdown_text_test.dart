import 'package:beecount/pages/ai/chat/widgets/agent_markdown_text.dart';
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
    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('横向滚动正文后仍可恢复该回答的展开状态', (tester) async {
    final bucket = PageStorageBucket();
    const answerKey = PageStorageKey<String>('answer-details');
    final data = '明细\n\n```text\n${'1234567890' * 12}\n```';

    Widget page({required bool showAnswer}) => MaterialApp(
          home: Scaffold(
            body: PageStorage(
              bucket: bucket,
              child: SizedBox(
                width: 300,
                child: showAnswer
                    ? ExpansionTile(
                        key: answerKey,
                        title: const Text('展开完整回答'),
                        children: [AgentMarkdownText(data: data)],
                      )
                    : const SizedBox(),
              ),
            ),
          ),
        );

    await tester.pumpWidget(page(showAnswer: true));
    await tester.tap(find.text('展开完整回答'));
    await tester.pumpAndSettle();
    final code = find.byWidgetPredicate((w) =>
        w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
    final offset = tester.widget<SingleChildScrollView>(code).controller!;
    expect(offset.position.maxScrollExtent, greaterThan(0));
    offset.jumpTo(offset.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(offset.offset, greaterThan(0));
    expect(bucket.readState(tester.element(find.byKey(answerKey))), isTrue);

    await tester.pumpWidget(page(showAnswer: false));
    await tester.pumpWidget(page(showAnswer: true));
    await tester.pumpAndSettle();
    expect(code, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
