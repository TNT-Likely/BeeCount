part of '../header_skins.dart';

// ============================ 日落(渐变 + 落日 + 山) ============================

class _SunsetSkin extends StatelessWidget {
  const _SunsetSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
        : [_lighten(_hueShift(primary, 18), 0.22), _lighten(primary, 0.04)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _SunsetPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SunsetPainter extends CustomPainter {
  _SunsetPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 落日
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.66),
      h * 0.3,
      Paint()
        ..color = (isDark ? primary : Colors.white)
            .withValues(alpha: isDark ? 0.22 : 0.6),
    );
    // 远山
    final back = Paint()
      ..color = (isDark ? primary : _lighten(primary, -0.02))
          .withValues(alpha: isDark ? 0.15 : 0.45);
    final p1 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.82);
    p1.quadraticBezierTo(w * 0.28, h * 0.66, w * 0.55, h * 0.8);
    p1.quadraticBezierTo(w * 0.8, h * 0.92, w, h * 0.74);
    p1
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(p1, back);
    // 近山
    final front = Paint()
      ..color = (isDark ? primary : _lighten(primary, -0.1))
          .withValues(alpha: isDark ? 0.26 : 0.66);
    final p2 = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.9);
    p2.quadraticBezierTo(w * 0.35, h * 0.78, w * 0.62, h * 0.92);
    p2.quadraticBezierTo(w * 0.85, h, w, h * 0.88);
    p2
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(p2, front);
  }

  @override
  bool shouldRepaint(covariant _SunsetPainter old) =>
      old.primary != primary || old.isDark != isDark;
}
