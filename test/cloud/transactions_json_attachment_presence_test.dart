import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/cloud/transactions_json.dart';

void main() {
  Map<String, dynamic> item(String syncId) => {
        'type': 'expense',
        'amount': 10.0,
        'happenedAt': '2026-01-01T00:00:00Z',
        'syncId': syncId,
        'projectBudgetSyncId': null,
      };

  String snapshot(List<Map<String, dynamic>> items, {int version = 6}) =>
      jsonEncode({
        'version': version,
        'accounts': const [],
        'categories': const [],
        'tags': const [],
        'budgets': const [],
        'items': items,
      });

  for (final version in [6, 7]) {
    test('v$version omitted tags and attachments are authoritative empty', () {
      final parsed = parseJsonToImportData(
        snapshot([item('v$version-absent')], version: version),
      );
      final tx = parsed.transactions.single;

      expect(tx.tagNamesPresent, isTrue);
      expect(tx.tagNames, isEmpty);
      expect(tx.attachmentsPresent, isTrue);
      expect(tx.attachments, isEmpty);
    });
  }

  test('present empty attachments are authoritative clear', () {
    final raw = item('explicit-empty')..['attachments'] = <Object>[];
    final tx = parseJsonToImportData(snapshot([raw])).transactions.single;

    expect(tx.attachmentsPresent, isTrue);
    expect(tx.attachments, isEmpty);
  });

  test('present attachments preserve every metadata field', () {
    final raw = item('with-attachment')
      ..['attachments'] = [
        {
          'fileName': 'synthetic.jpg',
          'originalName': 'Synthetic.jpg',
          'fileSize': 123,
          'width': 10,
          'height': 20,
          'sortOrder': 3,
          'cloudFileId': 'cloud-synthetic',
          'cloudSha256': 'synthetic-sha',
        }
      ];
    final tx = parseJsonToImportData(snapshot([raw])).transactions.single;
    final attachment = tx.attachments!.single;

    expect(tx.attachmentsPresent, isTrue);
    expect(attachment.fileName, 'synthetic.jpg');
    expect(attachment.originalName, 'Synthetic.jpg');
    expect(attachment.fileSize, 123);
    expect(attachment.width, 10);
    expect(attachment.height, 20);
    expect(attachment.sortOrder, 3);
    expect(attachment.cloudFileId, 'cloud-synthetic');
    expect(attachment.cloudSha256, 'synthetic-sha');
  });

  test('malformed attachment item is skipped without blocking valid sibling',
      () {
    final invalid = item('invalid-attachment')
      ..['attachments'] = [
        {'fileName': 42}
      ];
    final valid = item('valid-sibling')..['attachments'] = <Object>[];

    final parsed = parseJsonToImportData(snapshot([invalid, valid]));

    expect(parsed.transactions.map((tx) => tx.syncId), ['valid-sibling']);
    expect(parsed.transactions.single.attachmentsPresent, isTrue);
    expect(parsed.transactions.single.attachments, isEmpty);
  });
}
