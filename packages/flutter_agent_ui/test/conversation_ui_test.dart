import 'package:agentcore/agentcore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_agent_ui/flutter_agent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, {ThemeData? theme}) =>
      MaterialApp(theme: theme, home: Scaffold(body: child));
  const step = AgentActivityStep(
      title: 'Read local data',
      status: AgentActivityStatus.completed,
      details: ['September · 3 rows']);
  const question = AgentPromptSuggestion(
      id: 'one',
      title: 'Explore details',
      prompt: 'Read the exact September scope.');

  test('display snapshots validate shape, size and immutable details', () {
    final restored = AgentActivityStep.tryFromJson(step.toJson());
    expect(restored?.title, step.title);
    expect(restored?.status, step.status);
    expect(restored?.details, step.details);
    expect(() => restored!.details.add('another'), throwsUnsupportedError);
    for (final invalid in [
      null,
      [],
      {},
      {'title': 'a', 'status': 'unknown', 'details': []},
      {'title': 'x' * 161, 'status': 'completed', 'details': []},
      {
        'title': 'a',
        'status': 'completed',
        'details': [3]
      },
      {
        'title': 'a',
        'status': 'completed',
        'details': ['x' * 301]
      },
      {'title': 'a', 'status': 'completed', 'details': List.filled(9, 'a')}
    ]) {
      expect(AgentActivityStep.tryFromJson(invalid), isNull);
    }
  });

  testWidgets(
      'disclosure defaults collapsed, preserves expansion during status updates and keeps answer visible',
      (tester) async {
    Widget answer(AgentActivityStatus status) => host(AgentAnswerView(
        activity: AgentActivityView(
            summary: 'Operation state', status: status, steps: const [step]),
        content: const Text('Answer content')));
    await tester.pumpWidget(answer(AgentActivityStatus.generating));
    expect(find.text('Read local data'), findsNothing);
    expect(find.text('Answer content'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pump();
    expect(find.text('September · 3 rows'), findsOneWidget);
    await tester.pumpWidget(answer(AgentActivityStatus.completed));
    expect(find.text('September · 3 rows'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pump();
    expect(find.text('Answer content'), findsOneWidget);
  });

  testWidgets(
      'waiting is not a spinning progress indicator, and preparation has no clickable empty disclosure',
      (tester) async {
    await tester.pumpWidget(host(const AgentActivityView(
        summary: 'Awaiting permission',
        status: AgentActivityStatus.waiting,
        steps: [step])));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(host(const AgentActivityView(
        summary: 'Preparing',
        status: AgentActivityStatus.preparing,
        steps: [])));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('agent-activity-details')), findsNothing);
  });

  testWidgets(
      'active execution auto-expands even when a fast tool already completed',
      (tester) async {
    Widget activity(
            AgentActivityStatus status, List<AgentActivityStep> steps) =>
        host(AgentActivityView(
            summary: 'State',
            status: status,
            steps: steps,
            expandWhileActive: true));
    await tester.pumpWidget(activity(AgentActivityStatus.preparing, []));
    expect(find.byKey(const ValueKey('agent-activity-details')), findsNothing);
    for (final status in [
      AgentActivityStatus.awaitingModel,
      AgentActivityStatus.thinking,
      AgentActivityStatus.generating
    ]) {
      await tester.pumpWidget(activity(status, [step]));
      expect(find.text('Read local data'), findsOneWidget);
      expect(find.text('September · 3 rows'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    }
    await tester.pumpWidget(activity(AgentActivityStatus.completed, [step]));
    expect(find.text('Read local data'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pump();
    expect(find.text('Read local data'), findsOneWidget);
  });

  testWidgets('manual expansion choices override active automatic disclosure',
      (tester) async {
    Widget activity(AgentActivityStatus status) => host(AgentActivityView(
        summary: 'State',
        status: status,
        steps: const [step],
        expandWhileActive: true));
    await tester.pumpWidget(activity(AgentActivityStatus.awaitingModel));
    expect(find.text('Read local data'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pump();
    for (final status in [
      AgentActivityStatus.thinking,
      AgentActivityStatus.generating
    ]) {
      await tester.pumpWidget(activity(status));
      expect(find.text('Read local data'), findsNothing);
    }
    await tester.tap(find.byKey(const ValueKey('agent-activity-toggle')));
    await tester.pump();
    await tester.pumpWidget(activity(AgentActivityStatus.completed));
    expect(find.text('Read local data'), findsOneWidget);
  });

  testWidgets(
      'answer content spans available width without bubble or avatar gutters',
      (tester) async {
    await tester.pumpWidget(host(SizedBox(
        width: 320,
        child: AgentAnswerView(
            content: Container(key: const ValueKey('content'), height: 40),
            actions: const Text('Actions')))));
    expect(tester.getSize(find.byKey(const ValueKey('content'))).width, 320);
  });

  testWidgets(
      'questions and templates rotate in one pool and preserve full prompts',
      (tester) async {
    AgentPromptSuggestion? selected;
    final questions = [
      question,
      const AgentPromptSuggestion(
          id: 'two', title: 'Second', prompt: 'Second complete request'),
      const AgentPromptSuggestion(
          id: 'three', title: 'Third', prompt: 'Third complete request')
    ];
    await tester.pumpWidget(host(AgentFollowUpSection(
        questions: questions,
        templates: const [
          AgentPromptSuggestion(
              id: 'template', title: 'Template', prompt: 'Complete template')
        ],
        title: 'Explore',
        rotateLabel: 'Another set',
        onSelected: (item) => selected = item)));
    expect(find.text('Third'), findsNothing);
    expect(find.text('Template'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('agent-follow-up-rotate')));
    await tester.pump();
    expect(selected, isNull);
    expect(find.text('Third'), findsOneWidget);
    await tester.tap(find.text('Third'));
    expect(selected?.prompt, 'Third complete request');
    expect(find.byKey(const ValueKey('agent-follow-up-more')), findsNothing);
    await tester.tap(find.text('Template'));
    expect(selected?.prompt, 'Complete template');
  });

  testWidgets(
      'narrow screens and large type reflow without overflow in light and dark themes',
      (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(
          MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                  child: SizedBox(
                      width: 240,
                      child: Column(children: [
                        const AgentActivityView(
                            summary:
                                'A deliberately long status message that wraps',
                            status: AgentActivityStatus.completed,
                            steps: [step]),
                        AgentFollowUpSection(
                            questions: const [
                              question
                            ],
                            templates: [
                              for (var i = 0; i < 6; i++)
                                AgentPromptSuggestion(
                                    id: 't$i',
                                    title: 'A long analysis topic $i',
                                    prompt: 'Full topic $i')
                            ],
                            title: 'Explore further',
                            rotateLabel: 'Another set',
                            onSelected: (_) {}),
                      ])))),
          theme: ThemeData(brightness: brightness)));
      await tester.tap(find.byKey(const ValueKey('agent-follow-up-rotate')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          tester
              .getSize(find.byKey(const ValueKey('agent-follow-up-t1')))
              .width,
          lessThanOrEqualTo(240));
    }
  });

  testWidgets('scroll overlay is labeled and invokes only the host callback',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(AgentScrollToLatestButton(
        label: 'Latest message', onPressed: () => tapped = true)));
    expect(find.byTooltip('Latest message'), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(tapped, isTrue);
    expect(tester.getSize(find.byType(IconButton)).width,
        greaterThanOrEqualTo(44));
  });

  testWidgets(
      'follow-up surface derives from primary and supports host palette overrides',
      (tester) async {
    Widget section({AgentFollowUpStyle style = const AgentFollowUpStyle()}) =>
        AgentFollowUpSection(
            questions: const [question],
            templates: const [],
            title: 'Explore',
            rotateLabel: 'Another set',
            onSelected: (_) {},
            style: style);
    for (final brightness in Brightness.values) {
      final scheme =
          ColorScheme.fromSeed(seedColor: Colors.purple, brightness: brightness)
              .copyWith(primary: Colors.green);
      await tester
          .pumpWidget(host(section(), theme: ThemeData(colorScheme: scheme)));
      await tester.pumpAndSettle();
      final surface = tester
          .widget<DecoratedBox>(
              find.byKey(const ValueKey('agent-follow-up-surface')))
          .decoration as BoxDecoration;
      expect(
          surface.color,
          Color.alphaBlend(
              Colors.green.withValues(
                  alpha: brightness == Brightness.dark ? 0.15 : 0.08),
              scheme.surface));
      expect(surface.color, isNot(scheme.surfaceContainerLow));
      expect(
          (tester
                  .widget<Container>(
                      find.byKey(const ValueKey('agent-follow-up-accent')))
                  .decoration as BoxDecoration)
              .color,
          Colors.green);
    }
    const custom = AgentFollowUpStyle(
        surfaceColor: Colors.black,
        accentColor: Colors.amber,
        foregroundColor: Colors.white,
        secondaryForegroundColor: Colors.grey,
        separatorColor: Colors.orange);
    await tester.pumpWidget(host(section(style: custom)));
    await tester.pumpAndSettle();
    expect(
        (tester
                .widget<DecoratedBox>(
                    find.byKey(const ValueKey('agent-follow-up-surface')))
                .decoration as BoxDecoration)
            .color,
        custom.surfaceColor);
    expect(tester.widget<Text>(find.text('Explore details')).style?.color,
        custom.foregroundColor);
    expect(tester.widget<Text>(find.text('Explore')).style?.color,
        custom.secondaryForegroundColor);
  });

  testWidgets(
      'manual navigation cancels initial positioning even during its stability window',
      (tester) async {
    final controller = ScrollController();
    final coordinator = AgentConversationScrollCoordinator(controller);
    addTearDown(coordinator.dispose);
    addTearDown(controller.dispose);
    var rows = 30;
    late StateSetter update;
    await tester.pumpWidget(host(StatefulBuilder(builder: (context, setState) {
      update = setState;
      return NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          coordinator.onScrollMetricsChanged();
          return false;
        },
        child: ListView.builder(
            controller: controller,
            itemCount: rows,
            itemBuilder: (_, index) =>
                SizedBox(height: 60, child: Text('Row $index'))),
      );
    })));
    coordinator.requestInitialPositioning();
    await tester.pump();
    expect(controller.offset, controller.position.maxScrollExtent);
    coordinator.onUserScroll();
    controller.jumpTo(120);
    update(() => rows = 40);
    await tester.pumpAndSettle();
    expect(controller.offset, 120);
  });
}
