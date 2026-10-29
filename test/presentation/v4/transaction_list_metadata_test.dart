import 'package:beecount/data/db.dart';
import 'package:beecount/pages/shared/transactions/bindings/transaction_list_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('15000 IDs are bounded, complete and emitted only after both reads',
      () async {
    final tagIds = <int>[], attachmentIds = <int>[];
    var active = 0, maximum = 0;
    Future<void> tick() async {
      active++;
      if (active > maximum) maximum = active;
      await Future<void>.delayed(Duration.zero);
      active--;
    }

    final result = await readTransactionListMetadata(
        transactionIds: List.generate(15000, (i) => i + 1),
        readTags: (ids) async {
          expect(ids.length, lessThanOrEqualTo(400));
          tagIds.addAll(ids);
          await tick();
          return <int, List<Tag>>{};
        },
        readAttachmentCounts: (ids) async {
          expect(ids.length, lessThanOrEqualTo(400));
          attachmentIds.addAll(ids);
          await tick();
          return {
            for (final id in ids)
              if (id.isEven) id: 2
          };
        });
    expect(maximum, lessThanOrEqualTo(6));
    expect(tagIds.toSet().length, 15000);
    expect(attachmentIds.toSet(), tagIds.toSet());
    expect(result.tags.length, 15000);
    expect(result.attachments.length, 15000);
    expect(result.attachments[14999], 0);
    expect(result.attachments[15000], 2);
  });

  test('a failed batch never returns a partial success snapshot', () async {
    await expectLater(
        readTransactionListMetadata(
            transactionIds: List.generate(1000, (i) => i),
            readTags: (ids) async {
              if (ids.contains(501)) throw StateError('Synthetic failed batch');
              return <int, List<Tag>>{};
            },
            readAttachmentCounts: (ids) async => <int, int>{}),
        throwsStateError);
  });

  test('superseded large requests stop scheduling later batches', () async {
    var current = true, tagReads = 0, countReads = 0;
    await expectLater(
        readTransactionListMetadata(
            transactionIds: List.generate(15000, (i) => i),
            isCurrent: () => current,
            readTags: (_) async {
              tagReads++;
              current = false;
              return <int, List<Tag>>{};
            },
            readAttachmentCounts: (_) async {
              countReads++;
              return <int, int>{};
            }),
        throwsA(isA<TransactionListMetadataSuperseded>()));
    expect(tagReads, 1);
    expect(countReads, 1);
  });

  test('invalid batch and concurrency values are rejected', () async {
    for (final args in [(0, 3), (501, 3), (400, 0), (400, 5)]) {
      await expectLater(
          readTransactionListMetadata(
              transactionIds: [1],
              batchSize: args.$1,
              concurrency: args.$2,
              readTags: (_) async => <int, List<Tag>>{},
              readAttachmentCounts: (_) async => <int, int>{}),
          throwsArgumentError);
    }
  });
}
