import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';

part 'header_skins/aurora_skin.dart';
part 'header_skins/bokeh_skin.dart';
part 'header_skins/clouds_skin.dart';
part 'header_skins/image_skin.dart';
part 'header_skins/memphis_skin.dart';
part 'header_skins/meteor_skin.dart';
part 'header_skins/mountains_skin.dart';
part 'header_skins/pattern_skins.dart';
part 'header_skins/sakura_skin.dart';
part 'header_skins/skyline_skin.dart';
part 'header_skins/sunset_skin.dart';
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

const String kHeaderSkinNone = 'none';

class HeaderSkin {
  const HeaderSkin({
    required this.id,
    required this.nameOf,
    required this.builder,
  });

  final String id;

  /// 皮肤显示名(i18n):用 AppLocalizations 解析,不硬编码。
  final String Function(AppLocalizations l10n) nameOf;

  /// 返回铺满 header 的装饰层(放进 Positioned.fill)。
  final Widget Function(Color primary, bool isDark) builder;
}

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
  HeaderSkin(
      id: 'aurora',
      nameOf: (l) => l.headerSkinAurora,
      builder: (p, d) => _AuroraSkin(p, d)),
  HeaderSkin(
      id: 'mountains',
      nameOf: (l) => l.headerSkinMountains,
      builder: (p, d) => _MountainsSkin(p, d)),
  HeaderSkin(
      id: 'bokeh',
      nameOf: (l) => l.headerSkinBokeh,
      builder: (p, d) => _BokehSkin(p, d)),
  HeaderSkin(
      id: 'waves',
      nameOf: (l) => l.headerSkinWaves,
      builder: (p, d) => _WavesSkin(p, d)),
  // 场景皮肤(代码绘制,跟随主题色)
  HeaderSkin(
      id: 'sunset',
      nameOf: (l) => l.headerSkinSunset,
      builder: (p, d) => _SunsetSkin(p, d)),
  HeaderSkin(
      id: 'clouds',
      nameOf: (l) => l.headerSkinClouds,
      builder: (p, d) => _CloudsSkin(p, d)),
  HeaderSkin(
      id: 'skyline',
      nameOf: (l) => l.headerSkinSkyline,
      builder: (p, d) => _SkylineSkin(p, d)),
  // 几何图案皮肤(亮=白色图案叠主题色底 / 暗=偏淡主题色图案叠纯黑)
  HeaderSkin(
      id: 'honeycomb',
      nameOf: (l) => l.headerSkinHoneycomb,
      builder: (p, d) => _PatternSkin(p, d, (c) => _HoneycombPainter(c))),
  HeaderSkin(
      id: 'starry',
      nameOf: (l) => l.headerSkinStarry,
      builder: (p, d) => _PatternSkin(p, d, (c) => _StarryPainter(c))),
  HeaderSkin(
      id: 'stripes',
      nameOf: (l) => l.headerSkinStripes,
      builder: (p, d) => _PatternSkin(p, d, (c) => _StripesPainter(c))),
  HeaderSkin(
      id: 'sakura',
      nameOf: (l) => l.headerSkinSakura,
      builder: (p, d) => _PatternSkin(p, d, (c) => _SakuraPainter(c))),
  HeaderSkin(
      id: 'meteor',
      nameOf: (l) => l.headerSkinMeteor,
      builder: (p, d) => _PatternSkin(p, d, (c) => _MeteorPainter(c))),
  HeaderSkin(
      id: 'memphis',
      nameOf: (l) => l.headerSkinMemphis,
      builder: (p, d) => _PatternSkin(p, d, (c) => _MemphisPainter(c))),
  // 图片皮肤(SVG 示例,仅 debug 可见;创作规范见 assets/header_skins/README.md)
  if (kDebugMode)
    HeaderSkin(
        id: 'example',
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
