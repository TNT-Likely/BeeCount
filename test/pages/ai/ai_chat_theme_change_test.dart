import 'dart:async';
import 'dart:convert';

import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/ai/core/bill_info.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/main.dart' as app;
import 'package:beecount/models/assistant_follow_up_metadata.dart';
import 'package:beecount/pages/ai/ai_chat_page.dart';
import 'package:beecount/pages/ai/chat/widgets/bill_card_widget.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai_eval/support/ledger_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsZh();
  late LedgerEvalFixture fixture;
  late int ledgerId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ai_capability_binding_v2': '{}',
      'selected_language': 'zh',
    });
    fixture = await LedgerEvalFixture.create();
    ledgerId = fixture.ledgers['main']!;
    final conversation = await fixture.repository
        .createConversation(const ConversationsCompanion());
    Future<int> save(
            String type, String content, Map<String, Object?> metadata) =>
        fixture.repository.createMessage(MessagesCompanion.insert(
            conversationId: conversation,
            role: 'assistant',
            content: content,
            messageType: type,
            metadata: Value(jsonEncode(metadata))));
    await save('text', '秋季复盘', {});
    final bill = await fixture.repository.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 28,
        happenedAt: fixture.now,
        note: '测试午餐');
    await save('bill_card', '已记账', {
      'bills': [
        BillInfo(
                amount: -28,
                type: BillType.expense,
                time: fixture.now,
                category: '午餐',
                ledgerId: ledgerId)
            .toJson()
      ],
      'txIds': [bill],
      'undoneIds': <int>[],
      'supplementalText': '按 20 天算共 560 元。',
    });
    await save('text', '满 60 元的有一笔。', {
      'contextLedgerId': ledgerId,
      'queryContext': {
        'displayRefs': ['all', 'large'],
        'queries': [
          for (final key in ['all', 'large'])
            {
              'ref': key,
              'ledgerId': ledgerId,
              'filters': {
                'start': '2026-09-01',
                'end': '2026-10-01',
                'categoryNames': ['餐饮'],
                if (key == 'large') 'minAmount': 60,
              }
            },
        ]
      },
      ...AssistantFollowUpMetadata.encode([
        const core.AgentPromptSuggestion(
            id: 'cash', title: '现金多少？', prompt: '现金多少？')
      ], ledgerId: ledgerId),
    });
  });
  tearDown(() => fixture.close());

  for (final withSheet in [false, true]) {
    final location = withSheet ? '打开的相关账单' : '聊天记录';
    testWidgets('实际 App 主题在$location中逐帧切换深浅色', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(ProviderScope(overrides: [
        databaseProvider.overrideWithValue(fixture.database),
        repositoryProvider.overrideWithValue(fixture.repository),
        localAgentToolGatewayProvider.overrideWithValue(fixture.gateway),
        currentLedgerIdProvider.overrideWith((_) => ledgerId),
        welcomeCheckProvider.overrideWith((_) async => true),
        shouldShowWelcomeProvider.overrideWith((_) => true),
      ], child: const app.MainApp()));
      await tester.pump();
      unawaited(app.globalNavigatorKey.currentState!.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const AIChatPage())));
      await tester.pumpAndSettle();
      final open = find.text(l.agentEvidenceBills);
      final history = find.byType(ListView).first;
      await tester.dragUntilVisible(
          find.byType(BillCardWidget), history, const Offset(0, 240));
      await tester.dragUntilVisible(
          open.hitTestable(), history, const Offset(0, -240));
      final followUp = find.byKey(const ValueKey('agent-follow-up-cash'));
      expect(followUp, findsOneWidget);
      if (withSheet) {
        await tester.tap(open);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BeeSelectField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('≥ 60').last);
        await tester.pumpAndSettle();
        expect(find.text(l.agentEvidenceCount(1)), findsOneWidget);
      }

      for (final brightness in [Brightness.dark, Brightness.light]) {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        await tester.pump();
        // The button text can fail halfway through its theme animation.
        for (var frame = 0; frame < 15; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull);
        }
        expect(Theme.of(tester.element(find.byType(AIChatPage))).brightness,
            brightness);
        expect(find.byType(ErrorWidget), findsNothing);
        if (withSheet) {
          expect(find.text(l.agentEvidenceCount(1)), findsOneWidget);
        }
      }
      if (withSheet) {
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
      }
      expect(find.byType(BeeSheet), findsNothing);
      expect(open, findsOneWidget);
      expect(followUp, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
