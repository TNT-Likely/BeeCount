import 'dart:async';
import 'dart:convert';

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

/// The fixed Cloud filters this device's events before returning /sync/pull.
/// A since=0 replay therefore cannot recover its successful latest writes.
class _InviteProvider extends FakeBeeCountCloudProvider {
  CloudStorageService? storageOverride;
  @override
  CloudStorageService get storage => storageOverride ?? super.storage;
  @override
  Future<BeeCountCloudPullResult> pullChanges({
    int? since,
    int limit = 1000,
    bool persistCursor = true,
  }) async {
    final page = await super
        .pullChanges(since: since, limit: limit, persistCursor: persistCursor);
    final changes = page.changes
        .where((c) => c.updatedByDeviceId != 'test-device-id')
        .toList();
    return BeeCountCloudPullResult(
        changes: changes,
        serverCursor: changes.isEmpty ? (since ?? 0) : changes.last.changeId,
        hasMore: page.hasMore);
  }

  @override
  Future<BeeCountCloudSharedResources> fetchSharedResources({
    required String ledgerId,
  }) async =>
      const BeeCountCloudSharedResources(
          ownerUserId: 'other-owner', categories: [], accounts: [], tags: []);
}

class _GatedStorage extends FakeBeeCountCloudStorageService {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<String?> download({required String path}) async {
    entered.complete();
    await release.future;
    return super.download(path: path);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late SyncEngine engine;
  late _InviteProvider provider;
  late ChangeTracker tracker;
  late int ownLedger;
  late List<Map<String, Object?>> originalTransactions;
  late List<Map<String, Object?>> originalTags;
  late List<Map<String, Object?>> originalAttachments;

  Future<List<Map<String, Object?>>> rows(String table,
          [String suffix = 'ORDER BY id']) async =>
      (await db.customSelect('SELECT * FROM $table $suffix').get())
          .map((r) => r.data)
          .toList();

  Map<String, dynamic> targetSnapshot() => {
        'ledgerSyncId': 'new-shared',
        'ledgerName': 'New shared',
        'currency': 'CNY',
        'monthStartDay': 8,
        'count': 1,
        'items': <Map<String, dynamic>>[
          {
            'syncId': 'target-latest',
            'type': 'expense',
            'amount': 0.31,
            'happenedAt': '2026-10-25T12:00:00Z',
            'note': 'current projected value',
            'excludeFromStats': false,
            'excludeFromBudget': false,
          }
        ],
        // Must never import the owner's user-global primary resources.
        'categories': [
          {
            'syncId': 'foreign-primary',
            'name': 'Do not import',
            'kind': 'expense'
          }
        ],
        'accounts': [],
        'tags': [],
        'budgets': [],
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    provider = _InviteProvider();
    engine = SyncEngine(
        db: db,
        provider: provider,
        changeTracker: tracker,
        repo: LocalRepository(db, changeTracker: tracker));
    ownLedger = await db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: 'Original eight',
        syncId: const Value('own-eight'),
        monthStartDay: const Value(8)));
    final tags = <int>[];
    for (var i = 0; i < 3; i++) {
      tags.add(await db.into(db.tags).insert(TagsCompanion.insert(
          name: 'Original $i', syncId: Value('own-tag-$i'))));
    }
    for (var i = 0; i < 71; i++) {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ownLedger,
          type: 'expense',
          amount: i == 0 ? -2 : (i == 1 ? 0 : 0.37),
          happenedAt: Value(DateTime.utc(2026, 10, 25, 12, 49)),
          note: Value(i == 70 ? 'already pushed latest edit' : 'original $i'),
          currencyCode: Value(i.isEven ? null : 'USD'),
          nativeAmount: Value(i.isEven ? null : 85.19999999999999),
          excludeFromStats: Value(i % 3 == 0),
          excludeFromBudget: Value(i % 5 == 0),
          syncId: Value('original-$i')));
    }
    final last = (await db.select(db.transactions).get()).last;
    for (final tag in tags) {
      await db.into(db.transactionTags).insert(
          TransactionTagsCompanion.insert(transactionId: last.id, tagId: tag));
    }
    for (var i = 0; i < 2; i++) {
      await db.into(db.transactionAttachments).insert(
          TransactionAttachmentsCompanion.insert(
              transactionId: last.id,
              fileName: 'original-$i.png',
              sortOrder: const Value(0)));
    }
    originalTransactions = await rows('transactions');
    originalTags = await rows('transaction_tags');
    originalAttachments = await rows('transaction_attachments');
    provider.pushFakeLedger(
        ledgerId: 'own-eight', ledgerName: 'Original eight', monthStartDay: 8);
    provider.pushFakeLedger(
        ledgerId: 'new-shared',
        ledgerName: 'New shared',
        role: 'editor',
        isShared: true,
        memberCount: 2,
        monthStartDay: 8);
    provider.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'own-eight',
        ledgerId: 'own-eight',
        payload: {'ledgerName': 'Original eight', 'monthStartDay': 1});
    provider.pushFakeChange(
        entitySyncId: 'original-70',
        ledgerId: 'own-eight',
        payload: {
          'type': 'expense',
          'amount': 0.37,
          'happenedAt': '2026-10-25T12:49:53Z',
          'note': 'old foreign value',
          'tagIds': ['own-tag-0', 'own-tag-1', 'own-tag-2'],
        });
    provider.pushFakeChange(
        entityType: 'ledger',
        entitySyncId: 'own-eight',
        ledgerId: 'own-eight',
        updatedByDeviceId: 'test-device-id',
        payload: {'ledgerName': 'Original eight', 'monthStartDay': 8});
    provider.pushFakeChange(
        entitySyncId: 'original-70',
        ledgerId: 'own-eight',
        updatedByDeviceId: 'test-device-id',
        payload: {
          'type': 'expense',
          'amount': 0.37,
          'happenedAt': '2026-10-25T12:49:00Z',
          'note': 'already pushed latest edit',
        });
    await provider.storage
        .upload(path: 'new-shared', data: jsonEncode(targetSnapshot()));
    await engine.appCursor.commit(500);
  });

  tearDown(() async {
    engine.stopListeningRealtime();
    await db.close();
  });

  test('native accept preserves an unrelated restored ledger day8', () async {
    await engine.onInviteAccepted('new-shared');
    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ownLedger)))
        .getSingle();
    expect(ledger.monthStartDay, 8);
  });

  test('native accept preserves all71 transactions, tags and attachments',
      () async {
    await engine.onInviteAccepted('new-shared');
    expect(await rows('transactions', 'WHERE ledger_id=$ownLedger ORDER BY id'),
        originalTransactions);
    expect(await rows('transaction_tags'), originalTags);
    expect(await rows('transaction_attachments'), originalAttachments);
  });

  Future<int> registerTarget() async {
    await engine.syncLedgersFromServer();
    return (await (db.select(db.ledgers)
              ..where((l) => l.syncId.equals('new-shared')))
            .getSingle())
        .id;
  }

  Future<void> snapshot(Map<String, dynamic> value) =>
      provider.storage.upload(path: 'new-shared', data: jsonEncode(value));

  test('WS self joined uses only target full and leaves global cursor500',
      () async {
    final done = engine.events
        .where((e) => e is PullCompleted && e.ledgerId == 'new-shared')
        .first;
    engine.startListeningRealtime();
    provider.emitRealtimeEvent(const BeeCountCloudRealtimeEvent(
        type: 'member_change',
        ledgerId: 'new-shared',
        rawData: {'changeType': 'joined', 'userId': 'test-user-id'}));
    await done.timeout(const Duration(seconds: 5));
    expect(await engine.appCursor.read(), 500);
    expect(provider.pullCalls, isEmpty);
    expect(await rows('transactions', 'WHERE ledger_id=$ownLedger ORDER BY id'),
        originalTransactions);
    expect((await db.select(db.transactions).get()).last.note,
        'current projected value');
    expect((await db.select(db.transactions).get()).last.nativeAmount, isNull);
    expect(await db.select(db.categories).get(), isEmpty,
        reason:
            'formal full owner resources must not enter user primary tables');
  });

  test('same-device target latest full, signed zero and legacy NULL are exact',
      () async {
    final id = await registerTarget();
    final value = targetSnapshot();
    value['items'] = [
      {
        ...(value['items'] as List).single as Map<String, dynamic>,
        'amount': -2.0,
        'nativeAmount': -14.2,
        'currencyCode': 'USD'
      },
      {
        'syncId': 'zero-null',
        'type': 'income',
        'amount': 0.0,
        'happenedAt': '2026-10-25T12:49:00Z',
        'excludeFromStats': true,
        'excludeFromBudget': false
      }
    ];
    value['count'] = 2;
    await snapshot(value);
    provider.pushFakeChange(
        entitySyncId: 'target-latest',
        ledgerId: 'new-shared',
        updatedByDeviceId: 'test-device-id',
        payload: {'amount': 999, 'note': 'history must not be read'});
    expect(await engine.hydrateLedgerFromServer('new-shared'), 2);
    final target = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(id)))
        .get();
    expect(target.first.amount, -2);
    expect(target.first.nativeAmount, -14.2);
    expect(target.first.currencyCode, 'USD');
    expect(target.last.amount, 0);
    expect(target.last.nativeAmount, isNull);
    expect(target.last.currencyCode, isNull);
    expect(target.last.excludeFromStats, true);
    expect(await engine.appCursor.read(), 500);
    expect(provider.pullCalls, isEmpty);
    await engine.hydrateLedgerFromServer('new-shared');
    expect(
        await (db.select(db.transactions)..where((t) => t.ledgerId.equals(id)))
            .get(),
        target);
    expect(await rows('transactions', 'WHERE ledger_id=$ownLedger ORDER BY id'),
        originalTransactions);
  });

  test('full false flags and omitted tags attachments clear only target values',
      () async {
    final ledger = await registerTarget();
    final tx = await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
            ledgerId: ledger,
            type: 'expense',
            amount: 9,
            syncId: const Value('target-latest'),
            nativeAmount: const Value(99),
            currencyCode: const Value('USD'),
            excludeFromStats: const Value(true),
            excludeFromBudget: const Value(true)));
    final tag = (await db.select(db.tags).get()).first;
    await db.into(db.transactionTags).insert(
        TransactionTagsCompanion.insert(transactionId: tx, tagId: tag.id));
    await db.into(db.transactionAttachments).insert(
        TransactionAttachmentsCompanion.insert(
            transactionId: tx, fileName: 'target-stale.png'));
    await engine.hydrateLedgerFromServer('new-shared');
    final row = await (db.select(db.transactions)
          ..where((t) => t.id.equals(tx)))
        .getSingle();
    expect(row.excludeFromStats, false);
    expect(row.excludeFromBudget, false);
    expect(row.nativeAmount, isNull);
    expect(row.currencyCode, isNull);
    expect(await rows('transaction_tags', 'WHERE transaction_id=$tx'), isEmpty);
    expect(await rows('transaction_attachments', 'WHERE transaction_id=$tx'),
        isEmpty);
    expect(
        await rows('transaction_tags', 'WHERE transaction_id!=$tx ORDER BY id'),
        originalTags);
    expect(
        await rows(
            'transaction_attachments', 'WHERE transaction_id!=$tx ORDER BY id'),
        originalAttachments);
  });

  test(
      'pending target refuses before any overwrite and keeps pending/error/cursor',
      () async {
    final id = await registerTarget();
    await tracker.recordLedgerChange(
        entityType: 'transaction',
        entityId: 900,
        entitySyncId: 'pending-local',
        ledgerId: id,
        action: 'upsert');
    final before = await rows('local_changes');
    await expectLater(engine.hydrateLedgerFromServer('new-shared'),
        throwsA(isA<StateError>()));
    expect(await rows('local_changes'), before);
    expect(await db.select(db.syncPullErrors).get(), isEmpty);
    expect(await engine.appCursor.read(), 500);
    expect(await rows('transactions'), originalTransactions);
  });

  final invalidItems = <String, void Function(Map<String, dynamic>)>{
    'missing type': (m) => m.remove('type'),
    'missing amount': (m) => m.remove('amount'),
    'string amount': (m) => m['amount'] = '0.31',
    'missing time': (m) => m.remove('happenedAt'),
    'invalid time': (m) => m['happenedAt'] = 'not-a-time',
    'missing flag': (m) => m.remove('excludeFromStats'),
    'nonbool flag': (m) => m['excludeFromBudget'] = 0,
    'missing identity': (m) => m.remove('syncId'),
    'wrong scope': (m) => m['ledgerSyncId'] = 'own-eight',
    'invalid native': (m) => m['nativeAmount'] = 'NaN',
    'unknown currency': (m) => m['currencyCode'] = '???',
    'name-only tags': (m) => m['tags'] = 'must not create primary tag',
    'unknown category': (m) => m['categoryId'] = 'not-shared-category',
    'unknown tag': (m) => m['tagIds'] = ['not-shared-tag'],
  };
  for (final entry in invalidItems.entries) {
    test('reject ${entry.key} before applying an earlier valid item', () async {
      await registerTarget();
      final value = targetSnapshot();
      final invalid =
          Map<String, dynamic>.from((value['items'] as List).single as Map);
      invalid['syncId'] = 'second-invalid';
      entry.value(invalid);
      value['items'] = <Map<String, dynamic>>[
        Map<String, dynamic>.from((value['items'] as List).single as Map),
        invalid,
      ];
      value['count'] = 2;
      await snapshot(value);
      await expectLater(engine.hydrateLedgerFromServer('new-shared'),
          throwsA(isA<FormatException>()));
      expect(await rows('transactions'), originalTransactions);
      expect(await rows('transaction_tags'), originalTags);
      expect(await rows('transaction_attachments'), originalAttachments);
      expect(await engine.appCursor.read(), 500);
      expect(await db.select(db.tags).get(), hasLength(3));
    });
  }

  test('cross-ledger tx syncId rejects rather than updating original row',
      () async {
    await registerTarget();
    final value = targetSnapshot();
    ((value['items'] as List).single as Map)['syncId'] = 'original-70';
    await snapshot(value);
    await expectLater(engine.hydrateLedgerFromServer('new-shared'),
        throwsA(isA<FormatException>()));
    expect(await rows('transactions'), originalTransactions);
    expect(await rows('transaction_tags'), originalTags);
  });

  test('budget target scope and cross-ledger identity are checked atomically',
      () async {
    await registerTarget();
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
        ledgerId: ownLedger, amount: 50, syncId: const Value('own-budget')));
    final before = await rows('budgets');
    final value = targetSnapshot();
    value['budgets'] = [
      {
        'syncId': 'own-budget',
        'ledgerSyncId': 'new-shared',
        'amount': 0.0,
        'enabled': false
      }
    ];
    await snapshot(value);
    await expectLater(engine.hydrateLedgerFromServer('new-shared'),
        throwsA(isA<FormatException>()));
    expect(await rows('budgets'), before);
    expect(await rows('transactions'), originalTransactions);
  });

  test(
      'target budget false and zero survive without importing global resources',
      () async {
    final target = await registerTarget();
    final value = targetSnapshot();
    value['budgets'] = [
      {
        'syncId': 'target-budget',
        'ledgerSyncId': 'new-shared',
        'amount': 0.0,
        'enabled': false,
        'period': 'monthly',
        'startDay': 8
      }
    ];
    await snapshot(value);
    expect(await engine.hydrateLedgerFromServer('new-shared'), 2);
    final budget = await db.select(db.budgets).getSingle();
    expect(budget.ledgerId, target);
    expect(budget.amount, 0);
    expect(budget.enabled, false);
    expect(budget.startDay, 8);
    expect(await db.select(db.categories).get(), isEmpty);
  });

  test('formal full hydrates all501 rows without ordinary pull paging/cursor',
      () async {
    final target = await registerTarget();
    final value = targetSnapshot();
    final item = (value['items'] as List).single as Map<String, dynamic>;
    value['items'] = [
      for (var i = 0; i < 501; i++) {...item, 'syncId': 'page-$i'}
    ];
    value['count'] = 501;
    await snapshot(value);
    expect(await engine.hydrateLedgerFromServer('new-shared'), 501);
    expect(
        await (db.select(db.transactions)
              ..where((t) => t.ledgerId.equals(target)))
            .get(),
        hasLength(501));
    expect(provider.pullCalls, isEmpty);
    expect(await engine.appCursor.read(), 500);
    expect(await rows('transactions', 'WHERE ledger_id=$ownLedger ORDER BY id'),
        originalTransactions);
  });

  test('ordinary delta missing native still uses original insert default',
      () async {
    await engine.applyRemoteChange(const BeeCountCloudSyncChange(
        changeId: 10,
        ledgerId: 'own-eight',
        entityType: 'transaction',
        entitySyncId: 'delta-default',
        action: 'upsert',
        payload: {
          'type': 'expense',
          'amount': 9.0,
          'happenedAt': '2026-10-25T12:00:00Z'
        }));
    final tx = await (db.select(db.transactions)
          ..where((t) => t.syncId.equals('delta-default')))
        .getSingle();
    expect(tx.nativeAmount, 9);
  });

  test('purge removes only target tx tag overrides including null-sync safety',
      () async {
    final target = await registerTarget();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: target,
        type: 'expense',
        amount: 0.31,
        syncId: const Value('target-leaving')));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: target, type: 'expense', amount: 0));
    for (final tx in ['target-leaving', 'original-70', '']) {
      await db.into(db.transactionTagOverrides).insert(
          TransactionTagOverridesCompanion.insert(
              transactionSyncId: tx,
              tagSyncId: 'same-global-tag',
              createdAt: DateTime.utc(2026, 10, 25)));
    }
    final done = engine.events
        .where((e) => e is PullCompleted && e.ledgerId == 'new-shared')
        .first;
    engine.startListeningRealtime();
    provider.emitRealtimeEvent(const BeeCountCloudRealtimeEvent(
        type: 'member_change',
        ledgerId: 'new-shared',
        rawData: {'changeType': 'removed', 'userId': 'test-user-id'}));
    await done.timeout(const Duration(seconds: 5));
    final overrides = await db.select(db.transactionTagOverrides).get();
    expect(
        overrides.map((r) => r.transactionSyncId).toSet(), {'original-70', ''});
    expect(await rows('transactions'), originalTransactions);
    expect(
        await (db.select(db.ledgers)..where((l) => l.id.equals(target))).get(),
        isEmpty);
  });

  for (final broken in [
    'missing scope',
    'wrong scope',
    'missing items',
    'missing budgets',
    'count mismatch',
    'duplicate tx'
  ]) {
    test('formal header rejects $broken without writes or cursor change',
        () async {
      await registerTarget();
      final v = targetSnapshot();
      switch (broken) {
        case 'missing scope':
          v.remove('ledgerSyncId');
          break;
        case 'wrong scope':
          v['ledgerSyncId'] = 'own-eight';
          break;
        case 'missing items':
          v.remove('items');
          break;
        case 'missing budgets':
          v.remove('budgets');
          break;
        case 'count mismatch':
          v['count'] = 2;
          break;
        case 'duplicate tx':
          v['items'] = [...(v['items'] as List), ...(v['items'] as List)];
          v['count'] = 2;
          break;
      }
      await snapshot(v);
      await expectLater(engine.hydrateLedgerFromServer('new-shared'),
          throwsA(isA<FormatException>()));
      expect(await rows('transactions'), originalTransactions);
      expect(await engine.appCursor.read(), 500);
    });
  }

  test('pending created during snapshot wait is rechecked before transaction',
      () async {
    final target = await registerTarget();
    final gate = _GatedStorage();
    await gate.upload(path: 'new-shared', data: jsonEncode(targetSnapshot()));
    provider.storageOverride = gate;
    final call = engine.hydrateLedgerFromServer('new-shared');
    final assertion = expectLater(call, throwsA(isA<StateError>()));
    await gate.entered.future;
    await tracker.recordLedgerChange(
        entityType: 'transaction',
        entityId: 900,
        entitySyncId: 'local-after-http',
        ledgerId: target,
        action: 'upsert');
    final pending = await rows('local_changes');
    gate.release.complete();
    await assertion;
    expect(await rows('transactions'), originalTransactions);
    expect(await rows('local_changes'), pending);
    expect(await engine.appCursor.read(), 500);
  });

  test('ordinary pull waits for hydration then still reads its original cursor',
      () async {
    await registerTarget();
    final gate = _GatedStorage();
    await gate.upload(path: 'new-shared', data: jsonEncode(targetSnapshot()));
    provider.storageOverride = gate;
    final call = engine.hydrateLedgerFromServer('new-shared');
    await gate.entered.future;
    final pull = engine.pull('own-eight');
    expect(provider.pullCalls, isEmpty);
    gate.release.complete();
    expect(await call, 1);
    expect(await pull, 0);
    expect(provider.pullCalls.single.since, 500);
    expect(await engine.appCursor.read(), 500);
  });

  test('native pending refusal happens before read-ledgers metadata overwrite',
      () async {
    final target = await registerTarget();
    await (db.update(db.ledgers)..where((l) => l.id.equals(target)))
        .write(const LedgersCompanion(monthStartDay: Value(9)));
    await tracker.recordLedgerChange(
        entityType: 'ledger',
        entityId: target,
        entitySyncId: 'new-shared',
        ledgerId: target,
        action: 'upsert');
    final before = await rows('ledgers');
    await engine.onInviteAccepted('new-shared');
    expect(await rows('ledgers'), before);
    expect(await rows('transactions'), originalTransactions);
  });

  test(
      'shared stable refs beat same-name primary resources and preserve ordered files',
      () async {
    final target = await registerTarget();
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        name: 'Same category',
        kind: 'expense',
        syncId: const Value('own-category')));
    await db.into(db.accounts).insert(AccountsCompanion.insert(
        ledgerId: ownLedger,
        name: 'Same account',
        syncId: const Value('own-account')));
    await db.into(db.sharedLedgerCategories).insert(
        SharedLedgerCategoriesCompanion.insert(
            ledgerSyncId: 'new-shared',
            syncId: 'shared-category',
            name: 'Same category',
            kind: 'expense',
            updatedAt: DateTime.utc(2026, 10, 25)));
    await db.into(db.sharedLedgerAccounts).insert(
        SharedLedgerAccountsCompanion.insert(
            ledgerSyncId: 'new-shared',
            syncId: 'shared-account',
            name: 'Same account',
            updatedAt: DateTime.utc(2026, 10, 25)));
    await db.into(db.sharedLedgerTags).insert(SharedLedgerTagsCompanion.insert(
        ledgerSyncId: 'new-shared',
        syncId: 'shared-tag',
        name: 'Shared tag',
        updatedAt: DateTime.utc(2026, 10, 25)));
    final globals = {
      for (final table in ['categories', 'accounts', 'tags'])
        table: await rows(table)
    };
    final v = targetSnapshot();
    final item = (v['items'] as List).single as Map;
    item.addAll(<String, dynamic>{
      'categoryId': 'shared-category',
      'categoryName': 'Same category',
      'accountId': 'shared-account',
      'accountName': 'Same account',
      'tagIds': ['shared-tag'],
      'attachments': [
        {
          'fileName': 'first.png',
          'sortOrder': 0,
          'cloudFileId': 'file-one',
          'cloudSha256': 'a' * 64
        },
        {
          'fileName': 'second.png',
          'sortOrder': 1,
          'cloudFileId': 'file-two',
          'cloudSha256': 'b' * 64
        }
      ]
    });
    await snapshot(v);
    await engine.hydrateLedgerFromServer('new-shared');
    final row = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(target)))
        .getSingle();
    expect(row.categoryId, isNull);
    expect(row.categorySyncIdOverride, 'shared-category');
    expect(row.accountId, isNull);
    expect(row.accountSyncIdOverride, 'shared-account');
    final tags = await db.select(db.transactionTagOverrides).get();
    expect(tags.single.transactionSyncId, 'target-latest');
    expect(tags.single.tagSyncId, 'shared-tag');
    final files = await (db.select(db.transactionAttachments)
          ..where((a) => a.transactionId.equals(row.id)))
        .get();
    expect(files.map((a) => a.sortOrder), [0, 1]);
    expect(files.map((a) => a.cloudFileId), ['file-one', 'file-two']);
    for (final table in globals.keys) {
      expect(await rows(table), globals[table]);
    }
    expect(
        await rows('transaction_attachments',
            'WHERE transaction_id!=${row.id} ORDER BY id'),
        originalAttachments);
  });

  test(
      'purge target with only NULL syncId leaves unrelated blank override untouched',
      () async {
    final target = await registerTarget();
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: target, type: 'expense', amount: 0));
    await db.into(db.transactionTagOverrides).insert(
        TransactionTagOverridesCompanion.insert(
            transactionSyncId: '',
            tagSyncId: 'same-global-tag',
            createdAt: DateTime.utc(2026, 10, 25)));
    final before = await db.select(db.transactionTagOverrides).get();
    final done = engine.events
        .where((e) => e is PullCompleted && e.ledgerId == 'new-shared')
        .first;
    engine.startListeningRealtime();
    provider.emitRealtimeEvent(const BeeCountCloudRealtimeEvent(
        type: 'member_change',
        ledgerId: 'new-shared',
        rawData: {'changeType': 'removed', 'userId': 'test-user-id'}));
    await done.timeout(const Duration(seconds: 5));
    expect(await db.select(db.transactionTagOverrides).get(), before);
    expect(await rows('transactions'), originalTransactions);
  });

  test(
      'target legacy attachment sort ties preserve original array order and IDs',
      () async {
    final target = await registerTarget();
    final v = targetSnapshot();
    final item = (v['items'] as List).single as Map<String, dynamic>;
    item['attachments'] = [
      for (var i = 0; i < 3; i++)
        <String, dynamic>{
          'fileName': 'legacy-$i.png',
          'sortOrder': 0,
          'cloudFileId': 'legacy-file-$i',
          'cloudSha256': ['a', 'b', 'c'][i] * 64
        }
    ];
    await snapshot(v);
    await engine.hydrateLedgerFromServer('new-shared');
    final tx = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(target)))
        .getSingle();
    final first = await rows(
        'transaction_attachments', 'WHERE transaction_id=${tx.id} ORDER BY id');
    expect(first.map((r) => r['file_name']),
        ['legacy-0.png', 'legacy-1.png', 'legacy-2.png']);
    expect(first.map((r) => r['sort_order']), [0, 0, 0]);
    await engine.hydrateLedgerFromServer('new-shared');
    expect(
        await rows('transaction_attachments',
            'WHERE transaction_id=${tx.id} ORDER BY id'),
        first);
    expect(
        await rows('transaction_attachments',
            'WHERE transaction_id!=${tx.id} ORDER BY id'),
        originalAttachments);
  });

  test(
      'fresh target hydration replaces only its inherited orphan override before insert',
      () async {
    await registerTarget();
    await db.into(db.sharedLedgerTags).insert(SharedLedgerTagsCompanion.insert(
        ledgerSyncId: 'new-shared',
        syncId: 'owner-tag',
        name: 'Owner tag',
        updatedAt: DateTime.utc(2026, 10, 25)));
    for (final id in ['target-latest', 'original-70']) {
      await db.into(db.transactionTagOverrides).insert(
          TransactionTagOverridesCompanion.insert(
              transactionSyncId: id,
              tagSyncId: 'owner-tag',
              createdAt: DateTime.utc(2026, 10, 20)));
    }
    final ownBefore = await (db.select(db.transactionTagOverrides)
          ..where((t) => t.transactionSyncId.equals('original-70')))
        .get();
    final v = targetSnapshot();
    ((v['items'] as List).single as Map<String, dynamic>)['tagIds'] = [
      'owner-tag'
    ];
    await snapshot(v);
    expect(await engine.hydrateLedgerFromServer('new-shared'), 1);
    final target = await (db.select(db.transactionTagOverrides)
          ..where((t) => t.transactionSyncId.equals('target-latest')))
        .get();
    expect(target, hasLength(1));
    expect(target.single.tagSyncId, 'owner-tag');
    expect(
        await (db.select(db.transactionTagOverrides)
              ..where((t) => t.transactionSyncId.equals('original-70')))
            .get(),
        ownBefore);
    expect(await rows('transactions', 'WHERE ledger_id=$ownLedger ORDER BY id'),
        originalTransactions);
  });

  test(
      'target deleted during full download rejects before no-reference orphan writes',
      () async {
    final target = await registerTarget();
    await db.into(db.transactionTagOverrides).insert(
        TransactionTagOverridesCompanion.insert(
            transactionSyncId: 'original-70',
            tagSyncId: 'retained-override',
            createdAt: DateTime.utc(2026, 10, 25)));
    final overrides = await db.select(db.transactionTagOverrides).get();
    final gate = _GatedStorage();
    await gate.upload(path: 'new-shared', data: jsonEncode(targetSnapshot()));
    provider.storageOverride = gate;
    final call = engine.hydrateLedgerFromServer('new-shared');
    final assertion = expectLater(call, throwsA(isA<StateError>()));
    await gate.entered.future;
    await (db.delete(db.ledgers)..where((l) => l.id.equals(target))).go();
    gate.release.complete();
    await assertion;
    expect(await rows('transactions'), originalTransactions);
    expect(await db.select(db.transactionTagOverrides).get(), overrides);
    expect(await rows('transaction_tags'), originalTags);
    expect(await rows('transaction_attachments'), originalAttachments);
    expect(await engine.appCursor.read(), 500);
    expect(
        await (db.select(db.ledgers)..where((l) => l.id.equals(target))).get(),
        isEmpty);
  });
}
