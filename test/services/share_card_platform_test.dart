import 'dart:io';

import 'package:beecount/presentation/v4/bindings/share_card_platform.dart';
import 'package:beecount/services/export/share_poster_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const galleryChannel = MethodChannel('gal');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('beecount-share-card-unit-');
    messenger.setMockMethodCallHandler(
        pathChannel, (_) async => directory.path);
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(pathChannel, null);
    messenger.setMockMethodCallHandler(shareChannel, null);
    messenger.setMockMethodCallHandler(galleryChannel, null);
    await directory.delete(recursive: true);
  });
  for (final entry in {
    '': ShareResultStatus.dismissed,
    'dev.fluttercommunity.plus/share/unavailable':
        ShareResultStatus.unavailable,
    'QA activity': ShareResultStatus.success
  }.entries) {
    test('original temporary PNG contract and ${entry.value.name}', () async {
      Map<Object?, Object?>? arguments;
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        expect(call.method, 'share');
        arguments = Map<Object?, Object?>.from(call.arguments as Map);
        return entry.key;
      });
      final status = await const ShareCardPlatform()
          .share(bytes, const Rect.fromLTWH(10, 20, 100, 44));
      expect(status, entry.value);
      final path = (arguments!['paths'] as List).single as String;
      expect(File(path).parent.path, directory.path);
      expect(path.split('/').last, matches(r'^beecount_share_\d+\.png$'));
      expect(await File(path).readAsBytes(), bytes);
      expect(arguments!['mimeTypes'], ['image/png']);
      expect(arguments!['text'], isNotEmpty);
      expect(arguments!['originWidth'], 100);
      expect(arguments!['originHeight'], 44);
    });
  }
  test('legacy share API silently catches errors; new adapter receives them',
      () async {
    messenger.setMockMethodCallHandler(
        shareChannel, (_) async => throw PlatformException(code: 'QA_FAILURE'));
    await SharePosterService.sharePoster(bytes);
    await expectLater(
        const ShareCardPlatform()
            .share(bytes, const Rect.fromLTWH(0, 0, 44, 44)),
        throwsA(isA<PlatformException>()));
  });
  for (final code in [null, 'ACCESS_DENIED', 'NOT_ENOUGH_SPACE']) {
    test('Gal keeps permission/save result ${code ?? 'success'}', () async {
      messenger.setMockMethodCallHandler(galleryChannel, (call) async {
        if (call.method == 'requestAccess') return true;
        expect(call.method, 'putImageBytes');
        expect((call.arguments as Map)['bytes'], bytes);
        if (code != null) throw PlatformException(code: code);
        return null;
      });
      expect(
          await SharePosterService.savePosterToGallery(bytes),
          code == null
              ? SavePosterResult.success
              : code == 'ACCESS_DENIED'
                  ? SavePosterResult.accessDenied
                  : SavePosterResult.failed);
    });
  }
}
