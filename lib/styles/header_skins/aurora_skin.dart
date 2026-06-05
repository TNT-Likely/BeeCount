part of '../header_skins.dart';

// ============================ 极光(渐变 + 柔光斑) ============================

class _AuroraSkin extends StatelessWidget {
  const _AuroraSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
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
            .withValues(alpha: isDark ? 0.13 : 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.primary != primary || old.isDark != isDark;
}
