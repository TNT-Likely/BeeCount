import 'dart:async';
import 'dart:io';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/data/repositories/local/local_transaction_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('project validation 与 transaction insert 之间不能并发删除 project', () async {
    final dir = await Directory.systemTemp.createTemp('beecount-project-race-');
    final file = File('${dir.path}/race.sqlite');
    final barrier = _ProjectValidationBarrier();
    final dbA = BeeDatabase.forTesting(
      NativeDatabase(file).interceptWith(barrier),
    );
    // 先完整打开/迁移 A，再打开第二连接，避免并发 schema migration 干扰探针。
    await dbA.customSelect('SELECT 1').get();
    final dbB = BeeDatabase.forTesting(NativeDatabase(file));
    await dbB.customSelect('SELECT 1').get();
    addTearDown(() async {
      await dbB.close();
      await dbA.close();
      await dir.delete(recursive: true);
    });

    await dbA.into(dbA.ledgers).insert(LedgersCompanion.insert(name: 'L'));
    final projectId = await dbA.into(dbA.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('project'),
            amount: 100,
            name: const Value('P'),
            startAt: Value(DateTime.utc(2026, 8, 1)),
            endAt: Value(DateTime.utc(2026, 9, 1)),
            status: const Value('active'),
            syncId: const Value('project-race'),
          ),
        );

    final txRepo = LocalTransactionRepository(dbA);
    final deleteRepo = LocalRepository(dbB);
    barrier.arm(expectedSyncId: 'project-race', expectedLedgerId: 1);
    final insertFuture = txRepo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 8, 10),
      syncId: 'tx-race',
      projectBudgetSyncId: 'project-race',
    );

    await barrier.validationReturned.future.timeout(const Duration(seconds: 3));
    expect(barrier.matchCount, 1);
    expect(barrier.matchedStatement, contains('FROM "budgets"'));
    expect(barrier.matchedArgs, contains('project-race'));
    Object? deleteError;
    final deleteSettled = Completer<void>();
    final deleteFuture = deleteRepo.deleteBudget(projectId).catchError((e) {
      deleteError = e;
    }).whenComplete(deleteSettled.complete);

    // 旧实现没有 transaction：B 会在 A 写入前完成删除。修复后 B 应被 A 的
    // transaction 锁住；不对具体 SQLite busy/引用错误作约束，只断言最终不 dangling。
    await Future.any<void>([
      deleteSettled.future,
      Future<void>.delayed(const Duration(milliseconds: 500)),
    ]);
    barrier.resume();

    Object? insertError;
    await insertFuture.catchError((e) {
      insertError = e;
      return -1;
    });
    await deleteFuture;

    final tx = await (dbA.select(dbA.transactions)
          ..where((row) => row.syncId.equals('tx-race')))
        .getSingleOrNull();
    final project = await (dbA.select(dbA.budgets)
          ..where((row) => row.syncId.equals('project-race')))
        .getSingleOrNull();
    expect(insertError, equals(null));
    expect(deleteError == null, isFalse);
    expect(tx?.ledgerId, 1);
    expect(tx?.projectBudgetSyncId, 'project-race');
    expect(project?.ledgerId, 1);
  });

  test('companion validation/write 之间也不能并发删除 project', () async {
    final dir =
        await Directory.systemTemp.createTemp('beecount-companion-race-');
    final file = File('${dir.path}/race.sqlite');
    final barrier = _ProjectValidationBarrier();
    final dbA = BeeDatabase.forTesting(
      NativeDatabase(file).interceptWith(barrier),
    );
    await dbA.customSelect('SELECT 1').get();
    final dbB = BeeDatabase.forTesting(NativeDatabase(file));
    await dbB.customSelect('SELECT 1').get();
    addTearDown(() async {
      await dbB.close();
      await dbA.close();
      await dir.delete(recursive: true);
    });

    await dbA.into(dbA.ledgers).insert(LedgersCompanion.insert(name: 'L'));
    final projectId = await dbA.into(dbA.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('project'),
            amount: 100,
            name: const Value('P'),
            startAt: Value(DateTime.utc(2026, 8, 1)),
            endAt: Value(DateTime.utc(2026, 9, 1)),
            status: const Value('active'),
            syncId: const Value('project-companion-race'),
          ),
        );

    barrier.arm(
      expectedSyncId: 'project-companion-race',
      expectedLedgerId: 1,
    );
    final insertFuture =
        LocalTransactionRepository(dbA).insertTransactionCompanion(
      TransactionsCompanion.insert(
        ledgerId: 1,
        type: 'expense',
        amount: 10,
        syncId: const Value('tx-companion-race'),
        projectBudgetSyncId: const Value('project-companion-race'),
      ),
    );
    await barrier.validationReturned.future.timeout(const Duration(seconds: 3));
    expect(barrier.matchCount, 1);
    expect(barrier.matchedStatement, contains('FROM "budgets"'));
    expect(barrier.matchedArgs, contains('project-companion-race'));

    Object? deleteError;
    final deleteSettled = Completer<void>();
    final deleteFuture =
        LocalRepository(dbB).deleteBudget(projectId).catchError((e) {
      deleteError = e;
    }).whenComplete(deleteSettled.complete);
    await Future.any<void>([
      deleteSettled.future,
      Future<void>.delayed(const Duration(milliseconds: 500)),
    ]);
    barrier.resume();

    Object? insertError;
    await insertFuture.catchError((e) {
      insertError = e;
      return -1;
    });
    await deleteFuture;

    final tx = await (dbA.select(dbA.transactions)
          ..where((row) => row.syncId.equals('tx-companion-race')))
        .getSingleOrNull();
    final project = await (dbA.select(dbA.budgets)
          ..where((row) => row.syncId.equals('project-companion-race')))
        .getSingleOrNull();
    expect(insertError, equals(null));
    expect(deleteError == null, isFalse);
    expect(tx?.ledgerId, 1);
    expect(tx?.projectBudgetSyncId, 'project-companion-race');
    expect(project?.ledgerId, 1);
  });

  test('project delete 引用检查后并发 insert 也不能留下 dangling link', () async {
    final dir =
        await Directory.systemTemp.createTemp('beecount-project-delete-race-');
    final file = File('${dir.path}/race.sqlite');
    final barrier = _ReferenceCheckBarrier();
    final dbA = BeeDatabase.forTesting(
      NativeDatabase(file).interceptWith(barrier),
    );
    await dbA.customSelect('SELECT 1').get();
    final dbB = BeeDatabase.forTesting(NativeDatabase(file));
    await dbB.customSelect('SELECT 1').get();
    addTearDown(() async {
      await dbB.close();
      await dbA.close();
      await dir.delete(recursive: true);
    });

    await dbA.into(dbA.ledgers).insert(LedgersCompanion.insert(name: 'L'));
    final projectId = await dbA.into(dbA.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('project'),
            amount: 100,
            name: const Value('P'),
            startAt: Value(DateTime.utc(2026, 8, 1)),
            endAt: Value(DateTime.utc(2026, 9, 1)),
            status: const Value('active'),
            syncId: const Value('project-delete-race'),
          ),
        );

    barrier.arm(expectedProjectSyncId: 'project-delete-race');
    Object? deleteError;
    final deleteFuture =
        LocalRepository(dbA).deleteBudget(projectId).catchError((e) {
      deleteError = e;
    });
    await barrier.referenceCheckReturned.future
        .timeout(const Duration(seconds: 3));
    expect(barrier.matchCount, 1);
    expect(barrier.matchedStatement, contains('project_budget_sync_id'));
    expect(barrier.matchedArgs, contains('project-delete-race'));

    Object? insertError;
    final insertSettled = Completer<void>();
    final insertFuture = LocalTransactionRepository(dbB)
        .addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 8, 10),
      syncId: 'tx-delete-race',
      projectBudgetSyncId: 'project-delete-race',
    )
        .catchError((e) {
      insertError = e;
      return -1;
    }).whenComplete(insertSettled.complete);

    await Future.any<void>([
      insertSettled.future,
      Future<void>.delayed(const Duration(milliseconds: 500)),
    ]);
    barrier.resume();
    await deleteFuture;
    await insertFuture;

    final tx = await (dbA.select(dbA.transactions)
          ..where((row) => row.syncId.equals('tx-delete-race')))
        .getSingleOrNull();
    final project = await (dbA.select(dbA.budgets)
          ..where((row) => row.syncId.equals('project-delete-race')))
        .getSingleOrNull();
    expect(deleteError, equals(null));
    expect(insertError == null, isFalse);
    expect(tx, equals(null));
    expect(project, equals(null));
  });

  test('ledger update validation 后并发 project delete 不能留下 dangling link',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('beecount-ledger-update-race-');
    final file = File('${dir.path}/race.sqlite');
    final barrier = _ProjectValidationBarrier();
    final dbA = BeeDatabase.forTesting(
      NativeDatabase(file).interceptWith(barrier),
    );
    await dbA.customSelect('SELECT 1').get();
    final dbB = BeeDatabase.forTesting(NativeDatabase(file));
    await dbB.customSelect('SELECT 1').get();
    addTearDown(() async {
      await dbB.close();
      await dbA.close();
      await dir.delete(recursive: true);
    });

    await dbA.into(dbA.ledgers).insert(
          LedgersCompanion.insert(
            name: 'L1',
            currency: const Value('USD'),
          ),
        );
    final targetLedgerId = await dbA.into(dbA.ledgers).insert(
          LedgersCompanion.insert(name: 'L2'),
        );
    final projectId = await dbA.into(dbA.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: targetLedgerId,
            type: const Value('project'),
            amount: 100,
            name: const Value('P'),
            startAt: Value(DateTime.utc(2026, 8, 1)),
            endAt: Value(DateTime.utc(2026, 9, 1)),
            status: const Value('active'),
            syncId: const Value('project-ledger-update-race'),
          ),
        );

    // 明确模拟 trigger 安装前遗留的跨账本坏行；只在 seed 时移除 insert
    // guard，写入后立即恢复原生产 trigger。竞态本身在完整 guards 下运行。
    await dbA
        .customStatement('DROP TRIGGER trg_transactions_project_link_insert');
    final txId = await dbA.into(dbA.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 10,
            nativeAmount: const Value(999),
            syncId: const Value('tx-ledger-update-race'),
            projectBudgetSyncId: const Value('project-ledger-update-race'),
          ),
        );
    await dbA.customStatement('''
CREATE TRIGGER IF NOT EXISTS trg_transactions_project_link_insert
BEFORE INSERT ON transactions
WHEN NEW.project_budget_sync_id IS NOT NULL
BEGIN
  SELECT RAISE(ABORT, 'project_link_requires_expense')
    WHERE NEW.type <> 'expense';
  SELECT RAISE(ABORT, 'project_link_target_invalid')
    WHERE NOT EXISTS (
      SELECT 1 FROM budgets b
      WHERE b.sync_id = NEW.project_budget_sync_id
        AND b.type = 'project'
        AND b.ledger_id = NEW.ledger_id
    );
END;
''');

    barrier.arm(
      expectedSyncId: 'project-ledger-update-race',
      expectedLedgerId: targetLedgerId,
    );
    Object? updateError;
    final updateFuture = LocalRepository(dbA, changeTracker: ChangeTracker(dbA))
        .updateTransactionLedger(id: txId, ledgerId: targetLedgerId)
        .catchError((e) {
      updateError = e;
    });
    await barrier.validationReturned.future.timeout(const Duration(seconds: 3));
    expect(barrier.matchCount, 1);
    expect(barrier.matchedStatement, contains('FROM "budgets"'));
    expect(barrier.matchedArgs, contains('project-ledger-update-race'));

    Object? deleteError;
    final deleteFuture =
        LocalRepository(dbB).deleteBudget(projectId).catchError((e) {
      deleteError = e;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    barrier.resume();
    await updateFuture.timeout(const Duration(seconds: 5));
    await deleteFuture.timeout(const Duration(seconds: 5));

    final tx = await (dbA.select(dbA.transactions)
          ..where((row) => row.id.equals(txId)))
        .getSingleOrNull();
    final project = await (dbA.select(dbA.budgets)
          ..where((row) => row.id.equals(projectId)))
        .getSingleOrNull();
    final changes = await (dbA.select(dbA.localChanges)
          ..where((row) => row.entitySyncId.equals('tx-ledger-update-race')))
        .get();
    expect(updateError, equals(null));
    expect(deleteError == null, isFalse);
    expect(tx?.ledgerId, targetLedgerId);
    expect(tx?.nativeAmount, 10);
    expect(tx?.projectBudgetSyncId, 'project-ledger-update-race');
    expect(project?.ledgerId, targetLedgerId);
    expect(changes, hasLength(1));
    expect(changes.single.ledgerId, targetLedgerId);
  });

  test('linked writer 与 project identity mutation 竞态不能留下 dangling link',
      () async {
    final dir = await Directory.systemTemp
        .createTemp('beecount-project-identity-race-');
    final file = File('${dir.path}/race.sqlite');
    final barrier = _ProjectValidationBarrier();
    final dbA = BeeDatabase.forTesting(
      NativeDatabase(file).interceptWith(barrier),
    );
    await dbA.customSelect('SELECT 1').get();
    final dbB = BeeDatabase.forTesting(NativeDatabase(file));
    await dbB.customSelect('SELECT 1').get();
    addTearDown(() async {
      await dbB.close();
      await dbA.close();
      await dir.delete(recursive: true);
    });

    await dbA.into(dbA.ledgers).insert(LedgersCompanion.insert(name: 'L'));
    final projectId = await dbA.into(dbA.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('project'),
            amount: 100,
            name: const Value('P'),
            startAt: Value(DateTime.utc(2026, 8, 1)),
            endAt: Value(DateTime.utc(2026, 9, 1)),
            status: const Value('active'),
            syncId: const Value('project-identity-race'),
          ),
        );

    barrier.arm(expectedSyncId: 'project-identity-race', expectedLedgerId: 1);
    Object? insertError;
    final insertFuture = LocalTransactionRepository(dbA)
        .addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 10,
      happenedAt: DateTime.utc(2026, 8, 10),
      syncId: 'tx-identity-race',
      projectBudgetSyncId: 'project-identity-race',
    )
        .catchError((e) {
      insertError = e;
      return -1;
    });
    await barrier.validationReturned.future.timeout(const Duration(seconds: 3));
    expect(barrier.matchCount, 1);
    expect(barrier.matchedStatement, contains('FROM "budgets"'));
    expect(barrier.matchedArgs, contains('project-identity-race'));

    Object? mutationError;
    final mutationFuture = dbB.customStatement(
      'UPDATE budgets SET sync_id = ? WHERE id = ?',
      ['project-identity-mutated', projectId],
    ).catchError((e) {
      mutationError = e;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    barrier.resume();
    await insertFuture.timeout(const Duration(seconds: 5));
    await mutationFuture.timeout(const Duration(seconds: 5));

    final tx = await (dbA.select(dbA.transactions)
          ..where((row) => row.syncId.equals('tx-identity-race')))
        .getSingleOrNull();
    final linkedProject = tx?.projectBudgetSyncId == null
        ? null
        : await (dbA.select(dbA.budgets)
              ..where((row) => row.syncId.equals(tx!.projectBudgetSyncId!)))
            .getSingleOrNull();
    expect(insertError, equals(null));
    expect(mutationError == null, isFalse);
    expect(tx?.ledgerId, 1);
    expect(tx?.projectBudgetSyncId, 'project-identity-race');
    expect(linkedProject?.syncId, 'project-identity-race');
    expect(linkedProject?.ledgerId, 1);
  });
}

class _ProjectValidationBarrier extends QueryInterceptor {
  Completer<void> validationReturned = Completer<void>();
  final Completer<void> _resume = Completer<void>();
  var _armed = false;
  String? _expectedSyncId;
  int? _expectedLedgerId;
  int matchCount = 0;
  String? matchedStatement;
  List<Object?>? matchedArgs;

  void arm({required String expectedSyncId, required int expectedLedgerId}) {
    _expectedSyncId = expectedSyncId;
    _expectedLedgerId = expectedLedgerId;
    _armed = true;
  }

  void resume() {
    if (!_resume.isCompleted) _resume.complete();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    final hasExpectedProjectRow = result.any(
      (row) =>
          row['sync_id'] == _expectedSyncId &&
          row['ledger_id'] == _expectedLedgerId &&
          row['type'] == 'project',
    );
    final isExpectedValidation = _armed &&
        statement.contains('FROM "budgets"') &&
        statement.contains('"sync_id"') &&
        statement.contains('"type"') &&
        args.contains(_expectedSyncId) &&
        hasExpectedProjectRow;
    if (isExpectedValidation) {
      _armed = false;
      matchCount++;
      matchedStatement = statement;
      matchedArgs = List<Object?>.of(args);
      validationReturned.complete();
      await _resume.future;
    }
    return result;
  }
}

class _ReferenceCheckBarrier extends QueryInterceptor {
  Completer<void> referenceCheckReturned = Completer<void>();
  final Completer<void> _resume = Completer<void>();
  var _armed = false;
  String? _expectedProjectSyncId;
  int matchCount = 0;
  String? matchedStatement;
  List<Object?>? matchedArgs;

  void arm({required String expectedProjectSyncId}) {
    _expectedProjectSyncId = expectedProjectSyncId;
    _armed = true;
  }

  void resume() {
    if (!_resume.isCompleted) _resume.complete();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final result = await executor.runSelect(statement, args);
    final isExpectedReferenceCheck = _armed &&
        statement.contains('FROM "transactions"') &&
        statement.contains('"project_budget_sync_id"') &&
        args.contains(_expectedProjectSyncId);
    if (isExpectedReferenceCheck) {
      _armed = false;
      matchCount++;
      matchedStatement = statement;
      matchedArgs = List<Object?>.of(args);
      referenceCheckReturned.complete();
      await _resume.future;
    }
    return result;
  }
}
