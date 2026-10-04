import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/attachment_service.dart';

class _MockImagePicker extends Mock implements ImagePicker {}

class _Compressor extends UnsupportedFlutterImageCompress {
  final Uint8List output;
  final calls = <({int width, int height, int quality})>[];

  _Compressor(this.output);

  @override
  Future<XFile?> compressAndGetFile(
    String path,
    String targetPath, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async {
    calls.add((width: minWidth, height: minHeight, quality: quality));
    await File(targetPath).writeAsBytes(output);
    return XFile(targetPath);
  }
}

class _TestAttachmentService extends AttachmentService {
  final Directory directory;

  _TestAttachmentService(super.ref, this.directory, ImagePicker picker)
      : super(picker: picker);

  @override
  Future<Directory> getAttachmentDirectory() async =>
      Directory('${directory.path}/attachments')..createSync();

  @override
  Future<Directory> getThumbnailDirectory() async =>
      Directory('${directory.path}/thumbs')..createSync();
}

Future<Uint8List> png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawPaint(ui.Paint()..color = const ui.Color(0xFF123456));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(ImageSource.camera);

  late Directory directory;
  late BeeDatabase db;
  late ProviderContainer container;
  late _MockImagePicker picker;
  late _Compressor compressor;
  late FlutterImageCompressPlatform previousCompressor;
  late File source;
  late Uint8List originalBytes;
  late Uint8List compressedBytes;
  late int transactionId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('beecount-attachments-');
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement(
      "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')",
    );
    transactionId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: 1,
            type: 'expense',
            amount: 100,
            happenedAt: Value(DateTime(2026, 1, 1)),
          ),
        );
    originalBytes = await png(100, 5000);
    compressedBytes = await png(20, 200);
    source = await File('${directory.path}/long-receipt.png')
        .writeAsBytes(originalBytes);
    picker = _MockImagePicker();
    when(() => picker.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => [XFile(source.path)]);
    when(() => picker.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => XFile(source.path));
    compressor = _Compressor(compressedBytes);
    previousCompressor = FlutterImageCompressPlatform.instance;
    FlutterImageCompressPlatform.instance = compressor;
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(LocalRepository(db)),
      attachmentServiceProvider.overrideWith(
        (ref) => _TestAttachmentService(ref, directory, picker),
      ),
    ]);
  });

  tearDown(() async {
    container.dispose();
    FlutterImageCompressPlatform.instance = previousCompressor;
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> keepOriginal(bool enabled) async {
    await container.read(attachmentKeepOriginalProvider.future);
    await container
        .read(attachmentKeepOriginalProvider.notifier)
        .setEnabled(enabled);
  }

  test('default compression is retained for gallery, camera and saved files',
      () async {
    final service = container.read(attachmentServiceProvider);
    await service.pickFromGallery();
    await service.takePhoto();
    verify(() => picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 80,
        )).called(1);
    verify(() => picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 80,
        )).called(1);

    final saved = await service.saveAttachment(
      transactionId: transactionId,
      sourceFile: source,
      index: 0,
    );
    expect(saved, isNotNull);
    expect(compressor.calls, [(width: 1920, height: 1920, quality: 80)]);
    expect(saved!.width, 20);
    expect(saved.height, 200);
    final file = File(await service.getAttachmentPath(saved.fileName));
    expect(await file.readAsBytes(), compressedBytes);
    expect(await source.readAsBytes(), originalBytes);
  });

  test(
      'original mode disables gallery and camera resizing and quality reduction',
      () async {
    await keepOriginal(true);
    final service = container.read(attachmentServiceProvider);
    await service.pickFromGallery();
    await service.takePhoto();
    verify(() => picker.pickMultiImage()).called(1);
    verify(() => picker.pickImage(source: ImageSource.camera)).called(1);
  });

  test('original long image retains bytes, dimensions, extension and metadata',
      () async {
    // Simulate a restart with the persisted setting before the first service call.
    SharedPreferences.setMockInitialValues({
      AttachmentKeepOriginalNotifier.preferenceKey: true,
    });
    final service = container.read(attachmentServiceProvider);
    final saved = await service.saveAttachment(
      transactionId: transactionId,
      sourceFile: source,
      index: 2,
    );
    expect(saved, isNotNull);
    expect(compressor.calls, isEmpty);
    expect(saved!.fileName, 'sha_${sha256.convert(originalBytes)}.png');
    expect(saved.originalName, 'long-receipt.png');
    expect(saved.fileSize, originalBytes.length);
    expect(saved.width, 100);
    expect(saved.height, 5000);
    expect(saved.sortOrder, 2);
    expect(
        await File(await service.getAttachmentPath(saved.fileName))
            .readAsBytes(),
        originalBytes);
    expect(await source.readAsBytes(), originalBytes);
  });

  test(
      'original attachment deduplication retains shared files until last removal',
      () async {
    await keepOriginal(true);
    final service = container.read(attachmentServiceProvider);
    final results = await service.saveAttachments(
      transactionId: transactionId,
      sourceFiles: [source, source],
    );
    expect(results, hasLength(2));
    expect(results[0].fileName, results[1].fileName);
    expect(results.map((a) => a.sortOrder), [0, 1]);
    final file = File(await service.getAttachmentPath(results[0].fileName));
    await service.deleteAttachment(results[0].id);
    expect(await file.readAsBytes(), originalBytes);
    await service.deleteAttachment(results[1].id);
    expect(await file.exists(), isFalse);
    expect(await source.exists(), isTrue);
  });

  test('thumbnails still use a small cached copy without altering the original',
      () async {
    await keepOriginal(true);
    final service = container.read(attachmentServiceProvider);
    final saved = await service.saveAttachment(
      transactionId: transactionId,
      sourceFile: source,
      index: 0,
    );
    final thumb = await service.getThumbnailPath(saved!.fileName);
    expect(thumb, isNotNull);
    expect(compressor.calls, [(width: 200, height: 200, quality: 70)]);
    expect(
        await File(await service.getAttachmentPath(saved.fileName))
            .readAsBytes(),
        originalBytes);
    await service.getThumbnailPath(saved.fileName);
    expect(compressor.calls, hasLength(1));
  });

  test('switching off restores compression for subsequent attachments',
      () async {
    await keepOriginal(true);
    final service = container.read(attachmentServiceProvider);
    final original = await service.saveAttachment(
        transactionId: transactionId, sourceFile: source, index: 0);
    await keepOriginal(false);
    final compressed = await service.saveAttachment(
        transactionId: transactionId, sourceFile: source, index: 1);
    expect(original!.fileName, isNot(compressed!.fileName));
    expect(original.height, 5000);
    expect(compressed.height, 200);
    expect(compressor.calls, hasLength(1));
    expect(
        await File(await service.getAttachmentPath(original.fileName))
            .readAsBytes(),
        originalBytes);
  });

  test('urgent saves bypass compression regardless of the setting', () async {
    final service = container.read(attachmentServiceProvider);
    final saved = await service.saveAttachment(
        transactionId: transactionId,
        sourceFile: source,
        index: 0,
        urgent: true);
    expect(saved, isNotNull);
    expect(compressor.calls, isEmpty);
    expect(saved!.width, isNull);
    expect(saved.height, isNull);
    expect(
        await File(await service.getAttachmentPath(saved.fileName))
            .readAsBytes(),
        originalBytes);
  });
}
