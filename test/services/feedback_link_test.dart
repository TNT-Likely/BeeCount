import 'dart:async';

import 'package:beecount/pages/settings/support/bindings/feedback_link.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final package = PackageInfo(
      appName: 'QA',
      packageName: 'qa.beecount',
      version: '0.0.1',
      buildNumber: '412');
  const device = (osVersion: 'Android 15', model: '测试机 A&B+');
  const chooser = 'https://github.com/TNT-Likely/BeeCount/issues/new/choose';

  test('the chooser uses the common form IDs and URL-encodes field values',
      () async {
    final uri = await githubFeedbackUri(
        readPackage: () async => package,
        readDevice: () async => device,
        ciVersion: '4.0.1');
    expect(uri.toString().split('?').first, chooser);
    expect(Uri.parse(uri.toString()).queryParameters, {
      'app_version': '4.0.1 (412)',
      'os_version': 'Android 15',
      'device': '测试机 A&B+',
    });
    expect(supportVersionLabel(package, ciVersion: ''), 'dev-0.0.1 (412)');
    expect(supportVersionLabel(package, ciVersion: '4.0.1'), '4.0.1');
    expect(
        supportVersionLabel(package,
            ciVersion: '4.0.1+412', includeBuildNumber: true),
        '4.0.1+412');
  });

  test('missing fields still open the chooser with any available metadata',
      () async {
    final partial = await githubFeedbackUri(
        readPackage: () => throw const FormatException(),
        readDevice: () async => (osVersion: 'iOS 18.2', model: '  '),
        ciVersion: '4.0.1');
    expect(partial.queryParameters, {
      'app_version': '4.0.1',
      'os_version': 'iOS 18.2',
    });
    final empty = await githubFeedbackUri(
        readPackage: () async => throw MissingPluginException(),
        readDevice: () async => throw MissingPluginException(),
        ciVersion: '');
    expect(empty.toString(), chooser);
  });

  testWidgets('a stalled device plugin cannot delay the feedback link',
      (tester) async {
    final gate = Completer<FeedbackDevice>();
    final pending = githubFeedbackUri(
        readPackage: () async => package,
        readDevice: () => gate.future,
        ciVersion: '');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect((await pending).queryParameters, {'app_version': 'dev-0.0.1 (412)'});
    gate.complete(device);
  });

  test('Android selects the OS release and model from the native payload',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('dev.fluttercommunity.plus/device_info');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
              for (final key in [
                'board',
                'bootloader',
                'brand',
                'device',
                'display',
                'fingerprint',
                'hardware',
                'host',
                'id',
                'manufacturer',
                'name',
                'product',
                'serialNumber',
                'tags',
                'type'
              ])
                key: 'private fixture',
              'version': {
                'codename': 'REL',
                'incremental': 'test',
                'previewSdkInt': 0,
                'release': '15',
                'sdkInt': 35,
              },
              'model': 'Pixel 8',
              'isPhysicalDevice': true,
              'isLowRamDevice': false,
            });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });
    final uri = await githubFeedbackUri(
        readPackage: () async => package, ciVersion: '4.0.1');
    expect(uri.queryParameters, {
      'app_version': '4.0.1 (412)',
      'os_version': 'Android 15',
      'device': 'Pixel 8',
    });
  });

  test('iOS uses a hardware model and never uses the assigned device name',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const channel = MethodChannel('dev.fluttercommunity.plus/device_info');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var modelName = 'iPhone 16 Pro';
    messenger.setMockMethodCallHandler(
        channel,
        (call) async => {
              'name': 'QA personal device name',
              'identifierForVendor': 'private-identifier',
              'systemName': 'iOS',
              'systemVersion': '18.2',
              'model': 'iPhone',
              'modelName': modelName,
              'localizedModel': 'iPhone',
              'isPhysicalDevice': true,
              'isiOSAppOnMac': false,
              'utsname': {
                'sysname': 'Darwin',
                'nodename': 'QA personal hostname',
                'release': '24',
                'version': 'QA kernel build',
                'machine': 'iPhone17,1',
              }
            });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });
    final uri = await githubFeedbackUri(
        readPackage: () async => package, ciVersion: '4.0.1');
    expect(uri.queryParameters, {
      'app_version': '4.0.1 (412)',
      'os_version': 'iOS 18.2',
      'device': 'iPhone 16 Pro',
    });
    modelName = 'Unknown device';
    final newer = await githubFeedbackUri(
        readPackage: () async => package, ciVersion: '');
    expect(newer.queryParameters['device'], 'iPhone17,1');
  });
}
