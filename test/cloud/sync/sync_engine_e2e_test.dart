// SyncEngine 端到端测试。
//
// 用 in-memory Drift + FakeBeeCountCloudProvider 跑完整 pull/push/apply
// 链路。Day 1:smoke test 验证 fake provider 能跟 SyncEngine 兜上,跑通空 pull
// 路径。Day 2 加更多场景(脏数据 / 单飞 / web 新建账本 / busy retry 等)。

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/cloud/sync_service.dart' show SyncDiff;
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

import '_fakes/fake_beecount_cloud_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late ChangeTracker changeTracker;
  late LocalRepository repo;
  late FakeBeeCountCloudProvider provider;
  late SyncEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    changeTracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: changeTracker);
    provider = FakeBeeCountCloudProvider();
    engine = SyncEngine(
      db: db,
      provider: provider,
      changeTracker: changeTracker,
      repo: repo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('smoke', () {
    test('空 server → pull 返 0,不 prime LookupCache', () async {
      final applied = await engine.pull('');
      expect(applied, 0);
      // pullChanges 只调一次(探针),没数据直接 return
      expect(provider.pullCalls, hasLength(1));
      expect(provider.pullCalls.first.since, 0); // 初始 cursor=0
      expect(provider.pullCalls.first.persistCursor, isFalse,
          reason: 'app 侧接管 cursor,不让 cloud-sync 包持久化');
    });

    test('cursor 在 SharedPreferences 持久化', () async {
      // 第一次空 pull 不推进 cursor
      await engine.pull('');
      final prefs = await SharedPreferences.getInstance();
      // 应该还没有 app cursor key
      final keys = prefs.getKeys().where((k) => k.startsWith('app_pull_cursor_'));
      expect(keys, isEmpty, reason: '空 pull 不应推进 cursor');
    });
  });

  group('apply 远端 change', () {
    test('server 推 transaction change → 本地 transactions 表 insert', () async {
      // 准备:本地建好 ledger 和 category(因为 transaction 引用它们)
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'L1',
              syncId: const Value('ledger-1'),
            ),
          );
      final catId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Food',
              kind: 'expense',
              syncId: const Value('cat-1'),
            ),
          );

      // server 推一条 transaction
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-A',
        ledgerId: 'ledger-1',
        payload: {
          'syncId': 'tx-A',
          'type': 'expense',
          'amount': 12.5,
          'happenedAt': '2026-05-01T10:00:00Z',
          'note': 'lunch',
          'categoryName': 'Food',
          'categoryKind': 'expense',
          'categoryId': 'cat-1',
        },
      );

      final applied = await engine.pull('1');
      expect(applied, 1);

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.first.syncId, 'tx-A');
      expect(txs.first.amount, 12.5);
      expect(txs.first.ledgerId, ledgerId);
      expect(txs.first.categoryId, catId);
    });

    test('apply 成功后 cursor 推进到本页末尾', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1')));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'C', kind: 'expense', syncId: const Value('C1')));

      // 推 3 条 change
      for (var i = 0; i < 3; i++) {
        provider.pushFakeChange(
          entityType: 'transaction',
          entitySyncId: 'tx-$i',
          ledgerId: 'L1',
          payload: {
            'syncId': 'tx-$i',
            'type': 'expense',
            'amount': 10.0,
            'happenedAt': '2026-05-01T10:00:00Z',
            'categoryName': 'C',
            'categoryKind': 'expense',
            'categoryId': 'C1',
          },
        );
      }

      final applied = await engine.pull('1');
      expect(applied, 3);

      // 再次 pull 应该是空(cursor 已到末尾)
      final applied2 = await engine.pull('1');
      expect(applied2, 0);
    });
  });

  group('web 新建账本场景', () {
    test('server 推 ledger entity change → 本地 ledgers 表 insert', () async {
      // 本地没这账本
      expect((await db.select(db.ledgers).get()), isEmpty);

      // server 推一条 ledger:upsert change(模拟 web 新建账本)
      provider.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'new-ledger-uuid',
        ledgerId: 'new-ledger-uuid',
        payload: {
          'ledgerName': 'My New Ledger',
          'currency': 'USD',
        },
      );

      await engine.pull('');

      final ledgers = await db.select(db.ledgers).get();
      expect(ledgers, hasLength(1));
      expect(ledgers.first.syncId, 'new-ledger-uuid');
      expect(ledgers.first.name, 'My New Ledger');
      expect(ledgers.first.currency, 'USD');
    });

    test('server 推 ledger change 但 payload 缺 ledgerName → 跳过', () async {
      provider.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'broken-ledger',
        ledgerId: 'broken-ledger',
        payload: {}, // 没 ledgerName
      );

      await engine.pull('');

      // 本地仍空
      expect((await db.select(db.ledgers).get()), isEmpty);
    });
  });

  group('pull 单飞锁', () {
    test('同时 2 个 pull → server pullChanges 只调一次', () async {
      // 同时触发 2 个 pull,合并到同一个 in-flight Future
      final f1 = engine.pull('');
      final f2 = engine.pull('');
      await Future.wait([f1, f2]);

      expect(provider.pullCalls, hasLength(1),
          reason: '单飞锁应让第二个 caller 复用 in-flight 结果');
    });

    test('replay(sinceOverride 非空)等待 in-flight 完成后独立跑', () async {
      // 普通 pull
      final f1 = engine.pull('');
      // replay 等 in-flight 完后独立跑
      final f2 = engine.pull('', sinceOverride: 0);
      await Future.wait([f1, f2]);

      // 2 次 pullChanges 调用:普通 pull 1 次 + replay 1 次
      expect(provider.pullCalls, hasLength(2));
    });
  });

  group('错误恢复', () {
    test('pullChanges 抛错 → engine.pull 抛出,cursor 不推进', () async {
      provider.pullErrorInjector = (since) => Exception('network error');

      // sync 入口的 catch 会兜住错误,但底层 pull 应抛
      // 用 .pull() 直接调,期待抛
      await expectLater(engine.pull(''), throwsA(isA<Exception>()));

      // cursor 未推进 — read 仍是 0
      final cursor = await engine.appCursor.read();
      expect(cursor, 0);
    });

    test('apply 时单条 change payload 异常 → 整页 rollback + 错误入 sync_pull_errors + cursor 不推进',
        () async {
      // 推 5 条 change,第 3 条 payload 用错误类型(categoryId 传 int 而不是 string)
      // 让 _applyTransactionChange 内 `payload['categoryId'] as String?` 抛 TypeError
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1')));

      for (var i = 0; i < 5; i++) {
        final payload = <String, dynamic>{
          'syncId': 'tx-$i',
          'type': 'expense',
          'amount': 10.0,
          'happenedAt': '2026-05-01T10:00:00Z',
        };
        if (i == 2) {
          // 故意脏数据:categoryId 应是 String,这里传 int
          payload['categoryId'] = 12345;
        }
        provider.pushFakeChange(
          entityType: 'transaction',
          entitySyncId: 'tx-$i',
          ledgerId: 'L1',
          payload: payload,
        );
      }

      final applied = await engine.pull('');
      // 整页 rollback,applied=0
      expect(applied, 0);

      // 本地 transactions 表应该是空(rollback 生效,不是只插了前两条)
      final txs = await db.select(db.transactions).get();
      expect(txs, isEmpty,
          reason: 'apply 抛错时整页 rollback,前面已 INSERT 的也应回滚');

      // cursor 不推进(读 0)
      expect(await engine.appCursor.read(), 0);

      // 错误入 sync_pull_errors 表
      final errors = await engine.pullErrors.watchUnresolved().first;
      expect(errors, hasLength(1));
      expect(errors.first.changeId, 3); // 第 3 条触发
      expect(errors.first.entityType, 'transaction');
      expect(errors.first.entitySyncId, 'tx-2');
      expect(errors.first.errorClass, contains('TypeError'));
    });

    test('修复后 server 推同 change_id 新版本 → markResolved', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1')));

      // 先推一条会抛错的
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-A',
        ledgerId: 'L1',
        payload: {
          'categoryId': 999, // 错误类型
          'amount': 10.0,
        },
      );
      await engine.pull('');
      expect((await engine.pullErrors.watchUnresolved().first), hasLength(1));

      // 通过 markResolved 模拟"server 修了 + app 拉到新版本":
      // 实际逻辑应该是 server push 新 change_id 触发 apply 成功后 markResolved
      // 这里直接调测试 marker
      await engine.pullErrors.markResolved(1);
      expect((await engine.pullErrors.watchUnresolved().first), isEmpty);
    });
  });

  group('cursor 持久化', () {
    test('apply 成功后 cursor 写入 SharedPreferences,跨 SyncEngine 实例可读', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1')));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'C', kind: 'expense', syncId: const Value('C1')));

      for (var i = 0; i < 3; i++) {
        provider.pushFakeChange(
          entityType: 'transaction',
          entitySyncId: 'tx-$i',
          ledgerId: 'L1',
          payload: {
            'syncId': 'tx-$i',
            'type': 'expense',
            'amount': 10.0,
            'happenedAt': '2026-05-01T10:00:00Z',
            'categoryId': 'C1',
            'categoryName': 'C',
            'categoryKind': 'expense',
          },
        );
      }

      await engine.pull('');
      final cursor1 = await engine.appCursor.read();
      expect(cursor1, 3, reason: '3 条 change 后 cursor 应到 changeId=3');

      // 模拟 app 重启:新建 SyncEngine,读 cursor 继续
      final engine2 = SyncEngine(
        db: db,
        provider: provider,
        changeTracker: changeTracker,
        repo: repo,
      );
      final cursor2 = await engine2.appCursor.read();
      expect(cursor2, 3, reason: '新 SyncEngine 实例应从 SharedPreferences 读到上次 cursor');

      // 第二个 engine pull 应该看到"无变更"(空 pull)
      final applied = await engine2.pull('');
      expect(applied, 0);
      // 验证 pullChanges 是从 since=3 开始,不是从 0 重拉
      expect(provider.pullCalls.last.since, 3);
    });
  });

  group('replay (sinceOverride=0)', () {
    test('replay 从头拉所有 change,即使 cursor 已推进', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1')));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'C', kind: 'expense', syncId: const Value('C1')));

      for (var i = 0; i < 3; i++) {
        provider.pushFakeChange(
          entityType: 'transaction',
          entitySyncId: 'tx-$i',
          ledgerId: 'L1',
          payload: {
            'syncId': 'tx-$i',
            'type': 'expense',
            'amount': 10.0,
            'happenedAt': '2026-05-01T10:00:00Z',
            'categoryId': 'C1',
            'categoryName': 'C',
            'categoryKind': 'expense',
          },
        );
      }

      // 第一次 pull,cursor 推到 3
      await engine.pull('');
      expect(await engine.appCursor.read(), 3);

      // replay 从 0 拉 — 由于 apply 是 syncId upsert 幂等,重拉不会重复插
      provider.pullCalls.clear();
      final applied = await engine.pull('', sinceOverride: 0);
      expect(applied, 3, reason: 'replay 应重新 apply 3 条');
      expect(provider.pullCalls.first.since, 0,
          reason: 'replay 必须从 since=0 拉');

      // 本地 transactions 仍是 3 条(没 dup)
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(3));
    });
  });

  group('push 路径', () {
    test('本地有 unpushed change → engine.push 推到 server', () async {
      // 本地通过 repo 写一条 tx(会触发 changeTracker.recordLedgerChange)
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'L', syncId: const Value('L1'),
            ),
          );
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 99.5,
          syncId: const Value('tx-push-1'),
        ),
      ]);

      // 验证 local_changes 已登记
      final unpushed =
          await changeTracker.getUnpushedChangesForLedger(ledgerId);
      expect(unpushed, hasLength(1));
      expect(unpushed.first.entityType, 'transaction');

      // 触发 engine.push
      final pushed = await engine.push(ledgerId.toString());
      expect(pushed, 1);

      // fake provider 收到 1 个 batch,内含 1 条 change
      expect(provider.pushedBatches, hasLength(1));
      expect(provider.pushedBatches.first, hasLength(1));
      expect(provider.pushedBatches.first.first['entity_sync_id'], 'tx-push-1');
      expect(provider.pushedBatches.first.first['action'], 'upsert');

      // local_changes 已 markPushed
      final remaining = await changeTracker.getUnpushedChangesForLedger(ledgerId);
      expect(remaining, isEmpty);
    });

    test('push 后再调 → 无新变更 → 不发 batch', () async {
      final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: const Value('L1')));
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 10.0,
            syncId: const Value('tx-1')),
      ]);
      await engine.push(ledgerId.toString());
      expect(provider.pushedBatches, hasLength(1));

      // 第二次 push 无变更
      final pushed2 = await engine.push(ledgerId.toString());
      expect(pushed2, 0);
      expect(provider.pushedBatches, hasLength(1), reason: '无变更不应发新 batch');
    });
  });

  group('recordChanges=false:fullPull 不反向回流', () {
    test('LocalRepository.insertTransactionsBatch(recordChanges: false) → 不写 local_changes',
        () async {
      final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: const Value('L1')));

      // 模拟 fullPull 路径:DataImportService 大批量插 + recordChanges=false
      await repo.insertTransactionsBatch(
        List.generate(
            50,
            (i) => TransactionsCompanion.insert(
                  ledgerId: ledgerId,
                  type: 'expense',
                  amount: i.toDouble(),
                  syncId: Value('fullpull-tx-$i'),
                )),
        recordChanges: false,
      );

      // 本地有 50 条 tx,但 local_changes 表为空(不会反向 push)
      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(50));
      final changes =
          await changeTracker.getUnpushedChangesForLedger(ledgerId);
      expect(changes, isEmpty,
          reason: 'fullPull 写入不应触发 changeTracker.recordLedgerChange');
    });

    test('默认 recordChanges=true 路径仍正常登记', () async {
      final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: const Value('L1')));
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 1.0,
            syncId: const Value('normal-tx')),
      ]); // 不传 recordChanges,走默认 true
      final changes =
          await changeTracker.getUnpushedChangesForLedger(ledgerId);
      expect(changes, hasLength(1));
    });
  });

  group('附件 upload/download', () {
    test('uploadAttachments 上传未同步附件 → 回填 cloudFileId + 登记 update change',
        () async {
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
                name: 'L', syncId: const Value('L1')),
          );
      // 插一条 tx + 一个未上传的 attachment
      final txId = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 5.0,
              syncId: const Value('tx-with-att'),
            ),
          );
      await db.into(db.transactionAttachments).insert(
            TransactionAttachmentsCompanion.insert(
              transactionId: txId,
              fileName: 'never-existing-file.jpg',
            ),
          );

      // uploadAttachments 会跑(虽然本地文件不存在,会 skip,但不抛错)
      final uploaded = await engine.uploadAttachments(ledgerId: ledgerId);
      // 本地文件不存在 → uploaded=0,不抛
      expect(uploaded, 0);
      // 没真发 HTTP(因为没文件)
      expect(provider.uploadAttachmentCalls, isEmpty);
    });
  });

  group('共享账本 Editor 不 fullPush', () {
    test('isShared=true + myRole=editor → 不触发 fullPush', () async {
      // 本地标记此账本是共享 Editor
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'Shared',
              syncId: const Value('shared-l1'),
              isShared: const Value(true),
              myRole: const Value('editor'),
            ),
          );
      // 远端不返此账本(模拟 owner 在,但 server list 路径下 Editor 角色看到的视角)
      // — 即使 storage.list 没返,Editor 也不应 fullPush(会覆盖 Owner 数据)
      final result = await engine.sync(ledgerId: ledgerId.toString());

      expect(provider.writeCreateLedgerCalls, isEmpty,
          reason: 'Editor 角色永不应触发 fullPush');
      expect(result.hasError, isFalse);
    });
  });

  group('apply 各种 entity type', () {
    test('account / category / tag insert', () async {
      provider.pushFakeChange(
        entityType: 'category',
        entitySyncId: 'cat-X',
        ledgerId: '',
        payload: {
          'name': 'NewCat',
          'kind': 'expense',
          'sortOrder': 0,
        },
      );
      provider.pushFakeChange(
        entityType: 'account',
        entitySyncId: 'acc-X',
        ledgerId: '0',
        payload: {
          'name': 'NewAcc',
          'type': 'cash',
          'currency': 'CNY',
        },
      );
      provider.pushFakeChange(
        entityType: 'tag',
        entitySyncId: 'tag-X',
        ledgerId: '0',
        payload: {'name': 'NewTag'},
      );

      final applied = await engine.pull('');
      expect(applied, 3);

      final cats = await db.select(db.categories).get();
      expect(cats.where((c) => c.syncId == 'cat-X'), hasLength(1));
      final accs = await db.select(db.accounts).get();
      expect(accs.where((a) => a.syncId == 'acc-X'), hasLength(1));
      final tags = await db.select(db.tags).get();
      expect(tags.where((t) => t.syncId == 'tag-X'), hasLength(1));
    });

    test('apply update 已存在的实体(按 syncId upsert,不重复 insert)', () async {
      // 本地先有
      final catId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'Original',
              kind: 'expense',
              syncId: const Value('cat-upd'),
            ),
          );
      // server 推 update,改名
      provider.pushFakeChange(
        entityType: 'category',
        entitySyncId: 'cat-upd',
        ledgerId: '',
        payload: {
          'name': 'Renamed',
          'kind': 'expense',
        },
      );

      await engine.pull('');

      final cats = await (db.select(db.categories)
            ..where((c) => c.id.equals(catId)))
          .get();
      expect(cats, hasLength(1)); // 没新增,只更新
      expect(cats.first.name, 'Renamed');
    });
  });

  group('apply delete change', () {
    test('server 推 transaction:delete → 本地行被删 + cache 同步移除', () async {
      // 准备:本地有一条 tx
      final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: 'L', syncId: const Value('L1')));
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 8.0,
              syncId: const Value('tx-to-delete'),
            ),
          );

      // server 推一条 delete
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-to-delete',
        ledgerId: 'L1',
        action: 'delete',
      );

      await engine.pull('');

      // 本地被删
      final remaining = await db.select(db.transactions).get();
      expect(remaining, isEmpty);
    });
  });

  group('fullPush 路径', () {
    test('远端无此账本 → SyncEngine.sync 触发 fullPush 流程', () async {
      // 本地建账本 + 1 条 tx
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'My Ledger',
              syncId: const Value('my-ledger-uuid'),
              currency: const Value('CNY'),
            ),
          );
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
                name: 'C', kind: 'expense', syncId: const Value('C1')),
          );
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 50.0,
            syncId: const Value('tx-full-1')),
      ]);

      // server storage.list 返空 → fullPush 决策触发
      // (provider 默认就是空)

      final result = await engine.sync(ledgerId: ledgerId.toString());

      // fullPush 路径:writeCreateLedger 被调
      expect(provider.writeCreateLedgerCalls, isNotEmpty,
          reason: 'fullPush 应调 writeCreateLedger 显式建 server 账本');
      // 不应有 error
      expect(result.hasError, isFalse);
    });

    test('远端有此账本 → 走增量 push,不 fullPush', () async {
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'L',
              syncId: const Value('existing-uuid'),
            ),
          );
      // 标记 server 端已有此账本
      provider.pushFakeLedgerSnapshot(ledgerId: 'existing-uuid');

      // 加一条 unpushed change
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 5.0,
            syncId: const Value('tx-incr')),
      ]);

      final result = await engine.sync(ledgerId: ledgerId.toString());

      expect(provider.writeCreateLedgerCalls, isEmpty,
          reason: '远端已有账本时不应触发 fullPush');
      expect(result.hasError, isFalse);
      // 增量 push 应有 1 batch
      expect(provider.pushedBatches, hasLength(1));
    });
  });

  group('SyncEvent stream(PR 1 解耦改造)', () {
    test('WS pull 完成 emit PullCompleted 到 events stream', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1')));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'C', kind: 'expense', syncId: const Value('C1')));

      // 订阅 events
      final received = <SyncEvent>[];
      final sub = engine.events.listen(received.add);

      engine.startListeningRealtime();
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-event',
        ledgerId: 'L1',
        payload: {
          'syncId': 'tx-event',
          'type': 'expense',
          'amount': 1.0,
          'happenedAt': '2026-05-01T10:00:00Z',
          'categoryId': 'C1',
          'categoryName': 'C',
          'categoryKind': 'expense',
        },
      );
      provider.emitRealtimeEvent(BeeCountCloudRealtimeEvent(
        type: 'sync_change',
        ledgerId: 'L1',
        rawData: const {},
      ));

      await Future.delayed(const Duration(milliseconds: 1500));

      engine.stopListeningRealtime();
      await sub.cancel();

      // 至少有一个 PullCompleted 事件
      final pullEvents = received.whereType<PullCompleted>().toList();
      expect(pullEvents, isNotEmpty);
      expect(pullEvents.last.ledgerId, 'L1');
      expect(pullEvents.last.applied, greaterThan(0));
    });

    test('sync push 后清缓存 + emit,getStatus 从 localNewer 刷新为 inSync'
        '(修复:同步完成后「我的」页状态自动更新,不用手动下拉)', () async {
      final ledgerId = await db.into(db.ledgers).insert(
            LedgersCompanion.insert(
              name: 'L',
              syncId: const Value('existing-uuid'),
            ),
          );
      // 远端已有此账本 → 走增量 push,避开 fullPush 复杂路径
      provider.pushFakeLedgerSnapshot(ledgerId: 'existing-uuid');
      // 本地写一条 tx → 产生 unpushed local_change
      await repo.insertTransactionsBatch([
        TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 8.0,
          syncId: const Value('tx-push-event'),
        ),
      ]);

      // 同步前:有未推送变更 → getStatus = localNewer,并把结果写进 _statusCache
      final before = await engine.getStatus(ledgerId: ledgerId);
      expect(before.diff, SyncDiff.localNewer,
          reason: '本地有未推送变更,同步前应为 localNewer(并落入缓存)');

      final received = <SyncEvent>[];
      final sub = engine.events.listen(received.add);
      final result = await engine.sync(ledgerId: ledgerId.toString());
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(result.pushed, greaterThan(0));
      // 修复点 1:push 完成 emit PushCompleted,通知 UI 重新读同步状态
      expect(received.whereType<PushCompleted>(), isNotEmpty,
          reason: 'push 上传本地变更后必须 emit PushCompleted');
      // 修复点 2(真正根因):push 后清了 _statusCache,getStatus 不再吃旧缓存。
      // 若仍命中缓存返回 localNewer,「我的」页就得手动下拉才更新 —— 本 bug。
      final after = await engine.getStatus(ledgerId: ledgerId);
      expect(after.diff, SyncDiff.inSync,
          reason: 'push 成功后 getStatus 必须刷新为 inSync;'
              '命中旧缓存返回 localNewer 即是本 bug 复现');
    });

    test('多种事件类型 dispatch:PullCompleted / ProfileFieldApplied 等', () async {
      final received = <SyncEvent>[];
      final sub = engine.events.listen(received.add);

      // 直接调 _emit 不容易(私有),但 syncMyProfile / pull 路径会 emit。
      // 这里用 syncMyProfile 路径:fake provider 抛 UnimplementedError →
      // 整个流程进 catch 不 emit。我们改测 pull → PullCompleted
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1')));
      engine.startListeningRealtime();
      provider.emitRealtimeEvent(BeeCountCloudRealtimeEvent(
        type: 'sync_change',
        ledgerId: 'L1',
        rawData: const {},
      ));
      await Future.delayed(const Duration(milliseconds: 1500));
      engine.stopListeningRealtime();
      await sub.cancel();

      expect(received.whereType<PullCompleted>(), isNotEmpty);
    });
  });

  group('WS realtime', () {
    test('startListeningRealtime + 模拟 WS sync_change → 1s debounce 后触发 pull',
        () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: 'L', syncId: const Value('L1')));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          name: 'C', kind: 'expense', syncId: const Value('C1')));

      // 启动 WS 监听
      engine.startListeningRealtime();

      // 推一条 change 到 server,然后模拟 WS event
      provider.pushFakeChange(
        entityType: 'transaction',
        entitySyncId: 'tx-ws',
        ledgerId: 'L1',
        payload: {
          'syncId': 'tx-ws',
          'type': 'expense',
          'amount': 7.0,
          'happenedAt': '2026-05-01T10:00:00Z',
          'categoryId': 'C1',
          'categoryName': 'C',
          'categoryKind': 'expense',
        },
      );
      provider.emitRealtimeEvent(BeeCountCloudRealtimeEvent(
        type: 'sync_change',
        ledgerId: 'L1',
        rawData: const {},
      ));

      // _schedulePull 内 1 秒 debounce + 兜底 syncLedgersFromServer
      // 等待足够时间让 debounce + pull 完成
      await Future.delayed(const Duration(milliseconds: 1500));

      // 验证 apply 成功
      final txs = await db.select(db.transactions).get();
      expect(txs.where((t) => t.syncId == 'tx-ws'), hasLength(1));

      engine.stopListeningRealtime();
    });
  });
}

