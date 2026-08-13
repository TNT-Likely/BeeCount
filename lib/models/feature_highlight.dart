/// 新功能红点(What's New dots)。
///
/// 目标:发新版后,让用户**自己发现**新功能,而不是靠他去读更新日志。
///
/// ## 为什么不是弹窗
///
/// 记账是高频且目的极强的动作,用户打开 App 是为了记一笔早餐 —— 弹窗打断的
/// 是所有人,收益却只在少数人身上;而且它对「修了某个小 bug」这种条目也照发
/// 一遍,不发又要额外维护一张判断表。红点则是零打扰的:不想探索的人只是多看
/// 到一个小圆点,想探索的人被直接引到位置(比弹窗说「新增周年皮肤」有用得多,
/// 那句话看完还得自己找)。
///
/// ## 为什么是红点而不是 NEW 角标
///
/// 决定性的一条:**红点能在任何尺寸的入口上生存,NEW 不能。** 这套机制是
/// 多级传播的 —— 同一个功能要在 tab 图标(22px)、列表项图标(36px)、页面行
/// 上同时亮。8px 的圆到处放得下;四个字母塞进 22px 的 tab 角上只会糊成一团。
/// 选了 NEW 就等于放弃路径引导,而路径引导是这套机制唯一的价值。
///
/// 另外三条:红点零文案(NEW 要出 zh / zh_TW / en / ko 四份);红点固定
/// #FF3B30 亮暗通吃(NEW 用主题色会在蜜蜂黄这种高亮度底上看不清,用固定红
/// 又和红点没区别、只是更占地方);多条同时命中时,三级路径挂三个 NEW 标签
/// 会很吵,三个小圆点不会。
///
/// **两层分工**,别混用:
/// - **路径引导**(tab / 列表项)= 红点,回答「这个方向有你没见过的东西」;
/// - **内容标识**(皮肤卡片这类)= [HeaderSkin.badge] 那种角标(`1st`/`NEW`),
///   回答「**这一个**是新的」。周年皮肤卡片上不挂红点,就是因为它已经有
///   `1st` 角标 + 置顶分组 —— 红点走到皮肤页门口,使命就完成了,再往里钻
///   等于承认页面自己没做好。
///
/// ## 机制:只看「点没点过」,不跟版本号绑定
///
/// 每个功能声明一条**入口路径**。没被点过的功能,在路径的每一级入口亮红点;
/// 用户走到终点(叶子入口)时整条链一起熄灭,并永久记进已读。
///
/// 早先的版本绑过「首发版本 + 升级区间」,换掉了,因为那套有两个真实缺陷:
/// - **版本号填错是静默失败** —— 红点不亮,没有任何报错,只能靠人肉复查;
///   实测第一版就填错过一次(写成了 3.8.0,实际下个版本是 3.7.1)。
/// - 开发机上区间恒为空,自测不了,只能给 debug 开特例 —— 特例本身又意味着
///   开发看到的行为和线上不一致。
///
/// 「点没点过」既没有这些坑,语义也更贴事实:红点回答的本来就是
/// 「这个入口我探过了吗」,跟它是哪个版本进来的没有内在关系。
///
/// ## 三条设计约束
///
/// 1. **首次安装绝不亮红点。** 新用户眼里所有功能都是新的,全亮等于全噪音。
///    实现上靠「第一次跑这套逻辑时,把当前清单整体预标记为已读」判掉,
///    但要能认出「从没有红点功能的旧版升上来」的老用户 —— 那批人恰恰是
///    要引导的对象,不能一起标掉。判定见 `featureHighlightInitProvider`。
/// 2. **不进云同步。** 红点是「这台设备上的人看没看过」,多设备各算各的才对 ——
///    在 iPad 上看过不代表手机上这个人也看过。所以只存 SharedPreferences。
/// 3. **只挂值得引导的功能,过气了就从清单里删掉。** bug 修复、文案调整不进
///    这份清单。而且清单**不是历史档案** —— 一个功能发布几个版本后就该摘掉,
///    否则一个从很老版本升上来的用户会同时看到一堆红点。删除是安全的:
///    已读记录留在 prefs 里不影响任何事。
library;

/// 一条新功能的引导声明。
class FeatureHighlight {
  const FeatureHighlight({required this.id, required this.anchors});

  /// 稳定 id,存进 prefs 当已读标记。**一旦发版就不要改**,改了等于让所有
  /// 已经看过的用户重新亮一次。
  final String id;

  /// 从根入口到功能本身的路径,每一级一个锚点 id。
  ///
  /// 例:`['tab_mine', 'personalize', 'header_skin']` —— 「我的」tab、
  /// 「个性化设置」那一行、「皮肤」那一行会依次亮红点,进到皮肤页后
  /// 整条链熄灭。**最后一项是叶子**,访问它才算真正看到了功能。
  final List<String> anchors;

  String get leafAnchor => anchors.last;
}

/// 当前要引导的新功能。
///
/// 加一条 = 所有老用户下次启动就会看到红点(他们的已读集合里没有这个 id)。
/// **发布几个版本后记得删** —— 见上面约束 3。
const List<FeatureHighlight> kFeatureHighlights = [
  FeatureHighlight(
    id: 'anniversary_skins',
    anchors: ['tab_mine', 'personalize', 'header_skin'],
  ),
  FeatureHighlight(
    id: 'skin_animation_toggle',
    // 开关就在外观设置页上,没有更深的层级,叶子就是页面本身
    anchors: ['tab_mine', 'personalize'],
  ),
];

/// 还没被点过的功能 id。
Set<String> unreadFrom(
  Set<String> seenIds, {
  List<FeatureHighlight> catalog = kFeatureHighlights,
}) {
  return {
    for (final f in catalog)
      if (!seenIds.contains(f.id)) f.id,
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
