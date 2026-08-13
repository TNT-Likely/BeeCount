import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feature_highlight.dart';
import '../services/system/logger_service.dart';

/// 新功能红点的状态层。设计说明见 [FeatureHighlight] 的文档注释。
///
/// **不进 appearance 同步包** —— 红点回答的是「这台设备上的人看没看过」,
/// 在 iPad 上看过不代表手机前的这个人也看过。只存本机 prefs。

/// 已经点开过的功能 id。这是**唯一**的持久化状态 —— 红点亮不亮完全由它
/// 和当前清单的差集决定,不掺版本号。
const _kPrefSeen = 'featureHighlight.seen';

/// 当前还没被看过的功能 id。
final unreadFeaturesProvider = StateProvider<Set<String>>((ref) => const {});

/// 启动初始化。
final featureHighlightInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getStringList(_kPrefSeen);

  if (stored == null) {
    // 第一次跑这套逻辑。两种人会走到这里,必须分开:
    //
    // - **全新安装**:清单里的东西对他而言不是「新功能」,是 App 本来的样子。
    //   全部预标记为已读,一个红点都不亮。
    // - **从没有红点功能的旧版升上来的老用户**:这批人恰恰是要引导的对象,
    //   什么都不标,清单里的功能照常亮。
    //
    // 靠 welcome_shown 区分 —— 老用户必然走过引导页,全新安装此刻还没走。
    final isUpgrade = prefs.getBool('welcome_shown') ?? false;
    final seed = isUpgrade ? <String>{} : {for (final f in kFeatureHighlights) f.id};
    await prefs.setStringList(_kPrefSeen, seed.toList());
    ref.read(unreadFeaturesProvider.notifier).state = unreadFrom(seed);
    logger.info('feature_highlight',
        isUpgrade ? '老用户首次带红点启动,清单全亮' : '全新安装,清单预置为已读');
    return;
  }

  final seen = stored.toSet();
  final unread = unreadFrom(seen);
  ref.read(unreadFeaturesProvider.notifier).state = unread;
  if (unread.isNotEmpty) {
    logger.info('feature_highlight', '待引导: $unread');
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
