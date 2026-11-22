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
import '../../data/repositories/local/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/app_localizations_resolver.dart';
import 'config_export_service.dart' show ConfigExportService;
import 'transaction_csv_export.dart';

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

  final BeeDatabase _db;
  final Future<Directory> Function() _documents;
  final Future<Directory> Function() _temporary;
  final Future<SharedPreferences> Function() _preferences;
  final Future<Uint8List?> Function(String)? _downloadAttachment;
  bool _running = false;

  Future<FullDataExportResult> export({AppLocalizations? l10n}) async {
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
      final repository = LocalRepository(_db);
      final language = l10n ?? resolveAppLocalizations(null);
      final (snapshots, categories) = await _db.transaction(() async {
        final snapshot = await _snapshot(ledgers, repository, language);
        final config = await ConfigExportService.exportToYaml(
            repository: repository, portable: true, preferences: prefs);
        await File(p.join(contents.path, 'config.yaml')).writeAsString(config);
        return snapshot;
      });
      final missing = <Map<String, Object?>>[];
      var fileCount = 0;
      for (final snapshot in snapshots) {
        fileCount += await _exportAttachments(snapshot, documents, missing);
      }
      await _exportConfigAssets(categories, contents, documents,
          prefs.getString('user_avatar_path'), missing);
      if (missing.isNotEmpty) {
        await _writeCsv(contents, 'missing_files.csv', [
          ['kind', 'ledgerId', 'transactionId', 'fileName', 'archivePath'],
          for (final file in missing)
            [
              file['kind'],
              file['ledgerId'],
              file['transactionId'],
              file['fileName'],
              file['archivePath']
            ],
        ]);
      }
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

  Future<(List<_LedgerFiles>, List<Category>)> _snapshot(
    Directory ledgersDirectory,
    LocalRepository repository,
    AppLocalizations l10n,
  ) async {
    final ledgers = await repository.getAllLedgers();
    final folderNames = <String>{};
    final snapshots = <_LedgerFiles>[];
    for (final ledger in ledgers) {
      final base = _safeName(ledger.name, 'Ledger');
      var folder = base;
      for (var suffix = 1;
          folderNames.contains(folder.toLowerCase()) ||
              await Directory(p.join(ledgersDirectory.path, folder)).exists();
          suffix++) {
        folder = '$base (${ledger.id}-$suffix)';
      }
      folderNames.add(folder.toLowerCase());
      final directory =
          await Directory(p.join(ledgersDirectory.path, folder)).create();
      final csv = await buildTransactionExportCsv(
        repo: repository,
        ledgerId: ledger.id,
        l10n: l10n,
      );
      // Use the same UTF-8 BOM as the standalone CSV export.
      await File(p.join(directory.path, 'transactions.csv'))
          .writeAsString('\uFEFF$csv');
      final transactionIds = _db.selectOnly(_db.transactions)
        ..addColumns([_db.transactions.id])
        ..where(_db.transactions.ledgerId.equals(ledger.id));
      final attachments = await (_db.select(_db.transactionAttachments)
            ..where((row) => row.transactionId.isInQuery(transactionIds))
            ..orderBy([
              (row) => OrderingTerm.asc(row.sortOrder),
              (row) => OrderingTerm.asc(row.id)
            ]))
          .get();
      snapshots.add(
          (ledger: ledger, directory: directory, attachments: attachments));
    }
    return (snapshots, await repository.getAllCategories());
  }

  Future<int> _exportAttachments(
    _LedgerFiles snapshot,
    Directory documents,
    List<Map<String, Object?>> missing,
  ) async {
    if (snapshot.attachments.isEmpty) return 0;
    final directory =
        await Directory(p.join(snapshot.directory.path, 'images')).create();
    final copied = <String>{};
    final original = Directory(p.join(documents.path, 'attachments'));
    for (final attachment in snapshot.attachments) {
      final name = attachment.fileName;
      if (copied.contains(name) || !_safeFileName(name)) continue;
      final destination = File(p.join(directory.path, name));
      if (await _copyFile(original, name, destination) ||
          await _download(attachment, destination)) {
        copied.add(name);
      }
    }
    for (final attachment in snapshot.attachments) {
      if (!copied.contains(attachment.fileName)) {
        missing.add({
          'kind': 'attachment',
          'ledgerId': snapshot.ledger.id,
          'transactionId': attachment.transactionId,
          'fileName': attachment.fileName,
          'archivePath': _safeFileName(attachment.fileName)
              ? 'ledgers/${p.basename(snapshot.directory.path)}/images/${attachment.fileName}'
              : '',
        });
      }
    }
    return copied.length;
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
    List<Category> categories,
    Directory contents,
    Directory documents,
    String? avatar,
    List<Map<String, Object?>> missing,
  ) async {
    final icons = Directory(p.join(documents.path, 'custom_icons'));
    final checked = <String>{};
    for (final category in categories) {
      final icon = category.customIconPath;
      if (icon == null || icon.isEmpty) continue;
      final name = p.basename(icon);
      if (!checked.add(name)) continue;
      final target = 'custom_icons/$name';
      if (!await _copyFile(icons, name, File(p.join(contents.path, target)))) {
        missing.add(
            {'kind': 'categoryIcon', 'fileName': name, 'archivePath': target});
      }
    }
    if (avatar != null && avatar.isNotEmpty) {
      final name = p.basename(avatar);
      final target = 'avatar/$name';
      if (!await _copyFile(Directory(p.join(documents.path, 'avatars')), name,
          File(p.join(contents.path, target)))) {
        missing
            .add({'kind': 'avatar', 'fileName': name, 'archivePath': target});
      }
    }
  }

  static bool _safeFileName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.endsWith('.') &&
      !name.endsWith(' ') &&
      !RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]').hasMatch(name);

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

  static const _csv = ListToCsvConverter(eol: '\r\n');

  static void _writeRow(IOSink sink, List<Object?> row) {
    sink.write(_csv.convert([
      [
        for (final cell in row)
          if (cell is String) _csvText(cell) else cell ?? ''
      ],
    ]));
    sink.write('\r\n');
  }

  static Future<void> _writeCsv(
      Directory root, String name, Iterable<List<Object?>> rows) async {
    final sink = File(p.join(root.path, name)).openWrite();
    try {
      sink.write('\uFEFF');
      for (final row in rows) {
        _writeRow(sink, row);
      }
    } finally {
      await sink.close();
    }
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
            name.endsWith('.csv') || name == 'config.yaml'
                ? ZipFileEncoder.GZIP
                : ZipFileEncoder.STORE);
      }
    } finally {
      await zip.close();
    }
  }
}
