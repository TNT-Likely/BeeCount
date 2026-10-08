import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import '../cloud/sync/_fakes/fake_beecount_cloud_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalRepository repo;
  late FakeBeeCountCloudProvider provider;
  late SyncEngine engine;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    final tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    provider = FakeBeeCountCloudProvider();
    engine = SyncEngine(
        db: db, provider: provider, changeTracker: tracker, repo: repo);
  });
  tearDown(() async => db.close());

  Future<Category> pullChild(Map<String, dynamic> fields) async {
    provider.pushFakeChange(
        entityType: 'category',
        entitySyncId: 'child',
        ledgerId: '__user_global__',
        payload: {
          'syncId': 'child',
          'name': '早餐',
          'kind': 'expense',
          'level': 2,
          ...fields
        });
    await engine.pull('');
    return (db.select(db.categories)..where((c) => c.syncId.equals('child')))
        .getSingle();
  }

  test('稳定父 ID 优先于过期名称', () async {
    final parent = await repo.createCategory(
        name: '伙食', kind: 'expense', syncId: 'parent');
    await repo.createCategory(
        name: '餐饮', kind: 'expense', syncId: 'replacement');
    final child =
        await pullChild({'parentSyncId': 'parent', 'parentName': '餐饮'});
    expect(child.parentId, parent);
  });

  test('旧协议只带名称时按同类型父级关联', () async {
    final parent = await repo.createCategory(
        name: '餐饮', kind: 'expense', syncId: 'parent');
    await repo.createCategory(name: '餐饮', kind: 'income', syncId: 'income');
    expect((await pullChild({'parentName': '餐饮'})).parentId, parent);
  });

  test('稳定 ID 缺失时不挂到同名的替代分类', () async {
    await repo.createCategory(
        name: '餐饮', kind: 'expense', syncId: 'replacement');
    expect(
        (await pullChild({'parentSyncId': 'deleted', 'parentName': '餐饮'}))
            .parentId,
        isNull);
  });

  test('稳定 ID 指向不同类型时不按名字重新关联', () async {
    await repo.createCategory(name: '餐饮', kind: 'income', syncId: 'income');
    await repo.createCategory(name: '餐饮', kind: 'expense', syncId: 'parent');
    expect(
        (await pullChild({'parentSyncId': 'income', 'parentName': '餐饮'}))
            .parentId,
        isNull);
  });

  test('部分更新省略父字段时保留已有关联', () async {
    final parent = await repo.createCategory(
        name: '餐饮', kind: 'expense', syncId: 'parent');
    await repo.createCategory(
        name: '早餐',
        kind: 'expense',
        level: 2,
        parentId: parent,
        syncId: 'child');
    provider.pushFakeChange(
        entityType: 'category',
        entitySyncId: 'child',
        ledgerId: '__user_global__',
        payload: {'name': '新早餐'});
    await engine.pull('');
    final child = await (db.select(db.categories)
          ..where((c) => c.syncId.equals('child')))
        .getSingle();
    expect(child.name, '新早餐');
    expect(child.level, 2);
    expect(child.parentId, parent);
  });
}
