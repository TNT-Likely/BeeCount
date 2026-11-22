import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db.dart';

class FullDataExportResult {
  const FullDataExportResult(
      this.file, this.ledgerCount, this.attachmentCount, this.missingFileCount);

  final File file;
  final int ledgerCount;
  final int attachmentCount;
  final int missingFileCount;
}

typedef _LedgerFiles = ({
  Ledger ledger,
  Directory directory,
  int transactions,
  List<TransactionAttachment> attachments,
});

/// A portable snapshot of the data on this device. All output is staged in cache.
class FullDataExportService {
  FullDataExportService(
    this._db, {
    Future<Directory> Function() documents = getApplicationDocumentsDirectory,
    Future<Directory> Function() temporary = getTemporaryDirectory,
    Future<SharedPreferences> Function() preferences =
        SharedPreferences.getInstance,
    Future<Uint8List?> Function(String fileId)? downloadAttachment,
  })  : _documents = documents,
        _temporary = temporary,
        _preferences = preferences,
        _downloadAttachment = downloadAttachment;

  // Configuration backups can contain login credentials and provider API keys.
  // Export only known portable settings in this freely shareable archive.
  static const _settings = {
    'account_feature_enabled',
    'default_income_account_id',
    'default_expense_account_id',
    'reminder_enabled',
    'reminder_hour',
    'reminder_minute',
    'selected_language',
    'selected_language_country',
    'primaryColor',
    'fontScaleLevel',
    'customFontScale',
    'themeMode',
    'darkModePatternStyle',
    'headerSkin',
    'skinCardOpacity',
    'skinCardBlur',
    'compactAmount',
    'showTransactionTime',
    'noteDisplayMode',
    'noteHistoryScope',
    'noteHistorySort',
    'noteHistoryLimit',
    'incomeExpenseColorScheme',
    'auto_screenshot_billing_enabled',
    'shortcut_prefer_camera',
    'assetTrendView',
    'v4_home_summary_style',
    'attachmentKeepOriginal',
    'hideAmounts',
    'skinAnimationEnabled',
    'headerDecorationStyle',
    'userChosenPrimaryColor',
    'displayName',
    'selected_currency',
    'current_ledger_id',
  };

  final BeeDatabase _db;
  final Future<Directory> Function() _documents;
  final Future<Directory> Function() _temporary;
  final Future<SharedPreferences> Function() _preferences;
  final Future<Uint8List?> Function(String)? _downloadAttachment;
  bool _running = false;

  Future<FullDataExportResult> export() async {
    if (_running) throw StateError('An export is already running');
    _running = true;
    Directory? working;
    var succeeded = false;
    try {
      final documents = await _documents();
      final prefs = await _preferences();
      working = await (await _temporary()).createTemp('beecount-export-');
      final contents =
          await Directory(p.join(working.path, 'contents')).create();
      final ledgers =
          await Directory(p.join(contents.path, 'ledgers')).create();
      final settings = {
        for (final key in _settings)
          if (prefs.containsKey(key)) key: prefs.get(key),
      };
      final (snapshots, config) = await _db.transaction(
        () => _snapshot(ledgers, contents, settings),
      );
      final missing = <Map<String, Object?>>[];
      var fileCount = 0;
      final index = <Map<String, Object?>>[];
      for (final snapshot in snapshots) {
        final copied = await _exportAttachments(snapshot, documents, missing);
        fileCount += copied;
        index.add({
          'id': snapshot.ledger.id,
          'name': snapshot.ledger.name,
          'directory': 'ledgers/${p.basename(snapshot.directory.path)}',
          'transactionCount': snapshot.transactions,
          'attachmentFileCount': copied,
        });
      }
      await _exportConfigAssets(config, contents, documents,
          prefs.getString('user_avatar_path'), missing);
      await _writeJson(contents, 'config.json', config);
      await _writeJson(contents, 'manifest.json', {
        'format': 'beecount-data-export',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'databaseSchemaVersion': _db.schemaVersion,
        'ledgers': index,
        'missingFiles': missing,
      });
      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final output = File(p.join(working.path, 'BeeCount-$timestamp.zip'));
      final sourcePath = contents.path;
      final outputPath = output.path;
      await _zipInBackground(sourcePath, outputPath);
      await contents.delete(recursive: true);
      succeeded = true;
      return FullDataExportResult(
          output, snapshots.length, fileCount, missing.length);
    } finally {
      _running = false;
      if (!succeeded && working != null) {
        await working.delete(recursive: true);
      }
    }
  }

  Future<(List<_LedgerFiles>, Map<String, Object?>)> _snapshot(
    Directory ledgersDirectory,
    Directory contents,
    Map<String, Object?> settings,
  ) async {
    final ledgers = await (_db.select(_db.ledgers)
          ..orderBy([(row) => OrderingTerm.asc(row.id)]))
        .get();
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final config = <String, Object?>{
      'settings': settings,
      'accounts': _rows(accounts),
      'categories': _rows(categories),
      'tags': _rows(await _db.select(_db.tags).get()),
      'exchangeRateOverrides':
          _rows(await _db.select(_db.exchangeRateOverrides).get()),
    };
    await _writeJson(contents, 'conversations.json', {
      'conversations': _rows(await _db.select(_db.conversations).get()),
      'messages': _rows(await _db.select(_db.messages).get()),
      'memories': _rows(await _db.select(_db.agentMemories).get()),
      'summaries':
          _rows(await _db.select(_db.agentConversationSummaries).get()),
    });
    final folderNames = <String>{};
    final snapshots = <_LedgerFiles>[];
    final accountMap = {for (final row in accounts) row.id: row};
    final categoryMap = {for (final row in categories) row.id: row.name};
    for (final ledger in ledgers) {
      final baseName = _safeName(ledger.name, 'Ledger');
      var name = baseName;
      for (var suffix = 1;
          folderNames.contains(name.toLowerCase()) ||
              await Directory(p.join(ledgersDirectory.path, name)).exists();
          suffix++) {
        name = '$baseName (${ledger.id}-$suffix)';
      }
      folderNames.add(name.toLowerCase());
      final directory =
          await Directory(p.join(ledgersDirectory.path, name)).create();
      snapshots.add(
          await _snapshotLedger(ledger, directory, accountMap, categoryMap));
    }
    return (snapshots, config);
  }

  Future<_LedgerFiles> _snapshotLedger(
    Ledger ledger,
    Directory directory,
    Map<int, Account> accounts,
    Map<int, String> categories,
  ) async {
    final syncId = ledger.syncId;
    final transactionIds = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.id])
      ..where(_db.transactions.ledgerId.equals(ledger.id));
    final transactionSyncIds = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.syncId])
      ..where(_db.transactions.ledgerId.equals(ledger.id));
    final sharedAccounts = syncId == null
        ? <SharedLedgerAccount>[]
        : await (_db.select(_db.sharedLedgerAccounts)
              ..where((row) => row.ledgerSyncId.equals(syncId)))
            .get();
    final sharedCategories = syncId == null
        ? <SharedLedgerCategory>[]
        : await (_db.select(_db.sharedLedgerCategories)
              ..where((row) => row.ledgerSyncId.equals(syncId)))
            .get();
    await _writeJson(directory, 'ledger.json', {
      'ledger': ledger.toJson(),
      'recurringTransactions': _rows(
          await (_db.select(_db.recurringTransactions)
                ..where((row) => row.ledgerId.equals(ledger.id)))
              .get()),
      'budgets': _rows(await (_db.select(_db.budgets)
            ..where((row) => row.ledgerId.equals(ledger.id)))
          .get()),
      'transactionTags': _rows(await (_db.select(_db.transactionTags)
            ..where((row) => row.transactionId.isInQuery(transactionIds)))
          .get()),
      'transactionTagOverrides': _rows(await (_db
              .select(_db.transactionTagOverrides)
            ..where(
                (row) => row.transactionSyncId.isInQuery(transactionSyncIds)))
          .get()),
      'sharedAccounts': _rows(sharedAccounts),
      'sharedCategories': _rows(sharedCategories),
      if (syncId != null)
        'sharedTags': _rows(await (_db.select(_db.sharedLedgerTags)
              ..where((row) => row.ledgerSyncId.equals(syncId)))
            .get()),
      if (syncId != null)
        'members': _rows(await (_db.select(_db.ledgerMembers)
              ..where((row) => row.ledgerSyncId.equals(syncId)))
            .get()),
    });
    final attachments = await (_db.select(_db.transactionAttachments)
          ..where((row) => row.transactionId.isInQuery(transactionIds))
          ..orderBy([(row) => OrderingTerm.asc(row.id)]))
        .get();
    final count = await _writeTransactions(
      directory,
      ledger,
      accounts,
      categories,
      {for (final row in sharedAccounts) row.syncId: row},
      {for (final row in sharedCategories) row.syncId: row.name},
    );
    return (
      ledger: ledger,
      directory: directory,
      transactions: count,
      attachments: attachments
    );
  }

  Future<int> _writeTransactions(
    Directory directory,
    Ledger ledger,
    Map<int, Account> accounts,
    Map<int, String> categories,
    Map<String, SharedLedgerAccount> sharedAccounts,
    Map<String, String> sharedCategories,
  ) async {
    const csv = ListToCsvConverter(eol: '\r\n');
    final jsonSink =
        File(p.join(directory.path, 'transactions.json')).openWrite();
    final csvSink =
        File(p.join(directory.path, 'transactions.csv')).openWrite();
    var count = 0;
    int? cursor;
    try {
      jsonSink.write('[');
      csvSink.write('\uFEFF');
      csvSink.write(csv.convert([
        [
          'id',
          'date',
          'type',
          'amount',
          'currency',
          'ledgerAmount',
          'category',
          'account',
          'toAccount',
          'note',
        ]
      ]));
      csvSink.write('\r\n');
      while (true) {
        final lastId = cursor;
        final rows = await (_db.select(_db.transactions)
              ..where((row) =>
                  row.ledgerId.equals(ledger.id) &
                  (lastId == null
                      ? const Constant(true)
                      : row.id.isBiggerThanValue(lastId)))
              ..orderBy([(row) => OrderingTerm.asc(row.id)])
              ..limit(500))
            .get();
        if (rows.isEmpty) break;
        for (final row in rows) {
          if (count++ > 0) jsonSink.write(',');
          jsonSink.write(jsonEncode(row.toJson()));
          final account = accounts[row.accountId];
          final shared = sharedAccounts[row.accountSyncIdOverride];
          csvSink.write(csv.convert([
            [
              row.id,
              row.happenedAt.toUtc().toIso8601String(),
              _csvText(row.type),
              row.amount,
              _csvText(row.currencyCode ??
                  account?.currency ??
                  shared?.currency ??
                  ledger.currency),
              row.nativeAmount ?? row.amount,
              _csvText(categories[row.categoryId] ??
                  sharedCategories[row.categorySyncIdOverride]),
              _csvText(account?.name ?? shared?.name),
              _csvText(accounts[row.toAccountId]?.name ??
                  sharedAccounts[row.toAccountSyncIdOverride]?.name),
              _csvText(row.note),
            ]
          ]));
          csvSink.write('\r\n');
        }
        cursor = rows.last.id;
        await Future.wait([jsonSink.flush(), csvSink.flush()]);
      }
      jsonSink.write(']');
    } finally {
      await Future.wait([jsonSink.close(), csvSink.close()]);
    }
    return count;
  }

  Future<int> _exportAttachments(
    _LedgerFiles snapshot,
    Directory documents,
    List<Map<String, Object?>> missing,
  ) async {
    final directory =
        await Directory(p.join(snapshot.directory.path, 'attachments'))
            .create();
    final records = <Map<String, Object?>>[];
    final paths = <String, String>{};
    final original = Directory(p.join(documents.path, 'attachments'));
    for (final attachment in snapshot.attachments) {
      final lookup = attachment.fileName;
      var archived = paths[lookup];
      if (archived == null) {
        final name = '${attachment.id}_${_safeName(lookup, 'image')}';
        final destination = File(p.join(directory.path, name));
        if (await _copyFile(original, lookup, destination) ||
            await _download(attachment, destination)) {
          archived = 'attachments/$name';
          paths[lookup] = archived;
        }
      }
      if (archived == null) {
        missing.add({
          'kind': 'attachment',
          'ledgerId': snapshot.ledger.id,
          'transactionId': attachment.transactionId,
          'fileName': lookup
        });
      }
      records.add({...attachment.toJson(), 'archivePath': archived});
    }
    await _writeJson(snapshot.directory, 'attachments.json', records);
    return paths.length;
  }

  Future<bool> _download(
      TransactionAttachment attachment, File destination) async {
    final cloudId = attachment.cloudFileId;
    if (cloudId == null || _downloadAttachment == null) return false;
    Uint8List? bytes;
    try {
      bytes = await _downloadAttachment(cloudId)
          .timeout(const Duration(seconds: 30));
    } on Exception {
      return false;
    }
    if (bytes == null || bytes.isEmpty) return false;
    final expected = attachment.cloudSha256;
    if (expected != null &&
        expected.isNotEmpty &&
        sha256.convert(bytes).toString() != expected.toLowerCase()) {
      return false;
    }
    await destination.writeAsBytes(bytes);
    return true;
  }

  static Future<void> _exportConfigAssets(
    Map<String, Object?> config,
    Directory contents,
    Directory documents,
    String? avatar,
    List<Map<String, Object?>> missing,
  ) async {
    final icons = Directory(p.join(documents.path, 'custom_icons'));
    final categories = config['categories']! as List<Map<String, dynamic>>;
    final exported = <String, String>{};
    for (final category in categories) {
      final path = category['customIconPath'] as String?;
      if (path == null || path.isEmpty) continue;
      final name = p.basename(path);
      var relative = exported[name];
      if (relative == null) {
        final archiveName = '${category['id']}_${_safeName(name, 'icon')}';
        final target = 'assets/custom_icons/$archiveName';
        if (await _copyFile(icons, name, File(p.join(contents.path, target)))) {
          relative = target;
          exported[name] = target;
        } else {
          missing.add({
            'kind': 'categoryIcon',
            'categoryId': category['id'],
            'fileName': name
          });
        }
      }
      category['customIconPath'] = relative;
    }
    if (avatar != null && avatar.isNotEmpty) {
      final name = p.basename(avatar);
      final target = 'assets/avatar/${_safeName(name, 'avatar')}';
      if (await _copyFile(Directory(p.join(documents.path, 'avatars')), name,
          File(p.join(contents.path, target)))) {
        config['avatar'] = target;
      } else {
        missing.add({'kind': 'avatar', 'fileName': name});
      }
    }
  }

  static Future<bool> _copyFile(
      Directory source, String name, File destination) async {
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.contains('/') ||
        name.contains('\\') ||
        name.contains('\u0000') ||
        await FileSystemEntity.type(source.path, followLinks: false) !=
            FileSystemEntityType.directory) {
      return false;
    }
    final file = File(p.join(source.path, name));
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() == 0) {
      return false;
    }
    await destination.parent.create(recursive: true);
    await file.copy(destination.path);
    return true;
  }

  static String _safeName(String value, String fallback) {
    var name =
        value.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]'), '_').trim();
    name = name.replaceAll(RegExp(r'^\.+|[.\s]+$'), '');
    if (name.isEmpty) return fallback;
    if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)',
            caseSensitive: false)
        .hasMatch(name)) {
      name = '_$name';
    }
    return String.fromCharCodes(name.runes.take(55))
        .replaceFirst(RegExp(r'[.\s]+$'), '');
  }

  static String _csvText(String? value) {
    if (value == null) return '';
    return RegExp(r'^\s*[=+\-@]|^[\t\r\n]').hasMatch(value) ? "'$value" : value;
  }

  static List<Map<String, dynamic>> _rows(Iterable<DataClass> rows) =>
      rows.map((row) => row.toJson()).toList();

  static Future<void> _writeJson(
      Directory root, String name, Object data) async {
    await File(p.join(root.path, name)).writeAsString(jsonEncode(data));
  }

  static Future<void> _zipInBackground(String source, String output) =>
      Isolate.run(() => _encodeZip(source, output));

  static Future<void> _encodeZip(String source, String output) async {
    final zip = ZipFileEncoder()..create(output);
    try {
      await for (final entry
          in Directory(source).list(recursive: true, followLinks: false)) {
        if (entry is! File) continue;
        final name = p.split(p.relative(entry.path, from: source)).join('/');
        await zip.addFile(
            entry,
            name,
            name.endsWith('.json') || name.endsWith('.csv')
                ? ZipFileEncoder.GZIP
                : ZipFileEncoder.STORE);
      }
    } finally {
      await zip.close();
    }
  }
}
