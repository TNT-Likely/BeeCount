import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late int source;
  late int target;
  late int other;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    source = await repo.createLedger(name: 'Source');
    target = await repo.createLedger(name: 'Target');
    other = await repo.createLedger(name: 'Foreign', currency: 'USD');
  });
  tearDown(() async => db.close());

  Future<int> fixture(int ledger) => repo.addTransaction(
        ledgerId: ledger,
        type: 'expense',
        currencyCode: 'USD',
        nativeAmount: 73.25,
        amount: 10,
        happenedAt: DateTime(2025, 10, 11),
        excludeFromBudget: true,
        note: 'Original',
      );

  test(
      'same-base move preserves the original ID, snapshot, tags and file reference',
      () async {
    final id = await fixture(source);
    final tag = await repo.createTag(name: 'Sample');
    await repo.updateTransactionTags(transactionId: id, tagIds: [tag]);
    await db.into(db.transactionAttachments).insert(
        TransactionAttachmentsCompanion.insert(
            transactionId: id, fileName: 'photo.png'));
    final before = (await repo.getTransactionById(id))!;
    expect(
        await repo.moveTransactionsLocally(
          sourceLedgerId: source,
          targetLedgerId: target,
          transactionIds: {id},
        ),
        1);
    final moved = (await repo.getTransactionById(id))!;
    expect(moved, before.copyWith(ledgerId: target));
    expect((await repo.getTagsForTransaction(id)).single.id, tag);
    expect((await repo.getAttachmentsByTransaction(id)).single.fileName,
        'photo.png');
  });

  test('a mismatched row rolls back the entire selection', () async {
    final first = await fixture(source);
    final unrelated = await fixture(target);
    await expectLater(
        repo.moveTransactionsLocally(
          sourceLedgerId: source,
          targetLedgerId: target,
          transactionIds: {first, unrelated},
        ),
        throwsStateError);
    expect((await repo.getTransactionById(first))?.ledgerId, source);
    expect((await repo.getTransactionById(unrelated))?.ledgerId, target);
  });

  test('different base currency is rejected', () async {
    final id = await fixture(source);
    await expectLater(
        repo.moveTransactionsLocally(
          sourceLedgerId: source,
          targetLedgerId: other,
          transactionIds: {id},
        ),
        throwsStateError);
    expect((await repo.getTransactionById(id))?.ledgerId, source);
  });
}
