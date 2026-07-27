import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/transactions_json.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/data/repositories/transaction_repository.dart';
import 'package:beecount/services/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;
  late int ledgerId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    ledgerId = await repo.createLedger(name: 'Import target');
  });

  tearDown(() => db.close());

  test('linked non-expense is isolated before batch buffering', () async {
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          ledgerId: ledgerId,
          type: const Value('project'),
          amount: 100,
          syncId: const Value('project-1'),
          name: const Value('Project'),
          startAt: Value(DateTime.utc(2026, 1, 1)),
          endAt: Value(DateTime.utc(2026, 2, 1)),
          status: const Value('active'),
        ));

    final result = await dataImportService.importTransactions(
      repo,
      ledgerId,
      [
        ImportTransaction(
          type: 'income',
          amount: 10,
          happenedAt: DateTime.utc(2026, 1, 2),
          syncId: 'invalid-income',
          projectBudgetSyncId: 'project-1',
          projectBudgetSyncIdPresent: true,
        ),
        ImportTransaction(
          type: 'expense',
          amount: 20,
          happenedAt: DateTime.utc(2026, 1, 3),
          syncId: 'valid-expense',
          projectBudgetSyncId: 'project-1',
          projectBudgetSyncIdPresent: true,
        ),
      ],
      accountNameToId: const {},
      categoryCache: const {},
      tagNameToId: {},
      recordChanges: false,
    );

    expect(result.inserted, 1);
    expect(result.failed, 1);
    expect(await repo.getTransactionBySyncId('invalid-income'), isNull);
    expect(await repo.getTransactionBySyncId('valid-expense'), isNotNull);
    expect(await db.select(db.localChanges).get(), isEmpty);
  });

  test('project lookup failure is isolated and later sibling continues',
      () async {
    final throwingRepo = _ThrowingProjectLookupRepository(
      db,
      throwSyncId: 'project-lookup-throws',
    );
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          ledgerId: ledgerId,
          type: const Value('project'),
          amount: 100,
          syncId: const Value('project-ok'),
          name: const Value('Project ok'),
          startAt: Value(DateTime.utc(2026, 1, 1)),
          endAt: Value(DateTime.utc(2026, 2, 1)),
          status: const Value('active'),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 5,
          happenedAt: Value(DateTime.utc(2026, 1, 2)),
          syncId: const Value('existing-lookup-throws'),
        ));

    final result = await dataImportService.importTransactions(
      throwingRepo,
      ledgerId,
      [
        ImportTransaction(
          type: 'expense',
          amount: 9,
          happenedAt: DateTime.utc(2026, 1, 3),
          syncId: 'existing-lookup-throws',
          projectBudgetSyncId: 'project-lookup-throws',
          projectBudgetSyncIdPresent: true,
        ),
        ImportTransaction(
          type: 'expense',
          amount: 7,
          happenedAt: DateTime.utc(2026, 1, 4),
          syncId: 'later-after-lookup-failure',
          projectBudgetSyncId: 'project-ok',
          projectBudgetSyncIdPresent: true,
        ),
      ],
      accountNameToId: const {},
      categoryCache: const {},
      tagNameToId: {},
      recordChanges: false,
    );

    expect(result.inserted, 1);
    expect(result.failed, 1);
    expect(
      (await throwingRepo.getTransactionBySyncId('existing-lookup-throws'))!
          .amount,
      5,
    );
    expect(
      await throwingRepo.getTransactionBySyncId('later-after-lookup-failure'),
      isNotNull,
    );
  });

  test('existing update failure is isolated and later sibling continues',
      () async {
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          ledgerId: ledgerId,
          type: const Value('project'),
          amount: 100,
          syncId: const Value('project-retained'),
          name: const Value('Retained project'),
          startAt: Value(DateTime.utc(2026, 1, 1)),
          endAt: Value(DateTime.utc(2026, 2, 1)),
          status: const Value('active'),
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: ledgerId,
          type: 'expense',
          amount: 5,
          happenedAt: Value(DateTime.utc(2026, 1, 4)),
          syncId: const Value('existing-linked'),
          projectBudgetSyncId: const Value('project-retained'),
        ));

    final result = await dataImportService.importTransactions(
      repo,
      ledgerId,
      [
        ImportTransaction(
          type: 'income',
          amount: 99,
          happenedAt: DateTime.utc(2026, 1, 5),
          syncId: 'existing-linked',
          // Legacy/absent project key: repository must retain the old link,
          // then reject changing a linked expense into income.
          projectBudgetSyncIdPresent: false,
        ),
        ImportTransaction(
          type: 'expense',
          amount: 7,
          happenedAt: DateTime.utc(2026, 1, 6),
          syncId: 'later-valid',
        ),
      ],
      accountNameToId: const {},
      categoryCache: const {},
      tagNameToId: {},
      recordChanges: false,
    );

    expect(result.inserted, 1);
    expect(result.failed, 1);
    final existing = await repo.getTransactionBySyncId('existing-linked');
    expect(existing, isNotNull);
    expect(existing!.type, 'expense');
    expect(existing.amount, 5);
    expect(existing.projectBudgetSyncId, 'project-retained');
    expect(await repo.getTransactionBySyncId('later-valid'), isNotNull);
    expect(await db.select(db.localChanges).get(), isEmpty);
  });
  test('existing restore atomically converges relations and is idempotent',
      () async {
    final oldTagId = await repo.createTag(name: 'Old tag');
    final newTagId = await repo.createTag(name: 'New tag');
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 5,
            happenedAt: Value(DateTime.utc(2026, 1, 7)),
            syncId: const Value('existing-relations'),
          ),
        );
    await db.into(db.transactionTags).insert(
          TransactionTagsCompanion.insert(
            transactionId: txId,
            tagId: oldTagId,
          ),
        );
    await repo.createAttachment(
      transactionId: txId,
      fileName: 'old.jpg',
      originalName: 'Old.jpg',
      fileSize: 1,
      width: 2,
      height: 3,
      sortOrder: 4,
      cloudFileId: 'old-cloud',
      cloudSha256: 'old-sha',
    );

    final authoritative = parseJsonToImportData(jsonEncode({
      'version': 7,
      'accounts': const [],
      'categories': const [],
      'tags': const [],
      'budgets': const [],
      'items': [
        {
          'type': 'expense',
          'amount': 42,
          'happenedAt': '2026-01-08T00:00:00Z',
          'note': 'updated',
          'syncId': 'existing-relations',
          'projectBudgetSyncId': null,
          'tags': 'New tag',
          'attachments': [
            {
              'fileName': 'new.jpg',
              'originalName': 'New.jpg',
              'fileSize': 123,
              'width': 10,
              'height': 20,
              'sortOrder': 5,
              'cloudFileId': 'new-cloud',
              'cloudSha256': 'new-sha',
            },
          ],
        },
      ],
    })).transactions.single;

    for (var pass = 0; pass < 2; pass++) {
      final result = await dataImportService.importTransactions(
        repo,
        ledgerId,
        [authoritative],
        accountNameToId: const {},
        categoryCache: const {},
        tagNameToId: {'New tag': newTagId},
        recordChanges: false,
      );
      expect(result.inserted, 1);
      expect(result.failed, 0);
    }

    final row = await repo.getTransactionBySyncId('existing-relations');
    expect(row, isNotNull);
    expect(row!.amount, 42);
    expect(row.note, 'updated');

    final tags = await repo.getTagsForTransaction(txId);
    expect(tags.map((tag) => tag.name), ['New tag']);

    final attachments = await repo.getAttachmentsByTransaction(txId);
    expect(attachments, hasLength(1));
    final attachment = attachments.single;
    expect(attachment.fileName, 'new.jpg');
    expect(attachment.originalName, 'New.jpg');
    expect(attachment.fileSize, 123);
    expect(attachment.width, 10);
    expect(attachment.height, 20);
    expect(attachment.sortOrder, 5);
    expect(attachment.cloudFileId, 'new-cloud');
    expect(attachment.cloudSha256, 'new-sha');
  });

  test('present empty clears relations while absent preserves them', () async {
    final oldTagId = await repo.createTag(name: 'Presence old');

    Future<int> seed(String syncId) async {
      final txId = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerId,
              type: 'expense',
              amount: 5,
              happenedAt: Value(DateTime.utc(2026, 1, 11)),
              syncId: Value(syncId),
            ),
          );
      await db.into(db.transactionTags).insert(
            TransactionTagsCompanion.insert(
              transactionId: txId,
              tagId: oldTagId,
            ),
          );
      await repo.createAttachment(
        transactionId: txId,
        fileName: '$syncId-old.jpg',
      );
      return txId;
    }

    final clearId = await seed('relations-clear');
    final preserveId = await seed('relations-preserve');
    final result = await dataImportService.importTransactions(
      repo,
      ledgerId,
      [
        ImportTransaction(
          type: 'expense',
          amount: 6,
          happenedAt: DateTime.utc(2026, 1, 12),
          syncId: 'relations-clear',
          tagNames: const [],
          attachments: const [],
        ),
        ImportTransaction(
          type: 'expense',
          amount: 7,
          happenedAt: DateTime.utc(2026, 1, 13),
          syncId: 'relations-preserve',
        ),
      ],
      accountNameToId: const {},
      categoryCache: const {},
      tagNameToId: {},
      recordChanges: false,
    );

    expect(result.inserted, 2);
    expect(result.failed, 0);
    expect(await repo.getTagsForTransaction(clearId), isEmpty);
    expect(await repo.getAttachmentsByTransaction(clearId), isEmpty);
    expect(
        (await repo.getTagsForTransaction(preserveId)).map((tag) => tag.name),
        ['Presence old']);
    expect(
        (await repo.getAttachmentsByTransaction(preserveId))
            .map((attachment) => attachment.fileName),
        ['relations-preserve-old.jpg']);
    expect(await db.select(db.localChanges).get(), isEmpty);
  });

  test('v6 omitted attachments authoritatively clears existing metadata',
      () async {
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            type: 'expense',
            amount: 5,
            ledgerId: ledgerId,
            happenedAt: Value(DateTime.utc(2026, 1, 1)),
            syncId: const Value('v6-empty-attachments'),
          ),
        );
    await repo.createAttachment(
      transactionId: txId,
      fileName: 'must-clear.jpg',
      fileSize: 1,
      sortOrder: 0,
    );

    final snapshot = jsonEncode({
      'version': 6,
      'accounts': const [],
      'categories': const [],
      'tags': const [],
      'items': [
        {
          'type': 'expense',
          'amount': 6.0,
          'happenedAt': '2026-01-02T00:00:00.000Z',
          'syncId': 'v6-empty-attachments',
        }
      ],
    });
    final imported = parseJsonToImportData(snapshot).transactions.single;

    final result = await dataImportService.importTransactions(
      repo,
      ledgerId,
      [imported],
      accountNameToId: const {},
      categoryCache: const {},
      tagNameToId: const {},
      recordChanges: false,
    );

    expect(result.inserted, 1);
    expect(result.failed, 0);
    expect(await repo.getAttachmentsByTransaction(txId), isEmpty);
  });

  test('real v7 zero-attachment export clears stale existing metadata',
      () async {
    final sourceDb = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(sourceDb.close);
    final sourceRepo = LocalRepository(sourceDb);
    final sourceLedgerId = await sourceRepo.createLedger(name: 'Source');
    await sourceDb.into(sourceDb.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: sourceLedgerId,
            type: 'expense',
            amount: 12,
            happenedAt: Value(DateTime.utc(2026, 1, 20)),
            syncId: const Value('real-export-empty-attachments'),
          ),
        );

    final targetId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 5,
            happenedAt: Value(DateTime.utc(2026, 1, 19)),
            syncId: const Value('real-export-empty-attachments'),
          ),
        );
    await repo.createAttachment(
      transactionId: targetId,
      fileName: 'stale-target.jpg',
      fileSize: 1,
    );

    final exported = await exportTransactionsJson(sourceDb, sourceLedgerId);
    final rawItem = ((jsonDecode(exported) as Map<String, dynamic>)['items']
            as List<dynamic>)
        .single as Map<String, dynamic>;
    expect(rawItem.containsKey('attachments'), isFalse);
    final imported = parseJsonToImportData(exported).transactions.single;

    final result = await dataImportService.importTransactions(
      repo,
      ledgerId,
      [imported],
      accountNameToId: const {},
      categoryCache: const {},
      tagNameToId: const {},
      recordChanges: false,
    );

    expect(result.inserted, 1);
    expect(result.failed, 0);
    expect(await repo.getAttachmentsByTransaction(targetId), isEmpty);
  });

  test('relation insert failure rolls back main row tags and attachments',
      () async {
    final trackedRepo = LocalRepository(db, changeTracker: ChangeTracker(db));
    final oldTagId = await repo.createTag(name: 'Rollback old');
    final newTagId = await repo.createTag(name: 'Rollback new');
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 5,
            note: const Value('old note'),
            happenedAt: Value(DateTime.utc(2026, 1, 9)),
            syncId: const Value('rollback-existing'),
          ),
        );
    await db.into(db.transactionTags).insert(
          TransactionTagsCompanion.insert(
            transactionId: txId,
            tagId: oldTagId,
          ),
        );
    await db.into(db.transactionTagOverrides).insert(
          TransactionTagOverridesCompanion.insert(
            transactionSyncId: 'rollback-existing',
            tagSyncId: 'rollback-owner-tag',
            createdAt: DateTime.utc(2026, 1, 9),
          ),
        );
    await repo.createAttachment(
      transactionId: txId,
      fileName: 'rollback-old.jpg',
      originalName: 'Rollback old.jpg',
      fileSize: 10,
    );
    await db.customStatement('''
      CREATE TRIGGER fail_e4s12a_attachment_insert
      BEFORE INSERT ON transaction_attachments
      BEGIN
        SELECT RAISE(ABORT, 'forced E4-S12A attachment failure');
      END;
    ''');

    await expectLater(
      trackedRepo.updateTransactionWithRelationsBySyncId(
        TransactionRelationsUpdateBySyncIdData(
          transaction: TransactionUpdateBySyncIdData(
            syncId: 'rollback-existing',
            type: 'expense',
            amount: 99,
            happenedAt: DateTime.utc(2026, 1, 10),
            note: 'new note',
          ),
          tagIds: [newTagId],
          attachments: const [
            BatchAttachmentData(fileName: 'rollback-new.jpg'),
          ],
        ),
        recordChanges: true,
      ),
      throwsA(anything),
    );

    final row = await repo.getTransactionBySyncId('rollback-existing');
    expect(row, isNotNull);
    expect(row!.amount, 5);
    expect(row.note, 'old note');
    expect((await repo.getTagsForTransaction(txId)).map((tag) => tag.name),
        ['Rollback old']);
    final attachments = await repo.getAttachmentsByTransaction(txId);
    expect(attachments.map((attachment) => attachment.fileName),
        ['rollback-old.jpg']);
    final overrides = await (db.select(db.transactionTagOverrides)
          ..where((row) => row.transactionSyncId.equals('rollback-existing')))
        .get();
    expect(overrides.map((row) => row.tagSyncId), ['rollback-owner-tag']);
    expect(await db.select(db.localChanges).get(), isEmpty);
  });

  test('tracked relation update honors recordChanges false', () async {
    final trackedRepo = LocalRepository(db, changeTracker: ChangeTracker(db));
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 5,
            happenedAt: Value(DateTime.utc(2026, 1, 16)),
            syncId: const Value('tracked-suppressed'),
          ),
        );

    final txId = await trackedRepo.updateTransactionWithRelationsBySyncId(
      TransactionRelationsUpdateBySyncIdData(
        transaction: TransactionUpdateBySyncIdData(
          syncId: 'tracked-suppressed',
          type: 'expense',
          amount: 8,
          happenedAt: DateTime.utc(2026, 1, 17),
        ),
        tagIds: const [],
        attachments: const [],
      ),
      recordChanges: false,
    );

    expect(txId, isNotNull);
    expect(await db.select(db.localChanges).get(), isEmpty);
  });

  test('tracked atomic relation update records exactly one update change',
      () async {
    final trackedRepo = LocalRepository(db, changeTracker: ChangeTracker(db));
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 5,
            happenedAt: Value(DateTime.utc(2026, 1, 14)),
            syncId: const Value('tracked-existing'),
          ),
        );

    final txId = await trackedRepo.updateTransactionWithRelationsBySyncId(
      TransactionRelationsUpdateBySyncIdData(
        transaction: TransactionUpdateBySyncIdData(
          syncId: 'tracked-existing',
          type: 'expense',
          amount: 8,
          happenedAt: DateTime.utc(2026, 1, 15),
        ),
        tagIds: const [],
        attachments: const [],
      ),
    );

    expect(txId, isNotNull);
    final changes = await db.select(db.localChanges).get();
    expect(changes, hasLength(1));
    expect(changes.single.entityType, 'transaction');
    expect(changes.single.entitySyncId, 'tracked-existing');
    expect(changes.single.action, 'update');
  });
}

class _ThrowingProjectLookupRepository extends LocalRepository {
  _ThrowingProjectLookupRepository(
    super.db, {
    required this.throwSyncId,
  });

  final String throwSyncId;

  @override
  Future<Budget?> getProjectBudgetBySyncId(String syncId) {
    if (syncId == throwSyncId) {
      throw StateError('forced project lookup failure');
    }
    return super.getProjectBudgetBySyncId(syncId);
  }
}
