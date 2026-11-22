import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/services/export/full_data_export_service.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'ZIP preserves ledgers, paged transactions, attachments, and portable settings',
      () async {
    final root =
        await Directory.systemTemp.createTemp('beecount-full-export-test-');
    addTearDown(() => root.delete(recursive: true));
    final documents = await Directory(p.join(root.path, 'docs')).create();
    final scratch = await Directory(p.join(root.path, 'scratch')).create();
    for (final directory in ['attachments', 'avatars', 'custom_icons']) {
      await Directory(p.join(documents.path, directory)).create();
    }
    final png =
        await File('test/fixtures/design/category-coffee.png').readAsBytes();
    for (final dir in ['attachments', 'avatars', 'custom_icons']) {
      await File(p.join(documents.path, dir, 'qa.png')).writeAsBytes(png);
    }
    SharedPreferences.setMockInitialValues({
      'themeMode': 'dark',
      'user_avatar_path': 'avatars/qa.png',
      'cloud_supabase_cfg': 'DO_NOT_EXPORT',
      'ai_api_key': 'DO_NOT_EXPORT',
    });
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(10,'旅行/2026','CNY'),(20,'旅行_2026','USD'),(30,'家庭','CNY')");
    final accountId = await db.into(db.accounts).insert(
        AccountsCompanion.insert(
            ledgerId: 10, name: 'QA Bank', currency: const Value('USD')));
    final categoryId = await db.into(db.categories).insert(
        CategoriesCompanion.insert(
            name: 'QA food',
            kind: 'expense',
            iconType: const Value('custom'),
            customIconPath: const Value('custom_icons/qa.png')));
    final tagId =
        await db.into(db.tags).insert(TagsCompanion.insert(name: 'QA tag'));
    final txId =
        await db.into(db.transactions).insert(TransactionsCompanion.insert(
              ledgerId: 10,
              type: 'expense',
              amount: 20.125,
              note: const Value('=unsafe formula'),
              accountId: Value(accountId),
              categoryId: Value(categoryId),
              nativeAmount: const Value(145.52),
              excludeFromBudget: const Value(true),
            ));
    await db.into(db.transactionTags).insert(
        TransactionTagsCompanion.insert(transactionId: txId, tagId: tagId));
    await db
        .into(db.budgets)
        .insert(BudgetsCompanion.insert(ledgerId: 10, amount: 500));
    await db.into(db.conversations).insert(
        ConversationsCompanion.insert(title: const Value('QA conversation')));
    await db.batch((batch) {
      batch.insertAll(
          db.transactions,
          List.generate(
              503,
              (index) => TransactionsCompanion.insert(
                  ledgerId: 20, type: 'income', amount: index.toDouble())));
    });
    for (final name in ['qa.png', 'qa.png', 'remote.png', '../forbidden.png']) {
      await db
          .into(db.transactionAttachments)
          .insert(TransactionAttachmentsCompanion.insert(
            transactionId: txId,
            fileName: name,
            cloudFileId: name == 'remote.png'
                ? const Value('remote')
                : const Value.absent(),
            cloudSha256: name == 'remote.png'
                ? Value(sha256.convert(png).toString())
                : const Value.absent(),
          ));
    }
    final service = FullDataExportService(db,
        documents: () async => documents,
        temporary: () async => scratch,
        downloadAttachment: (id) async => id == 'remote' ? png : null);
    final result = await service.export();
    expect(result.ledgerCount, 3);
    expect(result.attachmentCount, 2);
    expect(result.missingFileCount, 1);
    expect(result.file.path, endsWith('.zip'));
    expect(result.file.parent.listSync(), hasLength(1));

    final archive =
        ZipDecoder().decodeBytes(await result.file.readAsBytes(), verify: true);
    dynamic jsonAt(String name) =>
        jsonDecode(utf8.decode(archive.findFile(name)!.content as List<int>));
    final manifest = jsonAt('manifest.json') as Map;
    final ledgers = manifest['ledgers'] as List;
    final folders = ledgers.map((row) => row['directory'] as String).toList();
    expect(folders, hasLength(3));
    expect(folders.toSet(), hasLength(3));
    expect(folders.first, 'ledgers/旅行_2026');
    expect(ledgers.first['name'], '旅行/2026');
    expect(ledgers[1]['transactionCount'], 503);
    expect(folders.last, 'ledgers/家庭');
    expect(jsonAt('${folders.last}/transactions.json'), isEmpty);
    expect(jsonAt('${folders[1]}/transactions.json'), hasLength(503));
    final ledger = jsonAt('${folders.first}/ledger.json') as Map;
    expect(ledger['budgets'], hasLength(1));
    expect(ledger['transactionTags'].single['tagId'], tagId);
    final transaction =
        (jsonAt('${folders.first}/transactions.json') as List).single;
    expect(transaction['amount'], 20.125);
    expect(transaction['nativeAmount'], 145.52);
    expect(transaction['excludeFromBudget'], isTrue);
    final csv = utf8.decode(archive
        .findFile('${folders.first}/transactions.csv')!
        .content as List<int>);
    expect(csv, contains('USD'));
    expect(csv, contains('QA Bank'));
    expect(csv, contains("'=unsafe formula"));
    final attachments = jsonAt('${folders.first}/attachments.json') as List;
    expect(attachments[0]['archivePath'], attachments[1]['archivePath']);
    for (final attachment in [attachments[0], attachments[2]]) {
      final asset =
          archive.findFile('${folders.first}/${attachment['archivePath']}');
      expect(asset!.content, png);
    }
    expect(attachments[3]['archivePath'], isNull);
    expect(manifest['missingFiles'].single['fileName'], '../forbidden.png');
    final config = jsonAt('config.json') as Map;
    expect(config['settings'], {'themeMode': 'dark'});
    final icon = config['categories']
        .firstWhere((row) => row['id'] == categoryId)['customIconPath'];
    expect(archive.findFile(icon)!.content, png);
    expect(archive.findFile(config['avatar'])!.content, png);
    expect(jsonAt('conversations.json')['conversations'].single['title'],
        'QA conversation');
    expect((await db.select(db.transactions).get()).length, 504);
  });
}
