import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:beecount/ai/providers/ai_constants.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/services/export/config_export_service.dart';
import 'package:beecount/services/export/full_data_export_service.dart';
import 'package:beecount/services/export/transaction_csv_export.dart';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

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
    final storedName = 'sha_${sha256.convert(png)}.png';
    await File(p.join(documents.path, 'attachments', storedName))
        .writeAsBytes(png);
    for (final dir in ['avatars', 'custom_icons']) {
      await File(p.join(documents.path, dir, 'qa.png')).writeAsBytes(png);
    }
    SharedPreferences.setMockInitialValues({
      'themeMode': 'dark',
      'user_avatar_path': 'avatars/qa.png',
      'cloud_supabase_cfg': 'DO_NOT_EXPORT',
      AIConstants.keyGlmApiKey: 'DO_NOT_EXPORT',
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
            name: 'QA "food"',
            kind: 'expense',
            iconType: const Value('custom'),
            customIconPath: const Value('/old/container/custom_icons/qa.png')));
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
    await db.batch((batch) {
      batch.insertAll(
          db.transactions,
          List.generate(
              503,
              (index) => TransactionsCompanion.insert(
                  ledgerId: 20, type: 'income', amount: index.toDouble())));
    });
    for (final name in [
      storedName,
      storedName,
      'remote.png',
      '../forbidden.png'
    ]) {
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
    final l10n = AppLocalizationsZh();
    final repo = LocalRepository(db);
    final categoryCount = (await repo.getAllCategories()).length;
    final result = await service.export(l10n: l10n);
    expect(result.ledgerCount, 3);
    expect(result.attachmentCount, 2);
    expect(result.missingFileCount, 1);
    expect(result.file.path, endsWith('.zip'));
    expect(result.file.parent.listSync(), hasLength(1));

    final archive =
        ZipDecoder().decodeBytes(await result.file.readAsBytes(), verify: true);
    String textAt(String entry) =>
        utf8.decode(archive.findFile(entry)!.content as List<int>);
    expect(archive.files.map((file) => p.extension(file.name)).toSet(),
        {'.csv', '.png', '.yaml'});
    final yaml = textAt('config.yaml');
    final config = AppConfig.fromYaml(loadYaml(yaml) as Map);
    expect(config.ledgers!.items.map((ledger) => ledger.name).toSet(),
        {'旅行/2026', '旅行_2026', '家庭'});
    expect(config.appSettings!.themeMode, 'dark');
    expect(config.accounts!.items.single.name, 'QA Bank');
    expect(config.budgets!.items.single.ledgerName, '旅行/2026');
    expect(config.tags!.items.single.name, 'QA tag');
    final icon =
        config.categories!.items.singleWhere((row) => row.name == 'QA "food"');
    expect(icon.customIconPath, 'custom_icons/qa.png');
    expect(archive.findFile(icon.customIconPath!)!.content, png);
    expect(archive.findFile('avatar/qa.png')!.content, png);
    expect(yaml, isNot(contains('DO_NOT_EXPORT')));
    expect(config.ai, isNull);
    expect(config.supabase, isNull);
    expect((await repo.getAllCategories()).length, categoryCount);

    final restored = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(restored.close);
    final restoreRepo = LocalRepository(restored);
    await ConfigExportService.importFromYaml(
      yaml,
      repository: restoreRepo,
      options: const ExportOptions(
        categories: false,
        accounts: false,
        recurringTransactions: false,
        budgets: false,
        appSettings: false,
        ai: false,
      ),
    );
    expect((await restoreRepo.getAllLedgers()).map((row) => row.name).toSet(),
        {'旅行/2026', '旅行_2026', '家庭'});
    expect((await restoreRepo.getAllTags()).single.name, 'QA tag');

    for (final (id, folder) in [
      (10, '旅行_2026'),
      (20, '旅行_2026 (20-1)'),
      (30, '家庭'),
    ]) {
      final standalone = await buildTransactionExportCsv(
        repo: repo,
        ledgerId: id,
        l10n: l10n,
      );
      final zipped = archive.findFile('ledgers/$folder/transactions.csv')!;
      expect(zipped.content, utf8.encode('\uFEFF$standalone'));
    }
    const folder = 'ledgers/旅行_2026';
    final csv = textAt('$folder/transactions.csv');
    expect(csv, contains(storedName));
    expect(csv, contains('remote.png'));
    for (final name in [storedName, 'remote.png']) {
      expect(archive.findFile('$folder/images/$name')!.content, png);
    }
    final missing =
        const CsvToListConverter(eol: '\r\n', shouldParseNumbers: false)
            .convert(textAt('missing_files.csv').replaceFirst('\uFEFF', ''));
    expect(missing, hasLength(2));
    expect(missing.last, ['attachment', '10', '$txId', '../forbidden.png', '']);
    expect((await db.select(db.transactions).get()).length, 504);
  });
}
