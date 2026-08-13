import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart' show BeeTheme;

part 'header_skins/anniv_cake_skin.dart';
part 'header_skins/skin_common.dart';
part 'header_skins/anniversary_skin.dart';
part 'header_skins/aurora_skin.dart';
part 'header_skins/bokeh_skin.dart';
part 'header_skins/bubbles_skin.dart';
part 'header_skins/clouds_skin.dart';
part 'header_skins/galaxy_skin.dart';
part 'header_skins/image_skin.dart';
part 'header_skins/lowpoly_skin.dart';
part 'header_skins/memphis_skin.dart';
part 'header_skins/meteor_skin.dart';
part 'header_skins/mountains_skin.dart';
part 'header_skins/pattern_skins.dart';
part 'header_skins/prism_skin.dart';
part 'header_skins/sakura_skin.dart';
part 'header_skins/silk_skin.dart';
part 'header_skins/skyline_skin.dart';
part 'header_skins/sunset_skin.dart';
part 'header_skins/terrazzo_skin.dart';
part 'header_skins/waves_skin.dart';

/// 皮肤系统:皮肤 = 叠在「主题色底」之上的装饰层(渲染在 PrimaryHeader)。
///
/// 设计原则:**皮肤跟随用户主题色(theme-tinted)** —— 用 HSL 从 primary 派生出
/// 渐变 / 图形,所以任何主题色都成立(「主题色 + 皮肤 = PrimaryHeader」)。
/// - 亮色模式:整体保持在主题色的明度区间(偏亮),让 header 现有的深色文字仍可读。
/// - 暗色模式:纯黑底(不叠主题色底),图形仍用主题色但更淡,保持白色文字可读。
///
/// 两类皮肤:**代码皮肤**(渐变/几何/光斑,跟随主题色,见各 `header_skins/*_skin.dart`
/// part)与 **图片皮肤**(`_ImageSkin`,SVG 全幅铺满;themed=true 整幅染成主题色,否则
/// 用 SVG 自带配色)。**一个皮肤一个 part 文件**;新增见 assets/header_skins/README.md。
///
/// 代码皮肤可以是**动态**的(builder 返回带 AnimationController 的 StatefulWidget,
/// 用 RepaintBoundary 隔离、尊重系统「减弱动态效果」,首例见 anniversary_skin.dart),
/// 也可通过可选的 [HeaderSkin.tabBarBuilder] 同时装饰悬浮 tab 胶囊。

const String kHeaderSkinNone = 'none';

/// 皮肤分组 —— 选择页按这个分节展示,与 web 端 `HeaderSkinMeta.group` 对齐。
/// 新增系列(比如秋日)时加一个枚举值 + [kHeaderSkinGroupOrder] 里排个位置即可。
enum HeaderSkinGroup {
  /// 周年纪念款,永远置顶。
  anniversary,

  /// 主题色渐变。
  gradient,

  /// 场景剪影(日落 / 云 / 天际线 / 银河)。
  scene,

  /// 几何图案(蜂巢 / 星空 / 条纹…),透明图案叠在主题色底上。
  pattern,

  /// 几何艺术(低多边形 / 棱镜 / 水磨石),自带底色。
  geometric,
}

/// 分组在选择页里的先后顺序。
const List<HeaderSkinGroup> kHeaderSkinGroupOrder = [
  HeaderSkinGroup.anniversary,
  HeaderSkinGroup.gradient,
  HeaderSkinGroup.scene,
  HeaderSkinGroup.pattern,
  HeaderSkinGroup.geometric,
];

class HeaderSkin {
  const HeaderSkin({
    required this.id,
    required this.nameOf,
    required this.builder,
    required this.group,
    this.tabBarBuilder,
    this.isAnimated = false,
    this.boundPrimary,
    this.badge,
    this.deprecated = false,
  });

  final String id;

  /// 皮肤显示名(i18n):用 AppLocalizations 解析,不硬编码。
  final String Function(AppLocalizations l10n) nameOf;

  /// 返回铺满 header 的装饰层(放进 Positioned.fill)。
  final Widget Function(Color primary, bool isDark) builder;

  /// 可选:悬浮 tab 胶囊内的装饰层(垫在图标之下,见 app.dart _BeeBottomBar)。
  /// 不实现则 tab 无装饰,现有皮肤行为零变化。
  final Widget Function(Color primary, bool isDark)? tabBarBuilder;

  /// 是否带动画(选择页据此分「动态 / 静态」两组)。
  final bool isAnimated;

  /// **绑定主题色**:非 null 表示皮肤自带整套配色。选中这类皮肤时会把 App 主题色
  /// 自动切成这个颜色、并锁定主题色选择 —— 否则会出现「头部枫红、按钮蜜黄」的割裂。
  /// 换回普通皮肤时自动恢复用户原先手选的颜色(见 applyHeaderSkin)。
  final Color? boundPrimary;

  /// 皮肤是否自带配色(= 绑定了主题色)。
  bool get hasFixedPalette => boundPrimary != null;

  /// 选择页卡片左上角小徽标(如周年款的「1st」),null 不显示。
  final String? badge;

  /// 所属分组,选择页据此分节。
  final HeaderSkinGroup group;

  /// **已下架**:选择页不再展示,但 [headerSkinById] 仍能查到。
  ///
  /// 这是「不好看想撤掉」和「不能坑老用户」之间的折中 —— 直接从
  /// [kHeaderSkins] 删掉的话,正在用这款皮肤的人下次打开 App 会发现 header
  /// 变回纯色,那是**回收已发布的功能**。标记下架则新用户看不到、老用户照常用,
  /// 真要清库存等某个大版本再物理删。
  final bool deprecated;
}

/// 选择页可见的皮肤(滤掉已下架的)。
List<HeaderSkin> get kVisibleHeaderSkins =>
    kHeaderSkins.where((s) => !s.deprecated).toList();

/// 按「动态 / 静态」分组的过滤器,供选择页分段切换使用。
enum HeaderSkinFilter { all, animated, static_ }

/// 当前皮肤绑定的主题色;null = 用户可自由选主题色。
Color? boundPrimaryOf(String skinId) => headerSkinById(skinId)?.boundPrimary;

// ---- HSL 派生工具(供各皮肤 part 共用)----
Color _lighten(Color c, double amount) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
}

Color _hueShift(Color c, double deg) {
  final h = HSLColor.fromColor(c);
  return h.withHue((h.hue + deg) % 360).toColor();
}

/// 已注册皮肤(不含「无」)。
final List<HeaderSkin> kHeaderSkins = [
  // 一周年纪念款(2025.9.10—2026.9.10)×2,置顶展示;选择页带「1st」角标。
  // 曾经有第三款「周年账单」(一张年度小票),已下架:设计稿把票排在 300×208
  // 方画布的右半边,而真实 header 是 440×172 的扁条、右上角还被三个功能图标
  // 占着 —— 票要么细成一条、要么压着图标,两头不讨好。
  HeaderSkin(
      id: 'anniversary',
      group: HeaderSkinGroup.anniversary,
      nameOf: (l) => l.headerSkinAnniversary,
      builder: (p, d) => _AnniversarySkin(p, d),
      tabBarBuilder: (p, d) => _AnniversaryTabDeco(p, d),
      isAnimated: true,
      // 绑定蜜金,不再跟随主题色。星空的星光只有暖白/金是「真的」,主题色
      // 一换紫换绿,银河立刻显假(星云代码里那条「hue 偏移 ±14° 以内,否则
      // 黑底泛脏绿/脏红」的注释就是在跟这个搏斗)。纪念款绑品牌色也贴题:
      // 这是蜜蜂的第一年。#F8C91C 同时是暗色下月牙/流星的暖色,整套自洽。
      boundPrimary: BeeTheme.honeyGold,
      badge: '1st'),
  HeaderSkin(
      id: 'anniv_cake',
      group: HeaderSkinGroup.anniversary,
      nameOf: (l) => l.headerSkinAnnivCake,
      builder: (p, d) => _AnnivCakeSkin(d),
      tabBarBuilder: (p, d) => _AnnivCakeTabDeco(d),
      isAnimated: true,
      boundPrimary: _kCakeCandleL,
      badge: '1st'),
  // 秋日系列(枫叶清秋 / 桂月中秋 / 银杏金秋 / 柿柿如意 / 秋雨梧桐 / 雁阵南飞)
  // 不在这一版:计划以付费皮肤形态单独发布,提前免费放出去就收不回来了。
  // 代码在 feat/autumn-skins-paid 分支上,见 .docs/skin-monetization-research.md。
  HeaderSkin(
      id: 'aurora',
      group: HeaderSkinGroup.gradient,
      nameOf: (l) => l.headerSkinAurora,
      builder: (p, d) => _AuroraSkin(p, d)),
  HeaderSkin(
      id: 'mountains',
      group: HeaderSkinGroup.gradient,
      nameOf: (l) => l.headerSkinMountains,
      builder: (p, d) => _MountainsSkin(p, d)),
  HeaderSkin(
      id: 'bokeh',
      group: HeaderSkinGroup.gradient,
      nameOf: (l) => l.headerSkinBokeh,
      builder: (p, d) => _BokehSkin(p, d)),
  HeaderSkin(
      id: 'waves',
      group: HeaderSkinGroup.gradient,
      nameOf: (l) => l.headerSkinWaves,
      builder: (p, d) => _WavesSkin(p, d)),
  HeaderSkin(
      id: 'silk',
      group: HeaderSkinGroup.gradient,
      nameOf: (l) => l.headerSkinSilk,
      builder: (p, d) => _SilkSkin(p, d)),
  HeaderSkin(
      id: 'bubbles',
      group: HeaderSkinGroup.gradient,
      nameOf: (l) => l.headerSkinBubbles,
      builder: (p, d) => _BubblesSkin(p, d)),
  // 场景皮肤(代码绘制,跟随主题色)
  HeaderSkin(
      id: 'sunset',
      group: HeaderSkinGroup.scene,
      nameOf: (l) => l.headerSkinSunset,
      builder: (p, d) => _SunsetSkin(p, d)),
  HeaderSkin(
      id: 'clouds',
      group: HeaderSkinGroup.scene,
      nameOf: (l) => l.headerSkinClouds,
      builder: (p, d) => _CloudsSkin(p, d)),
  HeaderSkin(
      id: 'skyline',
      group: HeaderSkinGroup.scene,
      nameOf: (l) => l.headerSkinSkyline,
      builder: (p, d) => _SkylineSkin(p, d)),
  HeaderSkin(
      id: 'galaxy',
      group: HeaderSkinGroup.scene,
      nameOf: (l) => l.headerSkinGalaxy,
      builder: (p, d) => _GalaxySkin(p, d)),
  // 几何图案皮肤(亮=白色图案叠主题色底 / 暗=偏淡主题色图案叠纯黑)
  HeaderSkin(
      id: 'honeycomb',
      group: HeaderSkinGroup.pattern,
      nameOf: (l) => l.headerSkinHoneycomb,
      builder: (p, d) => _PatternSkin(p, d, (c) => _HoneycombPainter(c))),
  HeaderSkin(
      id: 'starry',
      group: HeaderSkinGroup.pattern,
      nameOf: (l) => l.headerSkinStarry,
      builder: (p, d) => _PatternSkin(p, d, (c) => _StarryPainter(c))),
  HeaderSkin(
      id: 'stripes',
      group: HeaderSkinGroup.pattern,
      nameOf: (l) => l.headerSkinStripes,
      builder: (p, d) => _PatternSkin(p, d, (c) => _StripesPainter(c))),
  HeaderSkin(
      id: 'sakura',
      group: HeaderSkinGroup.pattern,
      nameOf: (l) => l.headerSkinSakura,
      builder: (p, d) => _PatternSkin(p, d, (c) => _SakuraPainter(c))),
  HeaderSkin(
      id: 'meteor',
      group: HeaderSkinGroup.pattern,
      nameOf: (l) => l.headerSkinMeteor,
      builder: (p, d) => _PatternSkin(p, d, (c) => _MeteorPainter(c))),
  HeaderSkin(
      id: 'memphis',
      group: HeaderSkinGroup.pattern,
      nameOf: (l) => l.headerSkinMemphis,
      builder: (p, d) => _PatternSkin(p, d, (c) => _MemphisPainter(c))),
  // 几何 / 艺术(代码绘制,自定义底,跟随主题色)
  HeaderSkin(
      id: 'lowpoly',
      group: HeaderSkinGroup.geometric,
      nameOf: (l) => l.headerSkinLowPoly,
      builder: (p, d) => _LowPolySkin(p, d)),
  HeaderSkin(
      id: 'prism',
      group: HeaderSkinGroup.geometric,
      nameOf: (l) => l.headerSkinPrism,
      builder: (p, d) => _PrismSkin(p, d)),
  HeaderSkin(
      id: 'terrazzo',
      group: HeaderSkinGroup.geometric,
      nameOf: (l) => l.headerSkinTerrazzo,
      builder: (p, d) => _TerrazzoSkin(p, d)),
  // 图片皮肤(SVG 示例,仅 debug 可见;创作规范见 assets/header_skins/README.md)
  if (kDebugMode)
    HeaderSkin(
        id: 'example',
      group: HeaderSkinGroup.geometric,
        nameOf: (l) => l.headerSkinExample,
        builder: (p, d) => _ImageSkin(
            'assets/header_skins/example_skin.svg', p, d,
            themed: true)),
];

HeaderSkin? headerSkinById(String id) {
  for (final s in kHeaderSkins) {
    if (s.id == id) return s;
  }
  return null;
}
