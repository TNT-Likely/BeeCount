import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/pages/transaction/search/bindings/transaction_batch.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalRepository repo;
  late TransactionBatchBinding binding;
  late int expense, transfer, outside, categoryId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db, changeTracker: ChangeTracker(db));
    binding = TransactionBatchBinding(repo);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,sync_id) VALUES(1,'生活','CNY','ledger-1'),(2,'旅行','USD','ledger-2')");
    categoryId = await repo.createCategory(name: '餐饮', kind: 'expense');
    final from =
        await repo.createAccount(ledgerId: 1, name: '美元现金', currency: 'USD');
    final to =
        await repo.createAccount(ledgerId: 1, name: '美元银行卡', currency: 'USD');
    expense = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        currencyCode: 'USD',
        nativeAmount: 86.4,
        categorySyncIdOverride: 'old-category',
        accountSyncIdOverride: 'from-owner',
        happenedAt: DateTime(2026, 9, 5, 12, 34, 56),
        note: '旧备注',
        excludeFromStats: true,
        excludeFromBudget: true);
    transfer = await repo.addTransaction(
        ledgerId: 1,
        type: 'transfer',
        amount: 30,
        currencyCode: 'USD',
        nativeAmount: 219,
        accountId: from,
        toAccountId: to,
        accountSyncIdOverride: 'from-owner',
        toAccountSyncIdOverride: 'to-owner',
        happenedAt: DateTime(2026, 9, 6, 1, 2, 3),
        note: '转账原备注');
    outside = await repo.addTransaction(
        ledgerId: 2,
        type: 'income',
        amount: 90,
        happenedAt: DateTime(2026, 9, 7));
    final tag = await repo.createTag(name: '旅行', color: '#219c9c');
    await repo.updateTransactionTags(transactionId: expense, tagIds: [tag]);
    await repo.createAttachment(
        transactionId: expense, fileName: 'synthetic.png', fileSize: 40);
  });
  tearDown(() async => db.close());

  Future<Map<String, Object?>> snapshot() async => {
        'transactions': (await db.select(db.transactions).get())
            .map((r) => r.toJson())
            .toList(),
        'tags': (await db.select(db.transactionTags).get())
            .map((r) => r.toJson())
            .toList(),
        'attachments': (await db.select(db.transactionAttachments).get())
            .map((r) => r.toJson())
            .toList(),
        'changes': (await db.select(db.localChanges).get())
            .map((r) => r.toJson())
            .toList(),
      };

  test('批量备注只改备注，保留外币快照、共享引用、转入账户及标签附件，并对 ID 去重', () async {
    final original = await snapshot();
    expect(
        await binding.replaceNotes(
            ledgerId: 1,
            transactionIds: [expense, expense, transfer],
            note: ' 新备注 '),
        2);
    for (final id in [expense, transfer]) {
      final old = (original['transactions'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((r) => r['id'] == id);
      final expected = {...old, 'note': '新备注'};
      expect((await repo.getTransactionById(id))!.toJson(), expected);
    }
    final after = await snapshot();
    expect(after['tags'], original['tags']);
    expect(after['attachments'], original['attachments']);
    expect((await repo.getTransactionById(outside))!.note, isNull);
    final added = (await db.select(db.localChanges).get())
        .skip((original['changes'] as List).length)
        .toList();
    expect(added.map((r) => (r.entityId, r.action, r.ledgerId)),
        [(expense, 'update', 1), (transfer, 'update', 1)]);
  });

  test('显式清空备注，不会清空分类或共享账户引用', () async {
    final before = (await repo.getTransactionById(expense))!.toJson();
    await binding.replaceNotes(
        ledgerId: 1, transactionIds: [expense], note: '  ');
    expect((await repo.getTransactionById(expense))!.toJson(),
        {...before, 'note': null});
  });

  test('个人分类替换只改变分类，清除原分类 override 并保留其余字段', () async {
    final target = (await repo.getCategoryById(categoryId))!;
    final before = (await repo.getTransactionById(expense))!.toJson();
    expect(
        await binding.changeCategory(
            ledgerId: 1, transactionIds: [expense], category: target),
        1);
    expect((await repo.getTransactionById(expense))!.toJson(),
        {...before, 'categoryId': categoryId, 'categorySyncIdOverride': null});
  });

  test('共享二级分类写入 syncId，synthetic ID 不进入主表外键', () async {
    await db.customStatement(
        "UPDATE ledgers SET is_shared=1,my_role='editor' WHERE id=1");
    await db.customStatement(
        "INSERT INTO shared_ledger_categories(ledger_sync_id,sync_id,name,kind,level,updated_at) VALUES('ledger-1','owner-child','共享午餐','expense',2,1792713600)");
    final available = await db.filterCategoriesForLedger(
        await repo.getAllCategories(), await db.loadLedgerPickerContext(1),
        kind: 'expense', topLevelOnly: false);
    final target = available.single;
    expect(target.id, lessThan(0));
    final before = (await repo.getTransactionById(expense))!.toJson();
    await binding.changeCategory(
        ledgerId: 1, transactionIds: [expense], category: target);
    expect((await repo.getTransactionById(expense))!.toJson(), {
      ...before,
      'categoryId': null,
      'categorySyncIdOverride': 'owner-child'
    });
  });

  test('越界账本、失效身份和转账分类变更在写入前拒绝', () async {
    final before = await snapshot();
    await expectLater(
        binding.replaceNotes(
            ledgerId: 1, transactionIds: [expense, outside], note: '错误'),
        throwsStateError);
    await expectLater(
        binding.replaceNotes(
            ledgerId: 1, transactionIds: [expense, 99999], note: '错误'),
        throwsStateError);
    await expectLater(
        binding.changeCategory(
            ledgerId: 1,
            transactionIds: [expense, transfer],
            category: (await repo.getCategoryById(categoryId))!),
        throwsStateError);
    expect(await snapshot(), before);
  });

  test('第二笔写入失败时整批回滚，连同第一笔的同步队列保持原样', () async {
    final before = await snapshot();
    await db.customStatement(
        "CREATE TRIGGER fail_second BEFORE UPDATE OF note ON transactions WHEN OLD.id=$transfer BEGIN SELECT RAISE(ABORT,'synthetic batch failure'); END");
    await expectLater(
        binding.replaceNotes(
            ledgerId: 1, transactionIds: [expense, transfer], note: '不能部分成功'),
        throwsA(isA<Exception>()));
    expect(await snapshot(), before);
  });

  test('旧账户字段调用不修改备注和分类；空批次不生成同步写入', () async {
    final before = (await repo.getTransactionById(expense))!.toJson();
    await repo.updateTransactionFields(
        id: expense,
        accountId: const d.Value<int?>(null),
        accountSyncIdOverride: 'new-owner-account',
        writeAccountSyncIdOverride: true);
    expect((await repo.getTransactionById(expense))!.toJson(),
        {...before, 'accountSyncIdOverride': 'new-owner-account'});
    final after = await snapshot();
    expect(
        await binding.replaceNotes(ledgerId: 1, transactionIds: [], note: '忽略'),
        0);
    expect(await snapshot(), after);
  });
  test('批量标签仅替换关联，个人标签与清空均保留财务字段和附件', () async {
    final before = await snapshot();
    final tag = await repo.createTag(name: '新标签', color: '#112233');
    await binding.replaceTags(
        ledgerId: 1, transactionIds: [expense, transfer], tagIds: [tag, tag]);
    expect((await repo.getTagsForTransaction(expense)).single.id, tag);
    expect((await repo.getTagsForTransaction(transfer)).single.id, tag);
    expect((await snapshot())['transactions'], before['transactions']);
    expect((await snapshot())['attachments'], before['attachments']);
    final changes = (await db.select(db.localChanges).get())
        .skip((before['changes'] as List).length)
        .where((change) => change.entityType == 'transaction')
        .toList();
    expect(changes.map((c) => c.entityId), [expense, transfer]);
    await binding
        .replaceTags(ledgerId: 1, transactionIds: [expense], tagIds: []);
    expect(await repo.getTagsForTransaction(expense), isEmpty);
  });
  test('共享标签使用当前账本镜像，清空同时清理 override，拒绝越界标签', () async {
    await db.customStatement(
        "UPDATE ledgers SET is_shared=1,my_role='editor' WHERE id=1");
    await db.customStatement(
        "INSERT INTO shared_ledger_tags(ledger_sync_id,sync_id,name,color,updated_at) VALUES('ledger-1','owner-tag','共享旅行','#112233',1792713600),('ledger-2','other-tag','其他账本','#445566',1792713600)");
    final before = (await repo.getTransactionById(expense))!.toJson();
    final id = syntheticIdForSyncId('owner-tag');
    await binding
        .replaceTags(ledgerId: 1, transactionIds: [expense], tagIds: [id]);
    expect(
        (await repo.getTagsForTransaction(expense)).single.syncId, 'owner-tag');
    expect(await db.select(db.transactionTags).get(), isEmpty);
    expect((await repo.getTransactionById(expense))!.toJson(), before);
    final unchanged = await snapshot();
    await expectLater(
        binding.replaceTags(
            ledgerId: 1,
            transactionIds: [expense],
            tagIds: [syntheticIdForSyncId('other-tag')]),
        throwsStateError);
    expect(await snapshot(), unchanged);
    await binding
        .replaceTags(ledgerId: 1, transactionIds: [expense], tagIds: []);
    expect(await db.select(db.transactionTagOverrides).get(), isEmpty);
  });
  test('批量标签第二笔失败时全部关联与同步队列回滚', () async {
    final tag = await repo.createTag(name: '回滚标签');
    await db.customStatement(
        "CREATE TRIGGER fail_batch_tags BEFORE INSERT ON transaction_tags WHEN NEW.transaction_id=$transfer BEGIN SELECT RAISE(ABORT,'reject second row'); END");
    final before = await snapshot();
    await expectLater(
        binding.replaceTags(
            ledgerId: 1, transactionIds: [expense, transfer], tagIds: [tag]),
        throwsA(isA<Exception>()));
    expect(await snapshot(), before);
    await expectLater(
        binding.replaceTags(
            ledgerId: 1, transactionIds: [expense, outside], tagIds: [tag]),
        throwsStateError);
    expect(await snapshot(), before);
  });
}
