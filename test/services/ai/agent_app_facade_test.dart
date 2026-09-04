import 'package:agentcore/agentcore.dart';
import 'package:beecount/agent/memory/local_agent_memory_repository.dart';
import 'package:beecount/agent/tools/local_agent_tools.dart';
import 'package:beecount/data/db.dart' hide AgentToolCall;
import 'package:beecount/services/ai/agent_app_facade.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late _FakeGateway gateway;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    gateway = _FakeGateway();
  });

  tearDown(() => db.close());

  test('a successful record response preserves cards and transaction ids',
      () async {
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
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
  });

  test('a malformed model response creates no transaction and records failure',
      () async {
    final facade = AgentAppFacade(
      memoryRepository: LocalAgentMemoryRepository(db),
      toolGateway: gateway,
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
}

final class _FakeModel implements AgentModel {
  _FakeModel(this._turns);

  final List<AgentTurn> _turns;

  @override
  Future<AgentTurn> nextTurn(AgentRequest request) async => _turns.removeAt(0);
}

final class _ThrowingModel implements AgentModel {
  @override
  Future<AgentTurn> nextTurn(AgentRequest request) =>
      Future.error(const FormatException('bad response'));
}

final class _FakeGateway implements LocalAgentToolGateway {
  final List<String> recordedTexts = [];

  @override
  Future<void> forgetMemory(int memoryId) async {}

  @override
  Future<AgentBudgetSummary> getBudgetStatus(int ledgerId) async =>
      const AgentBudgetSummary(daysRemaining: 10, dailyAvailable: 20);

  @override
  Future<List<AgentTransactionSummary>> queryTransactions({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) async =>
      const [];

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
  Future<void> saveExplicitMemory({
    required int? ledgerId,
    required String content,
  }) async {}
}
