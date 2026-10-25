import 'dart:io';
import 'package:beecount/widgets/biz/ledger_selector_dialog.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/presentation/v4/bindings/ai_conversation_preview.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/widgets/ai/agent_tool_authorization_dialog.dart';
import 'package:beecount/agent/permission/agent_authorization_gate.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget body) => MaterialApp(
    theme: beeTheme(brightness: Brightness.dark),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
        data: const MediaQueryData(
            size: Size(320, 568), textScaler: TextScaler.linear(1.4)),
        child: Scaffold(body: body)));
void main() {
  void small(WidgetTester t) {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('紧凑英文大字输入可直接编辑、发送与停止，运行中禁用文字输入', (t) async {
    small(t);
    final input = TextEditingController();
    addTearDown(input.dispose);
    var sent = '', stopped = 0, busy = false;
    late StateSetter update;
    final l = AppLocalizationsEn();
    await t.pumpWidget(host(StatefulBuilder(builder: (context, set) {
      update = set;
      return Column(children: [
        const Expanded(child: SizedBox()),
        BeeConversationInput(
            controller: input,
            hint: l.aiChatInputHint,
            sendLabel: l.v4AIChatSend,
            stopLabel: l.agentRunStop,
            busy: busy,
            onSend: () {
              sent = input.text;
              update(() => busy = true);
            },
            onStop: () {
              stopped++;
              update(() => busy = false);
            })
      ]);
    })));
    await t.enterText(find.byType(TextField), 'QA direct text');
    await t.tap(find.byKey(const ValueKey('ai-chat-send')));
    await t.pumpAndSettle();
    expect(sent, 'QA direct text');
    expect(t.widget<TextField>(find.byType(TextField)).enabled, false);
    await t.tap(find.byKey(const ValueKey('ai-chat-send')));
    await t.pumpAndSettle();
    expect(stopped, 1);
    expect(t.widget<TextField>(find.byType(TextField)).enabled, true);
    expect(t.takeException(), isNull);
  });
  testWidgets('英文短屏长参数授权可滚动，三种动作固定可达，关闭默认拒绝', (t) async {
    small(t);
    AgentToolAuthorizationChoice? result;
    await t.pumpWidget(host(Builder(
        builder: (context) => TextButton(
            onPressed: () async {
              result = await showAgentToolAuthorizationDialog(
                  context: context,
                  request: AgentToolAuthorizationRequest(
                      authorizationId: 'qa',
                      runId: 'qa',
                      ledgerId: 1,
                      toolName: 'record_transaction_from_text',
                      arguments: {
                        'sourceText':
                            List.filled(100, 'QA long source').join(' ')
                      }));
            },
            child: const Text('open')))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final l = AppLocalizationsEn();
    expect(find.byType(BeeDialog), findsOneWidget);
    for (final label in [
      l.agentAuthorizationDeny,
      l.agentAuthorizationAllowOnce,
      l.agentAuthorizationAlwaysAllow
    ]) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    await t.tap(find.byType(CloseButton));
    await t.pumpAndSettle();
    expect(result, AgentToolAuthorizationChoice.deny);
    expect(t.takeException(), isNull);
  });
  testWidgets('输入区与独立HTML规范保持17页边距、8内距和44操作区', (t) async {
    t.view.physicalSize = const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: 'qa');
    addTearDown(controller.dispose);
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: Column(children: [
          const Expanded(child: SizedBox()),
          BeeConversationInput(
              controller: controller,
              hint: 'input',
              sendLabel: 'send',
              stopLabel: 'stop',
              busy: false,
              onSend: () {},
              onStop: () {})
        ]))));
    await t.pumpAndSettle();
    final surface = find.descendant(
        of: find.byType(BeeConversationInput),
        matching: find.byType(BeeSurface));
    final frame = t.getRect(surface), field = t.getRect(find.byType(TextField));
    expect(frame.left, 17);
    expect(frame.width, 364);
    expect(field.left - frame.left, 8);
    expect(field.height, 48);
    expect(t.getSize(find.byKey(const ValueKey('ai-chat-send'))),
        const Size(44, 44));
    expect(
        t.widget<BeeSurface>(surface).borderRadius, BorderRadius.circular(18));
    final css =
        File('docs/design/card-refresh/prototype/src/ai-conversation.css')
            .readAsStringSync();
    expect(css, contains('margin:8px 17px 0;padding:8px;border-radius:18px'));
    expect(css, contains('min-height:48px'));
    expect(t.takeException(), isNull);
  });
  testWidgets('真实账本选择保留弹窗、当前项与ID返回，不切换或改写原账本', (t) async {
    small(t);
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalRepository(db);
    final first = await repo.createLedger(name: 'qa-ledger-one');
    final second =
        await repo.createLedger(name: 'qa-ledger-two', currency: 'USD');
    final before = await repo.getAllLedgers();
    int? selected;
    await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo)
        ],
        child: host(Builder(
            builder: (context) => TextButton(
                child: const Text('choose'),
                onPressed: () async {
                  selected =
                      await showLedgerSelector(context, currentLedgerId: first);
                })))));
    await t.tap(find.text('choose'));
    await t.pumpAndSettle();
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(t.widget<BeeLedgerPicker>(find.byType(BeeLedgerPicker)).currentId,
        '$first');
    await t.enterText(find.byType(TextField), 'qa-ledger-two');
    await t.pumpAndSettle();
    await t.tap(
        find.byWidgetPredicate((w) => w is Text && w.data == 'qa-ledger-two'));
    await t.pumpAndSettle();
    expect(selected, second);
    expect((await repo.getAllLedgers()).map((r) => r.toJson()).toList(),
        before.map((r) => r.toJson()).toList());
    await t.tap(find.text('choose'));
    await t.pumpAndSettle();
    await t.tap(find.byType(CloseButton));
    await t.pumpAndSettle();
    expect(selected, isNull);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });

  testWidgets('真实仓储只读目录不会创建空会话或消息', (t) async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalRepository(db);
    await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo)
        ],
        child: host(
            const SingleChildScrollView(child: LiveAIConversationPreview()))));
    await t.pumpAndSettle();
    expect(find.text('没有会话，不创建示例对象'), findsOneWidget);
    expect(await db.select(db.conversations).get(), isEmpty);
    expect(await db.select(db.messages).get(), isEmpty);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
}
