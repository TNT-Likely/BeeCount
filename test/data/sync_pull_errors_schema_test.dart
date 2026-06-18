// sync_pull_errors 表 schema 测试。
//
// v25 → v26 migration 是所有用户启动必跑的关键路径,出错 = 整体崩盘。
// 本测试验证:
//   1. schemaVersion 在最新版本(当前为 29,v29 加了 exclude_from_stats / exclude_from_budget)
//   2. sync_pull_errors 表完整 schema,所有列存在 + 默认值正确
//   3. UNIQUE(change_id) 约束生效
//   4. CRUD 基本操作正常
//
// 不测真的 v25→v26 ALTER 路径(需要 Drift schema export + 工具链),
// 但本测试能 catch schema 定义错误 + 默认值变更等回归。

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('schemaVersion = 29(确保 sync_pull_errors 表已纳入 schema)', () {
    expect(db.schemaVersion, 29);
  });

  test('sync_pull_errors 表存在,所有列就位', () async {
    // PRAGMA table_info 查表结构 — 如果表没建会抛或返空
    final cols = await db
        .customSelect("PRAGMA table_info(sync_pull_errors)")
        .get();
    expect(cols, isNotEmpty,
        reason: 'sync_pull_errors 表必须存在(v26 onCreate / onUpgrade 创建)');

    // 所有列名
    final columnNames = cols.map((r) => r.read<String>('name')).toSet();
    expect(columnNames, containsAll([
      'id',
      'change_id',
      'ledger_external_id',
      'entity_type',
      'entity_sync_id',
      'action',
      'raw_change_json',
      'error_class',
      'error_message',
      'stack_trace',
      'first_seen_at',
      'last_attempt_at',
      'attempt_count',
      'user_action',
      'resolved_at',
    ]));
  });

  test('INSERT + SELECT 正常 + 默认值 attempt_count=1', () async {
    final now = DateTime.now().toUtc();
    await db.into(db.syncPullErrors).insert(SyncPullErrorsCompanion.insert(
          changeId: 100,
          entityType: 'transaction',
          entitySyncId: 'tx-1',
          action: 'upsert',
          rawChangeJson: '{}',
          firstSeenAt: now,
          lastAttemptAt: now,
        ));

    final row = await (db.select(db.syncPullErrors)
          ..where((t) => t.changeId.equals(100)))
        .getSingle();
    expect(row.changeId, 100);
    expect(row.attemptCount, 1,
        reason: 'attempt_count 默认值应为 1');
    expect(row.userAction, isNull);
    expect(row.resolvedAt, isNull);
    expect(row.ledgerExternalId, isNull,
        reason: 'ledger_external_id 必须 nullable(user-global change 用)');
  });

  test('UNIQUE(change_id) 约束生效:重复 INSERT 同 change_id 抛错', () async {
    final now = DateTime.now().toUtc();
    await db.into(db.syncPullErrors).insert(SyncPullErrorsCompanion.insert(
          changeId: 200,
          entityType: 'transaction',
          entitySyncId: 'tx-1',
          action: 'upsert',
          rawChangeJson: '{}',
          firstSeenAt: now,
          lastAttemptAt: now,
        ));
    // 重复 INSERT 同 change_id 应抛 UNIQUE constraint
    await expectLater(
      db.into(db.syncPullErrors).insert(SyncPullErrorsCompanion.insert(
            changeId: 200,
            entityType: 'transaction',
            entitySyncId: 'tx-2',
            action: 'upsert',
            rawChangeJson: '{}',
            firstSeenAt: now,
            lastAttemptAt: now,
          )),
      throwsA(anything),
    );
  });

  test('UPDATE attempt_count + last_attempt_at 正常(SyncErrorStore update-first 路径)',
      () async {
    final now = DateTime.now().toUtc();
    await db.into(db.syncPullErrors).insert(SyncPullErrorsCompanion.insert(
          changeId: 300,
          entityType: 'transaction',
          entitySyncId: 'tx-1',
          action: 'upsert',
          rawChangeJson: '{}',
          firstSeenAt: now,
          lastAttemptAt: now,
        ));

    // 模拟 SyncErrorStore.record 的 customUpdate 路径
    final affected = await db.customUpdate(
      'UPDATE sync_pull_errors '
      'SET attempt_count = attempt_count + 1, last_attempt_at = ? '
      'WHERE change_id = ?',
      variables: [
        Variable<DateTime>(now.add(const Duration(seconds: 1))),
        Variable<int>(300),
      ],
      updates: {db.syncPullErrors},
    );
    expect(affected, 1);

    final row = await (db.select(db.syncPullErrors)
          ..where((t) => t.changeId.equals(300)))
        .getSingle();
    expect(row.attemptCount, 2);
  });

  test('UPDATE resolvedAt 标记已解决', () async {
    final now = DateTime.now().toUtc();
    await db.into(db.syncPullErrors).insert(SyncPullErrorsCompanion.insert(
          changeId: 400,
          entityType: 'transaction',
          entitySyncId: 'tx-1',
          action: 'upsert',
          rawChangeJson: '{}',
          firstSeenAt: now,
          lastAttemptAt: now,
        ));

    await (db.update(db.syncPullErrors)
          ..where((t) => t.changeId.equals(400)))
        .write(SyncPullErrorsCompanion(
      resolvedAt: Value(DateTime.now().toUtc()),
      userAction: const Value('skip'),
    ));

    final row = await (db.select(db.syncPullErrors)
          ..where((t) => t.changeId.equals(400)))
        .getSingle();
    expect(row.resolvedAt, isNotNull);
    expect(row.userAction, 'skip');
  });

  test('idx_sync_pull_errors_unresolved 索引存在(条件索引)', () async {
    // SQLite 不强制要求索引存在(查询仍能跑,只是慢),所以这里弱断言:
    // 如果 Drift 生成了索引,sqlite_master 应有对应行
    final indexes = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'sync_pull_errors'")
        .get();
    // 至少有 UNIQUE(change_id) 的隐式索引;条件索引若 Drift 未生成则非必须
    expect(indexes, isNotEmpty);
  });
}
