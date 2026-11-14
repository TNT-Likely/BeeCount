import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/pages/tag/manage/bindings/tag_library_data.dart';
import 'package:beecount/services/data/tag_seed_service.dart';
import 'package:beecount/services/export/config_export_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TagLibraryTestRepository extends LocalRepository {
  TagLibraryTestRepository(super.db);
  bool failBatch = false;
  @override
  Future<void> batchInsertTags(List<TagsCompanion> rows) async {
    if (failBatch) throw StateError('Synthetic tag import failure');
    await super.batchInsertTags(rows);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late TagLibraryTestRepository repo;
  late TagLibraryData data;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = TagLibraryTestRepository(db);
    data = TagLibraryData(repo);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'日常生活','CNY')");
  });
  tearDown(() async => db.close());
  const incoming =
      'tags:\n  items:\n    - name: Imported\n      color: "#219c9c"\n';
  test('分享只含标签，不继承默认账本/AI/账户或应用配置选项', () async {
    await repo.createTag(name: '旅行', color: '#219c9c');
    final yaml = await data.export(1),
        info = ConfigExportService.detectContent(yaml);
    expect(info.hasTags, isTrue);
    expect(info.hasLedgers, isFalse);
    expect(info.hasAi, isFalse);
    expect(info.hasAppSettings, isFalse);
    expect(info.hasAccounts, isFalse);
    expect(info.hasCategories, isFalse);
    expect(info.hasBudgets, isFalse);
    expect(info.hasRecurringTransactions, isFalse);
  });
  test('覆盖导入插入失败传播错误，原未使用标签和关联整体回滚', () async {
    final unused = await repo.createTag(name: '未使用', color: '#123456'),
        used = await repo.createTag(name: '已使用');
    final tx = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        happenedAt: DateTime(2026, 10, 24));
    await repo.addTagToTransaction(transactionId: tx, tagId: used);
    final before = await repo.getAllTags();
    repo.failBatch = true;
    await expectLater(data.importYaml(incoming, ledgerId: 1, overwrite: true),
        throwsStateError);
    expect(await repo.getAllTags(), before);
    expect(await repo.getTagById(unused), isNotNull);
    expect((await repo.getTagsForTransaction(tx)).single.id, used);
    expect((await repo.getTransactionsByLedger(1)), hasLength(1));
    repo.failBatch = false;
    await data.importYaml(incoming, ledgerId: 1, overwrite: true);
    expect(await repo.getTagById(unused), isNull);
    expect(await repo.getTagById(used), isNotNull);
    expect(await repo.getTagByName('Imported'), isNotNull);
  });
  test('清理前重新核对引用，确认期间变成已使用的标签保留', () async {
    final id = await repo.createTag(name: '候选'),
        candidates = await data.unused();
    expect(candidates.single.id, id);
    final tx = await repo.addTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 3,
        happenedAt: DateTime(2026, 10, 24));
    await repo.addTagToTransaction(transactionId: tx, tagId: id);
    expect(await data.clearUnused(candidates.map((t) => t.id)), 0);
    expect((await repo.getTagsForTransaction(tx)).single.id, id);
  });
  test('合并按原大小写规则去重，混合文件的其他账本不写入', () async {
    final id = await repo.createTag(name: 'IMPORTED', color: '#123456');
    const mixed =
        'ledgers:\n  items:\n    - name: 不应导入\n      currency: USD\ntags:\n  items:\n    - name: Imported\n      color: "#ffffff"\n    - name: New\n      color: "#ff0000"\n';
    await data.importYaml(mixed, ledgerId: 1, overwrite: false);
    expect((await repo.getAllLedgers()), hasLength(1));
    expect((await repo.getTagById(id))!.color, '#123456');
    expect((await repo.getAllTags()), hasLength(2));
  });
  test('默认生成保留已有同名色值，重复执行不新增', () async {
    final l = AppLocalizationsZh(), defaults = TagSeedService.getDefaultTags(l);
    final id =
        await repo.createTag(name: defaults.first.name, color: '#123456');
    expect(await data.generate(l), defaults.length - 1);
    expect(await data.generate(l), 0);
    expect((await repo.getTagById(id))!.color, '#123456');
    expect((await repo.getAllLedgers()), hasLength(1));
  });
}
