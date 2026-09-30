import 'dart:convert';
import 'dart:io';

import 'package:agentcore/agentcore.dart' as core;
import 'package:beecount/agent/permission/shared_preferences_agent_tool_permission_store.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/models/assistant_prompt_suggestions.dart';
import 'package:beecount/services/ai/agent_app_facade.dart';
import 'package:beecount/services/ai/ai_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai_eval/support/ledger_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final suite = jsonDecode(File('test/ai_eval/fixtures/readonly_cases_v1.json')
      .readAsStringSync()) as Map;
  final cases = (suite['cases'] as List)
      .cast<Map>()
      .where((item) => (item['tags'] as List).contains('analysis-template'))
      .toList();
  test('推荐提问目录与中英文 Eval 一一对应', () {
    expect(cases, hasLength(12));
    for (final l10n in [AppLocalizationsZh(), AppLocalizationsEn()]) {
      final items = AssistantPromptSuggestions.localized(l10n);
      expect(items, hasLength(6));
      expect(items.map((item) => item.id).toSet(), hasLength(6));
      for (final item in items) {
        expect(item.title, isNotEmpty);
        expect(item.prompt, isNot(item.title));
        expect(
            cases.where((testCase) =>
                ((((testCase['input'] as Map)['steps'] as List).single
                    as Map)['prompt']) ==
                item.prompt),
            hasLength(1));
      }
    }
  });
  test('上下文追问独立去重，六类完整模板可重复进入', () {
    for (final l10n in [AppLocalizationsZh(), AppLocalizationsEn()]) {
      final templates = AssistantPromptSuggestions.localized(l10n);
      final contextual = core.AgentPromptSuggestion(
          id: 'scoped', title: 'Scoped', prompt: '2026-09-15 to 2026-10-15');
      final items = AssistantPromptSuggestions.sections(l10n,
          contextual: [contextual, contextual],
          recentPrompts: [templates.first.prompt]);
      expect(items.questions, hasLength(1));
      expect(items.questions.first.prompt, contextual.prompt);
      expect(items.templates.map((item) => item.prompt),
          templates.map((item) => item.prompt));
      expect(items.templates, hasLength(6));
      expect(
          AssistantPromptSuggestions.sections(l10n,
              contextual: [contextual],
              recentPrompts: [contextual.prompt]).questions,
          isEmpty);
    }
  });
  for (final testCase in cases) {
    final english = (testCase['tags'] as List).contains('en');
    final suggestions = AssistantPromptSuggestions.localized(
        english ? AppLocalizationsEn() : AppLocalizationsZh());
    final step = ((testCase['input'] as Map)['steps'] as List).single as Map;
    final prompt = step['prompt'] as String;
    final suggestion = suggestions.singleWhere((item) => item.prompt == prompt);
    final calls = (step['oracleCalls'] as List)
        .cast<Map>()
        .indexed
        .map((entry) => core.AgentToolCall(
            id: 'entry-call-${entry.$1}',
            name: entry.$2['name'] as String,
            arguments: Map<String, Object?>.from(entry.$2['arguments'] as Map)))
        .toList();
    final call = calls.first;

    for (final streaming in [false, true]) {
      test('推荐提问使用完整文本和真实工具：${testCase['id']}（stream=$streaming）', () async {
        final fixture = await LedgerEvalFixture.create();
        addTearDown(fixture.close);
        final before = await fixture.transactionCount();
        final model = _ReplayModel([
          core.AgentTurn.toolCalls(calls),
          const core.AgentTurn.finalText('基于查询结果回答')
        ]);
        final service = AIChatService(
            repo: fixture.repository, agentFacade: _facade(fixture, model));
        final events = <AgentRunEvent>[];
        final AIResponse response;
        if (streaming) {
          events.addAll(await service
              .processMessageEvents(suggestion.prompt,
                  ledgerId: fixture.ledgers['main']!,
                  readOnly: true,
                  languageCode: english ? 'en' : 'zh')
              .toList());
          response = (events.last as AgentRunCompletedEvent).result.response;
        } else {
          response = await service.processMessage(suggestion.prompt,
              ledgerId: fixture.ledgers['main']!,
              readOnly: true,
              languageCode: english ? 'en' : 'zh');
        }
        expect(response.type, 'text');
        expect(model.requests.first.text, prompt);
        expect(model.requests.first.availableToolNames, contains(call.name));
        expect(model.requests.first.toolData, isEmpty);
        expect(model.requests.first.scope.allowsMutations, isFalse);
        final expected = (((testCase['expected'] as Map)['turns'] as List)
            .single as Map)['tools'] as List;
        for (final tool in expected.cast<Map>()) {
          final actual = model.requests.last.toolData
              .singleWhere((row) => row['name'] == tool['name']);
          final data = Map<String, Object?>.from(actual['data'] as Map);
          if (data['items'] is List) {
            data['itemCount'] = (data['items'] as List).length;
          }
          expect(
              core.agentEvalMismatches(tool['result'], data,
                  numericTolerance: 1e-9),
              isEmpty);
        }
        if (streaming) {
          expect(events.whereType<AgentToolStartedEvent>(),
              hasLength(calls.length));
          expect(
              events
                  .whereType<AgentToolCompletedEvent>()
                  .every((event) => event.succeeded),
              isTrue);
        }
        final audits = await fixture.database
            .select(fixture.database.agentToolCalls)
            .get();
        expect(
            audits.map((row) => row.toolName), calls.map((call) => call.name));
        expect(audits.every((row) => row.status == 'completed'), isTrue);
        expect(await fixture.transactionCount(), before);
      });
    }

    test('推荐提问不能绕过询问权限：${testCase['id']}', () async {
      final fixture = await LedgerEvalFixture.create();
      addTearDown(fixture.close);
      final before = await fixture.transactionCount();
      final store = SharedPreferencesAgentToolPermissionStore(
          getPreferences: SharedPreferences.getInstance);
      await store.setPermission(call.name, core.AgentToolPermission.ask);
      final model = _ReplayModel([
        core.AgentTurn.toolCalls([call]),
        const core.AgentTurn.finalText('未获权限')
      ]);
      final service = AIChatService(
          repo: fixture.repository,
          agentFacade: _facade(fixture, model, store: store));
      final events = <AgentRunEvent>[];
      await for (final event in service.processMessageEvents(suggestion.prompt,
          ledgerId: fixture.ledgers['main']!, readOnly: true)) {
        events.add(event);
        if (event is AgentToolAuthorizationRequestedEvent) {
          expect(
              service.resolveToolAuthorization(event.request.authorizationId,
                  core.AgentToolAuthorizationChoice.deny),
              isTrue);
        }
      }
      expect(events.whereType<AgentToolAuthorizationRequestedEvent>(),
          hasLength(1));
      expect(events.whereType<AgentToolCompletedEvent>(), isEmpty);
      expect(
          (events.last as AgentRunCompletedEvent)
              .result
              .response
              .followUpSuggestions,
          isEmpty);
      expect(model.requests.last.toolData.single['data'], contains('error'));
      final audits =
          await fixture.database.select(fixture.database.agentToolCalls).get();
      expect(audits.single.status, 'denied');
      expect(await fixture.transactionCount(), before);
    });

    test('推荐提问在模型不支持工具时正确提示：${testCase['id']}', () async {
      final fixture = await LedgerEvalFixture.create();
      addTearDown(fixture.close);
      final model = _ReplayModel([]);
      final service = AIChatService(
          repo: fixture.repository,
          agentFacade: AgentAppFacade(
            memoryRepository: fixture.memory,
            toolGateway: fixture.gateway,
            permissionStore: SharedPreferencesAgentToolPermissionStore(
                getPreferences: SharedPreferences.getInstance),
            model: model,
            modelCapabilityLoader: () async => core.AgentModelCapabilities(
                nativeToolCalls: core.AgentCapabilitySupport.unsupported),
          ));
      final response = await service.processMessage(suggestion.prompt,
          ledgerId: fixture.ledgers['main']!,
          l10n: english ? AppLocalizationsEn() : AppLocalizationsZh());
      expect(response.type, 'error');
      expect(response.action, AIResponseAction.openProviderSettings);
      expect(response.followUpSuggestions, isEmpty);
      expect(model.requests, isEmpty);
      expect(
          await fixture.database.select(fixture.database.agentToolCalls).get(),
          isEmpty);
    });
  }

  for (final streaming in [false, true]) {
    test('推荐提问误选写工具仍被硬拒绝（stream=$streaming）', () async {
      final fixture = await LedgerEvalFixture.create();
      addTearDown(fixture.close);
      final before = await fixture.transactionCount();
      final prompt = AssistantPromptSuggestions.localized(AppLocalizationsZh())
          .first
          .prompt;
      final model = _ReplayModel([
        core.AgentTurn.toolCalls([
          core.AgentToolCall(
              name: 'record_transaction_from_text',
              arguments: {'sourceText': prompt})
        ]),
        const core.AgentTurn.finalText('不能写入'),
      ]);
      final service = AIChatService(
          repo: fixture.repository, agentFacade: _facade(fixture, model));
      if (streaming) {
        await service
            .processMessageEvents(prompt,
                ledgerId: fixture.ledgers['main']!, readOnly: true)
            .toList();
      } else {
        await service.processMessage(prompt,
            ledgerId: fixture.ledgers['main']!, readOnly: true);
      }
      expect(await fixture.transactionCount(), before);
      final audits =
          await fixture.database.select(fixture.database.agentToolCalls).get();
      expect(audits.single.status, 'denied');
      expect(model.requests.last.toolData.single['data'], contains('error'));
    });
  }

  test('统一对话路径不按工具名拦截文本，无查询证据不生成追问', () async {
    final fixture = await LedgerEvalFixture.create();
    addTearDown(fixture.close);
    final model = _ReplayModel([const core.AgentTurn.finalText('收入 123')]);
    final response = await AIChatService(
            repo: fixture.repository, agentFacade: _facade(fixture, model))
        .processMessage('本月总收入多少？', ledgerId: fixture.ledgers['main']!);
    expect(response.type, 'text');
    expect(response.text, '收入 123');
    expect(response.action, isNull);
    expect(response.followUpSuggestions, isEmpty);
  });
}

AgentAppFacade _facade(LedgerEvalFixture fixture, core.AgentModel model,
        {SharedPreferencesAgentToolPermissionStore? store}) =>
    AgentAppFacade(
      memoryRepository: fixture.memory,
      toolGateway: fixture.gateway,
      permissionStore: store ??
          SharedPreferencesAgentToolPermissionStore(
              getPreferences: SharedPreferences.getInstance),
      model: model,
      now: () => fixture.now,
    );

final class _ReplayModel implements core.AgentModel {
  _ReplayModel(this.turns);
  final List<core.AgentTurn> turns;
  final requests = <core.AgentRequest>[];
  @override
  Future<core.AgentTurn> nextTurn(core.AgentRequest request) async {
    requests.add(request);
    return turns[requests.length - 1];
  }
}
