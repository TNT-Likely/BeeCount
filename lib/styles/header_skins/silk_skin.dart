part of '../header_skins.dart';

// ============================ 丝带(斜向流动的半透明色带) ============================

class _SilkSkin extends StatelessWidget {
  const _SilkSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
        : [_lighten(_hueShift(primary, 20), 0.22), _lighten(primary, 0.05)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _SilkPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SilkPainter extends CustomPainter {
  _SilkPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 多层斜向 sine 色带,自下往上叠,每层 hueShift 派生一点色相偏移。
    for (int i = 0; i < 5; i++) {
      final c = _hueShift(primary, i * 14.0 - 20);
      final color = isDark ? c : _lighten(c, 0.2);
      final paint = Paint()..color = color.withValues(alpha: isDark ? 0.16 : 0.5);
      final path = Path()..moveTo(-20, h);
      for (double x = -20; x <= w + 20; x += 8) {
        final y = h * 0.5 + math.sin(x / 60 + i * 1.3) * h * 0.28 + i * 6 - 14;
        path.lineTo(x, y);
      }
      path
        ..lineTo(w + 20, h)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SilkPainter old) =>
      old.primary != primary || old.isDark != isDark;
}
