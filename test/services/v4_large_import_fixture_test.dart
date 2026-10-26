import 'dart:convert';
import 'dart:io';

import 'package:beecount/services/import/csv_parser.dart';
import 'package:beecount/services/import/file_reader.dart';
import 'package:beecount/services/import/parsers/generic_parser.dart';
import 'package:beecount/utils/date_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      '15000 mixed CSV records pass the actual decoder, parser and column mapping',
      () async {
    final directory =
        Directory.systemTemp.createTempSync('beecount-15k-parser-');
    try {
      final generated = await Process.run('python3', [
        'tool/v4/generate_large_import_fixture.py',
        '--output-dir',
        directory.path,
      ]);
      expect(generated.exitCode, 0, reason: '${generated.stderr}');
      final csv = File('${directory.path}/beecount-15000-mixed.csv');
      final text = FileReaderService.decodeBytes(csv.readAsBytesSync());
      final rows = CsvParser.parse(text);
      expect(rows.length, 15001);
      final parser = GenericBillParser();
      final header = parser.findHeaderRow(rows);
      expect(header, 0);
      final mapping = parser.mapColumns(rows.first);
      expect(mapping.keys.toSet(), {
        'date',
        'type',
        'amount',
        'currency',
        'category',
        'sub_category',
        'account',
        'from_account',
        'to_account',
        'note',
        'tags',
        'attachments',
      });
      final oracle = File('${directory.path}/expected-records.jsonl')
          .readAsLinesSync()
          .map((line) => jsonDecode(line) as Map<String, dynamic>)
          .toList();
      final manifest = jsonDecode(
          File('${directory.path}/fixture-manifest.json')
              .readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['counts']['longNote'], 300);
      final currencies = <String>{}, types = <String>{};
      for (var index = 0; index < 15000; index++) {
        final actual = parser.parseRow(rows[index + 1], mapping)!;
        final expected = oracle[index];
        expect(rows[index + 1].length, 12, reason: 'record $index');
        expect(actual['note'], expected['note'], reason: 'record $index');
        expect(actual['currency'], expected['currencyCode']);
        expect(actual['account'], expected['accountName'] ?? '');
        expect(actual['from_account'], expected['fromAccountName'] ?? '');
        expect(actual['to_account'], expected['toAccountName'] ?? '');
        expect(DateParser.parse(actual['date'] as String),
            DateTime.parse(expected['happenedAtLocal'] as String));
        final tags = (actual['tags'] as String)
            .split(',')
            .where((name) => name.isNotEmpty)
            .toSet();
        expect(tags, (expected['tagNames'] as List).cast<String>().toSet());
        currencies.add(actual['currency'] as String);
        types.add(actual['type'] as String);
      }
      expect(currencies.length, 8);
      expect(types, {'支出', '收入', '转账'});
      expect(
          oracle.take(12).every((row) => (row['tagNames'] as List).length >= 2),
          isTrue);
      expect(
          oracle.any((row) => row['happenedAtLocal'] == '2024-02-29T00:00:07'),
          isTrue);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}
