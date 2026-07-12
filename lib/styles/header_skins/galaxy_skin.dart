part of '../header_skins.dart';

// ============================ 星系(中心径向光晕 + 漩涡星点) ============================

class _GalaxySkin extends StatelessWidget {
  const _GalaxySkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
        : [_lighten(_hueShift(primary, 20), 0.2), _lighten(primary, 0.05)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _GalaxyPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GalaxyPainter extends CustomPainter {
  _GalaxyPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    // 中心径向光晕
    final glowColor =
        isDark ? _lighten(primary, 0.1) : _lighten(_hueShift(primary, 30), 0.28);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withValues(alpha: isDark ? 0.5 : 0.7),
          glowColor.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.45));
    canvas.drawRect(Offset.zero & size, glow);
    // 漩涡星点(椭圆分布,模拟星系盘面)
    final rnd = math.Random(99);
    for (int i = 0; i < 60; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final dist = rnd.nextDouble() * w * 0.5;
      final x = center.dx + math.cos(a) * dist;
      final y = center.dy + math.sin(a) * dist * 0.5;
      final star = isDark ? Colors.white : _lighten(primary, -0.1);
      canvas.drawCircle(
          Offset(x, y),
          rnd.nextDouble() * 1.4 + 0.4,
          Paint()
            ..color = star.withValues(
                alpha: isDark ? (0.8 * rnd.nextDouble() + 0.2) : 0.55));
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter old) =>
      old.primary != primary || old.isDark != isDark;
}
