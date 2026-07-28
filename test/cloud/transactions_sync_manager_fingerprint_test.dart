import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/cloud/transactions_sync_manager.dart';

void main() {
  Map<String, dynamic> attachmentTransaction({
    String syncId = 'tx-attachment',
    Object? attachments = _attachmentsUnset,
  }) {
    final transaction = <String, dynamic>{
      'syncId': syncId,
      'happenedAt': '2026-08-01T00:00:00.000Z',
      'type': 'expense',
      'amount': 10.0,
      'categoryName': 'Food',
      'categoryKind': 'expense',
      'note': 'attachment test',
      'tags': 'A,B',
      'accountName': 'Cash',
    };
    if (!identical(attachments, _attachmentsUnset)) {
      transaction['attachments'] = attachments;
    }
    return transaction;
  }

  Map<String, dynamic> payloadForTransaction(
          Map<String, dynamic> transaction) =>
      <String, dynamic>{
        'items': [transaction],
        'budgets': const []
      };

  test('canonical fingerprint detects transaction project link changes', () {
    final unlinked = <String, dynamic>{
      'items': [
        {
          'syncId': 'tx-a',
          'happenedAt': '2026-08-01T00:00:00.000Z',
          'type': 'expense',
          'amount': 10.0,
          'projectBudgetSyncId': null,
        },
      ],
      'budgets': const [],
    };
    final linked = <String, dynamic>{
      'items': [
        Map<String, dynamic>.from(unlinked['items'][0])
          ..['projectBudgetSyncId'] = 'project-a',
      ],
      'budgets': const [],
    };

    expect(
      canonicalTransactionsFingerprint(linked),
      isNot(canonicalTransactionsFingerprint(unlinked)),
    );
  });

  test('canonical fingerprint detects budget content but ignores budget order',
      () {
    final first = <String, dynamic>{
      'items': const [],
      'budgets': [
        {
          'syncId': 'budget-b',
          'type': 'project',
          'amount': 200.0,
          'name': 'B',
        },
        {
          'syncId': 'budget-a',
          'type': 'total',
          'amount': 1000.0,
        },
      ],
    };
    final reordered = <String, dynamic>{
      'items': const [],
      'budgets': [
        Map<String, dynamic>.from(first['budgets'][1]),
        Map<String, dynamic>.from(first['budgets'][0]),
      ],
    };
    final changed = <String, dynamic>{
      'items': const [],
      'budgets': [
        Map<String, dynamic>.from(first['budgets'][0])..['amount'] = 201.0,
        Map<String, dynamic>.from(first['budgets'][1]),
      ],
    };

    final originalFingerprint = canonicalTransactionsFingerprint(first);
    expect(canonicalTransactionsFingerprint(reordered), originalFingerprint);
    expect(
      canonicalTransactionsFingerprint(changed),
      isNot(originalFingerprint),
    );
  });

  test(
      'canonical fingerprint uses all transaction fields as stable tie-breaker',
      () {
    final a = {
      'syncId': 'tx-a',
      'happenedAt': '2026-08-01T00:00:00.000Z',
      'type': 'expense',
      'amount': 10.0,
      'categoryName': 'Food',
      'categoryKind': 'expense',
      'note': 'same',
      'tags': 'A',
      'accountName': 'Cash',
      'projectBudgetSyncId': 'project-a',
    };
    final b = {
      'syncId': 'tx-b',
      'happenedAt': '2026-08-01T00:00:00.000Z',
      'type': 'expense',
      'amount': 10.0,
      'categoryName': 'Food',
      'categoryKind': 'expense',
      'note': 'same',
      'tags': 'B',
      'accountName': 'Card',
      'projectBudgetSyncId': 'project-b',
    };
    final first = <String, dynamic>{
      'items': [a, b],
      'budgets': const [],
    };
    final reversed = <String, dynamic>{
      'items': [b, a],
      'budgets': const [],
    };

    expect(canonicalTransactionsFingerprint(reversed),
        canonicalTransactionsFingerprint(first));
  });

  test(
      'canonical fingerprint stabilizes duplicate budget syncId by full content',
      () {
    final a = {'syncId': 'same', 'type': 'total', 'amount': 1.0};
    final b = {'syncId': 'same', 'type': 'project', 'amount': 2.0};
    expect(
      canonicalTransactionsFingerprint({
        'items': const [],
        'budgets': [a, b],
      }),
      canonicalTransactionsFingerprint({
        'items': const [],
        'budgets': [b, a],
      }),
    );
  });

  test('canonical fingerprint detects attachment add and removal', () {
    final noAttachments = payloadForTransaction(attachmentTransaction());
    final oneAttachment = payloadForTransaction(attachmentTransaction(
      attachments: [
        {'fileName': 'receipt.jpg', 'fileSize': 12},
      ],
    ));
    final removedAttachment = payloadForTransaction(attachmentTransaction(
      attachments: const [],
    ));

    final noAttachmentsFingerprint =
        canonicalTransactionsFingerprint(noAttachments);
    final oneAttachmentFingerprint =
        canonicalTransactionsFingerprint(oneAttachment);
    expect(oneAttachmentFingerprint, isNot(noAttachmentsFingerprint));
    expect(
      oneAttachmentFingerprint,
      isNot(canonicalTransactionsFingerprint(removedAttachment)),
    );
  });

  test('canonical fingerprint detects every serialized attachment field', () {
    final attachment = <String, dynamic>{
      'fileName': 'receipt.jpg',
      'originalName': 'original-receipt.jpg',
      'fileSize': 12,
      'width': 640,
      'height': 480,
      'sortOrder': 1,
      'cloudFileId': 'cloud-file-a',
      'cloudSha256': 'abc123',
    };
    final original = payloadForTransaction(attachmentTransaction(
      attachments: [attachment],
    ));
    final originalFingerprint = canonicalTransactionsFingerprint(original);
    final mutations = <String, dynamic>{
      'fileName': 'changed.jpg',
      'originalName': 'changed-original.jpg',
      'fileSize': 13,
      'width': 641,
      'height': 481,
      'sortOrder': 2,
      'cloudFileId': 'cloud-file-b',
      'cloudSha256': 'def456',
    };

    mutations.forEach((field, value) {
      final changed = Map<String, dynamic>.from(attachment)..[field] = value;
      expect(
        canonicalTransactionsFingerprint(payloadForTransaction(
          attachmentTransaction(attachments: [changed]),
        )),
        isNot(originalFingerprint),
        reason: 'changing attachment $field must change the fingerprint',
      );
    });
  });

  test('canonical fingerprint ignores attachment list and Map key order', () {
    final first = <String, dynamic>{
      'fileName': 'first.jpg',
      'metadata': <String, dynamic>{'a': 1, 'b': 2},
      'sortOrder': 1,
    };
    final second = <String, dynamic>{
      'fileName': 'second.jpg',
      'metadata': <String, dynamic>{'a': 3, 'b': 4},
      'sortOrder': 2,
    };
    final reorderedFirst = <String, dynamic>{
      'sortOrder': 1,
      'metadata': <String, dynamic>{'b': 2, 'a': 1},
      'fileName': 'first.jpg',
    };
    final reorderedSecond = <String, dynamic>{
      'sortOrder': 2,
      'metadata': <String, dynamic>{'b': 4, 'a': 3},
      'fileName': 'second.jpg',
    };

    expect(
      canonicalTransactionsFingerprint(payloadForTransaction(
        attachmentTransaction(attachments: [first, second]),
      )),
      canonicalTransactionsFingerprint(payloadForTransaction(
        attachmentTransaction(attachments: [reorderedSecond, reorderedFirst]),
      )),
    );
  });

  test('canonical fingerprint equates missing null and empty attachments', () {
    final missing = payloadForTransaction(attachmentTransaction());
    final nullAttachments = payloadForTransaction(attachmentTransaction(
      attachments: null,
    ));
    final emptyAttachments = payloadForTransaction(attachmentTransaction(
      attachments: const [],
    ));

    expect(
      canonicalTransactionsFingerprint(nullAttachments),
      canonicalTransactionsFingerprint(missing),
    );
    expect(
      canonicalTransactionsFingerprint(emptyAttachments),
      canonicalTransactionsFingerprint(missing),
    );
    expect(
      () => canonicalTransactionsFingerprint(payloadForTransaction(
        attachmentTransaction(attachments: 'not-a-list'),
      )),
      throwsFormatException,
    );
  });

  test('canonical fingerprint treats transaction syncId as identity', () {
    expect(
      canonicalTransactionsFingerprint(payloadForTransaction(
        attachmentTransaction(syncId: 'tx-a'),
      )),
      isNot(canonicalTransactionsFingerprint(payloadForTransaction(
        attachmentTransaction(syncId: 'tx-b'),
      ))),
    );
  });

  test('canonical fingerprint preserves budget and legacy absence equivalences',
      () {
    final budget = <String, dynamic>{
      'syncId': 'budget-a',
      'name': 'Budget A',
      'metadata': <String, dynamic>{'a': 1, 'b': 2},
    };
    final reversedBudget = <String, dynamic>{
      'metadata': <String, dynamic>{'b': 2, 'a': 1},
      'name': 'Budget A',
      'syncId': 'budget-a',
    };
    expect(
      canonicalTransactionsFingerprint({
        'items': const [],
        'budgets': [budget],
      }),
      canonicalTransactionsFingerprint({
        'items': const [],
        'budgets': [reversedBudget],
      }),
    );
    expect(
      canonicalTransactionsFingerprint({'items': const []}),
      canonicalTransactionsFingerprint(
          {'items': const [], 'budgets': const []}),
    );

    final absentLink = attachmentTransaction()..remove('projectBudgetSyncId');
    final nullLink = attachmentTransaction()..['projectBudgetSyncId'] = null;
    expect(
      canonicalTransactionsFingerprint(payloadForTransaction(absentLink)),
      canonicalTransactionsFingerprint(payloadForTransaction(nullLink)),
    );
  });
}

const _attachmentsUnset = Object();
