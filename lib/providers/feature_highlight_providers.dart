import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feature_highlight.dart';
import '../services/system/logger_service.dart';

/// 新功能红点的状态层。设计说明见 [FeatureHighlight] 的文档注释。
///
/// **不进 appearance 同步包** —— 红点回答的是「这台设备上的人看没看过」,
/// 在 iPad 上看过不代表手机前的这个人也看过。只存本机 prefs。

const _kPrefLastVersion = 'featureHighlight.lastVersion';
const _kPrefUnread = 'featureHighlight.unread';

/// 当前还没被看过的功能 id。
final unreadFeaturesProvider = StateProvider<Set<String>>((ref) => const {});

/// 当前版本号。
///
/// CI 用 `--dart-define=CI_VERSION` 注入真实版本;pubspec 里的 `version`
/// 是占位的 `0.0.1`(发版由 CI 覆写)。本地开发拿 0.0.1 去比对的话,清单里
/// 所有功能都落在「比当前版本还新」的区间外、红点永远不亮 —— 自测不了。
/// 所以本地回退成清单里的最大版本,等价于「装的就是最新版」。
String resolveCurrentVersion(String pubspecVersion) {
  const ci = String.fromEnvironment('CI_VERSION');
  if (ci.isNotEmpty) return ci;
  if (pubspecVersion != '0.0.1') return pubspecVersion;
  var max = '0.0.0';
  for (final f in kFeatureHighlights) {
    if (compareVersions(f.version, max) > 0) max = f.version;
  }
  return max;
}

/// 启动初始化:算出这一版有哪些新功能,并入未读集合。
final featureHighlightInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final info = await PackageInfo.fromPlatform();
  final current = resolveCurrentVersion(info.version);
  final previous = prefs.getString(_kPrefLastVersion);

  // 上次没看完的继续留着 —— 用户可能升了两版都没点进去,不该被后一次
  // 启动冲掉。
  final carried = prefs.getStringList(_kPrefUnread)?.toSet() ?? <String>{};
  final fresh = pendingFeatureIds(
    previousVersion: previous,
    currentVersion: current,
  );
  final unread = {...carried, ...fresh};

  ref.read(unreadFeaturesProvider.notifier).state = unread;
  await prefs.setString(_kPrefLastVersion, current);
  await prefs.setStringList(_kPrefUnread, unread.toList());

  if (previous == null) {
    logger.info('feature_highlight', '首次安装($current),不亮任何红点');
  } else if (fresh.isNotEmpty) {
    logger.info('feature_highlight', '$previous → $current 新增引导: $fresh');
  }
});

/// 访问了某个入口 —— 如果它是某些功能的叶子锚点,把那些功能标记为已读。
/// 收 [WidgetRef] 是因为调用方全是页面(在 initState 里调)。
Future<void> markAnchorVisited(WidgetRef ref, String anchor) async {
  final consumed = featuresConsumedBy(anchor);
  if (consumed.isEmpty) return;
  final unread = ref.read(unreadFeaturesProvider);
  final next = unread.difference(consumed);
  if (next.length == unread.length) return; // 本来就没亮,别写盘
  ref.read(unreadFeaturesProvider.notifier).state = next;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_kPrefUnread, next.toList());
  logger.info('feature_highlight', '「$anchor」已访问,熄灭: ${unread.difference(next)}');
}

/// 某个锚点要不要亮红点。UI 直接 watch 这个。
final anchorHasUnreadProvider = Provider.family<bool, String>((ref, anchor) {
  final unread = ref.watch(unreadFeaturesProvider);
  if (unread.isEmpty) return false;
  return anchorHasUnread(anchor, unread);
});
