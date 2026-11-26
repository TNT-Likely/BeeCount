import 'dart:async';
import 'dart:ui' show Locale;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _ciVersion = String.fromEnvironment('CI_VERSION');
const _metadataTimeout = Duration(milliseconds: 800);

String supportVersionLabel(
  PackageInfo? package, {
  String ciVersion = _ciVersion,
  bool includeBuildNumber = false,
}) {
  var version = ciVersion.trim();
  final packageVersion = package?.version.trim() ?? '';
  if (version.isEmpty && packageVersion.isNotEmpty) {
    version = 'dev-$packageVersion';
  }
  final build = package?.buildNumber.trim() ?? '';
  if (version.isNotEmpty &&
      build.isNotEmpty &&
      (includeBuildNumber || version.startsWith('dev-')) &&
      !version.endsWith(' ($build)') &&
      !version.endsWith('+$build')) {
    return '$version ($build)';
  }
  return version;
}

typedef FeedbackDevice = ({String? osVersion, String? model});

enum FeedbackKind {
  bug('01-bug_report_zh.yml', '04-bug_report_en.yml'),
  question('03-question_zh.yml', '06-question_en.yml'),
  feature('02-feature_request_zh.yml', '05-feature_request_en.yml');

  const FeedbackKind(this._chineseTemplate, this._englishTemplate);
  final String _chineseTemplate;
  final String _englishTemplate;

  String templateFor(Locale locale) =>
      locale.languageCode == 'zh' ? _chineseTemplate : _englishTemplate;
}

Future<FeedbackDevice> _readMobileDevice() async {
  final plugin = DeviceInfoPlugin();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final android = await plugin.androidInfo;
    final release = android.version.release.trim();
    return (
      osVersion: release.isEmpty ? null : 'Android $release',
      model: android.model.trim(),
    );
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    final ios = await plugin.iosInfo;
    final release = ios.systemVersion.trim();
    final system =
        ios.systemName.trim().isEmpty ? 'iOS' : ios.systemName.trim();
    final model = ios.modelName.trim();
    // New hardware may not have a marketing name in this plugin version.
    return (
      osVersion: release.isEmpty ? null : '$system $release',
      model: model.isEmpty || model == 'Unknown device'
          ? ios.utsname.machine.trim()
          : model,
    );
  }
  return (osVersion: null, model: null);
}

Future<T?> _readOptional<T>(Future<T> Function() read) async {
  try {
    return await read().timeout(_metadataTimeout);
  } catch (_) {
    return null;
  }
}

/// Open the selected issue form with only the fields that it declares.
Future<Uri> githubFeedbackUri({
  required FeedbackKind kind,
  required Locale locale,
  Future<PackageInfo> Function() readPackage = PackageInfo.fromPlatform,
  Future<FeedbackDevice> Function() readDevice = _readMobileDevice,
  String ciVersion = _ciVersion,
}) async {
  final fields = {'template': kind.templateFor(locale)};
  if (kind != FeedbackKind.feature) {
    final (package, device) = await (
      _readOptional(readPackage),
      kind == FeedbackKind.bug
          ? _readOptional(readDevice)
          : Future<FeedbackDevice?>.value(),
    ).wait;
    final version = supportVersionLabel(package,
        ciVersion: ciVersion, includeBuildNumber: true);
    final os = device?.osVersion?.trim() ?? '';
    final model = device?.model?.trim() ?? '';
    if (version.isNotEmpty) fields['app_version'] = version;
    if (os.isNotEmpty) fields['os_version'] = os;
    if (model.isNotEmpty) fields['device'] = model;
  }
  return Uri.https('github.com', '/TNT-Likely/BeeCount/issues/new', fields);
}
