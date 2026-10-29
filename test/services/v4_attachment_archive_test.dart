import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:beecount/services/attachment_export_import_service.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OwnedAttachments extends AttachmentService {
  _OwnedAttachments(super.ref, this.root);
  final Directory root;
  @override
  Future<Directory> getAttachmentDirectory() async =>
      Directory('${root.path}/attachments')..createSync();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late BeeDatabase db;
  late ProviderContainer container;
  late File attachment, icon, avatar;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('beecount-v4-archive-widget-');
    SharedPreferences.setMockInitialValues(
        {'user_avatar_path': 'avatars/qa.png'});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => root.path);
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'归档验收','CNY')");
    final tx = await db.into(db.transactions).insert(
        TransactionsCompanion.insert(ledgerId: 1, type: 'expense', amount: 12));
    for (final dir in ['attachments', 'custom_icons', 'avatars']) {
      Directory('${root.path}/$dir').createSync();
    }
    final bytes =
        File('test/fixtures/design/category-coffee.png').readAsBytesSync();
    attachment = File('${root.path}/attachments/qa-receipt.png')
      ..writeAsBytesSync(bytes);
    icon = File('${root.path}/custom_icons/qa-icon.png')
      ..writeAsBytesSync(bytes);
    avatar = File('${root.path}/avatars/qa.png')..writeAsBytesSync(bytes);
    await db.into(db.transactionAttachments).insert(
        TransactionAttachmentsCompanion.insert(
            transactionId: tx,
            fileName: 'qa-receipt.png',
            originalName: const Value('receipt.png'),
            fileSize: Value(bytes.length)));
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(LocalRepository(db)),
      attachmentServiceProvider
          .overrideWith((ref) => _OwnedAttachments(ref, root))
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    await root.delete(recursive: true);
  });
  test('真实归档服务保留附件元数据、图标、头像和进度，跳过/覆盖及缺文件恢复不改账单', () async {
    final service = container.read(attachmentExportImportServiceProvider),
        before = await db.select(db.transactions).get();
    final digest = sha256.convert(attachment.readAsBytesSync()).toString();
    final progress = <List<int>>[];
    final output = await service.exportAttachments(
        onProgress: (done, total) => progress.add([done, total]));
    expect(output, isNotNull);
    expect(output!.startsWith(root.path), isTrue);
    final archive = TarDecoder()
        .decodeBytes(GZipDecoder().decodeBytes(File(output).readAsBytesSync()));
    final metadata = jsonDecode(utf8.decode(
        archive.findFile('metadata.json')!.content as List<int>)) as Map;
    expect(metadata['count'], 1);
    expect(metadata['customIcons'], ['qa-icon.png']);
    expect(metadata['avatar'], 'qa.png');
    expect((metadata['attachments'] as List).single['transactionId'],
        before.single.id);
    expect(archive.findFile('images/qa-receipt.png'), isNotNull);
    expect(archive.findFile('custom_icons/qa-icon.png'), isNotNull);
    expect(archive.findFile('avatar/qa.png'), isNotNull);
    expect(progress.last, [2, 2]);
    final info = await service.previewArchive(output);
    expect(info!.count, 1);
    expect(info.customIconCount, 1);
    expect(info.hasAvatar, isTrue);
    final preview = await service.getArchivePreviewImages(output);
    expect(preview.attachments, hasLength(1));
    expect(preview.customIcons, hasLength(1));
    final skip = await service.importAttachments(
        archivePath: output,
        conflictStrategy: AttachmentExportImportService.conflictSkip);
    expect(skip.success, isTrue);
    expect(skip.skipped, 1);
    expect(skip.customIconsSkipped, 1);
    expect(sha256.convert(attachment.readAsBytesSync()).toString(), digest);
    attachment.writeAsBytesSync([1, 2]);
    icon.writeAsBytesSync([3, 4]);
    final overwrite = await service.importAttachments(
        archivePath: output,
        conflictStrategy: AttachmentExportImportService.conflictOverwrite);
    expect(overwrite.success, isTrue);
    expect(overwrite.overwritten, 1);
    expect(overwrite.customIconsImported, 1);
    expect(sha256.convert(attachment.readAsBytesSync()).toString(), digest);
    expect(sha256.convert(icon.readAsBytesSync()).toString(), digest);
    expect(avatar.existsSync(), isTrue);
    attachment.deleteSync();
    final restore = await service.importAttachments(
        archivePath: output,
        conflictStrategy: AttachmentExportImportService.conflictSkip);
    expect(restore.skipped, 1, reason: '原跳过策略同时考虑数据库记录，缺文件但记录还在也跳过');
    expect(attachment.existsSync(), isFalse);
    final repaired = await service.importAttachments(
        archivePath: output,
        conflictStrategy: AttachmentExportImportService.conflictOverwrite);
    expect(repaired.overwritten, 1);
    expect(repaired.imported, 1);
    expect(sha256.convert(attachment.readAsBytesSync()).toString(), digest);
    expect(await db.select(db.transactions).get(), before);
  });
  test('缺失、损坏归档的失败不改已有附件与真实账单', () async {
    final service = container.read(attachmentExportImportServiceProvider),
        before = attachment.readAsBytesSync();
    final invalid = File('${root.path}/invalid.tar.gz')
      ..writeAsBytesSync([1, 2, 3]);
    expect(await service.previewArchive(invalid.path), isNull);
    expect(
        (await service.getArchivePreviewImages(invalid.path)).isEmpty, isTrue);
    expect(
        (await service.importAttachments(
                archivePath: invalid.path,
                conflictStrategy: AttachmentExportImportService.conflictSkip))
            .success,
        isFalse);
    expect(
        (await service.importAttachments(
                archivePath: '${root.path}/missing.tar.gz',
                conflictStrategy: AttachmentExportImportService.conflictSkip))
            .success,
        isFalse);
    expect(attachment.readAsBytesSync(), before);
    expect(await db.select(db.transactions).get(), hasLength(1));
  });
}
