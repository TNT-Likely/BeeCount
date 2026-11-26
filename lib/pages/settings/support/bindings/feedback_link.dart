import 'dart:async';

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

/// GitHub's chooser passes these text-field IDs to the selected issue form.
Future<Uri> githubFeedbackUri({
  Future<PackageInfo> Function() readPackage = PackageInfo.fromPlatform,
  Future<FeedbackDevice> Function() readDevice = _readMobileDevice,
  String ciVersion = _ciVersion,
}) async {
  final (package, device) =
      await (_readOptional(readPackage), _readOptional(readDevice)).wait;
  final version = supportVersionLabel(package,
      ciVersion: ciVersion, includeBuildNumber: true);
  final os = device?.osVersion?.trim() ?? '';
  final model = device?.model?.trim() ?? '';
  final fields = {
    if (version.isNotEmpty) 'app_version': version,
    if (os.isNotEmpty) 'os_version': os,
    if (model.isNotEmpty) 'device': model,
  };
  return Uri.https('github.com', '/TNT-Likely/BeeCount/issues/new/choose',
      fields.isEmpty ? null : fields);
}
