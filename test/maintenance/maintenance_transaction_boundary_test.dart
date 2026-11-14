import 'dart:io';
import 'package:beecount/data/db.dart';
import 'package:beecount/services/maintenance/orphan_cleaner.dart';
import 'package:beecount/services/maintenance/orphan_record.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late Directory owned;
  late OrphanCleaner cleaner;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    owned =
        await Directory.systemTemp.createTemp('beecount-r103-boundary-owned-');
    cleaner = OrphanCleaner(db: db);
    await File('${owned.path}/keep.jpg').writeAsBytes([1, 2, 3]);
    await File('${owned.path}/dangling.jpg').writeAsBytes([4, 5]);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'Owned one','CNY'),(2,'Owned two','USD')");
    await db.customStatement(
        "INSERT INTO budgets(id,ledger_id,type,amount) VALUES(1,999,'total',10),(2,999,'total',20),(3,999,'total',30),(4,2,'total',40)");
    await db.customStatement(
        "INSERT INTO transactions(id,ledger_id,type,amount,happened_at,sync_id,note,currency_code,native_amount,exclude_from_stats) VALUES(10,1,'expense',12,1792454400,'tx-10','owned private one','USD',86.4,1),(20,2,'income',18,1792454400,'tx-20','owned private two','USD',18,0)");
    await db.customStatement(
        "INSERT INTO transaction_attachments(id,transaction_id,file_name) VALUES(10,10,'keep.jpg'),(20,20,'keep.jpg'),(30,999,'dangling.jpg')");
    await db.customStatement("INSERT INTO tags(id,name) VALUES(1,'Owned tag')");
    await db.customStatement(
        "INSERT INTO transaction_tags(transaction_id,tag_id) VALUES(10,1),(20,1)");
  });
  tearDown(() async {
    await db.close();
    await owned.delete(recursive: true);
  });
  List<OrphanRecord> budgets() => [
        for (final id in [1, 2, 3])
          OrphanRecord(
              type: OrphanType.budgetMissingLedger,
              title: 'Owned orphan $id',
              subtitle: 'Owned fixture',
              localId: id)
      ];
  Future<List<int>> budgetIds() async =>
      (await db.select(db.budgets).get()).map((x) => x.id).toList();
  Future<Map<String, List<Map<String, dynamic>>>> protected() async {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final table in [
      'ledgers',
      'transactions',
      'transaction_tags',
      'transaction_attachments',
      'tags'
    ]) {
      result[table] =
          (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
              .map((x) => x.data)
              .toList();
    }
    return result;
  }

  Future<void> trigger(int id, String action) => db.customStatement(
      "CREATE TRIGGER owned_failure BEFORE DELETE ON budgets WHEN OLD.id=$id BEGIN SELECT RAISE($action,'owned failure'); END");
  test('SQLite整体回滚后不继续在事务外删除后续记录', () async {
    final before = await protected();
    await trigger(2, 'ROLLBACK');
    final result = await cleaner.clean(budgets());
    expect(result.successCount, 0);
    expect(result.failures, hasLength(3));
    expect(await budgetIds(), [1, 2, 3, 4]);
    expect(await protected(), before);
  });
  test('普通ABORT保留原逐条部分成功且故障后仅重试失败项', () async {
    final before = await protected();
    await trigger(2, 'ABORT');
    final result = await cleaner.clean(budgets());
    expect(result.successCount, 2);
    expect(result.failures.single.record.localId, 2);
    expect(await budgetIds(), [2, 4]);
    expect(await protected(), before);
    await db.customStatement('DROP TRIGGER owned_failure');
    final retry =
        await cleaner.clean(result.failures.map((x) => x.record).toList());
    expect(retry.successCount, 1);
    expect(retry.failures, isEmpty);
    expect(await budgetIds(), [4]);
    expect(await protected(), before);
  });
  for (final id in [1, 3]) {
    test('首或末条全局ROLLBACK回退所有DB成功计数 $id', () async {
      await trigger(id, 'ROLLBACK');
      final result = await cleaner.clean(budgets());
      expect(result.successCount, 0);
      expect(result.failures, hasLength(3));
      expect(await budgetIds(), [1, 2, 3, 4]);
    });
  }
  test('DB整体回滚不伪装同步行和文件可回滚，保留独立边界', () async {
    final before = await protected();
    await trigger(2, 'ROLLBACK');
    await db.customStatement(
        "INSERT INTO local_changes(id,entity_type,entity_id,entity_sync_id,ledger_id,action) VALUES(50,'transaction',999,'missing-sync',1,'update')");
    final orphan = File('${owned.path}/orphan.jpg');
    await orphan.writeAsBytes([8, 9]);
    final result = await cleaner.clean([
      ...budgets(),
      const OrphanRecord(
          type: OrphanType.localChangeMissingEntity,
          title: 'Owned sync orphan',
          subtitle: 'Owned',
          localId: 50),
      OrphanRecord(
          type: OrphanType.fileOrphanAttachment,
          title: 'Owned file orphan',
          subtitle: 'Owned',
          filePath: orphan.path)
    ]);
    expect(result.successCount, 2);
    expect(result.failures, hasLength(3));
    expect(await budgetIds(), [1, 2, 3, 4]);
    expect(await db.select(db.localChanges).get(), isEmpty);
    expect(await orphan.exists(), false);
    expect(await File('${owned.path}/keep.jpg').readAsBytes(), [1, 2, 3]);
    expect(await protected(), before);
    await db.customStatement('DROP TRIGGER owned_failure');
    expect(
        (await cleaner.clean(result.failures.map((x) => x.record).toList()))
            .successCount,
        3);
    expect(await budgetIds(), [4]);
  });
  test('文件项失败不回滚已成功DB，未选附件关系和另一账本不变', () async {
    final before = await protected();
    final result = await cleaner.clean([
      ...budgets(),
      const OrphanRecord(
          type: OrphanType.fileOrphanAttachment,
          title: 'Invalid owned file',
          subtitle: 'Owned')
    ]);
    expect(result.successCount, 3);
    expect(result.failures, hasLength(1));
    expect(await budgetIds(), [4]);
    expect(await protected(), before);
    expect(await File('${owned.path}/keep.jpg').readAsBytes(), [1, 2, 3]);
  });
  test('附件孤儿行ABORT独立失败，重试只删关系不删物理文件', () async {
    await db.customStatement(
        "CREATE TRIGGER owned_attachment_failure BEFORE DELETE ON transaction_attachments WHEN OLD.id=30 BEGIN SELECT RAISE(ABORT,'owned attachment failure'); END");
    const record = OrphanRecord(
        type: OrphanType.attachmentMissingTx,
        title: 'Owned dangling attachment',
        subtitle: 'Owned',
        localId: 30);
    final result = await cleaner.clean([budgets().first, record]);
    expect(result.successCount, 1);
    expect(result.failures, hasLength(1));
    expect((await db.select(db.transactionAttachments).get()).map((x) => x.id),
        [10, 20, 30]);
    await db.customStatement('DROP TRIGGER owned_attachment_failure');
    expect((await cleaner.clean([record])).successCount, 1);
    expect((await db.select(db.transactionAttachments).get()).map((x) => x.id),
        [10, 20]);
    expect(await File('${owned.path}/dangling.jpg').exists(), true);
    expect(await File('${owned.path}/keep.jpg').readAsBytes(), [1, 2, 3]);
  });
  test('附件语句触发全局ROLLBACK时原关系全部回滚且后续预算不裸删', () async {
    final before = await protected();
    await db.customStatement(
        "CREATE TRIGGER owned_attachment_failure BEFORE DELETE ON transaction_attachments WHEN OLD.id=30 BEGIN SELECT RAISE(ROLLBACK,'owned rollback'); END");
    const record = OrphanRecord(
        type: OrphanType.attachmentMissingTx,
        title: 'Owned dangling attachment',
        subtitle: 'Owned',
        localId: 30);
    final result =
        await cleaner.clean([budgets().first, record, budgets().last]);
    expect(result.successCount, 0);
    expect(result.failures, hasLength(3));
    expect(await budgetIds(), [1, 2, 3, 4]);
    expect(await protected(), before);
    expect(await File('${owned.path}/keep.jpg').readAsBytes(), [1, 2, 3]);
  });
}
