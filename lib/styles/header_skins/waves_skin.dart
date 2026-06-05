part of '../header_skins.dart';

// ============================ 波浪(渐变 + 底部叠浪) ============================

class _WavesSkin extends StatelessWidget {
  const _WavesSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
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
          .withValues(alpha: isDark ? 0.07 + i * 0.03 : 0.10 + i * 0.05);
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
