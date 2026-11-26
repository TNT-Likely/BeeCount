import 'dart:async';
import 'dart:ui' show Locale;

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
  const newIssue = 'https://github.com/TNT-Likely/BeeCount/issues/new';
  const english = Locale('en');

  test('the bug form uses its own text fields and encodes their values',
      () async {
    final uri = await githubFeedbackUri(
        kind: FeedbackKind.bug,
        locale: english,
        readPackage: () async => package,
        readDevice: () async => device,
        ciVersion: '4.0.1');
    expect(uri.toString().split('?').first, newIssue);
    expect(Uri.parse(uri.toString()).queryParameters, {
      'template': '04-bug_report_en.yml',
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

  test('each feedback kind reads only the required metadata for its template',
      () async {
    const chineseTemplates = {
      FeedbackKind.bug: '01-bug_report_zh.yml',
      FeedbackKind.question: '03-question_zh.yml',
      FeedbackKind.feature: '02-feature_request_zh.yml',
    };
    const englishTemplates = {
      FeedbackKind.bug: '04-bug_report_en.yml',
      FeedbackKind.question: '06-question_en.yml',
      FeedbackKind.feature: '05-feature_request_en.yml',
    };
    for (final language in [
      const Locale('zh'),
      const Locale('zh', 'TW'),
      english,
      const Locale('ko'),
      const Locale('ru'),
    ]) {
      final templates =
          language.languageCode == 'zh' ? chineseTemplates : englishTemplates;
      for (final kind in FeedbackKind.values) {
        var packageReads = 0, deviceReads = 0;
        final uri = await githubFeedbackUri(
          kind: kind,
          locale: language,
          readPackage: () async {
            packageReads++;
            return package;
          },
          readDevice: () async {
            deviceReads++;
            return device;
          },
          ciVersion: '4.0.1',
        );
        expect(uri.toString().split('?').first, newIssue);
        expect(uri.queryParameters, {
          'template': templates[kind],
          if (kind != FeedbackKind.feature) 'app_version': '4.0.1 (412)',
          if (kind == FeedbackKind.bug) ...{
            'os_version': 'Android 15',
            'device': '测试机 A&B+',
          },
        });
        expect(packageReads, kind == FeedbackKind.feature ? 0 : 1);
        expect(deviceReads, kind == FeedbackKind.bug ? 1 : 0);
      }
    }
  });

  test('missing fields still open the selected form with available metadata',
      () async {
    final partial = await githubFeedbackUri(
        kind: FeedbackKind.bug,
        locale: english,
        readPackage: () => throw const FormatException(),
        readDevice: () async => (osVersion: 'iOS 18.2', model: '  '),
        ciVersion: '4.0.1');
    expect(partial.queryParameters, {
      'template': '04-bug_report_en.yml',
      'app_version': '4.0.1',
      'os_version': 'iOS 18.2',
    });
    final empty = await githubFeedbackUri(
        kind: FeedbackKind.bug,
        locale: english,
        readPackage: () async => throw MissingPluginException(),
        readDevice: () async => throw MissingPluginException(),
        ciVersion: '');
    expect(empty.queryParameters, {'template': '04-bug_report_en.yml'});
  });

  testWidgets('a stalled device plugin cannot delay the feedback link',
      (tester) async {
    final gate = Completer<FeedbackDevice>();
    final pending = githubFeedbackUri(
        kind: FeedbackKind.bug,
        locale: english,
        readPackage: () async => package,
        readDevice: () => gate.future,
        ciVersion: '');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect((await pending).queryParameters, {
      'template': '04-bug_report_en.yml',
      'app_version': 'dev-0.0.1 (412)',
    });
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
        kind: FeedbackKind.bug,
        locale: english,
        readPackage: () async => package,
        ciVersion: '4.0.1');
    expect(uri.queryParameters, {
      'template': '04-bug_report_en.yml',
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
        kind: FeedbackKind.bug,
        locale: english,
        readPackage: () async => package,
        ciVersion: '4.0.1');
    expect(uri.queryParameters, {
      'template': '04-bug_report_en.yml',
      'app_version': '4.0.1 (412)',
      'os_version': 'iOS 18.2',
      'device': 'iPhone 16 Pro',
    });
    modelName = 'Unknown device';
    final newer = await githubFeedbackUri(
        kind: FeedbackKind.bug,
        locale: english,
        readPackage: () async => package,
        ciVersion: '');
    expect(newer.queryParameters['device'], 'iPhone17,1');
  });
}
