/// 新功能红点(What's New dots)。
///
/// 目标:发新版后,让用户**自己发现**新功能,而不是靠他去读更新日志。
/// 形态选的是红点而不是弹窗 —— 记账是高频且目的极强的动作,用户打开 App
/// 是为了记一笔早餐,弹窗打断的是所有人,收益却只在少数人身上;红点则是
/// 零打扰的:不想探索的人只是多看到一个小圆点,想探索的人被直接引到位置。
///
/// ## 机制
///
/// 每个功能声明「首发版本」和「入口路径」。启动时比对**上次启动的版本**和
/// 当前版本,落在这个区间里的功能进入待办;路径上每一级入口都亮红点,用户
/// 走到终点(叶子入口)时整条链一起熄灭。
///
/// ## 三条设计约束
///
/// 1. **首次安装绝不亮红点。** 新用户眼里所有功能都是新的,全亮等于全噪音。
///    实现上靠「没有上次启动版本 = 首次安装」这一条判掉。
/// 2. **不进云同步。** 红点是「这台设备上的人看没看过」,多设备各算各的才对 ——
///    在 iPad 上看过不代表手机上这个人也看过。所以只存 SharedPreferences。
/// 3. **只挂值得引导的功能。** bug 修复、文案调整不进这份清单;进了清单的
///    每一条都应该是「用户不知道就亏了」的东西。
library;

/// 一条新功能的引导声明。
class FeatureHighlight {
  const FeatureHighlight({
    required this.id,
    required this.version,
    required this.anchors,
  });

  /// 稳定 id,存进 prefs 当已读标记。**一旦发版就不要改**,改了等于让所有
  /// 已经看过的用户重新亮一次。
  final String id;

  /// 首发版本(pubspec / CI_VERSION 那套三段式)。
  final String version;

  /// 从根入口到功能本身的路径,每一级一个锚点 id。
  ///
  /// 例:`['tab_mine', 'personalize', 'header_skin']` —— 「我的」tab、
  /// 「个性化设置」那一行、「皮肤」那一行会依次亮红点,进到皮肤页后
  /// 整条链熄灭。**最后一项是叶子**,访问它才算真正看到了功能。
  final List<String> anchors;

  String get leafAnchor => anchors.last;
}

/// 已登记的新功能。**加新条目时记得同步 [kFeatureHighlights] 的版本号**,
/// 写成还没发布的那个版本(发布后老用户升上来才会亮)。
const List<FeatureHighlight> kFeatureHighlights = [
  FeatureHighlight(
    id: 'anniversary_skins',
    version: '3.8.0',
    anchors: ['tab_mine', 'personalize', 'header_skin'],
  ),
  FeatureHighlight(
    id: 'skin_animation_toggle',
    version: '3.8.0',
    // 开关就在外观设置页上,没有更深的层级,叶子就是页面本身
    anchors: ['tab_mine', 'personalize'],
  ),
];

/// 三段式版本比较。返回负 / 0 / 正,语义同 [Comparable.compareTo]。
///
/// 只认 `1.2.3` 这种形状,多余的后缀(`-beta`、`+build`)一律截断后再比 ——
/// 版本区间判断只需要数字段,后缀参与比较反而会引入意外。
/// 解析不出的段按 0 算:宁可少亮一个红点,也不要因为版本号格式意外
/// 让所有人满屏红点。
int compareVersions(String a, String b) {
  final pa = _segments(a), pb = _segments(b);
  for (var i = 0; i < 3; i++) {
    final d = pa[i].compareTo(pb[i]);
    if (d != 0) return d;
  }
  return 0;
}

List<int> _segments(String v) {
  final core = v.split(RegExp(r'[-+]')).first.trim();
  final parts = core.split('.');
  return [
    for (var i = 0; i < 3; i++)
      i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
  ];
}

/// 算出这次升级要亮哪些功能。
///
/// [previousVersion] 为 null = **首次安装**,返回空(见约束 1)。
/// 区间取 `(previousVersion, currentVersion]`:上次启动之后、直到这一版为止
/// 首发的功能才算新。等于 previousVersion 的不算(上个版本就在了);
/// 大于 currentVersion 的也不算(清单里提前登记了还没发布的功能 ——
/// 开发期常见,不该提前泄露给用户)。
Set<String> pendingFeatureIds({
  required String? previousVersion,
  required String currentVersion,
  List<FeatureHighlight> catalog = kFeatureHighlights,
}) {
  if (previousVersion == null) return const {};
  return {
    for (final f in catalog)
      if (compareVersions(f.version, previousVersion) > 0 &&
          compareVersions(f.version, currentVersion) <= 0)
        f.id,
  };
}

/// 某个锚点下是否还有没看过的功能。
///
/// 路径上任意一级都会亮,所以是「anchors 里**包含**该锚点」而不是只看叶子。
bool anchorHasUnread(
  String anchor,
  Set<String> unreadIds, {
  List<FeatureHighlight> catalog = kFeatureHighlights,
}) {
  for (final f in catalog) {
    if (unreadIds.contains(f.id) && f.anchors.contains(anchor)) return true;
  }
  return false;
}

/// 访问某个锚点后,应当被标记已读的功能 id。
///
/// **只有叶子锚点才消费红点。** 路过中间层级(点开「个性化设置」)不算看到了
/// 皮肤,那时红点得继续往下指;走到叶子才算数,整条链随之熄灭。
Set<String> featuresConsumedBy(
  String anchor, {
  List<FeatureHighlight> catalog = kFeatureHighlights,
}) {
  return {
    for (final f in catalog)
      if (f.leafAnchor == anchor) f.id,
  };
}
