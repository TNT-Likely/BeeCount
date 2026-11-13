import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart' show BeeTheme;

part 'header_skins/anniv_cake_skin.dart';
part 'header_skins/skin_common.dart';
part 'header_skins/anniversary_skin.dart';
part 'header_skins/aurora_skin.dart';
part 'header_skins/mountains_skin.dart';
part 'header_skins/page_composition.dart';

/// 皮肤系统:皮肤 = 叠在「主题色底」之上的装饰层(渲染在 PrimaryHeader)。
///
/// 设计原则:**皮肤跟随用户主题色(theme-tinted)** —— 用 HSL 从 primary 派生出
/// 渐变 / 图形,所以任何主题色都成立(「主题色 + 皮肤 = PrimaryHeader」)。
/// - 亮色模式:整体保持在主题色的明度区间(偏亮),让 header 现有的深色文字仍可读。
/// - 暗色模式:低亮度底色与柔和主题装饰,保持白色文字可读。
///
/// 当前保留极光、山峦两款静态皮肤和两款周年动态皮肤。
/// **一个皮肤一个 part 文件**;新增见 assets/header_skins/README.md。
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
    this.pageBuilder,
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

  /// Reserved compatibility hook. Page composition reuses the original painters;
  /// [builder] remains available for every static/image skin and previews.
  final Widget Function(Color primary, bool isDark)? pageBuilder;

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
// Current catalogue: two anniversary animations and two static classics.
final List<HeaderSkin> kHeaderSkins = [
  HeaderSkin(
      id: 'anniversary',
      group: HeaderSkinGroup.anniversary,
      nameOf: (l) => l.headerSkinAnniversary,
      builder: (p, d) => _AnniversarySkin(p, d),
      tabBarBuilder: (p, d) => _AnniversaryTabDeco(p, d),
      isAnimated: true,
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
];

HeaderSkin? headerSkinById(String id) {
  for (final s in kHeaderSkins) {
    if (s.id == id) return s;
  }
  return null;
}
