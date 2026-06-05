part of '../header_skins.dart';

// ============================ 光斑(渐变 + 散落气泡) ============================

class _BokehSkin extends StatelessWidget {
  const _BokehSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
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
        ..color = color.withValues(
            alpha: (isDark ? 0.06 : 0.08) + rnd.nextDouble() * 0.12);
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
