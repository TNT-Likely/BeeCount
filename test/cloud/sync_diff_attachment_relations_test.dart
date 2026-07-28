import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync_diff_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db, changeTracker: ChangeTracker(db));
    await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'Attachment diff ledger',
            currency: const Value('CNY'),
          ),
        );
  });

  tearDown(() async => db.close());

  Future<void> addProject(String syncId) async {
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            syncId: Value(syncId),
            ledgerId: 1,
            type: const Value('project'),
            amount: 100,
            period: const Value('once'),
            startDay: const Value(1),
            enabled: const Value(true),
            name: const Value('Project'),
            startAt: Value(DateTime(2026, 1, 1)),
            endAt: Value(DateTime(2026, 12, 31)),
            excludeFromMonthlyTotal: const Value(false),
            status: const Value('active'),
          ),
        );
  }

  test('present tags replace and present empty tags clear', () async {
    final happenedAt = DateTime(2026, 7, 27, 17);
    final transactionId = await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 26,
      happenedAt: happenedAt,
      syncId: 'tag-presence',
    );
    final oldTagId = await repo.createTag(name: 'Old tag');
    await repo.updateTransactionTags(
      transactionId: transactionId,
      tagIds: [oldTagId],
    );
    final replacement = ImportTransaction(
      type: 'expense',
      amount: 26,
      happenedAt: happenedAt,
      syncId: 'tag-presence',
      tagNamesPresent: true,
      tagNames: const ['New tag'],
      attachmentsPresent: false,
    );
    final replacementPreview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [replacement],
    );
    expect(replacementPreview!.modifiedCount, 1);
    expect(
        replacementPreview.changes.single.diffDetails.single, contains('标签'));
    final replacementResult = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: replacementPreview.changes,
      importData: ImportData(
        transactions: [replacement],
        tags: const [ImportTag(name: 'New tag')],
      ),
    );
    expect(replacementResult.modifiedCount, 1);
    expect(
        (await repo.getTagsForTransaction(transactionId))
            .map((tag) => tag.name),
        ['New tag']);

    final clear = ImportTransaction(
      type: 'expense',
      amount: 26,
      happenedAt: happenedAt,
      syncId: 'tag-presence',
      tagNamesPresent: true,
      tagNames: const [],
      attachmentsPresent: false,
    );
    final clearPreview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [clear],
    );
    expect(clearPreview!.modifiedCount, 1);
    final clearResult = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: clearPreview.changes,
      importData: ImportData(transactions: [clear]),
    );
    expect(clearResult.modifiedCount, 1);
    expect(await repo.getTagsForTransaction(transactionId), isEmpty);
  });

  test('attachment tuple multiplicity and null values are significant',
      () async {
    final happenedAt = DateTime(2026, 7, 27, 16);
    final transactionId = await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 25,
      happenedAt: happenedAt,
      syncId: 'attachment-multiplicity',
    );
    await repo.createAttachment(
      transactionId: transactionId,
      fileName: 'duplicate.jpg',
      originalName: null,
      fileSize: 50,
      width: 60,
      height: 70,
      sortOrder: 1,
      cloudFileId: 'duplicate-cloud',
      cloudSha256: 'duplicate-sha',
    );
    const localTuple = ImportAttachment(
      fileName: 'duplicate.jpg',
      originalName: null,
      fileSize: 50,
      width: 60,
      height: 70,
      sortOrder: 1,
      cloudFileId: 'duplicate-cloud',
      cloudSha256: 'duplicate-sha',
    );

    final duplicateCloud = ImportTransaction(
      type: 'expense',
      amount: 25,
      happenedAt: happenedAt,
      syncId: 'attachment-multiplicity',
      tagNamesPresent: false,
      attachmentsPresent: true,
      attachments: const [localTuple, localTuple],
    );
    final duplicatePreview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [duplicateCloud],
    );
    expect(duplicatePreview!.modifiedCount, 1);

    final emptyStringCloud = ImportTransaction(
      type: 'expense',
      amount: 25,
      happenedAt: happenedAt,
      syncId: 'attachment-multiplicity',
      tagNamesPresent: false,
      attachmentsPresent: true,
      attachments: const [
        ImportAttachment(
          fileName: 'duplicate.jpg',
          originalName: '',
          fileSize: 50,
          width: 60,
          height: 70,
          sortOrder: 1,
          cloudFileId: 'duplicate-cloud',
          cloudSha256: 'duplicate-sha',
        ),
      ],
    );
    final emptyStringPreview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [emptyStringCloud],
    );
    expect(emptyStringPreview!.modifiedCount, 1);
  });

  test('a bad modified item does not block a valid attachment sibling',
      () async {
    await addProject('retained-project');
    final happenedAt = DateTime(2026, 7, 27, 15);
    final badId = await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 23,
      happenedAt: happenedAt,
      note: 'bad stays',
      syncId: 'bad-retained-link',
      projectBudgetSyncId: 'retained-project',
    );
    await repo.createAttachment(
      transactionId: badId,
      fileName: 'bad-preserved.jpg',
      originalName: 'Bad preserved.jpg',
      fileSize: 1,
      width: 2,
      height: 3,
      sortOrder: 4,
      cloudFileId: 'bad-cloud',
      cloudSha256: 'bad-sha',
    );
    final validId = await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 24,
      happenedAt: happenedAt,
      syncId: 'valid-sibling',
    );
    await repo.createAttachment(
      transactionId: validId,
      fileName: 'valid-old.jpg',
      originalName: 'Valid old.jpg',
      fileSize: 10,
      width: 20,
      height: 30,
      sortOrder: 1,
      cloudFileId: 'valid-old-cloud',
      cloudSha256: 'valid-old-sha',
    );
    await db.delete(db.localChanges).go();

    final badCloud = ImportTransaction(
      type: 'income',
      amount: 23,
      happenedAt: happenedAt,
      note: 'invalid update',
      syncId: 'bad-retained-link',
      projectBudgetSyncIdPresent: false,
      tagNamesPresent: false,
      attachmentsPresent: false,
    );
    final validCloud = ImportTransaction(
      type: 'expense',
      amount: 24,
      happenedAt: happenedAt,
      syncId: 'valid-sibling',
      tagNamesPresent: false,
      attachmentsPresent: true,
      attachments: const [
        ImportAttachment(
          fileName: 'valid-new.jpg',
          originalName: 'Valid new.jpg',
          fileSize: 100,
          width: 200,
          height: 300,
          sortOrder: 2,
          cloudFileId: 'valid-new-cloud',
          cloudSha256: 'valid-new-sha',
        ),
      ],
    );
    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [badCloud, validCloud],
    );
    expect(preview!.modifiedCount, 2);

    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview.changes,
      importData: ImportData(transactions: [badCloud, validCloud]),
    );

    expect(result.modifiedCount, 1);
    final bad = await repo.getTransactionBySyncId('bad-retained-link');
    expect(bad!.type, 'expense');
    expect(bad.note, 'bad stays');
    expect(bad.projectBudgetSyncId, 'retained-project');
    expect((await repo.getAttachmentsByTransaction(badId)).single.fileName,
        'bad-preserved.jpg');
    final validAttachments = await repo.getAttachmentsByTransaction(validId);
    expect(validAttachments, hasLength(1));
    expect(validAttachments.single.fileName, 'valid-new.jpg');
    expect(validAttachments.single.cloudSha256, 'valid-new-sha');
    final changes = await db.select(db.localChanges).get();
    expect(changes, hasLength(1));
    expect(changes.single.entitySyncId, 'valid-sibling');
    expect(changes.single.action, 'update');
  });

  test('absent relations preserve attachments and tags during another change',
      () async {
    final happenedAt = DateTime(2026, 7, 27, 14);
    final transactionId = await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 22,
      happenedAt: happenedAt,
      note: 'old note',
      syncId: 'relations-absent',
    );
    final tagId = await repo.createTag(name: 'Preserved tag');
    await repo.updateTransactionTags(
      transactionId: transactionId,
      tagIds: [tagId],
    );
    await repo.createAttachment(
      transactionId: transactionId,
      fileName: 'preserved.jpg',
      originalName: 'Preserved.jpg',
      fileSize: 123,
      width: 456,
      height: 789,
      sortOrder: 6,
      cloudFileId: 'preserved-cloud',
      cloudSha256: 'preserved-sha',
    );
    await db.delete(db.localChanges).go();
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 22,
      happenedAt: happenedAt,
      note: 'new note',
      syncId: 'relations-absent',
      tagNamesPresent: false,
      attachmentsPresent: false,
    );

    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );
    expect(preview!.modifiedCount, 1);
    expect(preview.changes.single.diffDetails, ['备注: "old note" → "new note"']);

    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview.changes,
      importData: ImportData(transactions: [cloud]),
    );

    expect(result.modifiedCount, 1);
    final attachments = await repo.getAttachmentsByTransaction(transactionId);
    expect(attachments, hasLength(1));
    final attachment = attachments.single;
    expect(attachment.fileName, 'preserved.jpg');
    expect(attachment.originalName, 'Preserved.jpg');
    expect(attachment.fileSize, 123);
    expect(attachment.width, 456);
    expect(attachment.height, 789);
    expect(attachment.sortOrder, 6);
    expect(attachment.cloudFileId, 'preserved-cloud');
    expect(attachment.cloudSha256, 'preserved-sha');
    expect(
        (await repo.getTagsForTransaction(transactionId))
            .map((tag) => tag.name),
        ['Preserved tag']);
  });

  test('present empty attachments previews and applies an authoritative clear',
      () async {
    final happenedAt = DateTime(2026, 7, 27, 13);
    final transactionId = await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 21,
      happenedAt: happenedAt,
      syncId: 'attachment-clear',
    );
    await repo.createAttachment(
      transactionId: transactionId,
      fileName: 'clear-me.jpg',
      originalName: 'Clear me.jpg',
      fileSize: 55,
      width: 66,
      height: 77,
      sortOrder: 8,
      cloudFileId: 'clear-cloud',
      cloudSha256: 'clear-sha',
    );
    await db.delete(db.localChanges).go();
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 21,
      happenedAt: happenedAt,
      syncId: 'attachment-clear',
      tagNamesPresent: false,
      attachmentsPresent: true,
      attachments: const [],
    );

    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );
    expect(preview!.modifiedCount, 1);
    expect(preview.changes.single.diffDetails, contains('附件变更'));

    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview.changes,
      importData: ImportData(transactions: [cloud]),
    );

    expect(result.modifiedCount, 1);
    expect(await repo.getAttachmentsByTransaction(transactionId), isEmpty);
    final changes = await db.select(db.localChanges).get();
    expect(changes, hasLength(1));
    expect(changes.single.action, 'update');
  });

  test('selected modified preview atomically replaces all attachment metadata',
      () async {
    final happenedAt = DateTime(2026, 7, 27, 12);
    final transactionId = await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 20,
      happenedAt: happenedAt,
      syncId: 'attachment-apply',
    );
    await repo.createAttachment(
      transactionId: transactionId,
      fileName: 'old.jpg',
      originalName: 'Old.jpg',
      fileSize: 1,
      width: 2,
      height: 3,
      sortOrder: 4,
      cloudFileId: 'old-cloud',
      cloudSha256: 'old-sha',
    );
    await db.delete(db.localChanges).go();
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 20,
      happenedAt: happenedAt,
      syncId: 'attachment-apply',
      tagNamesPresent: false,
      attachmentsPresent: true,
      attachments: const [
        ImportAttachment(
          fileName: 'new.jpg',
          originalName: 'New.jpg',
          fileSize: 101,
          width: 202,
          height: 303,
          sortOrder: 5,
          cloudFileId: 'new-cloud',
          cloudSha256: 'new-sha',
        ),
      ],
    );
    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );
    expect(preview!.modifiedCount, 1);

    final result = await syncDiffService.applySyncChanges(
      repo: repo,
      ledgerId: 1,
      selectedChanges: preview.changes,
      importData: ImportData(transactions: [cloud]),
    );

    expect(result.modifiedCount, 1);
    final attachments = await repo.getAttachmentsByTransaction(transactionId);
    expect(attachments, hasLength(1));
    final attachment = attachments.single;
    expect(attachment.fileName, 'new.jpg');
    expect(attachment.originalName, 'New.jpg');
    expect(attachment.fileSize, 101);
    expect(attachment.width, 202);
    expect(attachment.height, 303);
    expect(attachment.sortOrder, 5);
    expect(attachment.cloudFileId, 'new-cloud');
    expect(attachment.cloudSha256, 'new-sha');
    expect(attachments.any((item) => item.fileName == 'old.jpg'), isFalse);
    final changes = await db.select(db.localChanges).get();
    expect(changes, hasLength(1));
    expect(changes.single.entityType, 'transaction');
    expect(changes.single.entitySyncId, 'attachment-apply');
    expect(changes.single.action, 'update');
  });

  test('transport order is ignored but sortOrder metadata is meaningful',
      () async {
    final happenedAt = DateTime(2026, 7, 27, 11);
    final transactionId = await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 19,
      happenedAt: happenedAt,
      syncId: 'attachment-order',
    );
    await repo.createAttachment(
      transactionId: transactionId,
      fileName: 'first.jpg',
      originalName: 'First.jpg',
      fileSize: 10,
      width: 100,
      height: 200,
      sortOrder: 1,
      cloudFileId: 'first-cloud',
      cloudSha256: 'first-sha',
    );
    await repo.createAttachment(
      transactionId: transactionId,
      fileName: 'second.jpg',
      originalName: 'Second.jpg',
      fileSize: 20,
      width: 300,
      height: 400,
      sortOrder: 2,
      cloudFileId: 'second-cloud',
      cloudSha256: 'second-sha',
    );

    ImportTransaction cloudWithSecondSortOrder(int sortOrder) =>
        ImportTransaction(
          type: 'expense',
          amount: 19,
          happenedAt: happenedAt,
          syncId: 'attachment-order',
          tagNamesPresent: false,
          attachmentsPresent: true,
          attachments: [
            ImportAttachment(
              fileName: 'second.jpg',
              originalName: 'Second.jpg',
              fileSize: 20,
              width: 300,
              height: 400,
              sortOrder: sortOrder,
              cloudFileId: 'second-cloud',
              cloudSha256: 'second-sha',
            ),
            const ImportAttachment(
              fileName: 'first.jpg',
              originalName: 'First.jpg',
              fileSize: 10,
              width: 100,
              height: 200,
              sortOrder: 1,
              cloudFileId: 'first-cloud',
              cloudSha256: 'first-sha',
            ),
          ],
        );

    final reversed = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloudWithSecondSortOrder(2)],
    );
    expect(reversed!.changes, isEmpty);

    final changedSortOrder = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloudWithSecondSortOrder(3)],
    );
    expect(changedSortOrder!.modifiedCount, 1);
    expect(changedSortOrder.changes.single.diffDetails, contains('附件变更'));
  });

  test('attachment-only metadata change is selectable in preview', () async {
    final happenedAt = DateTime(2026, 7, 27, 10);
    final transactionId = await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 18,
      happenedAt: happenedAt,
      note: 'same',
      syncId: 'attachment-only',
    );
    await repo.createAttachment(
      transactionId: transactionId,
      fileName: 'receipt.jpg',
      originalName: 'Receipt.jpg',
      fileSize: 100,
      width: 640,
      height: 480,
      sortOrder: 2,
      cloudFileId: 'cloud-file',
      cloudSha256: 'old-sha',
    );
    final cloud = ImportTransaction(
      type: 'expense',
      amount: 18,
      happenedAt: happenedAt,
      note: 'same',
      syncId: 'attachment-only',
      tagNamesPresent: false,
      attachmentsPresent: true,
      attachments: const [
        ImportAttachment(
          fileName: 'receipt.jpg',
          originalName: 'Receipt.jpg',
          fileSize: 100,
          width: 640,
          height: 480,
          sortOrder: 2,
          cloudFileId: 'cloud-file',
          cloudSha256: 'new-sha',
        ),
      ],
    );

    final preview = await syncDiffService.computeDiff(
      repo: repo,
      ledgerId: 1,
      cloudTransactions: [cloud],
    );

    expect(preview, isNotNull);
    expect(preview!.addedCount, 0);
    expect(preview.deletedCount, 0);
    expect(preview.modifiedCount, 1,
        reason: preview.changes.map((change) => change.diffDetails).toString());
    expect(
      preview.changes.single.diffDetails.any((detail) => detail.contains('附件')),
      isTrue,
      reason: preview.changes.single.diffDetails.toString(),
    );
  });

  test('attachment diff uses one batch query instead of per-item N+1',
      () async {
    final countingRepo = _AttachmentQueryCountingRepository(
      db,
      changeTracker: ChangeTracker(db),
    );
    final happenedAt = DateTime(2026, 7, 27, 9);
    for (final syncId in ['batch-attachment-1', 'batch-attachment-2']) {
      await countingRepo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 17,
        happenedAt: happenedAt,
        syncId: syncId,
      );
    }

    final preview = await syncDiffService.computeDiff(
      repo: countingRepo,
      ledgerId: 1,
      cloudTransactions: [
        for (final syncId in ['batch-attachment-1', 'batch-attachment-2'])
          ImportTransaction(
            type: 'expense',
            amount: 17,
            happenedAt: happenedAt,
            syncId: syncId,
            tagNamesPresent: false,
            attachmentsPresent: true,
            attachments: const [],
          ),
      ],
    );

    expect(preview!.changes, isEmpty);
    expect(countingRepo.batchAttachmentQueries, 1);
    expect(countingRepo.singleAttachmentQueries, 0);
  });
}

class _AttachmentQueryCountingRepository extends LocalRepository {
  _AttachmentQueryCountingRepository(
    super.db, {
    super.changeTracker,
  });

  int batchAttachmentQueries = 0;
  int singleAttachmentQueries = 0;

  @override
  Future<Map<int, List<TransactionAttachment>>> getAttachmentsForTransactions(
      List<int> transactionIds) {
    batchAttachmentQueries++;
    return super.getAttachmentsForTransactions(transactionIds);
  }

  @override
  Future<List<TransactionAttachment>> getAttachmentsByTransaction(
      int transactionId) {
    singleAttachmentQueries++;
    return super.getAttachmentsByTransaction(transactionId);
  }
}
