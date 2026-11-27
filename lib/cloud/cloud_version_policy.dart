import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

/// App 端维护的 BeeCount Cloud 版本策略（仅靠双端版本号提示升级，不做逐功能兼容矩阵）。
const String kMinCloudVersion = '1.10.0';
const String kRecommendedCloudVersion = '1.11.0';

const String kCloudUpgradeGuideUrlZh =
    'https://count.beejz.com/docs/cloud-sync/beecount-cloud';
const String kCloudUpgradeGuideUrlEn =
    'https://count.beejz.com/en/docs/cloud-sync/beecount-cloud';
const String kAppReleasesUrl = 'https://github.com/TNT-Likely/BeeCount/releases';

/// Cloud 本地源码未注入 `APP_VERSION` 时的默认开发版 fallback。
const String _kCloudDevFallbackVersion = '1.0.0';

class CloudSemVer implements Comparable<CloudSemVer> {
  const CloudSemVer(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final RegExp _pattern =
      RegExp(r'^\s*v?(\d+)\.(\d+)\.(\d+)(?:$|[+\-\s(])', caseSensitive: false);

  static CloudSemVer? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = _pattern.firstMatch(raw);
    if (match == null) return null;
    return CloudSemVer(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  String get normalized => '$major.$minor.$patch';

  @override
  int compareTo(CloudSemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(CloudSemVer other) => compareTo(other) < 0;
  bool operator <=(CloudSemVer other) => compareTo(other) <= 0;
  bool operator >(CloudSemVer other) => compareTo(other) > 0;
  bool operator >=(CloudSemVer other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is CloudSemVer &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => normalized;
}

enum CloudVersionMatchStatus {
  /// 断网、超时、非 BeeCount Cloud 或本地源码开发版 fallback（1.0.0）时跳过提示。
  unknown,

  /// App 与 Cloud 均满足对方推荐版本。
  matched,

  /// Cloud 低于 App 推荐版本，放行同步并温和提示升级 Cloud。
  upgradeCloudRecommended,

  /// Cloud 低于 App 最低要求，暂停云同步（本地记账不受影响）并强提示升级 Cloud。
  upgradeCloudRequired,

  /// App 低于 Cloud 推荐版本，放行同步并温和提示更新 App。
  upgradeAppRecommended,

  /// App 低于 Cloud 最低要求（含收到 HTTP 426），暂停云同步并强提示更新 App。
  upgradeAppRequired,
}

class CloudVersionCompatibility {
  const CloudVersionCompatibility({
    required this.status,
    this.appVersion,
    this.serverVersion,
    this.targetVersion,
    this.minCloudVersion = kMinCloudVersion,
    this.recommendedCloudVersion = kRecommendedCloudVersion,
    this.serverMinAppVersion,
    this.serverRecommendedAppVersion,
  });

  const CloudVersionCompatibility.unknown({
    this.appVersion,
    this.serverVersion,
  })  : status = CloudVersionMatchStatus.unknown,
        targetVersion = null,
        minCloudVersion = kMinCloudVersion,
        recommendedCloudVersion = kRecommendedCloudVersion,
        serverMinAppVersion = null,
        serverRecommendedAppVersion = null;

  final CloudVersionMatchStatus status;
  final String? appVersion;
  final String? serverVersion;

  /// 当前应升级到的目标版本号（推荐版本或最低要求版本）。
  final String? targetVersion;
  final String minCloudVersion;
  final String recommendedCloudVersion;
  final String? serverMinAppVersion;
  final String? serverRecommendedAppVersion;

  bool get isMatched => status == CloudVersionMatchStatus.matched;
  bool get isUnknown => status == CloudVersionMatchStatus.unknown;

  bool get needsNotice =>
      status != CloudVersionMatchStatus.unknown &&
      status != CloudVersionMatchStatus.matched;

  bool get isBlocking =>
      status == CloudVersionMatchStatus.upgradeCloudRequired ||
      status == CloudVersionMatchStatus.upgradeAppRequired;

  bool get upgradeTargetIsCloud =>
      status == CloudVersionMatchStatus.upgradeCloudRecommended ||
      status == CloudVersionMatchStatus.upgradeCloudRequired;

  bool get upgradeTargetIsApp =>
      status == CloudVersionMatchStatus.upgradeAppRecommended ||
      status == CloudVersionMatchStatus.upgradeAppRequired;

  /// 首页一次性提示的已读记忆键：同一 `(appVersion, serverVersion, status)` 只提醒一次。
  String get dismissPairKey =>
      '${appVersion ?? ''}|${serverVersion ?? ''}|${status.name}';

  factory CloudVersionCompatibility.fromUpgradeRequired(
    BeeCountCloudUpgradeRequiredException exc, {
    String? fallbackAppVersion,
  }) {
    final app = CloudSemVer.tryParse(exc.clientAppVersion ?? fallbackAppVersion)
            ?.normalized ??
        exc.clientAppVersion ??
        fallbackAppVersion;
    final server = CloudSemVer.tryParse(exc.serverVersion)?.normalized ??
        exc.serverVersion;
    return CloudVersionCompatibility(
      status: CloudVersionMatchStatus.upgradeAppRequired,
      appVersion: app,
      serverVersion: server,
      targetVersion: exc.minAppVersion ?? exc.recommendedAppVersion,
      serverMinAppVersion: exc.minAppVersion,
      serverRecommendedAppVersion: exc.recommendedAppVersion,
    );
  }
}

bool isDevFallbackServerVersion(String? raw) {
  if (raw == null) return true;
  final trimmed = raw.trim().toLowerCase();
  if (trimmed.isEmpty) return true;
  if (trimmed == _kCloudDevFallbackVersion || trimmed.contains('-dev')) {
    return true;
  }
  return false;
}

CloudVersionCompatibility evaluateCloudVersionCompatibility({
  required String? appVersion,
  required BeeCountCloudServerVersion? server,
  String minCloudVersion = kMinCloudVersion,
  String recommendedCloudVersion = kRecommendedCloudVersion,
}) {
  if (server == null) {
    return CloudVersionCompatibility.unknown(appVersion: appVersion);
  }
  final parsedApp = CloudSemVer.tryParse(appVersion);
  final parsedServer = CloudSemVer.tryParse(server.version);
  if (parsedServer == null || isDevFallbackServerVersion(server.version)) {
    return CloudVersionCompatibility.unknown(
      appVersion: parsedApp?.normalized ?? appVersion,
      serverVersion: server.version,
    );
  }

  final parsedMinCloud = CloudSemVer.tryParse(minCloudVersion);
  final parsedRecCloud = CloudSemVer.tryParse(recommendedCloudVersion);
  final parsedMinApp = CloudSemVer.tryParse(server.minAppVersion);
  final parsedRecApp = CloudSemVer.tryParse(server.recommendedAppVersion);

  final normalizedApp = parsedApp?.normalized ?? appVersion;
  final normalizedServer = parsedServer.normalized;

  CloudVersionCompatibility build(
    CloudVersionMatchStatus status, {
    String? target,
  }) =>
      CloudVersionCompatibility(
        status: status,
        appVersion: normalizedApp,
        serverVersion: normalizedServer,
        targetVersion: target,
        minCloudVersion: minCloudVersion,
        recommendedCloudVersion: recommendedCloudVersion,
        serverMinAppVersion: server.minAppVersion,
        serverRecommendedAppVersion: server.recommendedAppVersion,
      );

  // 优先级：必须档 > 建议档。
  if (parsedMinCloud != null && parsedServer < parsedMinCloud) {
    return build(
      CloudVersionMatchStatus.upgradeCloudRequired,
      target: parsedMinCloud.normalized,
    );
  }
  if (parsedApp != null && parsedMinApp != null && parsedApp < parsedMinApp) {
    return build(
      CloudVersionMatchStatus.upgradeAppRequired,
      target: parsedMinApp.normalized,
    );
  }
  if (parsedRecCloud != null && parsedServer < parsedRecCloud) {
    return build(
      CloudVersionMatchStatus.upgradeCloudRecommended,
      target: parsedRecCloud.normalized,
    );
  }
  if (parsedApp != null && parsedRecApp != null && parsedApp < parsedRecApp) {
    return build(
      CloudVersionMatchStatus.upgradeAppRecommended,
      target: parsedRecApp.normalized,
    );
  }

  return build(CloudVersionMatchStatus.matched);
}
