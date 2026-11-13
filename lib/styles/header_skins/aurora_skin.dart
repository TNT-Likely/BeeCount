part of '../header_skins.dart';

// ============================ 极光(渐变 + 柔光斑) ============================

class _AuroraSkin extends StatelessWidget {
  const _AuroraSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? _auroraNightColors(primary)
        : [
            _lighten(primary, 0.20),
            primary,
            _lighten(_hueShift(primary, 30), 0.12)
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
    if (size.isEmpty) return;
    if (isDark) {
      _paintNight(canvas, size);
      return;
    }
    final blobs = <(Offset, double)>[
      (Offset(size.width * 0.15, size.height * 0.25), size.width * 0.24),
      (Offset(size.width * 0.88, size.height * 0.12), size.width * 0.18),
      (Offset(size.width * 0.72, size.height * 0.85), size.width * 0.28),
    ];
    for (final (center, r) in blobs) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
      canvas.drawCircle(center, r, paint);
    }
  }

  void _paintNight(Canvas canvas, Size size) {
    // Soft, static curtains remain visible behind translucent cards. Their
    // luminance is limited so white labels do not sit on a bright light source.
    final hue = HSLColor.fromColor(primary).hue;
    final mint = HSLColor.fromAHSL(1, (hue + 65) % 360, .58, .42).toColor();
    final blue = HSLColor.fromAHSL(1, (hue + 145) % 360, .62, .40).toColor();
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
              center: const Alignment(.70, -.65),
              radius: 1.1,
              colors: [
                mint.withValues(alpha: .20),
                mint.withValues(alpha: 0)
              ]).createShader(rect));
    for (final (offset, color, alpha) in [
      (0.0, mint, .20),
      (.18, blue, .16),
    ]) {
      final curtain = Path()
        ..moveTo(-size.width * .15, size.height * (.58 + offset))
        ..cubicTo(
            size.width * .20,
            size.height * (.08 + offset),
            size.width * .48,
            size.height * (.80 + offset),
            size.width * .72,
            size.height * (.25 + offset))
        ..cubicTo(
            size.width * .87,
            size.height * (-.05 + offset),
            size.width * 1.02,
            size.height * (.12 + offset),
            size.width * 1.16,
            size.height * (.05 + offset));
      canvas.drawPath(
          curtain,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * .20
            ..strokeCap = StrokeCap.round
            ..color = color.withValues(alpha: alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25));
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.primary != primary || old.isDark != isDark;
}

List<Color> _auroraNightColors(Color primary) => [
      Color.lerp(const Color(0xff101b24), primary, .035)!,
      const Color(0xff101b22),
      const Color(0xff14191f),
    ];
