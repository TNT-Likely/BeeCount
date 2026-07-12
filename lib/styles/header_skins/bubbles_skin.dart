part of '../header_skins.dart';

// ============================ 气泡(渐变 + 散落圆 + 左上高光) ============================

class _BubblesSkin extends StatelessWidget {
  const _BubblesSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
        : [_lighten(_hueShift(primary, -15), 0.14), _lighten(primary, 0.04)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _BubblesPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BubblesPainter extends CustomPainter {
  _BubblesPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(21); // 固定种子,避免 rebuild 抖动
    for (int i = 0; i < 14; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final rad = 8 + rnd.nextDouble() * 32;
      final c = _hueShift(primary, (rnd.nextDouble() - 0.5) * 60);
      final fill = isDark ? _lighten(c, 0.12) : _lighten(c, 0.22);
      canvas.drawCircle(Offset(x, y), rad,
          Paint()..color = fill.withValues(alpha: isDark ? 0.3 : 0.55));
      // 左上高光,营造通透感
      final hi = isDark ? _lighten(c, 0.3) : Colors.white;
      canvas.drawCircle(Offset(x - rad * 0.3, y - rad * 0.3), rad * 0.35,
          Paint()..color = hi.withValues(alpha: isDark ? 0.25 : 0.4));
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter old) =>
      old.primary != primary || old.isDark != isDark;
}
