import 'dart:async';

import 'package:agentcore/agentcore.dart'
    hide
        AgentAuthorizationPolicy,
        AgentMemoryDraft,
        AgentMemoryRecord,
        AgentMemoryRepository,
        AgentToolAuthorizationBroker,
        AgentToolAuthorizationChoice,
        AgentToolAuthorizationRequest,
        AgentToolAuthorizationRequester,
        AgentToolCallAudit,
        AgentToolPermission,
        AgentToolPermissionDescriptor,
        AgentToolPermissionStore,
        AgentToolPermissionCatalog,
        AgentNativeEventSink,
        AgentNativeFinalTextResponse,
        AgentNativeModelResponse,
        AgentNativeProtocolException,
        AgentNativeStreamEvent,
        AgentNativeTextDelta,
        AgentNativeToolCall,
        AgentNativeToolCallsResponse,
        AgentNativeToolDefinition,
        AgentNativeToolRequest,
        AgentNativeToolResult,
        AgentNativeToolStream,
        AgentNativeToolTimeoutException,
        AgentNativeToolTransport,
        AgentNativeToolUnsupportedException,
        AgentRequestNativeStreaming,
        NativeToolAgentModel,
        OpenAiCompatibleNativeToolTransport;
import 'package:beecount/agent/memory/local_agent_memory_repository.dart';
import 'package:beecount/agent/memory/agent_memory_repository.dart';
import 'package:beecount/agent/model/native_tool_agent_model.dart';
import 'package:beecount/agent/permission/agent_authorization_gate.dart';
import 'package:beecount/agent/permission/agent_tool_permission.dart';
import 'package:beecount/agent/runtime/agent_execution_settings.dart';
import 'package:beecount/agent/permission/shared_preferences_agent_tool_permission_store.dart';
import 'package:beecount/agent/tools/local_agent_tools.dart';
import 'package:beecount/data/db.dart' hide AgentToolCall;
import 'package:beecount/services/ai/agent_app_facade.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Tests the platform write result while retaining the real preferences cache.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  late BeeDatabase db;
  late _FakeGateway gateway;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    gateway = _FakeGateway();
  });

  tearDown(() => db.close());

  test('a successful record response preserves cards and transaction ids',
      () async {
    logger.clear();
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      model: _FakeModel([
        AgentTurn.toolCalls([
          AgentToolCall(
            id: 'call-1',
            name: 'record_transaction_from_text',
            arguments: const {'sourceText': '午饭 35'},
          ),
        ]),
        const AgentTurn.finalText('已完成'),
      ]),
      runIdFactory: () => 'run-1',
    );

    final response = await facade.processMessage(message: '午饭 35', ledgerId: 1);

    expect(response.type, 'bill_card');
    expect(response.transactionIds, [42]);
    expect(gateway.recordedTexts, ['午饭 35']);
    expect(
      logger.logs.any(
        (entry) =>
            entry.tag == 'AgentCore' &&
            entry.message.contains('运行结果已生成') &&
            entry.message.contains('responseType: bill_card'),
      ),
      isTrue,
    );
  });

  test('uses the locally selected model-turn limit for an Agent run', () async {
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      executionSettingsStore: _FixedExecutionSettingsStore(2),
      model: _FakeModel([
        AgentTurn.toolCalls([AgentToolCall(name: 'unknown-first')]),
        AgentTurn.toolCalls([AgentToolCall(name: 'unknown-second')]),
        const AgentTurn.finalText('不应请求第三轮'),
      ]),
      runIdFactory: () => 'run-limited-turns',
    );

    final response = await facade.processMessage(message: '测试', ledgerId: 1);

    expect(response.response.text, '这次操作步骤过多，请简化后重试。');
  });

  test('a fragmented native record tool call reaches the local tool', () async {
    final transport = OpenAiCompatibleNativeToolTransport(
      toolStream: ({required messages, required tools, logTag}) {
        final hasToolResult = messages.any(
          (message) => message['role'] == 'tool',
        );
        if (hasToolResult) {
          return Stream<Map<String, dynamic>>.value({
            'choices': [
              {
                'delta': {'content': '已记录早饭 8 元。'},
              },
            ],
          });
        }
        return Stream<Map<String, dynamic>>.fromIterable([
          {
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'id': 'call-native-record',
                      'function': {
                        'name': 'record_transaction_from_text',
                        'arguments': '{"sourceText":"早饭花了8元"}',
                      },
                    },
                  ],
                },
              },
            ],
          },
          {
            'choices': [
              {
                'delta': {
                  'tool_calls': [
                    {
                      'index': 0,
                      'function': {'name': '', 'arguments': ''},
                    },
                  ],
                },
              },
            ],
          },
        ]);
      },
    );
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      model: NativeToolAgentModel(transport: transport),
      runIdFactory: () => 'run-native-record',
    );

    final response = await facade.processMessage(
      message: '早饭花了8元',
      ledgerId: 1,
    );

    expect(response.type, 'bill_card');
    expect(gateway.recordedTexts, ['早饭花了8元']);
  });

  test('a malformed model response creates no transaction and records failure',
      () async {
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      model: _ThrowingModel(),
      runIdFactory: () => 'run-2',
    );

    final response = await facade.processMessage(message: '测试', ledgerId: 1);
    final run = await (db.select(db.agentRuns)
          ..where((item) => item.runId.equals('run-2')))
        .getSingle();

    expect(response.type, 'error');
    expect(run.status, 'failed');
    expect(gateway.recordedTexts, isEmpty);
  });

  test('unsupported native tools return a direct configuration hint', () async {
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      model: _UnsupportedModel(),
      runIdFactory: () => 'run-unsupported',
    );

    final response = await facade.processMessage(message: '午饭 35', ledgerId: 1);

    expect(response.type, 'error');
    expect(response.text, contains('不支持 Agent 原生工具调用'));
    expect(gateway.recordedTexts, isEmpty);
  });

  test('loads scoped local memories into the Agent request context', () async {
    final memory = LocalAgentMemoryRepository(db);
    await memory.saveExplicit(const AgentMemoryDraft(
      ledgerId: 1,
      kind: 'explicit',
      content: '咖啡默认用微信支付',
    ));
    final model = _CapturingModel();
    final facade = AgentAppFacade(
      memoryRepository: memory,
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      model: model,
      runIdFactory: () => 'run-3',
    );

    await facade.processMessage(message: '咖啡', ledgerId: 1);

    expect(model.request!.context['memories'], ['咖啡默认用微信支付']);
    expect(model.request!.context['currentTime'], isA<String>());
  });

  test('loads bounded conversation history into the Agent request context',
      () async {
    final model = _CapturingModel();
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      conversationHistoryLoader: (conversationId) async {
        expect(conversationId, 42);
        return [
          {
            'role': 'assistant',
            'content': '上轮查询到本月支出 80 元。',
          },
          {
            'role': 'user',
            'content': 'ok',
          },
        ];
      },
      model: model,
      runIdFactory: () => 'run-history',
    );

    await facade.processMessage(
      message: '继续',
      ledgerId: 1,
      conversationId: 42,
    );

    expect(model.request!.context['recentMessages'], [
      {
        'role': 'assistant',
        'content': '上轮查询到本月支出 80 元。',
      },
      {
        'role': 'user',
        'content': 'ok',
      },
    ]);
  });

  test('sanitizes and caps conversation history before prompting the model',
      () async {
    final model = _CapturingModel();
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      conversationHistoryLoader: (_) async => [
        {'role': 'system', 'content': '不得把这条系统消息传给模型。'},
        {'role': 'user', 'content': ''},
        for (var i = 0; i < 13; i++)
          {'role': 'assistant', 'content': '第 $i 条 ${'x' * 2100}'},
        {'role': 'assistant', 'content': 123},
      ],
      model: model,
      runIdFactory: () => 'run-history-safety',
    );

    await facade.processMessage(
      message: '继续',
      ledgerId: 1,
      conversationId: 42,
    );

    final history = (model.request!.context['recentMessages']! as List)
        .cast<Map<String, Object?>>();
    expect(history, hasLength(12));
    expect(history.first['content'], startsWith('第 1 条'));
    expect((history.first['content'] as String).length, 2001);
    expect(history.last['content'], startsWith('第 12 条'));
    expect(history.where((item) => item['role'] == 'system'), isEmpty);
  });

  test('event stream reports tool execution before its final response',
      () async {
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      model: _FakeModel([
        AgentTurn.toolCalls([
          AgentToolCall(
            id: 'call-1',
            name: 'record_transaction_from_text',
            arguments: const {'sourceText': '午饭 35'},
          ),
        ]),
        const AgentTurn.finalText('已完成'),
      ]),
      runIdFactory: () => 'run-events',
    );

    final events = await facade
        .processMessageEvents(message: '午饭 35', ledgerId: 1)
        .toList();

    final started = events.whereType<AgentToolStartedEvent>().single;
    expect(started.toolName, 'record_transaction_from_text');
    expect(started.arguments, {'sourceText': '午饭 35'});
    expect(started.callId, 'call-1');
    final completed = events.whereType<AgentToolCompletedEvent>().single;
    expect(completed.toolName, 'record_transaction_from_text');
    expect(completed.arguments, {'sourceText': '午饭 35'});
    expect(completed.callId, 'call-1');
    expect(completed.result, isNotNull);
    expect(completed.succeeded, isTrue);
    expect(events.last, isA<AgentRunCompletedEvent>());
  });

  test('persists a failed local tool call in the run activity audit', () async {
    final memory = LocalAgentMemoryRepository(db);
    gateway.throwOnQuery = true;
    final facade = AgentAppFacade(
      memoryRepository: memory,
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      model: _FakeModel([
        AgentTurn.toolCalls([
          AgentToolCall(
            id: 'failed-query-call',
            name: 'query_transactions',
          ),
        ]),
      ]),
      runIdFactory: () => 'failed-tool-run',
    );

    final response = await facade.processMessage(
      message: '查询本月明细',
      ledgerId: 1,
    );
    final audits = await memory.listToolCalls('failed-tool-run');

    expect(response.response.type, 'error');
    expect(audits, hasLength(1));
    expect(audits.single.callId, 'failed-query-call');
    expect(audits.single.toolName, 'query_transactions');
    expect(audits.single.status, 'failed');
  });

  test('emits authorization before a write tool starts and waits for the reply',
      () async {
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(
        permission: AgentToolPermission.ask,
      ),
      model: _FakeModel([
        AgentTurn.toolCalls([
          AgentToolCall(
            id: 'call-authorized',
            name: 'record_transaction_from_text',
            arguments: const {'sourceText': '午饭 35'},
          ),
        ]),
        const AgentTurn.finalText('已完成'),
      ]),
      runIdFactory: () => 'run-authorized',
    );
    final iterator = StreamIterator(
      facade.processMessageEvents(message: '午饭 35', ledgerId: 1),
    );

    expect(await iterator.moveNext(), isTrue);
    final requested = iterator.current as AgentToolAuthorizationRequestedEvent;
    expect(requested.request.runId, 'run-authorized');
    expect(requested.request.ledgerId, 1);
    expect(requested.request.toolName, 'record_transaction_from_text');
    expect(requested.request.arguments, {'sourceText': '午饭 35'});
    expect(requested.request.authorizationId, isNot('call-authorized'));
    expect(gateway.recordedTexts, isEmpty);

    expect(
      facade.resolveToolAuthorization(
        'call-authorized',
        AgentToolAuthorizationChoice.allowOnce,
      ),
      isFalse,
    );
    expect(
      facade.resolveToolAuthorization(
        requested.request.authorizationId,
        AgentToolAuthorizationChoice.allowOnce,
      ),
      isTrue,
    );
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isA<AgentToolStartedEvent>());
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isA<AgentToolCompletedEvent>());
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isA<AgentRunCompletedEvent>());
    expect(await iterator.moveNext(), isFalse);
    expect(gateway.recordedTexts, ['午饭 35']);
    expect(
      facade.resolveToolAuthorization(
        requested.request.authorizationId,
        AgentToolAuthorizationChoice.allowOnce,
      ),
      isFalse,
    );
  });

  test('explicit memory intent reaches authorization instead of hard denial',
      () async {
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(
        permission: AgentToolPermission.ask,
      ),
      model: _FakeModel([
        AgentTurn.toolCalls([
          AgentToolCall(
            id: 'call-memory',
            name: 'save_explicit_memory',
            arguments: const {'content': '我喜欢喝茶'},
          ),
        ]),
        const AgentTurn.finalText('好的，我记住了。'),
      ]),
      runIdFactory: () => 'run-memory-intent',
    );
    final iterator = StreamIterator(
      facade.processMessageEvents(
        message: '请记住我喜欢喝茶',
        ledgerId: 1,
      ),
    );

    expect(await iterator.moveNext(), isTrue);
    final requested = iterator.current as AgentToolAuthorizationRequestedEvent;
    expect(requested.request.toolName, 'save_explicit_memory');
    expect(requested.request.arguments, {'content': '我喜欢喝茶'});
    expect(
      facade.resolveToolAuthorization(
        requested.request.authorizationId,
        AgentToolAuthorizationChoice.allowOnce,
      ),
      isTrue,
    );

    while (await iterator.moveNext()) {
      // Drain the run so the tool result is persisted and the stream closes.
    }
    expect(gateway.savedMemories, ['我喜欢喝茶']);
  });

  test('denied authorization is audited and returned to the next model turn',
      () async {
    final model = _FakeModel([
      AgentTurn.toolCalls([
        AgentToolCall(
          id: 'call-denied',
          name: 'record_transaction_from_text',
          arguments: const {'sourceText': '午饭 35'},
        ),
      ]),
      const AgentTurn.finalText('已取消'),
    ]);
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(
        permission: AgentToolPermission.ask,
      ),
      model: model,
      runIdFactory: () => 'run-denied',
    );
    final iterator = StreamIterator(
      facade.processMessageEvents(message: '午饭 35', ledgerId: 1),
    );

    expect(await iterator.moveNext(), isTrue);
    final requested = iterator.current as AgentToolAuthorizationRequestedEvent;
    expect(
      facade.resolveToolAuthorization(
        requested.request.authorizationId,
        AgentToolAuthorizationChoice.deny,
      ),
      isTrue,
    );
    final remainingEvents = <AgentRunEvent>[];
    while (await iterator.moveNext()) {
      remainingEvents.add(iterator.current);
    }
    final audit = await (db.select(db.agentToolCalls)
          ..where((row) => row.runId.equals('run-denied')))
        .getSingle();

    expect(gateway.recordedTexts, isEmpty);
    expect(remainingEvents.whereType<AgentToolStartedEvent>(), isEmpty);
    expect(remainingEvents.whereType<AgentToolCompletedEvent>(), isEmpty);
    expect(remainingEvents.last, isA<AgentRunCompletedEvent>());
    expect(model.requests, hasLength(2));
    expect(model.requests.last.toolData, [
      {
        'id': 'call-denied',
        'name': 'record_transaction_from_text',
        'data': {'error': '用户未授权此操作。'},
      },
    ]);
    expect(audit.callId, 'call-denied');
    expect(audit.status, 'denied');
    expect(audit.detail, '用户未授权此操作。');
  });

  test('non-stream processing denies write tools without waiting for UI',
      () async {
    final model = _FakeModel([
      AgentTurn.toolCalls([
        AgentToolCall(
          id: 'call-no-ui',
          name: 'record_transaction_from_text',
          arguments: const {'sourceText': '午饭 35'},
        ),
      ]),
      const AgentTurn.finalText('未执行'),
    ]);
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(
        permission: AgentToolPermission.ask,
      ),
      model: model,
      runIdFactory: () => 'run-no-ui',
    );

    final response = await facade.processMessage(
      message: '午饭 35',
      ledgerId: 1,
    );
    final audit = await (db.select(db.agentToolCalls)
          ..where((row) => row.runId.equals('run-no-ui')))
        .getSingle();

    expect(response.text, '未执行');
    expect(gateway.recordedTexts, isEmpty);
    expect(model.requests.last.toolData.single['data'], {
      'error': '用户未授权此操作。',
    });
    expect(audit.status, 'denied');
  });

  test('canceling an event stream stops its pending authorization', () async {
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(
        permission: AgentToolPermission.ask,
      ),
      model: _FakeModel([
        AgentTurn.toolCalls([
          AgentToolCall(
            id: 'call-canceled',
            name: 'record_transaction_from_text',
            arguments: const {'sourceText': '午饭 35'},
          ),
          AgentToolCall(
            id: 'call-after-cancel',
            name: 'record_transaction_from_text',
            arguments: const {'sourceText': '午饭 35'},
          ),
        ]),
        const AgentTurn.finalText('已取消'),
      ]),
      runIdFactory: () => 'run-canceled',
    );
    final iterator = StreamIterator(
      facade.processMessageEvents(message: '午饭 35', ledgerId: 1),
    );

    expect(await iterator.moveNext(), isTrue);
    final requested = iterator.current as AgentToolAuthorizationRequestedEvent;
    final runFinished = (db.select(db.agentRuns)
          ..where((row) => row.runId.equals('run-canceled')))
        .watchSingle()
        .firstWhere((run) => run.status == 'cancelled');
    await iterator.cancel();

    expect(
      facade.resolveToolAuthorization(
        requested.request.authorizationId,
        AgentToolAuthorizationChoice.allowOnce,
      ),
      isFalse,
    );
    await runFinished.timeout(const Duration(seconds: 2));
    expect(gateway.recordedTexts, isEmpty);
  });

  test('finishing one run keeps another run authorization pending', () async {
    var runNumber = 0;
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore:
          _MemoryPermissionStore(permission: AgentToolPermission.ask),
      model: _ConcurrentModel(),
      runIdFactory: () => 'concurrent-${++runNumber}',
    );
    final first = StreamIterator(
      facade.processMessageEvents(message: '午饭 35', ledgerId: 1),
    );
    final second = StreamIterator(
      facade.processMessageEvents(message: '晚饭 45', ledgerId: 1),
    );
    expect(await first.moveNext(), isTrue);
    expect(await second.moveNext(), isTrue);
    final firstRequest = first.current as AgentToolAuthorizationRequestedEvent;
    final secondRequest =
        second.current as AgentToolAuthorizationRequestedEvent;
    expect(firstRequest.request.authorizationId,
        isNot(secondRequest.request.authorizationId));
    expect(
        facade.resolveToolAuthorization(firstRequest.request.authorizationId,
            AgentToolAuthorizationChoice.allowOnce),
        isTrue);
    while (await first.moveNext()) {}
    final resolvedSecond = facade.resolveToolAuthorization(
        secondRequest.request.authorizationId,
        AgentToolAuthorizationChoice.allowOnce);
    while (await second.moveNext()) {}
    expect(resolvedSecond, isTrue);
    expect(gateway.recordedTexts, ['午饭 35', '晚饭 45']);
  });

  test('cancelling a pending model run blocks an always allowed write',
      () async {
    logger.clear();
    final model = _PendingModel();
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      model: model,
      runIdFactory: () => 'cancel-before-policy',
    );
    final subscription = facade
        .processMessageEvents(message: '午饭 35', ledgerId: 1)
        .listen((_) {});
    await model.started.future;
    final finished = (db.select(db.agentRuns)
          ..where((row) => row.runId.equals('cancel-before-policy')))
        .watchSingle()
        .firstWhere((run) => run.status == 'cancelled');
    await subscription.cancel();
    model.pending.complete(AgentTurn.toolCalls([
      AgentToolCall(
          id: 'late-write',
          name: 'record_transaction_from_text',
          arguments: const {'sourceText': '午饭 35'}),
    ]));
    await finished.timeout(const Duration(seconds: 2));
    expect(gateway.recordedTexts, isEmpty);
    expect(model.requests, hasLength(1));
    expect(
        logger.logs.any((entry) =>
            entry.message.contains('工具开始执行') &&
            entry.message.contains('cancel-before-policy')),
        isFalse);
  });

  test('cancelling during always allow persistence blocks execution', () async {
    logger.clear();
    final persistenceStarted = Completer<void>();
    final persistenceFinished = Completer<void>();
    final model = _FakeModel([
      AgentTurn.toolCalls([
        AgentToolCall(
            id: 'pending-write',
            name: 'record_transaction_from_text',
            arguments: const {'sourceText': '午饭 35'}),
      ]),
      const AgentTurn.finalText('已取消'),
    ]);
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(
        permission: AgentToolPermission.ask,
        onPersist: () {
          persistenceStarted.complete();
          return persistenceFinished.future;
        },
      ),
      model: model,
      runIdFactory: () => 'cancel-during-persistence',
    );
    final iterator = StreamIterator(
      facade.processMessageEvents(message: '午饭 35', ledgerId: 1),
    );
    expect(await iterator.moveNext(), isTrue);
    final requested = iterator.current as AgentToolAuthorizationRequestedEvent;
    expect(
        facade.resolveToolAuthorization(requested.request.authorizationId,
            AgentToolAuthorizationChoice.alwaysAllow),
        isTrue);
    await persistenceStarted.future;
    final finished = (db.select(db.agentRuns)
          ..where((row) => row.runId.equals('cancel-during-persistence')))
        .watchSingle()
        .firstWhere((run) => run.status == 'cancelled');
    await iterator.cancel();
    persistenceFinished.complete();
    await finished.timeout(const Duration(seconds: 2));
    expect(gateway.recordedTexts, isEmpty);
    expect(model.requests, hasLength(1));
    expect(
        logger.logs.any((entry) =>
            entry.message.contains('工具开始执行') &&
            entry.message.contains('cancel-during-persistence')),
        isFalse);
  });

  test('false preference write warns and authorizes only the current call',
      () async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = _RejectingPreferencesPlatform();
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    logger.clear();
    var runNumber = 0;
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: SharedPreferencesAgentToolPermissionStore(
        getPreferences: SharedPreferences.getInstance,
      ),
      model: _ConcurrentModel(),
      runIdFactory: () => 'false-persistence-${++runNumber}',
    );
    final first = StreamIterator(
      facade.processMessageEvents(message: '午饭 35', ledgerId: 1),
    );
    expect(await first.moveNext(), isTrue);
    final request = first.current as AgentToolAuthorizationRequestedEvent;
    facade.resolveToolAuthorization(request.request.authorizationId,
        AgentToolAuthorizationChoice.alwaysAllow);
    while (await first.moveNext()) {}
    expect(gateway.recordedTexts, ['午饭 35']);
    expect(
        logger.logs.any((entry) =>
            entry.level == LogLevel.warning &&
            entry.message.contains(
                'authorizationId: ${request.request.authorizationId}') &&
            entry.message.contains('persisted: false')),
        isTrue);
    expect(
        logger.logs.any((entry) =>
            entry.level == LogLevel.info &&
            entry.message.contains(
                'authorizationId: ${request.request.authorizationId}') &&
            entry.message.contains('choice: alwaysAllow') &&
            entry.message.contains('persisted: false')),
        isTrue);
    final later = StreamIterator(
      facade.processMessageEvents(message: '晚饭 45', ledgerId: 1),
    );
    expect(await later.moveNext(), isTrue);
    final laterEvent = later.current;
    // Drain the run even on regression, so database cleanup does not race it.
    facade.cancelPendingToolAuthorizations();
    while (await later.moveNext()) {}
    expect(laterEvent, isA<AgentToolAuthorizationRequestedEvent>());
    expect(gateway.recordedTexts, ['午饭 35']);
  });

  test('explicit cancellation denies pending requests and completes the run',
      () async {
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore:
          _MemoryPermissionStore(permission: AgentToolPermission.ask),
      model: _FakeModel([
        AgentTurn.toolCalls([
          AgentToolCall(
            id: 'call-explicit-cancel',
            name: 'record_transaction_from_text',
            arguments: const {'sourceText': '午饭 35'},
          ),
        ]),
        const AgentTurn.finalText('已取消'),
      ]),
    );
    final iterator = StreamIterator(
      facade.processMessageEvents(message: '午饭 35', ledgerId: 1),
    );
    expect(await iterator.moveNext(), isTrue);
    final requested = iterator.current as AgentToolAuthorizationRequestedEvent;
    facade.cancelPendingToolAuthorizations();
    expect(
        facade.resolveToolAuthorization(requested.request.authorizationId,
            AgentToolAuthorizationChoice.allowOnce),
        isFalse);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isA<AgentRunCompletedEvent>());
    expect(await iterator.moveNext(), isFalse);
    expect(gateway.recordedTexts, isEmpty);
  });

  test('stopping an active run returns immediately while its model waits',
      () async {
    final model = _PendingModel();
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      model: model,
      runIdFactory: () => 'stopped-active-run',
    );

    final events =
        facade.processMessageEvents(message: '本月花了多少', ledgerId: 1).toList();
    await model.started.future;
    facade.cancelActiveRuns();

    final completedEvents = await events.timeout(const Duration(seconds: 2));
    final completed = completedEvents.single as AgentRunCompletedEvent;
    final run = await (db.select(db.agentRuns)
          ..where((row) => row.runId.equals('stopped-active-run')))
        .getSingle();

    expect(completed.result.response.text, '本次操作已停止。');
    expect(run.status, 'cancelled');
    expect(gateway.recordedTexts, isEmpty);
    model.pending.complete(const AgentTurn.finalText('迟到的回复'));
  });

  test('stopping one run does not cancel another active run', () async {
    var runNumber = 0;
    final model = _RunScopedPendingModel();
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
      permissionStore: _MemoryPermissionStore(),
      model: model,
      runIdFactory: () => 'run-${String.fromCharCode(97 + runNumber++)}',
    );

    final first =
        facade.processMessageEvents(message: '查询一', ledgerId: 1).toList();
    final second =
        facade.processMessageEvents(message: '查询二', ledgerId: 1).toList();
    await model.waitUntilStarted('run-a');
    await model.waitUntilStarted('run-b');

    final cancelled = facade.cancelRun('run-a');
    model.complete('run-a', const AgentTurn.finalText('迟到的回复'));
    model.complete('run-b', const AgentTurn.finalText('第二个请求完成'));
    final firstEvents = await first;
    final secondEvents = await second;

    expect(cancelled, isTrue);
    expect(
      (firstEvents.single as AgentRunCompletedEvent).result.response.text,
      '本次操作已停止。',
    );
    expect(
      (secondEvents.single as AgentRunCompletedEvent).result.response.text,
      '第二个请求完成',
    );
  });

  for (final failsPersistence in [false, true]) {
    test('logs actual authorization persistence (fails: $failsPersistence)',
        () async {
      logger.clear();
      final facade = AgentAppFacade(
        memoryRepository: LocalAgentMemoryRepository(db),
        toolGateway: gateway,
        permissionStore: _MemoryPermissionStore(
          permission: AgentToolPermission.ask,
          failsPersistence: failsPersistence,
        ),
        model: _FakeModel([
          AgentTurn.toolCalls([
            AgentToolCall(
              id: 'call-persist',
              name: 'record_transaction_from_text',
              arguments: const {'sourceText': '午饭 35'},
            ),
          ]),
          const AgentTurn.finalText('已完成'),
        ]),
        runIdFactory: () => 'run-persist',
      );
      final iterator = StreamIterator(
        facade.processMessageEvents(message: '午饭 35', ledgerId: 1),
      );
      expect(await iterator.moveNext(), isTrue);
      final requested =
          iterator.current as AgentToolAuthorizationRequestedEvent;
      expect(
          logger.logs.any((entry) =>
              entry.level == LogLevel.info &&
              entry.message.contains(
                  'authorizationId: ${requested.request.authorizationId}') &&
              entry.message.contains('runId: run-persist') &&
              entry.message.contains('tool: record_transaction_from_text') &&
              entry.message.contains('arguments: {sourceText: 午饭 35}') &&
              entry.message.contains('ledgerId: 1')),
          isTrue);
      expect(
          facade.resolveToolAuthorization(requested.request.authorizationId,
              AgentToolAuthorizationChoice.alwaysAllow),
          isTrue);
      while (await iterator.moveNext()) {}
      expect(gateway.recordedTexts, ['午饭 35']);
      expect(
          logger.logs.any((entry) =>
              entry.level == LogLevel.info &&
              entry.message.contains(
                  'authorizationId: ${requested.request.authorizationId}') &&
              entry.message.contains('choice: alwaysAllow') &&
              entry.message.contains('persisted: ${!failsPersistence}')),
          isTrue);
      expect(
          logger.logs.any((entry) =>
              entry.level == LogLevel.warning &&
              entry.message.contains(
                  'authorizationId: ${requested.request.authorizationId}') &&
              entry.message.contains('disk full')),
          failsPersistence);
    });
  }
}

final class _FakeModel implements AgentModel {
  _FakeModel(this._turns);

  final List<AgentTurn> _turns;
  final List<AgentRequest> requests = [];

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    requests.add(request);
    return _turns.removeAt(0);
  }
}

final class _ThrowingModel implements AgentModel {
  @override
  Future<AgentTurn> nextTurn(AgentRequest request) =>
      Future.error(const FormatException('bad response'));
}

final class _PendingModel implements AgentModel {
  final started = Completer<void>();
  final pending = Completer<AgentTurn>();
  final requests = <AgentRequest>[];

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) {
    requests.add(request);
    if (requests.length > 1) {
      return Future.value(const AgentTurn.finalText('已取消'));
    }
    started.complete();
    return pending.future;
  }
}

final class _RunScopedPendingModel implements AgentModel {
  final Map<String, Completer<void>> _started = {};
  final Map<String, Completer<AgentTurn>> _pending = {};

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) {
    final runId = request.scope.id;
    _started.putIfAbsent(runId, Completer<void>.new).complete();
    return _pending.putIfAbsent(runId, Completer<AgentTurn>.new).future;
  }

  Future<void> waitUntilStarted(String runId) =>
      _started.putIfAbsent(runId, Completer<void>.new).future;

  void complete(String runId, AgentTurn turn) =>
      _pending[runId]!.complete(turn);
}

final class _RejectingPreferencesPlatform
    extends InMemorySharedPreferencesStore {
  _RejectingPreferencesPlatform() : super.empty();

  bool _failed = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.agent_tool_permissions_v1') {
      // Windows mutates its own cache before a failed disk write. The later
      // rollback also fails, leaving reload unable to remove this false grant.
      if (!_failed) {
        _failed = true;
        await super.setValue(valueType, key, value);
      }
      return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (key == 'flutter.agent_tool_permissions_v1') return false;
    return super.remove(key);
  }
}

final class _ConcurrentModel implements AgentModel {
  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    if (request.toolData.isNotEmpty) return const AgentTurn.finalText('已完成');
    return AgentTurn.toolCalls([
      AgentToolCall(
        id: 'same-model-call-id',
        name: 'record_transaction_from_text',
        arguments: {'sourceText': request.text},
      ),
    ]);
  }
}

final class _UnsupportedModel implements AgentModel {
  @override
  Future<AgentTurn> nextTurn(AgentRequest request) =>
      Future.error(const AgentNativeToolUnsupportedException());
}

final class _CapturingModel implements AgentModel {
  AgentRequest? request;

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async {
    this.request = request;
    return const AgentTurn.finalText('已完成');
  }
}

final class _FakeGateway implements LocalAgentToolGateway {
  final List<String> recordedTexts = [];
  final List<String> savedMemories = [];
  bool throwOnQuery = false;

  @override
  Future<List<AgentRecurringTransactionSummary>> getRecurringTransactions(
    int ledgerId,
  ) async =>
      const [];

  @override
  Future<bool> forgetMemory({
    required int ledgerId,
    required int memoryId,
  }) async =>
      false;

  @override
  Future<AgentBudgetSummary> getBudgetStatus(int ledgerId) async =>
      const AgentBudgetSummary(daysRemaining: 10, dailyAvailable: 20);

  @override
  Future<String> getLedgerCurrency(int ledgerId) async => 'CNY';

  @override
  Future<List<AgentTransactionSummary>> queryTransactions({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (throwOnQuery) throw StateError('query failed');
    return const [];
  }

  @override
  Future<AgentRecordToolResult> recordTransaction({
    required int ledgerId,
    required String text,
  }) async {
    recordedTexts.add(text);
    return const AgentRecordToolResult(
      success: true,
      transactionIds: [42],
      bills: [
        {
          'amount': -35.0,
          'time': '2026-01-01T12:00:00.000',
          'note': '午饭',
          'type': 'expense',
          'ledgerId': 1,
        },
      ],
    );
  }

  @override
  Future<int> saveExplicitMemory({
    required int? ledgerId,
    required String content,
  }) async {
    savedMemories.add(content);
    return 1;
  }
}

final class _MemoryPermissionStore implements AgentToolPermissionStore {
  _MemoryPermissionStore({
    this.permission = AgentToolPermission.alwaysAllow,
    this.failsPersistence = false,
    this.onPersist,
  });

  final AgentToolPermission permission;
  final bool failsPersistence;
  final Future<void> Function()? onPersist;

  @override
  Future<AgentToolPermission?> permissionFor(String toolName) async =>
      AgentToolPermissionCatalog.find(toolName) == null ? null : permission;

  @override
  Future<Map<String, AgentToolPermission>> readAll() async => {
        for (final descriptor in AgentToolPermissionCatalog.descriptors)
          descriptor.toolName: permission,
      };

  @override
  Future<void> restoreDefaults() async {}

  @override
  Future<void> setPermission(
    String toolName,
    AgentToolPermission permission,
  ) async {
    if (failsPersistence) throw StateError('disk full');
    await onPersist?.call();
  }
}

final class _FixedExecutionSettingsStore
    implements AgentExecutionSettingsStore {
  _FixedExecutionSettingsStore(this.maximumModelTurns);

  final int maximumModelTurns;

  @override
  Future<AgentExecutionSettings> read() async =>
      AgentExecutionSettings(maximumModelTurns: maximumModelTurns);

  @override
  Future<void> setMaximumModelTurns(int value) async {}
}
