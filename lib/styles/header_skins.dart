import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 头部皮肤系统(PoC):皮肤 = 叠在「主题色底」之上的装饰层。
///
/// 设计原则:**皮肤跟随用户主题色(theme-tinted)** —— 用 HSL 从 primary 派生出
/// 渐变 / 图形,所以任何主题色都成立(「主题色 + 皮肤 = PrimaryHeader」)。
/// - 亮色模式:整体保持在主题色的明度区间(偏亮),让 header 现有的深色文字仍可读。
/// - 暗色模式:在纯黑底上低透明叠主题色调,保持白色文字可读。
///
/// 角色插画类皮肤(猫/狗/雪人)需要真·插画素材,本文件只做纯代码可画的
/// 渐变 / 几何 / 低多边形 / 光斑 等;后续可再加「图片皮肤」类型。

const String kHeaderSkinNone = 'none';

class HeaderSkin {
  const HeaderSkin({required this.id, required this.nameOf, required this.builder});

  final String id;

  /// 皮肤显示名(i18n):用 AppLocalizations 解析,不硬编码。
  final String Function(AppLocalizations l10n) nameOf;

  /// 返回铺满 header 的装饰层(放进 Positioned.fill)。
  final Widget Function(Color primary, bool isDark) builder;
}

// ---- HSL 派生工具 ----
Color _lighten(Color c, double amount) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
}

Color _hueShift(Color c, double deg) {
  final h = HSLColor.fromColor(c);
  return h.withHue((h.hue + deg) % 360).toColor();
}

/// 纯黑 → primary 插值(暗色模式底色用)
Color _onBlack(Color primary, double t) => Color.lerp(Colors.black, primary, t)!;

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
];

HeaderSkin? headerSkinById(String id) {
  for (final s in kHeaderSkins) {
    if (s.id == id) return s;
  }
  return null;
}

// ============================ 极光(渐变 + 柔光斑) ============================

class _AuroraSkin extends StatelessWidget {
  const _AuroraSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, _onBlack(primary, 0.28)]
        : [_lighten(primary, 0.20), primary, _lighten(_hueShift(primary, 30), 0.12)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _AuroraPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final blobs = <(Offset, double)>[
      (Offset(size.width * 0.15, size.height * 0.25), size.width * 0.24),
      (Offset(size.width * 0.88, size.height * 0.12), size.width * 0.18),
      (Offset(size.width * 0.72, size.height * 0.85), size.width * 0.28),
    ];
    for (final (center, r) in blobs) {
      final paint = Paint()
        ..color = (isDark ? primary : Colors.white)
            .withValues(alpha: isDark ? 0.12 : 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.primary != primary || old.isDark != isDark;
}

// ============================ 山峦(低多边形 + 日月) ============================

class _MountainsSkin extends StatelessWidget {
  const _MountainsSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, _onBlack(primary, 0.18)]
        : [_lighten(primary, 0.24), _lighten(primary, 0.06)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _MountainsPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MountainsPainter extends CustomPainter {
  _MountainsPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // 日 / 月
    final orb = Paint()
      ..color = (isDark ? _onBlack(primary, 0.6) : Colors.white)
          .withValues(alpha: isDark ? 0.30 : 0.5);
    canvas.drawCircle(Offset(w * 0.78, h * 0.30), h * 0.16, orb);

    // 远山
    final back = Paint()
      ..color = (isDark ? _onBlack(primary, 0.30) : _lighten(primary, -0.02))
          .withValues(alpha: isDark ? 0.55 : 0.45);
    final p1 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.72)
      ..lineTo(w * 0.26, h * 0.50)
      ..lineTo(w * 0.52, h * 0.74)
      ..lineTo(w * 0.78, h * 0.48)
      ..lineTo(w, h * 0.70)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(p1, back);

    // 近山
    final front = Paint()
      ..color = (isDark ? _onBlack(primary, 0.48) : _lighten(primary, -0.10))
          .withValues(alpha: isDark ? 0.85 : 0.62);
    final p2 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.88)
      ..lineTo(w * 0.18, h * 0.68)
      ..lineTo(w * 0.40, h * 0.90)
      ..lineTo(w * 0.62, h * 0.66)
      ..lineTo(w * 0.85, h * 0.88)
      ..lineTo(w, h * 0.74)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(p2, front);
  }

  @override
  bool shouldRepaint(covariant _MountainsPainter old) =>
      old.primary != primary || old.isDark != isDark;
}

// ============================ 光斑(渐变 + 散落气泡) ============================

class _BokehSkin extends StatelessWidget {
  const _BokehSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, _onBlack(primary, 0.24)]
        : [
            _lighten(_hueShift(primary, -25), 0.12),
            primary,
            _lighten(_hueShift(primary, 35), 0.10),
          ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _BokehPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BokehPainter extends CustomPainter {
  _BokehPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7); // 固定种子,保持稳定
    final palette = isDark
        ? [primary, _hueShift(primary, 30), _lighten(primary, 0.2)]
        : [Colors.white, _lighten(primary, 0.25), _lighten(_hueShift(primary, 35), 0.15)];
    for (int i = 0; i < 9; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = size.width * (0.04 + rnd.nextDouble() * 0.14);
      final color = palette[rnd.nextInt(palette.length)];
      final paint = Paint()
        ..color = color.withValues(alpha: 0.08 + rnd.nextDouble() * 0.14);
      if (i % 3 == 0) {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      }
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BokehPainter old) =>
      old.primary != primary || old.isDark != isDark;
}

// ============================ 波浪(渐变 + 底部叠浪) ============================

class _WavesSkin extends StatelessWidget {
  const _WavesSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, _onBlack(primary, 0.16)]
        : [_lighten(primary, 0.18), primary];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _WavesPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  _WavesPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (int i = 0; i < 3; i++) {
      final baseY = h * (0.58 + i * 0.13);
      final amp = h * 0.07;
      final phase = i * 1.1;
      final color = (isDark ? primary : Colors.white)
          .withValues(alpha: isDark ? 0.08 + i * 0.03 : 0.10 + i * 0.05);
      final path = Path()..moveTo(0, baseY);
      for (double x = 0; x <= w; x += w / 48) {
        path.lineTo(x, baseY + amp * math.sin((x / w) * 2 * math.pi * 1.4 + phase));
      }
      path
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter old) =>
      old.primary != primary || old.isDark != isDark;
}

// ====== 几何图案皮肤(由原暗黑模式装饰图案改造而来:两种模式都可用) ======
// 共用一个渐变底 + 图案画笔:亮色用白色图案叠在主题色渐变上,暗色用主题色图案叠在黑底上。

class _PatternSkin extends StatelessWidget {
  const _PatternSkin(this.primary, this.isDark, this.painterFor);
  final Color primary;
  final bool isDark;
  final CustomPainter Function(Color patternColor) painterFor;

  @override
  Widget build(BuildContext context) {
    // 透明底:让 header 基础色透出(亮=主题色 / 暗=纯黑)。暗色模式下图案用主题色,
    // 与原「暗黑模式头部图案」**完全一致**;亮色模式用白色让图案在主题色底上可见。
    return CustomPaint(
      painter: painterFor(isDark ? primary : Colors.white),
      child: const SizedBox.expand(),
    );
  }
}

/// 蜂巢六边形
class _HoneycombPainter extends CustomPainter {
  _HoneycombPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const hexSize = 30.0;
    final hexHeight = hexSize * math.sqrt(3);
    final hexWidth = hexSize * 2;
    final rows = (size.height / hexHeight * 1.5).ceil() + 2;
    final cols = (size.width / (hexWidth * 0.75)).ceil() + 2;
    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final x = col * hexWidth * 0.75;
        final y = row * hexHeight + (col.isOdd ? hexHeight / 2 : 0);
        final random = math.Random((row * 1000 + col).hashCode);
        if (random.nextDouble() > 0.3) {
          final path = Path();
          for (int i = 0; i < 6; i++) {
            final a = (math.pi / 3) * i;
            final px = x + hexSize * math.cos(a);
            final py = y + hexSize * math.sin(a);
            if (i == 0) {
              path.moveTo(px, py);
            } else {
              path.lineTo(px, py);
            }
          }
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HoneycombPainter old) => old.color != color;
}

/// 星河(粒子 + 五角星)
class _StarryPainter extends CustomPainter {
  _StarryPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // 固定种子,保持一致性
    for (int i = 0; i < 35; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final particleSize = 2.0 + random.nextDouble() * 4; // 2-6 px
      final opacity = 0.1 + random.nextDouble() * 0.15; // 10%-25%
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), particleSize, paint);
      // 20% 的粒子带光晕(与原暗黑装饰一致)
      if (i % 5 == 0) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: opacity * 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(x, y), particleSize * 2, glowPaint);
      }
    }
    for (int i = 0; i < 10; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = 8.0 + random.nextDouble() * 8; // 8-16px
      final opacity = 0.15 + random.nextDouble() * 0.1;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawPath(_star(x, y, starSize, starSize * 0.4), paint);
    }
  }

  Path _star(double cx, double cy, double outer, double inner) {
    final path = Path();
    const points = 5;
    const angle = math.pi / points;
    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outer : inner;
      final a = angle * i - math.pi / 2;
      final x = cx + radius * math.cos(a);
      final y = cy + radius * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _StarryPainter old) => old.color != color;
}

/// 斜纹(三组不同粗细的对角线)
class _StripesPainter extends CustomPainter {
  _StripesPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 30.0;
    final paints = [
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
      Paint()
        ..color = color.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    ];
    for (int g = 0; g < 3; g++) {
      for (double i = -size.height + spacing * g;
          i < size.width + size.height;
          i += spacing * 3) {
        canvas.drawLine(
            Offset(i, 0), Offset(i + size.height, size.height), paints[g]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StripesPainter old) => old.color != color;
}
