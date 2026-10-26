import 'package:beecount/presentation/v4/bindings/support_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  test('About keeps CI fallback dev-version and build number', () async {
    PackageInfo.setMockInitialValues(
        appName: 'QA',
        packageName: 'qa.beecount',
        version: '9.2.0',
        buildNumber: '123',
        buildSignature: 'qa');
    expect(await const SupportPlatform().version(), 'dev-9.2.0 (123)');
  });
  test(
      'shortcut copy writes the complete original deep link to native clipboard',
      () async {
    String? value;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      expect(call.method, 'Clipboard.setData');
      value = (call.arguments as Map)['text'] as String;
      return null;
    });
    try {
      await const SupportPlatform().copy('beecount://new?type=transfer');
      expect(value, 'beecount://new?type=transfer');
    } finally {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    }
  });
  test('About original URL launch fallback probes and opens the exact URI',
      () async {
    var probes = 0;
    String? opened;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      if (call.method == 'canLaunch') return ++probes >= 3;
      opened = args['url'] as String;
      return true;
    });
    try {
      expect(
          await const SupportPlatform()
              .open(Uri.parse('https://github.com/TNT-Likely/BeeCount/issues')),
          isTrue);
      expect(probes, 3);
      expect(opened, 'https://github.com/TNT-Likely/BeeCount/issues');
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });
}
