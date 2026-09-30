import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/ai/core/ai_extraction_engine.dart';
import 'package:beecount/agent/permission/shared_preferences_agent_tool_permission_store.dart';
import 'package:beecount/services/ai/ai_bookkeeper.dart';
import 'package:beecount/services/ai/ai_chat_service.dart';
import 'package:beecount/services/ai/agent_app_facade.dart';
import 'package:beecount/services/billing/bill_creation_service.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/models/ai_quick_command.dart';
import 'package:beecount/services/ai/ai_quick_command_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai_eval/support/ledger_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  for (final events in [false, true]) {
    test('forceChat 保留预载数据分析，不触发 Agent 或记账（events=$events）', () async {
      final fixture = await LedgerEvalFixture.create();
      addTearDown(fixture.close);
      var probes = 0;
      String? receivedPrompt;
      String? receivedSystem;
      final bookkeeper = AiBookkeeper(
        repository: fixture.repository,
        engine: const DefaultAiExtractionEngine(),
        persister: BillCreationService(fixture.repository),
      );
      final service = AIChatService(
        repo: fixture.repository,
        bookkeeper: bookkeeper,
        agentFacade: AgentAppFacade(
          memoryRepository: fixture.memory,
          toolGateway: fixture.gateway,
          permissionStore: SharedPreferencesAgentToolPermissionStore(
            getPreferences: SharedPreferences.getInstance,
          ),
          modelCapabilityLoader: () async {
            probes++;
            throw StateError('Quick command must not probe tool capability');
          },
        ),
        chatCompletion: (input, {required systemPrompt}) async {
          receivedPrompt = input;
          receivedSystem = systemPrompt;
          return '根据提供数据分析完成';
        },
      );
      const prompt = '财务健康分析\n【本月统计】总收入: 5020，总支出: 1295';
      final before = await fixture.transactionCount();
      final response = events
          ? ((await service
                      .processMessageEvents(prompt,
                          ledgerId: fixture.ledgers['main']!, forceChat: true)
                      .toList())
                  .single as AgentRunCompletedEvent)
              .result
              .response
          : await service.processMessage(prompt,
              ledgerId: fixture.ledgers['main']!, forceChat: true);
      expect(response.type, 'text');
      expect(receivedPrompt, prompt);
      expect(receivedSystem, contains('已提供的账本数据'));
      expect(receivedSystem, isNot(contains('暂不支持')));
      expect(probes, 0);
      expect(await fixture.transactionCount(), before);
      expect(await fixture.database.select(fixture.database.agentRuns).get(),
          isEmpty);
    });

    test('普通账本查询不绕过工具校验（events=$events）', () async {
      final fixture = await LedgerEvalFixture.create();
      addTearDown(fixture.close);
      var plainChats = 0;
      final model = _NoToolModel();
      final service = AIChatService(
        repo: fixture.repository,
        bookkeeper: AiBookkeeper(
          repository: fixture.repository,
          engine: const DefaultAiExtractionEngine(),
          persister: BillCreationService(fixture.repository),
        ),
        agentFacade: AgentAppFacade(
          memoryRepository: fixture.memory,
          toolGateway: fixture.gateway,
          permissionStore: SharedPreferencesAgentToolPermissionStore(
              getPreferences: SharedPreferences.getInstance),
          model: model,
        ),
        chatCompletion: (input, {required systemPrompt}) async {
          plainChats++;
          return '绕过校验';
        },
      );
      const prompt = '本月总收入多少？';
      final response = events
          ? ((await service
                      .processMessageEvents(prompt,
                          ledgerId: fixture.ledgers['main']!)
                      .toList())
                  .last as AgentRunCompletedEvent)
              .result
              .response
          : await service.processMessage(prompt,
              ledgerId: fixture.ledgers['main']!);
      expect(response.type, 'error');
      expect(response.text, contains('本次查询未执行'));
      expect(plainChats, 0);
      expect(model.calls, 1);
    });
  }

  testWidgets('所有预设快捷指令预载数据后都可分析，不触发工具检测', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (value) {
        context = value;
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final fixture = await LedgerEvalFixture.create();
      try {
        var analyses = 0;
        final service = AIChatService(
          repo: fixture.repository,
          bookkeeper: AiBookkeeper(
            repository: fixture.repository,
            engine: const DefaultAiExtractionEngine(),
            persister: BillCreationService(fixture.repository),
          ),
          agentFacade: AgentAppFacade(
            memoryRepository: fixture.memory,
            toolGateway: fixture.gateway,
            permissionStore: SharedPreferencesAgentToolPermissionStore(
                getPreferences: SharedPreferences.getInstance),
            modelCapabilityLoader: () => throw StateError('Should not probe'),
          ),
          chatCompletion: (input, {required systemPrompt}) async {
            analyses++;
            for (final type in QuickCommandDataType.values) {
              expect(input, isNot(contains('[${type.name}]')));
            }
            expect(input, isNot(contains('获取月度统计数据失败')));
            expect(input, isNot(contains('获取分类统计数据失败')));
            return '分析完成';
          },
        );
        final generator = AIQuickCommandService(
            db: fixture.database, ledgerId: fixture.ledgers['main']!);
        final before = await fixture.transactionCount();
        final commands = AIQuickCommands.getAllCommands();
        expect(commands, hasLength(6));
        for (final command in commands) {
          final prompt = await generator.generatePrompt(command, context);
          final events = await service
              .processMessageEvents(prompt,
                  ledgerId: fixture.ledgers['main']!, forceChat: true)
              .toList();
          final response = (events.single as AgentRunCompletedEvent).result;
          expect(response.type, 'text', reason: command.id);
          expect(response.text, '分析完成');
        }
        expect(analyses, 6);
        expect(await fixture.transactionCount(), before);
        expect(await fixture.database.select(fixture.database.agentRuns).get(),
            isEmpty);
      } finally {
        await fixture.close();
      }
    });
  });
}

final class _NoToolModel implements core.AgentModel {
  var calls = 0;
  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest request) async {
    calls++;
    return const core.AgentTurn.finalText('错误的无工具答案');
  }
}
