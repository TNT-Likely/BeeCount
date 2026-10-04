import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:beecount/services/ai/billing_image_service.dart';
import 'package:beecount/utils/image_file_info.dart';

class _Picker extends Mock implements ImagePicker {}

class _Compressor extends UnsupportedFlutterImageCompress {
  int calls = 0;
  bool fail = false;

  @override
  Future<Uint8List> compressWithList(Uint8List bytes,
      {int minWidth = 1920,
      int minHeight = 1080,
      int inSampleSize = 1,
      int quality = 95,
      int rotate = 0,
      bool autoCorrectionAngle = true,
      CompressFormat format = CompressFormat.jpeg,
      bool keepExif = false}) async {
    calls++;
    expect(quality, 85);
    expect(format, CompressFormat.jpeg);
    if (fail) throw StateError('compression failed');
    // Retain the real resized PNG so assertions inspect the decoded dimensions.
    return bytes;
  }
}

Future<Uint8List> _png(int width, int height) async {
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
  late _Picker picker;
  late _Compressor compressor;
  late FlutterImageCompressPlatform previousCompressor;
  late BillingImageService service;

  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('beecount-billing-image-');
    picker = _Picker();
    compressor = _Compressor();
    previousCompressor = FlutterImageCompressPlatform.instance;
    FlutterImageCompressPlatform.instance = compressor;
    service = BillingImageService(
        picker: picker, temporaryDirectory: () async => directory);
  });

  tearDown(() async {
    FlutterImageCompressPlatform.instance = previousCompressor;
    await directory.delete(recursive: true);
  });

  for (final source in ImageSource.values) {
    test('$source picker switches compression immediately', () async {
      final file = await File('${directory.path}/source.png')
          .writeAsBytes(await _png(100, 5000));
      when(() => picker.pickImage(
            source: any(named: 'source'),
            maxWidth: any(named: 'maxWidth'),
            maxHeight: any(named: 'maxHeight'),
            imageQuality: any(named: 'imageQuality'),
          )).thenAnswer((_) async => XFile(file.path));

      await service.pickImage(source, keepOriginal: false);
      await service.pickImage(source, keepOriginal: true);
      await service.pickImage(source, keepOriginal: false);
      verify(() => picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85)).called(2);
      verify(() => picker.pickImage(source: source)).called(1);
    });
  }

  for (final size in [
    (width: 100, height: 5000),
    (width: 5000, height: 100),
    (width: 500, height: 600),
    (width: 1, height: 5000),
  ]) {
    test(
        'original ${size.width} × ${size.height} has a separate bounded AI copy',
        () async {
      final bytes = await _png(size.width, size.height);
      final original =
          await File('${directory.path}/source.png').writeAsBytes(bytes);
      final images = await service.prepare(original, keepOriginal: true);
      expect(images.attachment.path, original.path);
      expect(images.recognition.path, isNot(original.path));
      final info = await ImageFileInfo.fromFile(images.recognition);
      expect(info.width, lessThanOrEqualTo(1920));
      expect(info.height, lessThanOrEqualTo(1920));
      if (size.width <= 1920 && size.height <= 1920) {
        expect(info.width, size.width);
        expect(info.height, size.height);
      }
      expect(await original.readAsBytes(), bytes);
      expect(compressor.calls, 1);
      await images.dispose();
      expect(await images.recognition.exists(), isFalse);
      expect(await original.readAsBytes(), bytes);
    });
  }

  test('default mode reuses the compressed picker file', () async {
    final file = await File('${directory.path}/source.png')
        .writeAsBytes(await _png(100, 100));
    final images = await service.prepare(file, keepOriginal: false);
    expect(images.recognition.path, file.path);
    expect(images.attachment.path, file.path);
    expect(compressor.calls, 0);
    await images.dispose();
    expect(await file.exists(), isTrue);
  });

  test('failed AI copy leaves the source intact and removes temporary files',
      () async {
    final bytes = await _png(100, 5000);
    final file = await File('${directory.path}/source.png').writeAsBytes(bytes);
    compressor.fail = true;
    await expectLater(
        service.prepare(file, keepOriginal: true), throwsA(isA<StateError>()));
    expect(await file.readAsBytes(), bytes);
    expect(await directory.list().where((item) => item is Directory).toList(),
        isEmpty);
  });
}
