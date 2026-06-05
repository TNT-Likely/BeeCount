part of '../header_skins.dart';

// ============================ 山峦(低多边形 + 日月) ============================

class _MountainsSkin extends StatelessWidget {
  const _MountainsSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
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
      ..color = (isDark ? primary : Colors.white)
          .withValues(alpha: isDark ? 0.22 : 0.5);
    canvas.drawCircle(Offset(w * 0.78, h * 0.30), h * 0.16, orb);

    // 远山
    final back = Paint()
      ..color = (isDark ? primary : _lighten(primary, -0.02))
          .withValues(alpha: isDark ? 0.15 : 0.45);
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
      ..color = (isDark ? primary : _lighten(primary, -0.10))
          .withValues(alpha: isDark ? 0.26 : 0.62);
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
