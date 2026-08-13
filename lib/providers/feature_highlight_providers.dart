import 'package:flutter/foundation.dart' show kDebugMode;
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

/// 已经被点开过的功能。跟未读集合分开存:未读会被版本区间重算,
/// 「看过」是永久事实,不该跟着重算被翻回来。
const _kPrefSeen = 'featureHighlight.seen';

/// 启动初始化:算出这一版有哪些新功能,并入未读集合。
final featureHighlightInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final info = await PackageInfo.fromPlatform();
  final current = resolveCurrentVersion(info.version);
  final previous = prefs.getString(_kPrefLastVersion);
  final seen = prefs.getStringList(_kPrefSeen)?.toSet() ?? <String>{};

  // 上次没看完的继续留着 —— 用户可能升了两版都没点进去,不该被后一次
  // 启动冲掉。
  final carried = prefs.getStringList(_kPrefUnread)?.toSet() ?? <String>{};

  // debug build 退化成「没点过就亮」。
  //
  // 线上靠版本区间开窗,但开发机上那个窗口永远是空的:pubspec 里是占位的
  // 0.0.1、首次启动又会立刻把 lastVersion 写成当前版本 —— 于是第一次走
  // 「首次安装不亮」,之后每次都是「同版本无区间」,红点一次都看不到,
  // 自测只能靠手改 plist。
  //
  // 这里只放宽**入场**条件,退场仍然走同一套 seen 标记 —— 也就是说 debug
  // 下能看到红点怎么亮、怎么随访问熄灭,唯独不复现「升级那一刻才开窗」。
  // 那一半由 feature_highlight_test.dart 的纯函数测试覆盖(不吃 kDebugMode)。
  final fresh = kDebugMode
      ? {for (final f in kFeatureHighlights) f.id}
      : pendingFeatureIds(
          previousVersion: previous,
          currentVersion: current,
        );

  // 减掉看过的:debug 下 fresh 是全量,不减的话点完一轮下次启动又全亮回来
  final unread = {...carried, ...fresh}.difference(seen);

  ref.read(unreadFeaturesProvider.notifier).state = unread;
  await prefs.setString(_kPrefLastVersion, current);
  await prefs.setStringList(_kPrefUnread, unread.toList());

  if (kDebugMode) {
    logger.info('feature_highlight', 'debug 模式:未点过的一律亮 → $unread');
  } else if (previous == null) {
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
  // seen 是**累加**的永久记录。只清 unread 不够 —— debug 下每次启动会把
  // 清单全量放回 fresh,没有 seen 兜着就会「点完又亮」。
  final seen = prefs.getStringList(_kPrefSeen)?.toSet() ?? <String>{};
  await prefs.setStringList(_kPrefSeen, {...seen, ...consumed}.toList());
  logger.info('feature_highlight', '「$anchor」已访问,熄灭: ${unread.difference(next)}');
}

/// 某个锚点要不要亮红点。UI 直接 watch 这个。
final anchorHasUnreadProvider = Provider.family<bool, String>((ref, anchor) {
  final unread = ref.watch(unreadFeaturesProvider);
  if (unread.isEmpty) return false;
  return anchorHasUnread(anchor, unread);
});
