// LookupCache 单元测试。
//
// LookupCache 是 pull 路径上 `syncId → 本地 int id` 的全表缓存,prime 一次
// 后所有 apply 查询走内存。改动这个文件务必跑这个测试 — N+1 SELECT 是
// 之前 10k 数据卡 20 分钟的核心瓶颈,cache 是核心修复。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LookupCache cache;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    cache = LookupCache();
  });

  tearDown(() async {
    await db.close();
  });

  group('prime + lookup', () {
    test('prime 后能查到 ledger / category / account / tag', () async {
      // 准备数据
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Test Ledger',
              syncId: const Value('ledger-sync-1'),
            ),
          );
      final categoryId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Test Cat',
              kind: 'expense',
              syncId: const Value('cat-sync-1'),
            ),
          );
      final accountId = await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              ledgerId: ledgerId,
              name: 'Test Acc',
              syncId: const Value('acc-sync-1'),
            ),
          );
      final tagId = await db.into(db.tags).insert(
            TagsCompanion.insert(
              name: 'Test Tag',
              syncId: const Value('tag-sync-1'),
            ),
          );

      await cache.prime(db);

      expect(cache.ledgerId('ledger-sync-1'), ledgerId);
      expect(cache.categoryId('cat-sync-1'), categoryId);
      expect(cache.accountId('acc-sync-1'), accountId);
      expect(cache.tagId('tag-sync-1'), tagId);
    });

    test('prime 后能查到 transaction(含 createdByUserId)', () async {
      final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: const Value('L1')));
      final txId = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 10.0,
              syncId: const Value('tx-sync-1'),
              createdByUserId: const Value('user-A'),
            ),
          );

      await cache.prime(db);

      final entry = cache.transaction('tx-sync-1');
      expect(entry, isNotNull);
      expect(entry!.id, txId);
      expect(entry.createdByUserId, 'user-A');
    });

    test('null / 空 syncId 一律返 null', () async {
      await cache.prime(db);
      expect(cache.ledgerId(null), isNull);
      expect(cache.ledgerId(''), isNull);
      expect(cache.categoryId(null), isNull);
      expect(cache.transaction(null), isNull);
    });

    test('miss 返 null(cache 内没有的 syncId)', () async {
      await cache.prime(db);
      expect(cache.ledgerId('nonexistent'), isNull);
      expect(cache.transaction('nonexistent'), isNull);
    });

    test('syncId 为 null 的行不入缓存', () async {
      // seed 行没 syncId
      await db.into(db.ledgers).insert(
            LedgersCompanion.insert(name: 'No SyncId'),
          );
      await cache.prime(db);
      expect(cache.ledgerId(null), isNull);
      // 也没办法用 name 查到,cache 只按 syncId 索引
    });
  });

  group('putXxx 写回', () {
    test('putLedger / putCategory / putAccount / putTag 立即可查', () async {
      await cache.prime(db); // 空 prime
      cache.putLedger('new-l', 100);
      cache.putCategory('new-c', 200);
      cache.putAccount('new-a', 300);
      cache.putTag('new-t', 400);

      expect(cache.ledgerId('new-l'), 100);
      expect(cache.categoryId('new-c'), 200);
      expect(cache.accountId('new-a'), 300);
      expect(cache.tagId('new-t'), 400);
    });

    test('putTransaction 包含 createdByUserId', () async {
      await cache.prime(db);
      cache.putTransaction('tx-new', 500, 'user-X');

      final entry = cache.transaction('tx-new');
      expect(entry, isNotNull);
      expect(entry!.id, 500);
      expect(entry.createdByUserId, 'user-X');

      cache.putTransaction('tx-no-creator', 501, null);
      expect(cache.transaction('tx-no-creator')!.createdByUserId, isNull);
    });

    test('putXxx 同 syncId 后写会覆盖前一次', () async {
      await cache.prime(db);
      cache.putLedger('l', 1);
      cache.putLedger('l', 2);
      expect(cache.ledgerId('l'), 2);
    });
  });

  group('removeTransaction(apply delete 路径用)', () {
    test('remove 后 cache 不再命中', () async {
      await cache.prime(db);
      cache.putTransaction('tx-del', 9, null);
      expect(cache.transaction('tx-del'), isNotNull);

      cache.removeTransaction('tx-del');
      expect(cache.transaction('tx-del'), isNull);
    });

    test('remove 不存在的 syncId 是 nop', () async {
      await cache.prime(db);
      cache.removeTransaction('never-existed'); // 不抛
    });
  });

  group('性能基准(10k transactions)', () {
    test('prime 10000 条 transactions 耗时 < 2000ms (debug)', () async {
      // 准备 10k tx + 1 ledger
      final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: const Value('L1')));
      final batch = <TransactionsCompanion>[];
      for (var i = 0; i < 10000; i++) {
        batch.add(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 10.0 + i,
          syncId: Value('tx-$i'),
          createdByUserId:
              i.isEven ? const Value('user-A') : const Value.absent(),
        ));
      }
      await db.batch((b) => b.insertAll(db.transactions, batch));

      final sw = Stopwatch()..start();
      await cache.prime(db);
      sw.stop();
      // 输出基准 — 改 LookupCache 后看是否退化
      // ignore: avoid_print
      print(
          '[Benchmark] LookupCache.prime 10k tx: ${sw.elapsedMilliseconds}ms');

      // assert 不退化太多。Debug 模式应该 < 2s。Release 应 < 200ms。
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason: 'prime 退化超过 2s,可能引入了 N+1');
      expect(cache.transaction('tx-9999'), isNotNull);
      expect(cache.transaction('tx-9999')!.createdByUserId, isNull); // 9999 是奇数
      expect(cache.transaction('tx-0')!.createdByUserId, 'user-A');
    });

    test('10000 次 cache lookup 耗时可忽略(单测内 < 100ms)', () async {
      // 准备数据
      final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: const Value('L1')));
      final batch = <TransactionsCompanion>[];
      for (var i = 0; i < 10000; i++) {
        batch.add(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 10.0,
          syncId: Value('tx-$i'),
        ));
      }
      await db.batch((b) => b.insertAll(db.transactions, batch));
      await cache.prime(db);

      // 10000 次查询
      final sw = Stopwatch()..start();
      int hits = 0;
      for (var i = 0; i < 10000; i++) {
        if (cache.transaction('tx-$i') != null) hits++;
      }
      sw.stop();
      // ignore: avoid_print
      print(
          '[Benchmark] LookupCache 10k lookup: ${sw.elapsedMilliseconds}ms ($hits hits)');

      expect(hits, 10000);
      expect(sw.elapsedMilliseconds, lessThan(100),
          reason: '10k 次 Map.get 应该几 ms 内完成');
    });
  });
}
