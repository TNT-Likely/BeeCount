import 'dart:async';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes/fake_beecount_cloud_provider.dart';

class _ControlledProvider extends FakeBeeCountCloudProvider {
  Future<void> Function()? beforePullReturns;
  int? pageSize;

  @override
  Future<BeeCountCloudPullResult> pullChanges({
    int? since,
    int limit = 1000,
    bool persistCursor = true,
  }) async {
    final result = await super.pullChanges(
      since: since,
      limit: pageSize ?? limit,
      persistCursor: persistCursor,
    );
    final hook = beforePullReturns;
    beforePullReturns = null;
    if (hook != null) await hook();
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late ChangeTracker tracker;
  late LocalRepository repo;
  late _ControlledProvider provider;
  late SyncEngine engine;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    provider = _ControlledProvider();
    engine = SyncEngine(
      db: db,
      provider: provider,
      changeTracker: tracker,
      repo: repo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedCategory({
    String syncId = 'category-1',
    int? parentId,
  }) {
    return db.into(db.categories).insert(CategoriesCompanion.insert(
          name: syncId,
          kind: 'expense',
          icon: const Value('train'),
          syncId: Value(syncId),
          level: Value(parentId == null ? 1 : 2),
          parentId: Value(parentId),
        ));
  }

  Future<Category?> category([String syncId = 'category-1']) {
    return (db.select(db.categories)..where((c) => c.syncId.equals(syncId)))
        .getSingleOrNull();
  }

  void remoteCategory({
    String syncId = 'category-1',
    String icon = 'train',
    String action = 'upsert',
    String? deviceId,
  }) {
    provider.pushFakeChange(
      entityType: 'category',
      entitySyncId: syncId,
      ledgerId: '__user_global__',
      action: action,
      updatedByDeviceId: deviceId,
      payload: {
        'syncId': syncId,
        'name': syncId,
        'kind': 'expense',
        'iconType': 'material',
        'icon': icon,
      },
    );
  }

  Future<void> editIcon(int id) {
    return repo.updateCategoryIcon(
      id,
      iconType: 'material',
      icon: 'vaccines',
    );
  }

  Future<void> expectDeferred({int cursor = 0}) async {
    expect(await engine.appCursor.read(), cursor);
    expect(await engine.pullErrors.watchUnresolved().first, isEmpty);
    expect(await tracker.getUnpushedChanges(), isNotEmpty);
  }

  Future<void> failOutboxWrites() {
    return db.customStatement(
      "CREATE TRIGGER fail_category_outbox BEFORE INSERT ON local_changes "
      "BEGIN SELECT RAISE(ABORT, 'outbox write failed'); END",
    );
  }

  for (final mutation in ['name', 'icon', 'clear custom icon']) {
    test('$mutation and its pending marker are committed atomically', () async {
      final id = await seedCategory();
      await failOutboxWrites();
      final editing = switch (mutation) {
        'name' => repo.updateCategory(id, name: 'Edited'),
        'icon' => editIcon(id),
        _ => repo.clearCategoryCustomIcon(id, materialIcon: 'vaccines'),
      };

      await expectLater(editing, throwsException);
      expect((await category())!.name, 'category-1');
      expect((await category())!.icon, 'train');
      expect(await db.select(db.localChanges).get(), isEmpty);
    });
  }

  for (final isChild in [false, true]) {
    test('${isChild ? 'child' : 'root'} creation and its marker are atomic',
        () async {
      final parentId = isChild ? await seedCategory(syncId: 'parent') : null;
      await failOutboxWrites();
      final creating = isChild
          ? repo.createSubCategory(
              parentId: parentId!,
              name: 'New child',
              kind: 'expense',
              syncId: 'category-1',
            )
          : repo.createCategory(
              name: 'New category',
              kind: 'expense',
              syncId: 'category-1',
            );

      await expectLater(creating, throwsException);
      expect(await category(), isNull);
      if (isChild) expect(await category('parent'), isNotNull);
      expect(await db.select(db.localChanges).get(), isEmpty);
    });
  }

  test('a server reconciliation cannot overwrite an edit made during HTTP',
      () async {
    final id = await seedCategory();
    await tracker.recordPulledFromServer(
      entityType: 'category',
      entityId: id,
      entitySyncId: 'category-1',
      ledgerId: 0,
    );
    remoteCategory();
    final responseReady = Completer<void>();
    final releaseResponse = Completer<void>();
    provider.beforePullReturns = () {
      responseReady.complete();
      return releaseResponse.future;
    };

    final pulling = engine.pull('');
    await responseReady.future;
    await editIcon(id);
    releaseResponse.complete();

    expect(await pulling, 0);
    expect((await category())!.icon, 'vaccines');
    await expectDeferred();

    await engine.pushUserGlobalEntities();
    expect(provider.pushedBatches.single.single['payload'],
        containsPair('icon', 'vaccines'));
    expect(await tracker.getUnpushedChanges(), isEmpty);
    remoteCategory(icon: 'vaccines');

    expect(await engine.pull(''), 2);
    expect((await category())!.icon, 'vaccines');
    expect(await engine.appCursor.read(), 2);
  });

  test('remote category updates also wait for local edits', () async {
    final id = await seedCategory();
    await editIcon(id);
    remoteCategory(deviceId: 'another-phone');

    expect(await engine.pull(''), 0);
    expect((await category())!.icon, 'vaccines');
    await expectDeferred();
  });

  test('remote deletion does not discard an unpushed category edit', () async {
    final id = await seedCategory();
    await editIcon(id);
    remoteCategory(action: 'delete');

    expect(await engine.pull(''), 0);
    expect((await category())!.icon, 'vaccines');
    await expectDeferred();
  });

  test('historical upsert does not resurrect a locally deleted category',
      () async {
    final id = await seedCategory();
    await repo.deleteCategory(id);
    remoteCategory();

    expect(await engine.pull(''), 0);
    expect(await category(), isNull);
    await expectDeferred();
    expect((await tracker.getUnpushedChanges()).single.action, 'delete');

    await engine.pushUserGlobalEntities();
    remoteCategory(action: 'delete');
    expect(await engine.pull(''), 2);
    expect(await category(), isNull);
    expect(await engine.appCursor.read(), 2);
  });

  test('parent deletion waits for unpushed edits to its children', () async {
    final parentId = await seedCategory(syncId: 'parent');
    final childId = await seedCategory(syncId: 'child', parentId: parentId);
    await editIcon(childId);
    remoteCategory(syncId: 'parent', action: 'delete');

    expect(await engine.pull(''), 0);
    expect(await category('parent'), isNotNull);
    expect((await category('child'))!.icon, 'vaccines');
    await expectDeferred();
  });

  test('a deferred category keeps the whole page unapplied', () async {
    final id = await seedCategory();
    await editIcon(id);
    provider.pushFakeChange(
      entityType: 'account',
      entitySyncId: 'account-1',
      payload: {'name': 'Remote account', 'type': 'cash', 'currency': 'CNY'},
    );
    remoteCategory();

    expect(await engine.pull(''), 0);
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.localChanges).get(), hasLength(1));
    expect(engine.pendingCustomIconJobs, isEmpty);
    await expectDeferred();
  });

  test('only the page containing the pending category is deferred', () async {
    final id = await seedCategory();
    await editIcon(id);
    provider.pageSize = 1;
    remoteCategory(syncId: 'unrelated', icon: 'flight');
    remoteCategory();
    remoteCategory(syncId: 'not-fetched');

    expect(await engine.pull(''), 1);
    expect((await category('unrelated'))!.icon, 'flight');
    expect((await category())!.icon, 'vaccines');
    expect(await category('not-fetched'), isNull);
    expect(provider.pullCalls, hasLength(2));
    await expectDeferred(cursor: 1);

    await engine.pushUserGlobalEntities();
    remoteCategory(icon: 'vaccines');
    expect(await engine.pull(''), 3);
    expect((await category())!.icon, 'vaccines');
    expect(await category('not-fetched'), isNotNull);
    expect(await engine.appCursor.read(), 4);
  });

  test('deferred replay persists its retry cursor instead of losing history',
      () async {
    final id = await seedCategory();
    await editIcon(id);
    await engine.appCursor.commit(100);
    remoteCategory();

    expect(await engine.replayAllChanges(), 0);
    await expectDeferred();
    expect((await category())!.icon, 'vaccines');

    await engine.pushUserGlobalEntities();
    remoteCategory(icon: 'vaccines');
    expect(await engine.pull(''), 2);
    expect(provider.pullCalls.last.since, 0);
    expect((await category())!.icon, 'vaccines');
    expect(await engine.appCursor.read(), 2);
  });

  test('pushed changes do not block historical category reconciliation',
      () async {
    final id = await seedCategory();
    await editIcon(id);
    final changes = await tracker.getUnpushedChanges();
    await tracker.markPushed(changes.map((c) => c.id).toList());
    remoteCategory(icon: 'local_hospital');

    expect(await engine.pull(''), 1);
    expect((await category())!.icon, 'local_hospital');
    expect(await engine.appCursor.read(), 1);
  });

  test('own-device events retain the existing skip behavior', () async {
    final id = await seedCategory();
    await editIcon(id);
    remoteCategory(deviceId: 'test-device-id');

    expect(await engine.pull(''), 0);
    expect((await category())!.icon, 'vaccines');
    expect(await engine.appCursor.read(), 1);
    expect(await tracker.getUnpushedChanges(), hasLength(1));
    expect(await engine.pullErrors.watchUnresolved().first, isEmpty);
  });

  test('a skipped category without payload does not defer the page', () async {
    final id = await seedCategory();
    await editIcon(id);
    provider.pushFakeChange(
      entityType: 'category',
      entitySyncId: 'category-1',
    );
    remoteCategory(syncId: 'unrelated');

    expect(await engine.pull(''), 1);
    expect((await category())!.icon, 'vaccines');
    expect(await category('unrelated'), isNotNull);
    expect(await engine.appCursor.read(), 2);
  });

  test('an unpushed different entity with the same sync id does not block',
      () async {
    await seedCategory();
    await tracker.recordUserGlobalChange(
      entityType: 'account',
      entityId: 1,
      entitySyncId: 'category-1',
      action: 'update',
    );
    remoteCategory(icon: 'local_hospital');

    expect(await engine.pull(''), 1);
    expect((await category())!.icon, 'local_hospital');
    expect(await engine.appCursor.read(), 1);
  });
}
