import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:crypto/crypto.dart';
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
      expect(manifest['version'], 2);
      expect(manifest['profile'], 'normal');
      expect(manifest['routineUiSamples'], isTrue);
      expect(manifest['constraintValidation']['status'], 'PASS');
      expect(
          manifest['constraintValidation']['rowsWithManualInputBoundary'], 0);
      expect(manifest['counts']['longNote'], 300);
      expect(manifest['counts']['zeroAmount'], 0);
      final accountCurrencies = <String, String>{};
      final currencies = <String>{}, types = <String>{};
      for (var index = 0; index < 15000; index++) {
        final actual = parser.parseRow(rows[index + 1], mapping)!;
        final expected = oracle[index];
        expect(rows[index + 1].length, 12, reason: 'record $index');
        expect(expected['manualInputBoundaryReasons'], isEmpty);
        if (expected['type'] != 'transfer') {
          expect(expected['category'], isNotNull);
        }
        // Category save uses String.length in addition to TextField maxLength.
        for (final key in ['category', 'subCategory']) {
          final name = expected[key] as String?;
          if (name != null) expect(name.trim().length, lessThanOrEqualTo(10));
        }
        for (final name in (expected['tagNames'] as List).cast<String>()) {
          expect(name.characters.length, lessThanOrEqualTo(20));
        }
        final amount = double.parse(
            (actual['amount'] as String).replaceAll(RegExp(r'[¥$,+-]'), ''));
        expect(amount.isFinite && amount > 0, isTrue, reason: 'record $index');
        expect(
            (expected['amount'] as String).contains('.')
                ? (expected['amount'] as String).split('.').last.length
                : 0,
            lessThanOrEqualTo(2),
            reason: 'manual amount input permits two decimals');
        for (final key in ['accountName', 'fromAccountName', 'toAccountName']) {
          final name = expected[key] as String?;
          if (name == null) continue;
          final previous = accountCurrencies[name];
          expect(
              previous == null || previous == expected['currencyCode'], isTrue,
              reason: 'routine UI account has one currency');
          accountCurrencies[name] = expected['currencyCode'] as String;
        }
        if (expected['type'] == 'transfer') {
          expect(expected['fromAccountName'], isNotNull);
          expect(expected['toAccountName'], isNot(expected['fromAccountName']));
        }
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
      final resources = jsonDecode(
          File('${directory.path}/fixture-resources.json')
              .readAsStringSync()) as Map<String, dynamic>;
      expect(resources['notAnImportableBackup'], isTrue);
      expect(resources['csvOnlyAccountType'], 'cash',
          reason:
              'CSV alone cannot prove account types/colors/icons were applied');
      final accounts =
          (resources['accounts'] as List).cast<Map<String, dynamic>>();
      expect(accounts.map((a) => a['type']).toSet(), {
        'cash',
        'bank_card',
        'credit_card',
        'alipay',
        'wechat',
        'other',
        'real_estate',
        'vehicle',
        'investment',
        'insurance',
        'social_fund',
        'loan'
      });
      expect(
          accounts
              .where((a) => a['transactionEligible'] == false)
              .any((a) => accountCurrencies.containsKey(a['name'])),
          isFalse);
      expect(
          (resources['tags'] as List).map((t) => t['color']).toSet().length, 8);
      final icon = resources['customIconImage'] as Map<String, dynamic>;
      expect(
          sha256
              .convert(
                  File('${directory.path}/${icon['file']}').readAsBytesSync())
              .toString(),
          icon['sha256']);
      expect(
          (resources['categories'] as List)
              .map((c) => c['icon'])
              .whereType<String>()
              .toSet()
              .length,
          greaterThan(4));
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
  test('over-limit import boundaries require an explicitly non-routine profile',
      () async {
    final directory =
        Directory.systemTemp.createTempSync('beecount-import-boundaries-');
    try {
      final generated = await Process.run('python3', [
        'tool/v4/generate_large_import_fixture.py',
        '--output-dir',
        directory.path,
        '--profile',
        'import-robustness',
        '--count',
        '1000',
      ]);
      expect(generated.exitCode, 0, reason: '${generated.stderr}');
      final manifest = jsonDecode(
          File('${directory.path}/fixture-manifest.json')
              .readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['routineUiSamples'], isFalse);
      expect(manifest['constraintValidation']['status'],
          'EXPLICIT_IMPORT_BOUNDARIES');
      final oracle = File('${directory.path}/expected-records.jsonl')
          .readAsLinesSync()
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();
      final reasons =
          oracle.expand((r) => r['manualInputBoundaryReasons'] as List).toSet();
      expect(
          reasons,
          containsAll([
            'category:over-10-utf16',
            'subCategory:over-10-utf16',
            'tagName:over-20-safe-units',
            'amount:not-positive',
            'amount:over-two-decimals',
          ]));
      // The profile documents accepted historical/import cases; it does not
      // claim the production importer rejects fields beyond editor limits.
      expect(oracle.every((r) => r.containsKey('manualInputBoundaryReasons')),
          isTrue);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}
