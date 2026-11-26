import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/services/attachment_service.dart';
import '_fakes/fake_beecount_cloud_provider.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String> getApplicationDocumentsPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
}

class _BeforeLinkRepository extends LocalRepository {
  _BeforeLinkRepository(super.db, this.beforeLink);
  final Future<void> Function() beforeLink;
  @override
  Future<int> createAttachment(
      {required int transactionId,
      required String fileName,
      String? originalName,
      int? fileSize,
      int? width,
      int? height,
      int sortOrder = 0,
      String? cloudFileId,
      String? cloudSha256}) async {
    await beforeLink();
    return super.createAttachment(
        transactionId: transactionId,
        fileName: fileName,
        originalName: originalName,
        fileSize: fileSize,
        width: width,
        height: height,
        sortOrder: sortOrder,
        cloudFileId: cloudFileId,
        cloudSha256: cloudSha256);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalRepository repo;
  late ChangeTracker tracker;
  late FakeBeeCountCloudProvider provider;
  late SyncEngine sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    provider = FakeBeeCountCloudProvider();
    sync = SyncEngine(
        db: db, provider: provider, changeTracker: tracker, repo: repo);
    await db.into(db.ledgers).insert(
        LedgersCompanion.insert(name: 'A', syncId: const Value('ledger-a')));
  });
  tearDown(() => db.close());

  void bill(String id, Map<String, dynamic> fields,
      {String ledger = 'ledger-a'}) {
    provider.pushFakeChange(entitySyncId: id, ledgerId: ledger, payload: {
      'type': 'expense',
      'amount': 9,
      'happenedAt': '2026-01-01T00:00:00Z',
      ...fields,
    });
  }

  test(
      'legacy Cloud UTC timestamps with and without an offset refer to the same instant',
      () async {
    bill('naive-time', {'happenedAt': '2026-10-28T12:00:00'});
    bill('explicit-time', {'happenedAt': '2026-10-28T20:00:00+08:00'});
    await sync.pull('1');
    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(2));
    for (final row in rows) {
      expect(row.happenedAt.toUtc(), DateTime.utc(2026, 10, 28, 12));
    }
  });

  test(
      'partial updates preserve a note and tag links, including shared overrides',
      () async {
    bill('tx', {'note': 'keep', 'tags': 'Legacy'});
    await sync.pull('');
    final tx = await db.select(db.transactions).getSingle();
    await db.into(db.transactionTagOverrides).insert(
        TransactionTagOverridesCompanion.insert(
            transactionSyncId: 'tx',
            tagSyncId: 'shared',
            createdAt: DateTime.utc(2026)));
    bill('tx', {'amount': 11});
    await sync.pull('');
    expect((await db.select(db.transactions).getSingle()).note, 'keep');
    expect(
        (await db.select(db.transactionTags).getSingle()).transactionId, tx.id);
    expect((await db.select(db.transactionTagOverrides).getSingle()).tagSyncId,
        'shared');
    bill('tx', {'note': null, 'tagIds': []});
    await sync.pull('');
    expect((await db.select(db.transactions).getSingle()).note, isNull);
    expect(await db.select(db.transactionTags).get(), isEmpty);
    expect(await db.select(db.transactionTagOverrides).get(), isEmpty);
    bill('tx', {
      'tags': ['Replacement']
    });
    await sync.pull('');
    final tag = await db.select(db.transactionTags).getSingle();
    expect(
        (await (db.select(db.tags)..where((row) => row.id.equals(tag.tagId)))
                .getSingle())
            .name,
        'Replacement');
    bill('tx', {'tags': null});
    await sync.pull('');
    expect(await db.select(db.transactionTags).get(), isEmpty);
  });

  test(
      'receipt cleanup checks all committed references, retains rolled-back files, and deletes the final orphan',
      () async {
    final scratch = await Directory.systemTemp.createTemp('receipt-contract-');
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(scratch.path);
    addTearDown(() async {
      PathProviderPlatform.instance = previousPaths;
      await scratch.delete(recursive: true);
    });
    const name = 'same.png';
    final original = File('${scratch.path}/attachments/$name');
    final thumbnail = File('${scratch.path}/attachment_thumbs/same_thumb.jpg');
    for (final file in [original, thumbnail]) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
    }
    Future<void> bothExist() async {
      for (final file in [original, thumbnail]) {
        expect(await file.readAsBytes(), [1, 2, 3]);
      }
    }

    const refs = {
      'attachments': [
        {'fileName': name, 'sortOrder': 0}
      ]
    };
    await db.into(db.ledgers).insert(
        LedgersCompanion.insert(name: 'B', syncId: const Value('ledger-b')));
    bill('one', refs);
    bill('two', refs, ledger: 'ledger-b');
    await sync.pull('');
    bill('one', {'attachments': []});
    await sync.pull('');
    expect(await repo.countAttachmentsByFileName(name), 1);
    await bothExist();
    provider.pushFakeChange(
        entitySyncId: 'two', ledgerId: 'ledger-b', action: 'delete');
    bill('three', refs);
    await sync.pull('');
    expect(await repo.countAttachmentsByFileName(name), 1);
    await bothExist();
    bill('three', {'attachments': []});
    bill('retry', {});
    await db.customStatement(
        "CREATE TRIGGER fail_pull BEFORE INSERT ON transactions WHEN NEW.sync_id='retry' BEGIN SELECT RAISE(ABORT,'fixture rejected'); END");
    // Depending on the caller, a blocked page is returned or signaled as a
    // sync error. Verify the database and files after the attempted page.
    try {
      await sync.pull('');
    } catch (_) {
      expect(await db.select(db.syncPullErrors).get(), isNotEmpty);
    }
    expect(await repo.countAttachmentsByFileName(name), 1);
    await bothExist();
    await db.customStatement('DROP TRIGGER fail_pull');
    await sync.pull('');
    expect(await repo.countAttachmentsByFileName(name), 0);
    expect(await original.exists(), isFalse);
    expect(await thumbnail.exists(), isFalse);
  });

  test(
      'an attachment being linked retains its bytes when pull removes the previous last link',
      () async {
    final scratch = await Directory.systemTemp.createTemp('receipt-race-');
    final paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(scratch.path);
    addTearDown(() async {
      PathProviderPlatform.instance = paths;
      await scratch.delete(recursive: true);
    });
    final bytes = utf8.encode('synthetic original');
    final name = 'sha_${sha256.convert(bytes)}.png';
    final source = File('${scratch.path}/photo.png');
    final original = File('${scratch.path}/attachments/$name');
    await source.writeAsBytes(bytes);
    await original.parent.create(recursive: true);
    await original.writeAsBytes(bytes);
    bill('old', {
      'attachments': [
        {'fileName': name}
      ]
    });
    bill('new', {});
    await sync.pull('');
    final tx = await (db.select(db.transactions)
          ..where((r) => r.syncId.equals('new')))
        .getSingle();
    final racing = _BeforeLinkRepository(db, () async {
      bill('old', {'attachments': []});
      await sync.pull('');
      expect(await original.exists(), isFalse);
    });
    final scope = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(racing)]);
    addTearDown(scope.dispose);
    final linked = await scope.read(attachmentServiceProvider).saveAttachment(
        transactionId: tx.id, sourceFile: source, index: 0, urgent: true);
    expect(linked?.fileName, name);
    expect(await repo.countAttachmentsByFileName(name), 1);
    expect(await original.readAsBytes(), bytes);
  });

  test(
      'valuation and changed category ranks journal stable IDs and roll back on journal failure',
      () async {
    final account = await db.into(db.accounts).insert(AccountsCompanion.insert(
          ledgerId: 1,
          name: 'Asset',
          initialBalance: const Value(1000),
        ));
    final first = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'A', kind: 'expense'));
    final second = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
            name: 'B',
            kind: 'expense',
            sortOrder: const Value(1),
            syncId: const Value('keep-id')));
    final same = await db
        .into(db.categories)
        .insert(CategoriesCompanion.insert(name: 'C', kind: 'expense'));
    await repo.updateAccountValuation(account, 1200);
    final ranks = [
      (id: first, sortOrder: 2),
      (id: first, sortOrder: 1),
      (id: second, sortOrder: 0),
      (id: same, sortOrder: 0)
    ];
    await repo.updateCategorySortOrders(ranks);
    await repo.updateCategorySortOrders(ranks);
    final updates = await tracker.getUnpushedChangesForLedger(0);
    expect(updates, hasLength(3));
    expect(updates.map((change) => change.action).toSet(), {'update'});
    final asset = (await repo.getAccount(account))!;
    final a = (await repo.getCategoryById(first))!;
    expect(asset.initialBalance, 1200);
    expect(asset.updatedAt, isNotNull);
    expect(asset.syncId, isNotEmpty);
    expect(a.syncId, isNotEmpty);
    expect(updates.map((change) => change.entitySyncId).toSet(),
        {asset.syncId, a.syncId, 'keep-id'});
    await db.customStatement(
        "CREATE TRIGGER fail_journal BEFORE INSERT ON local_changes BEGIN SELECT RAISE(ABORT,'fixture rejected'); END");
    await expectLater(
        repo.updateAccountValuation(account, 1300), throwsA(anything));
    await expectLater(
        repo.updateCategorySortOrders([(id: first, sortOrder: 0)]),
        throwsA(anything));
    expect((await repo.getAccount(account))!.initialBalance, 1200);
    expect((await repo.getCategoryById(first))!.sortOrder, 1);
    final local = LocalRepository(db);
    await local.updateAccountValuation(account, -20);
    await local.updateCategorySortOrders([(id: first, sortOrder: 3)]);
    expect((await local.getAccount(account))!.initialBalance, -20);
    expect((await local.getCategoryById(first))!.sortOrder, 3);
    expect(await tracker.getUnpushedChangesForLedger(0), hasLength(3));
  });
}
