import 'dart:async';
import 'package:beecount/agent/memory/agent_memory_repository.dart';
import 'package:beecount/agent/memory/local_agent_memory_repository.dart';
import 'package:beecount/agent/permission/agent_tool_permission.dart';
import 'package:beecount/agent/permission/shared_preferences_agent_tool_permission_store.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/ai/agent_memory_page.dart';
import 'package:beecount/pages/ai/agent_permissions_page.dart';
import 'package:beecount/pages/ai/agent_activity_page.dart';
import 'package:beecount/pages/ai/agent_tool_presentation.dart';
import 'package:beecount/presentation/v4/bindings/ai_advanced_preview.dart';
import 'package:beecount/presentation/v4/gallery/ai_advanced_sample.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount_business_ui/ai_advanced.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Memory implements AgentMemoryRepository {
  _Memory(this.real);
  final LocalAgentMemoryRepository real;
  bool readError = false,
      forgetError = false,
      clearError = false,
      runsError = false,
      callsError = false;
  final gates = <int, Completer<void>>{};
  Completer<void>? writeGate;
  int forgets = 0, clears = 0, reads = 0, runReads = 0;
  @override
  Future<List<AgentMemoryRecord>> listActive({required int ledgerId}) async {
    reads++;
    await gates[ledgerId]?.future;
    if (readError) throw StateError('SENSITIVE raw sqlite error');
    return real.listActive(ledgerId: ledgerId);
  }

  @override
  Future<bool> forget(int id, {required int ledgerId}) async {
    forgets++;
    await writeGate?.future;
    if (forgetError) throw StateError('SENSITIVE raw sqlite error');
    return real.forget(id, ledgerId: ledgerId);
  }

  @override
  Future<void> clearForLedger(int ledger) async {
    clears++;
    await writeGate?.future;
    if (clearError) throw StateError('SENSITIVE raw sqlite error');
    return real.clearForLedger(ledger);
  }

  @override
  Future<List<AgentRunRecord>> listRecentRuns({required int ledgerId}) async {
    runReads++;
    await gates[ledgerId]?.future;
    if (runsError) throw StateError('SENSITIVE raw sqlite error');
    return real.listRecentRuns(ledgerId: ledgerId);
  }

  @override
  Future<List<AgentToolCallRecord>> listToolCalls(String runId) {
    if (callsError) throw StateError('SENSITIVE raw tool detail');
    return real.listToolCalls(runId);
  }

  @override
  Future<AgentMemoryRecord> saveExplicit(AgentMemoryDraft draft) =>
      real.saveExplicit(draft);
  @override
  Future<List<AgentMemoryRecord>> search(
          {required int ledgerId, required String query}) =>
      real.search(ledgerId: ledgerId, query: query);
  @override
  Future<void> clearAll() => real.clearAll();
  @override
  Future<void> saveSummary(
          {required int? ledgerId,
          required int? conversationId,
          required String content}) =>
      real.saveSummary(
          ledgerId: ledgerId, conversationId: conversationId, content: content);
  @override
  Future<void> createRun(
          {required String runId,
          required int? ledgerId,
          required String userMessage}) =>
      real.createRun(
          runId: runId, ledgerId: ledgerId, userMessage: userMessage);
  @override
  Future<void> finishRun(
          {required String runId,
          required String status,
          String? errorMessage}) =>
      real.finishRun(runId: runId, status: status, errorMessage: errorMessage);
  @override
  Future<void> recordToolCall(AgentToolCallAudit call) =>
      real.recordToolCall(call);
  @override
  Future<int> toolCallCount(String runId) => real.toolCallCount(runId);
}

class _Permissions implements AgentToolPermissionStore {
  _Permissions(this.real);
  final SharedPreferencesAgentToolPermissionStore real;
  bool readError = false, writeError = false, restoreError = false;
  Completer<void>? gate;
  int writes = 0, restores = 0;
  @override
  Future<Map<String, AgentToolPermission>> readAll() {
    if (readError) throw StateError('SENSITIVE preference error');
    return real.readAll();
  }

  @override
  Future<AgentToolPermission?> permissionFor(String name) =>
      real.permissionFor(name);
  @override
  Future<void> setPermission(
      String name, AgentToolPermission permission) async {
    writes++;
    await gate?.future;
    if (writeError) throw StateError('SENSITIVE preference error');
    return real.setPermission(name, permission);
  }

  @override
  Future<void> restoreDefaults() async {
    restores++;
    await gate?.future;
    if (restoreError) throw StateError('SENSITIVE preference error');
    return real.restoreDefaults();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsEn();
  late BeeDatabase db;
  late _Memory memory;
  late _Permissions permissions;
  late AgentMemoryRecord local, global;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'unrelated': 'keep'});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    memory = _Memory(LocalAgentMemoryRepository(db));
    permissions = _Permissions(SharedPreferencesAgentToolPermissionStore(
        getPreferences: SharedPreferences.getInstance));
    local = await memory.saveExplicit(const AgentMemoryDraft(
        ledgerId: 1, kind: 'preference', content: 'Local preference A'));
    await memory.saveExplicit(const AgentMemoryDraft(
        ledgerId: 2, kind: 'preference', content: 'Private preference B'));
    global = await memory.saveExplicit(const AgentMemoryDraft(
        ledgerId: null, kind: 'preference', content: 'Global preference'));
    await memory.saveExplicit(AgentMemoryDraft(
        ledgerId: 1,
        kind: 'preference',
        content: 'Expired preference',
        expiresAt: DateTime.now().subtract(const Duration(days: 1))));
    final forgotten = await memory.saveExplicit(const AgentMemoryDraft(
        ledgerId: 1, kind: 'preference', content: 'Forgotten preference'));
    await memory.real.forget(forgotten.id, ledgerId: 1);
    await memory.saveSummary(
        ledgerId: 1, conversationId: null, content: 'Summary A');
    await memory.saveSummary(
        ledgerId: 2, conversationId: null, content: 'Private summary B');
    await memory.saveSummary(
        ledgerId: null, conversationId: null, content: 'Global summary');
    for (final status in ['completed', 'cancelled', 'failed', 'running']) {
      await memory.createRun(
          runId: 'run-$status', ledgerId: 1, userMessage: 'Message $status');
      if (status != 'running') {
        await memory.finishRun(
            runId: 'run-$status',
            status: status,
            errorMessage: status == 'failed' ? 'Synthetic run failure' : null);
      }
    }
    await memory.createRun(
        runId: 'private-run', ledgerId: 2, userMessage: 'Private activity B');
    for (final status in ['completed', 'denied', 'failed']) {
      await memory.recordToolCall(AgentToolCallAudit(
          runId: 'run-completed',
          callId: 'call-$status',
          toolName: 'query_transactions',
          status: status,
          detail: 'SENSITIVE_TOOL_DETAIL_DO_NOT_SHOW'));
    }
  });
  tearDown(() => db.close());
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        for (final gate in memory.gates.values) {
          if (!gate.isCompleted) gate.complete();
        }
        if (memory.writeGate != null && !memory.writeGate!.isCompleted) {
          memory.writeGate!.complete();
        }
        if (permissions.gate != null && !permissions.gate!.isCompleted) {
          permissions.gate!.complete();
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 6));
      }
    });
  }

  Widget host(Widget page,
          {Brightness brightness = Brightness.light, double scale = 1}) =>
      ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            currentLedgerIdProvider.overrideWith((ref) => 1),
            agentMemoryRepositoryProvider.overrideWithValue(memory),
            agentToolPermissionStoreProvider.overrideWithValue(permissions),
            localAgentToolGatewayProvider.overrideWith(
                (ref) => throw StateError('Tool execution forbidden')),
            agentModelCapabilityServiceProvider.overrideWith(
                (ref) => throw StateError('Model requests forbidden')),
            agentAppFacadeProvider.overrideWith(
                (ref) => throw StateError('Agent execution forbidden')),
            aiChatServiceProvider.overrideWith(
                (ref) => throw StateError('Chat requests forbidden'))
          ],
          child: MaterialApp(
              theme: beeTheme(brightness: brightness),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: page));
  Future<void> flush(WidgetTester t, {int cycles = 8}) async {
    for (var i = 0; i < cycles; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> show(WidgetTester t, Widget page) async {
    await t.pumpWidget(host(page));
    await flush(t);
  }

  Future<void> tap(WidgetTester t, String text) async {
    final base = find.text(text);
    if (base.evaluate().isEmpty) {
      await t.scrollUntilVisible(base, 160);
    }
    final f = base.last;
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(f, 160);
    } else {
      await t.ensureVisible(f);
    }
    await t.pump();
    await t.tap(f);
    await flush(t);
  }

  Future<void> permission(WidgetTester t, String name) async {
    final f = find.byKey(ValueKey('permission-status-$name'));
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(f, 160);
    } else {
      await t.ensureVisible(f);
    }
    await t.pump();
    await t.tap(f);
    await flush(t);
  }

  scenario('记忆仅展示当前和全局有效记录，隐藏其他账本过期和已遗忘', (t) async {
    await show(t, const AgentMemoryPage(ledgerId: 1));
    expect(find.text('Local preference A'), findsOneWidget);
    expect(find.text('Global preference'), findsOneWidget);
    for (final value in [
      'Private preference B',
      'Expired preference',
      'Forgotten preference'
    ]) {
      expect(find.text(value), findsNothing);
    }
    expect(find.byType(TextField), findsNothing);
  });
  scenario('取消单条遗忘不写SQLite', (t) async {
    await show(t, const AgentMemoryPage(ledgerId: 1));
    await t.tap(find.byKey(ValueKey('agent-memory-delete-${local.id}')));
    await flush(t);
    await tap(t, l.commonCancel);
    expect(memory.forgets, 0);
    expect(
        (await memory.real.listActive(ledgerId: 1))
            .any((x) => x.id == local.id),
        true);
  });
  scenario('确认单条遗忘保留其他账本全局及审计', (t) async {
    await show(t, const AgentMemoryPage(ledgerId: 1));
    await t.tap(find.byKey(ValueKey('agent-memory-delete-${local.id}')));
    await flush(t);
    await tap(t, l.commonDelete);
    expect(find.text('Local preference A'), findsNothing);
    expect(memory.forgets, 1);
    expect(
        (await db.select(db.agentMemories).get())
            .singleWhere((x) => x.id == local.id)
            .status,
        'forgotten');
    expect((await memory.real.listActive(ledgerId: 2)).map((x) => x.content),
        containsAll(['Private preference B', 'Global preference']));
    expect(await db.select(db.agentRuns).get(), hasLength(5));
  });
  scenario('全局记忆遗忘返回false如实失败不绕ledger权限', (t) async {
    await show(t, const AgentMemoryPage(ledgerId: 1));
    await t.tap(find.byKey(ValueKey('agent-memory-delete-${global.id}')));
    await flush(t);
    await tap(t, l.commonDelete);
    expect(find.text(l.commonFailed), findsOneWidget);
    expect(find.text('Global preference'), findsOneWidget);
    expect(
        (await db.select(db.agentMemories).get())
            .singleWhere((x) => x.id == global.id)
            .status,
        'active');
  });
  scenario('取消清空保留本账本记忆与摘要', (t) async {
    await show(t, const AgentMemoryPage(ledgerId: 1));
    await tap(t, l.agentMemoryClear);
    await tap(t, l.commonCancel);
    expect(memory.clears, 0);
    expect(await db.select(db.agentConversationSummaries).get(), hasLength(3));
  });
  scenario('确认清空仅当前账本含摘要且不清全局或他账', (t) async {
    await show(t, const AgentMemoryPage(ledgerId: 1));
    await tap(t, l.agentMemoryClear);
    await tap(t, l.commonDelete);
    expect(memory.clears, 1);
    expect(
        (await db.select(db.agentMemories).get()).where((x) => x.ledgerId == 1),
        isEmpty);
    expect(
        (await db.select(db.agentConversationSummaries).get())
            .map((x) => x.content),
        containsAll(['Private summary B', 'Global summary']));
    expect(find.text('Global preference'), findsOneWidget);
    expect(await db.select(db.agentRuns).get(), hasLength(5));
  });
  for (final operation in ['read', 'forget', 'clear']) {
    scenario('记忆$operation失败保留记录且不泄露原始错误', (t) async {
      memory.readError = operation == 'read';
      memory.forgetError = operation == 'forget';
      memory.clearError = operation == 'clear';
      await show(t, const AgentMemoryPage(ledgerId: 1));
      if (operation == 'forget') {
        await t.tap(find.byKey(ValueKey('agent-memory-delete-${local.id}')));
        await flush(t);
        await tap(t, l.commonDelete);
      }
      if (operation == 'clear') {
        await tap(t, l.agentMemoryClear);
        await tap(t, l.commonDelete);
      }
      expect(find.text(l.commonFailed), findsOneWidget);
      expect(find.textContaining('SENSITIVE'), findsNothing);
      expect(
          (await memory.real.listActive(ledgerId: 1))
              .any((x) => x.id == local.id),
          true);
      memory.readError = false;
      memory.forgetError = false;
      memory.clearError = false;
      await tap(t, l.v4RecordingRetry);
      expect(find.text('Local preference A'), findsOneWidget);
    });
  }
  scenario('遗忘执行防重与退页后完成保持原scoped写入', (t) async {
    memory.writeGate = Completer();
    await show(t, const AgentMemoryPage(ledgerId: 1));
    await t.tap(find.byKey(ValueKey('agent-memory-delete-${local.id}')));
    await flush(t);
    await tap(t, l.commonDelete);
    expect(memory.forgets, 1);
    expect(
        t
            .widget<BeeIconButton>(
                find.byKey(ValueKey('agent-memory-delete-${local.id}')))
            .onPressed,
        isNull);
    await t.pumpWidget(const SizedBox.shrink());
    memory.writeGate!.complete();
    await flush(t);
    expect(t.takeException(), isNull);
    expect(
        (await memory.real.listActive(ledgerId: 1))
            .any((x) => x.id == local.id),
        false);
  });
  scenario('记忆账本切换忽略旧读取避免串本', (t) async {
    memory.gates[1] = Completer();
    await show(t, const AgentMemoryPage(ledgerId: 1));
    await t.pumpWidget(host(const AgentMemoryPage(ledgerId: 2)));
    await flush(t);
    expect(find.text('Private preference B'), findsOneWidget);
    memory.gates[1]!.complete();
    await flush(t);
    expect(find.text('Local preference A'), findsNothing);
    expect(find.text('Private preference B'), findsOneWidget);
  });
  scenario('旧确认期间切账不遗忘新账或原账', (t) async {
    await show(t, const AgentMemoryPage(ledgerId: 1));
    await t.tap(find.byKey(ValueKey('agent-memory-delete-${local.id}')));
    await flush(t);
    await t.pumpWidget(host(const AgentMemoryPage(ledgerId: 2)));
    await flush(t);
    await tap(t, l.commonDelete);
    expect(memory.forgets, 0);
    expect(find.text('Private preference B'), findsOneWidget);
  });
  scenario('权限9原项默认与两枚举逐项核对', (t) async {
    expect(AgentToolPermission.values, hasLength(2));
    expect(AgentToolPermissionCatalog.descriptors, hasLength(9));
    expect(
        AgentToolPermissionCatalog.descriptors.where((d) => d.mutatesLocalData),
        hasLength(3));
    await show(t, const AgentPermissionsPage());
    for (final d in AgentToolPermissionCatalog.descriptors) {
      expect(await permissions.permissionFor(d.toolName), d.defaultPermission);
      final key = find.byKey(ValueKey('permission-status-${d.toolName}'));
      await t.scrollUntilVisible(key, 160);
      await flush(t);
      expect(
          find.descendant(
              of: key,
              matching: find.text(AgentToolPresentation.permissionLabel(
                  l, d.defaultPermission))),
          findsOneWidget);
    }
    expect(permissions.writes, 0);
  });
  for (final d in AgentToolPermissionCatalog.descriptors) {
    scenario('真实权限偏好保存${d.toolName}并保持其他默认', (t) async {
      await show(t, const AgentPermissionsPage());
      await permission(t, d.toolName);
      final next = d.defaultPermission == AgentToolPermission.ask
          ? AgentToolPermission.alwaysAllow
          : AgentToolPermission.ask;
      await tap(t, AgentToolPresentation.permissionLabel(l, next));
      expect(await permissions.permissionFor(d.toolName), next);
      expect(permissions.writes, 1);
      for (final other in AgentToolPermissionCatalog.descriptors
          .where((x) => x.toolName != d.toolName)) {
        expect(await permissions.permissionFor(other.toolName),
            other.defaultPermission);
      }
      expect((await SharedPreferences.getInstance()).getString('unrelated'),
          'keep');
    });
  }
  scenario('权限sheet取消与选择原值都不写入', (t) async {
    await show(t, const AgentPermissionsPage());
    await permission(t, 'record_transaction_from_text');
    await t.tapAt(const Offset(10, 10));
    await flush(t);
    expect(permissions.writes, 0);
    await permission(t, 'record_transaction_from_text');
    await tap(t, l.agentPermissionAsk);
    expect(permissions.writes, 0);
  });
  scenario('权限保存失败保留旧状态并只显示本地化错误', (t) async {
    permissions.writeError = true;
    await show(t, const AgentPermissionsPage());
    await permission(t, 'record_transaction_from_text');
    await tap(t, l.agentPermissionAlwaysAllow);
    expect(await permissions.permissionFor('record_transaction_from_text'),
        AgentToolPermission.ask);
    expect(find.text(l.agentPermissionWriteFailed), findsOneWidget);
    expect(find.textContaining('SENSITIVE'), findsNothing);
  });
  scenario('权限读取失败提供重试不永久加载', (t) async {
    permissions.readError = true;
    await show(t, const AgentPermissionsPage());
    expect(find.text(l.agentPermissionWriteFailed), findsOneWidget);
    permissions.readError = false;
    await tap(t, l.v4RecordingRetry);
    expect(find.byKey(const ValueKey('permission-status-query_transactions')),
        findsOneWidget);
  });
  scenario('恢复默认取消不动已保存偏好', (t) async {
    await permissions.real.setPermission(
        'record_transaction_from_text', AgentToolPermission.alwaysAllow);
    await show(t, const AgentPermissionsPage());
    await tap(t, l.agentPermissionsRestoreDefaults);
    await tap(t, l.commonCancel);
    expect(permissions.restores, 0);
    expect(await permissions.permissionFor('record_transaction_from_text'),
        AgentToolPermission.alwaysAllow);
  });
  scenario('恢复所有9项默认并保持其他偏好和数据库', (t) async {
    for (final d in AgentToolPermissionCatalog.descriptors) {
      await permissions.real.setPermission(
          d.toolName,
          d.defaultPermission == AgentToolPermission.ask
              ? AgentToolPermission.alwaysAllow
              : AgentToolPermission.ask);
    }
    await show(t, const AgentPermissionsPage());
    await tap(t, l.agentPermissionsRestoreDefaults);
    await tap(t, l.agentPermissionsRestoreConfirm);
    expect(permissions.restores, 1);
    for (final d in AgentToolPermissionCatalog.descriptors) {
      expect(await permissions.permissionFor(d.toolName), d.defaultPermission);
    }
    expect(
        (await SharedPreferences.getInstance())
            .getString(SharedPreferencesAgentToolPermissionStore.key),
        isNull);
    expect(await db.select(db.agentMemories).get(), hasLength(5));
    expect(
        (await SharedPreferences.getInstance()).getString('unrelated'), 'keep');
  });
  scenario('恢复失败不显示默认成功且保留原权限', (t) async {
    await permissions.real.setPermission(
        'record_transaction_from_text', AgentToolPermission.alwaysAllow);
    permissions.restoreError = true;
    await show(t, const AgentPermissionsPage());
    await tap(t, l.agentPermissionsRestoreDefaults);
    await tap(t, l.agentPermissionsRestoreConfirm);
    expect(find.text(l.agentPermissionWriteFailed), findsOneWidget);
    expect(await permissions.permissionFor('record_transaction_from_text'),
        AgentToolPermission.alwaysAllow);
  });
  scenario('权限写入中退页不会访问销毁ref', (t) async {
    permissions.gate = Completer();
    await show(t, const AgentPermissionsPage());
    await permission(t, 'record_transaction_from_text');
    await tap(t, l.agentPermissionAlwaysAllow);
    expect(permissions.writes, 1);
    await t.pumpWidget(const SizedBox.shrink());
    permissions.gate!.complete();
    await flush(t);
    expect(t.takeException(), isNull);
    expect(await permissions.permissionFor('record_transaction_from_text'),
        AgentToolPermission.alwaysAllow);
  });
  scenario('活动保留4种执行与3种工具状态且detail不外泄', (t) async {
    await show(t, const AgentActivityPage(ledgerId: 1));
    for (final row in [
      ('completed', l.agentActivityCompleted),
      ('cancelled', l.agentActivityCancelled),
      ('failed', l.agentActivityFailed),
      ('running', l.agentActivityRunning)
    ]) {
      final message = find.text('Message ${row.$1}');
      await t.scrollUntilVisible(message, 160);
      await flush(t);
      final card = t.widget<BeeAIAdvancedActivityCard>(find.ancestor(
          of: message, matching: find.byType(BeeAIAdvancedActivityCard)));
      expect(card.status, row.$2);
      if (row.$1 == 'failed') {
        expect(find.text('Synthetic run failure'), findsOneWidget);
      }
    }
    await t.drag(find.byType(ListView), const Offset(0, 1800));
    await flush(t);
    for (final row in [
      ('completed', l.agentActivityToolCompleted),
      ('denied', l.agentActivityToolDenied),
      ('failed', l.agentActivityToolFailed)
    ]) {
      expect(
          find.descendant(
              of: find
                  .byKey(ValueKey('agent-activity-tool-status-call-${row.$1}')),
              matching: find.text(row.$2)),
          findsOneWidget);
    }
    expect(find.textContaining('SENSITIVE_TOOL_DETAIL'), findsNothing);
    expect(find.text('Private activity B'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
  for (final source in ['runs', 'calls']) {
    scenario('活动$source读取故障可重试无半份历史或敏感错误', (t) async {
      memory.runsError = source == 'runs';
      memory.callsError = source == 'calls';
      await show(t, const AgentActivityPage(ledgerId: 1));
      expect(find.text(l.commonFailed), findsOneWidget);
      expect(find.textContaining('SENSITIVE'), findsNothing);
      expect(find.text('Message completed'), findsNothing);
      memory.runsError = false;
      memory.callsError = false;
      await tap(t, l.v4RecordingRetry);
      expect(find.text('Message completed'), findsOneWidget);
    });
  }
  scenario('活动账本切换忽略旧响应并保持只读', (t) async {
    memory.gates[1] = Completer();
    await show(t, const AgentActivityPage(ledgerId: 1));
    await t.pumpWidget(host(const AgentActivityPage(ledgerId: 2)));
    await flush(t);
    expect(find.text('Private activity B'), findsOneWidget);
    memory.gates[1]!.complete();
    await flush(t);
    expect(find.text('Message completed'), findsNothing);
    expect(memory.forgets, 0);
    expect(memory.clears, 0);
    expect(permissions.writes, 0);
  });
  scenario('活动保留原最近30次限制和下拉刷新', (t) async {
    for (var i = 0; i < 35; i++) {
      await memory.createRun(
          runId: 'recent-$i', ledgerId: 1, userMessage: 'Recent $i');
      await db.customStatement(
          'UPDATE agent_runs SET started_at=? WHERE run_id=?',
          [1900000000 + i, 'recent-$i']);
    }
    await show(t, const AgentActivityPage(ledgerId: 1));
    expect(find.byType(BeeAIAdvancedActivityCard), findsWidgets);
    expect((await memory.real.listRecentRuns(ledgerId: 1)), hasLength(30));
    expect(find.text('Message completed'), findsNothing);
    final old = memory.runReads;
    await t.drag(find.byType(ListView), const Offset(0, 500));
    await flush(t);
    expect(memory.runReads, greaterThan(old));
  });
  scenario('空记忆与空活动保留原空态', (t) async {
    await show(t, const AgentMemoryPage(ledgerId: 99));
    expect(find.text('Global preference'), findsOneWidget);
    await memory.real.clearAll();
    await t.pumpWidget(host(const AgentMemoryPage(ledgerId: 98)));
    await flush(t);
    expect(find.text(l.agentMemoryEmpty), findsOneWidget);
    await t.pumpWidget(host(const AgentActivityPage(ledgerId: 99)));
    await flush(t);
    expect(find.text(l.agentActivityEmpty), findsOneWidget);
  });
  scenario('只读真实preview不执行模型工具或写数据', (t) async {
    await show(t, const Scaffold(body: AIAdvancedPreview()));
    expect(find.textContaining(l.agentMemoryTitle), findsOneWidget);
    expect(memory.forgets, 0);
    expect(memory.clears, 0);
    expect(permissions.writes, 0);
    expect(await db.select(db.agentMemories).get(), hasLength(5));
  });
  for (final brightness in Brightness.values) {
    for (final page in [
      const AgentMemoryPage(ledgerId: 1),
      const AgentPermissionsPage(),
      const AgentActivityPage(ledgerId: 1)
    ]) {
      scenario('360px短屏大字体${brightness.name}${page.runtimeType}', (t) async {
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(host(page, brightness: brightness, scale: 1.5));
        await flush(t);
        await t.drag(find.byType(ListView), const Offset(0, -600));
        await flush(t);
        expect(t.takeException(), isNull);
      });
    }
  }
  scenario('360高横屏大字体权限sheet滚动选择仍可保存', (t) async {
    t.view.physicalSize = const Size(640, 360);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(host(const AgentPermissionsPage(), scale: 1.5));
    await flush(t);
    await permission(t, 'record_transaction_from_text');
    await tap(t, l.agentPermissionAlwaysAllow);
    expect(await permissions.permissionFor('record_transaction_from_text'),
        AgentToolPermission.alwaysAllow);
    expect(t.takeException(), isNull);
  });
  scenario('360高横屏大字体记忆确认仍可取消', (t) async {
    t.view.physicalSize = const Size(640, 360);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(host(const AgentMemoryPage(ledgerId: 1), scale: 1.5));
    await flush(t);
    final target = find.byKey(ValueKey('agent-memory-delete-${local.id}'));
    await t.scrollUntilVisible(target, 160);
    await flush(t);
    await t.tap(target);
    await flush(t);
    await tap(t, l.commonCancel);
    expect(memory.forgets, 0);
    expect(t.takeException(), isNull);
  });
  scenario('纯组件gallery受控示例不读取服务', (t) async {
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: const Scaffold(
            body: SingleChildScrollView(child: AIAdvancedSample()))));
    await t.pumpAndSettle();
    expect(find.byType(BeeAIAdvancedMemoryCard), findsOneWidget);
    expect(memory.reads, 0);
    expect(memory.runReads, 0);
    expect(permissions.writes, 0);
  });
}
