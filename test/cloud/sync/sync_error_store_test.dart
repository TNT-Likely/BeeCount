// SyncErrorStore 单元测试。
//
// SyncErrorStore 是 pull 路径上 apply 失败 change 的持久化。关键契约:
//   1. 新 change_id → INSERT
//   2. 已存在 change_id → attempt_count += 1(走 update-first 路径,不撞 UNIQUE)
//   3. 并发同 change_id record() → 不抛 UNIQUE constraint(catch + 降级 update)
//   4. markResolved 后 watchUnresolved 不返
//
// 旧实现的 bug:select-then-insert race 时第二次 record 撞 UNIQUE 抛错(已修)。

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';

BeeCountCloudSyncChange _change({
  required int changeId,
  String ledgerId = 'ledger-1',
  String entityType = 'transaction',
  String entitySyncId = 'tx-1',
  String action = 'upsert',
  Map<String, dynamic>? payload,
}) {
  return BeeCountCloudSyncChange(
    changeId: changeId,
    ledgerId: ledgerId,
    entityType: entityType,
    entitySyncId: entitySyncId,
    action: action,
    updatedByDeviceId: 'dev-test',
    updatedAt: '2026-05-24T10:00:00Z',
    payload: payload,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late SyncErrorStore store;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    store = SyncErrorStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('record(): 新增 / 累加 / 并发', () {
    test('新 change_id → INSERT,行可查到', () async {
      await store.record(
        change: _change(changeId: 100),
        error: Exception('test error'),
        stackTrace: StackTrace.current,
      );

      final rows = await store.watchUnresolved().first;
      expect(rows, hasLength(1));
      expect(rows.first.changeId, 100);
      expect(rows.first.entityType, 'transaction');
      expect(rows.first.attemptCount, 1);
      expect(rows.first.errorMessage, contains('test error'));
      expect(rows.first.resolvedAt, isNull);
    });

    test('同 change_id 再次 record → attempt_count = 2,不抛 UNIQUE', () async {
      final ch = _change(changeId: 200);
      await store.record(
        change: ch,
        error: Exception('first'),
        stackTrace: StackTrace.current,
      );
      await store.record(
        change: ch,
        error: Exception('second'),
        stackTrace: StackTrace.current,
      );
      await store.record(
        change: ch,
        error: Exception('third'),
        stackTrace: StackTrace.current,
      );

      final rows = await store.watchUnresolved().first;
      expect(rows, hasLength(1)); // 仍是同一行
      expect(rows.first.attemptCount, 3);
      // last error 替换为最新一次
      expect(rows.first.errorMessage, contains('third'));
    });

    test('并发 record 同 change_id 不抛 UNIQUE(降级 update 兜底)', () async {
      // 模拟"两个 pull 同时跑撞同一条脏 change"的场景。
      // 实际 race 难精确复现,但 N 次并发 record 不抛即可。
      final ch = _change(changeId: 300);
      await Future.wait([
        store.record(
            change: ch, error: Exception('a'), stackTrace: StackTrace.current),
        store.record(
            change: ch, error: Exception('b'), stackTrace: StackTrace.current),
        store.record(
            change: ch, error: Exception('c'), stackTrace: StackTrace.current),
        store.record(
            change: ch, error: Exception('d'), stackTrace: StackTrace.current),
        store.record(
            change: ch, error: Exception('e'), stackTrace: StackTrace.current),
      ]);

      final rows = await store.watchUnresolved().first;
      expect(rows, hasLength(1));
      expect(rows.first.attemptCount, greaterThanOrEqualTo(1));
    });

    test('不同 change_id → 分行', () async {
      for (var i = 0; i < 5; i++) {
        await store.record(
          change: _change(changeId: 400 + i),
          error: Exception('e$i'),
          stackTrace: StackTrace.current,
        );
      }
      final rows = await store.watchUnresolved().first;
      expect(rows, hasLength(5));
      // 按 changeId asc 排序
      for (var i = 0; i < 5; i++) {
        expect(rows[i].changeId, 400 + i);
      }
    });

    test('错误信息字段 errorClass / errorMessage / stackTrace 都被记录', () async {
      try {
        throw FormatException('bad payload field xyz');
      } catch (e, st) {
        await store.record(
          change: _change(changeId: 500),
          error: e,
          stackTrace: st,
        );
      }

      final rows = await store.watchUnresolved().first;
      expect(rows.first.errorClass, 'FormatException');
      expect(rows.first.errorMessage, contains('bad payload field xyz'));
      expect(rows.first.stackTrace, isNotNull);
    });

    test('rawChangeJson 含完整 change 信息(供开发者诊断)', () async {
      await store.record(
        change: _change(
          changeId: 600,
          entitySyncId: 'tx-abc-123',
          payload: {'amount': 12.5, 'type': null},
        ),
        error: Exception('e'),
        stackTrace: StackTrace.current,
      );
      final rows = await store.watchUnresolved().first;
      expect(rows.first.rawChangeJson, contains('tx-abc-123'));
      expect(rows.first.rawChangeJson, contains('12.5'));
    });

    test('ledgerId 空 → ledgerExternalId 写 null(user-global change)', () async {
      await store.record(
        change: _change(changeId: 700, ledgerId: ''),
        error: Exception('e'),
        stackTrace: StackTrace.current,
      );
      final rows = await store.watchUnresolved().first;
      expect(rows.first.ledgerExternalId, isNull);
    });
  });

  group('markResolved()', () {
    test('resolved 后 watchUnresolved 不再返该行', () async {
      await store.record(
        change: _change(changeId: 800),
        error: Exception('e'),
        stackTrace: StackTrace.current,
      );
      expect((await store.watchUnresolved().first), hasLength(1));

      await store.markResolved(800);

      expect((await store.watchUnresolved().first), isEmpty);
    });

    test('markResolved 不存在的 change_id 是 nop', () async {
      await store.markResolved(99999); // 不抛
    });

    test('resolved 的 change 后续再 record → 不会唤醒(仍然 resolved)', () async {
      // server 修了脏数据 + 推新 change → 新 change_id 不同,旧 change_id 保留 resolved。
      await store.record(
        change: _change(changeId: 900),
        error: Exception('e'),
        stackTrace: StackTrace.current,
      );
      await store.markResolved(900);

      // 同 change_id 再次 record(罕见场景:用户跳过后又错误重做)
      await store.record(
        change: _change(changeId: 900),
        error: Exception('e2'),
        stackTrace: StackTrace.current,
      );

      // 行被 update,但 resolvedAt 仍非空 → watchUnresolved 不返
      final rows = await store.watchUnresolved().first;
      expect(rows, isEmpty);
    });
  });
}
