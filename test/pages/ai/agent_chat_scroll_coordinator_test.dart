import 'package:beecount/pages/ai/agent_chat_scroll_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('首帧加载历史消息后无需额外刷新也定位到最后一条', (tester) async {
    final controller = ScrollController();
    final coordinator = AgentChatScrollCoordinator(controller);
    addTearDown(coordinator.dispose);
    var requested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            if (!requested) {
              requested = true;
              coordinator.requestInitialPositioning();
            }
            return ListView.builder(
              controller: controller,
              itemCount: 40,
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

    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets('助手消息进入列表后才滚动到底部', (tester) async {
    final controller = ScrollController();
    final coordinator = AgentChatScrollCoordinator(controller);
    addTearDown(coordinator.dispose);
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

  testWidgets('首帧内容尚未形成滚动范围时，后续布局变化仍定位到底部', (tester) async {
    final controller = ScrollController();
    final coordinator = AgentChatScrollCoordinator(controller);
    addTearDown(coordinator.dispose);
    var itemCount = 1;
    var requested = false;
    late StateSetter updateItems;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateItems = setState;
            if (!requested) {
              requested = true;
              coordinator.requestInitialPositioning();
            }
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

    await tester.pumpAndSettle();
    expect(controller.position.maxScrollExtent, 0);

    updateItems(() => itemCount = 40);
    coordinator.onContentLaidOut(targetReady: true);
    await tester.pump();

    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets('定位请求早于列表挂载时也会在后续帧定位到底部', (tester) async {
    final controller = ScrollController();
    final coordinator = AgentChatScrollCoordinator(controller);
    addTearDown(coordinator.dispose);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    coordinator.requestInitialPositioning();
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        home: ListView.builder(
          controller: controller,
          itemCount: 40,
          itemBuilder: (_, index) => SizedBox(
            height: 60,
            child: Text('late history $index'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets('首屏内容延迟超过重试窗口后仍会定位到底部', (tester) async {
    final controller = ScrollController();
    final coordinator = AgentChatScrollCoordinator(controller);
    addTearDown(coordinator.dispose);
    var itemCount = 1;
    var requested = false;
    late StateSetter updateItems;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateItems = setState;
            if (!requested) {
              requested = true;
              coordinator.requestInitialPositioning();
            }
            return ListView.builder(
              controller: controller,
              itemCount: itemCount,
              itemBuilder: (_, index) => SizedBox(
                height: 60,
                child: Text('delayed history $index'),
              ),
            );
          },
        ),
      ),
    );

    // Simulate a slow device where the history rows are not available before
    // the coordinator's current bounded frame retries are exhausted.
    for (var frame = 0; frame < 12; frame++) {
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }

    updateItems(() => itemCount = 40);
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.position.maxScrollExtent, greaterThan(0));
    expect(controller.offset, controller.position.maxScrollExtent);
  });

  testWidgets('首次定位后消息行高度变化仍会重新校正到底部', (tester) async {
    final controller = ScrollController();
    final coordinator = AgentChatScrollCoordinator(controller);
    addTearDown(coordinator.dispose);
    var itemHeight = 60.0;
    var requested = false;
    late StateSetter updateItems;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateItems = setState;
            if (!requested) {
              requested = true;
              coordinator.requestInitialPositioning();
            }
            return ListView.builder(
              controller: controller,
              itemCount: 40,
              itemBuilder: (_, index) => SizedBox(
                height: itemHeight,
                child: Text('resized history $index'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(controller.offset, controller.position.maxScrollExtent);

    updateItems(() => itemHeight = 80);
    coordinator.onScrollMetricsChanged();
    await tester.pump();
    await tester.pump();

    expect(controller.position.maxScrollExtent, greaterThan(1800));
    expect(controller.offset, controller.position.maxScrollExtent);
  });
}
