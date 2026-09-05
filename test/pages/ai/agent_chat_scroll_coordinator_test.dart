import 'package:beecount/pages/ai/agent_chat_scroll_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('初始历史消息完成布局后定位到最后一条', (tester) async {
    final controller = ScrollController();
    final coordinator = AgentChatScrollCoordinator(controller);
    var itemCount = 0;
    late StateSetter updateItems;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateItems = setState;
            return ListView.builder(
              controller: controller,
              itemCount: itemCount,
              itemBuilder: (_, index) => SizedBox(
                height: 60,
                child: Text('history $index'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    coordinator.requestInitialPositioning();
    coordinator.onContentLaidOut(targetReady: false);
    await tester.pump();
    expect(controller.offset, 0);

    updateItems(() => itemCount = 40);
    coordinator.onContentLaidOut(targetReady: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets('助手消息进入列表后才滚动到底部', (tester) async {
    final controller = ScrollController();
    final coordinator = AgentChatScrollCoordinator(controller);
    var itemCount = 3;
    late StateSetter updateItems;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateItems = setState;
            return ListView.builder(
              controller: controller,
              itemCount: itemCount,
              itemBuilder: (_, index) => SizedBox(
                height: 60,
                child: Text('message $index'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    coordinator.request();
    coordinator.onContentLaidOut(targetReady: false);
    await tester.pump();
    expect(controller.offset, 0);

    updateItems(() => itemCount = 40);
    coordinator.onContentLaidOut(targetReady: true);
    await tester.pump();
    expect(controller.position.maxScrollExtent, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.offset, controller.position.maxScrollExtent);
  });
}
