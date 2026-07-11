part of '../header_skins.dart';

// ============================ 水磨石(随机碎片点缀) ============================

class _TerrazzoSkin extends StatelessWidget {
  const _TerrazzoSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
        : [_lighten(_hueShift(primary, 15), 0.24), _lighten(primary, 0.06)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _TerrazzoPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TerrazzoPainter extends CustomPainter {
  _TerrazzoPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42); // 固定种子
    // 随机小碎片(圆 / 方),多 hue 派生,营造水磨石点缀。
    for (int i = 0; i < 40; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final s = 2 + rnd.nextDouble() * 6;
      final c = _hueShift(primary, (rnd.nextDouble() - 0.5) * 90);
      final col = isDark ? _lighten(c, 0.12) : _lighten(c, -0.05);
      final paint = Paint()..color = col.withValues(alpha: isDark ? 0.55 : 0.6);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rnd.nextDouble() * math.pi * 2);
      if (rnd.nextDouble() > 0.5) {
        canvas.drawCircle(Offset.zero, s, paint);
      } else {
        canvas.drawRect(Rect.fromLTWH(-s, -s * 0.6, s * 2, s * 1.2), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _TerrazzoPainter old) =>
      old.primary != primary || old.isDark != isDark;
}
