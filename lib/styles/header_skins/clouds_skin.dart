part of '../header_skins.dart';

// ============================ 云朵(渐变 + 叠云) ============================

class _CloudsSkin extends StatelessWidget {
  const _CloudsSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
        : [_lighten(primary, 0.22), _lighten(primary, 0.08)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _CloudsPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CloudsPainter extends CustomPainter {
  _CloudsPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  void _cloud(Canvas canvas, Offset c, double s, Paint paint) {
    canvas.drawCircle(Offset(c.dx, c.dy), s, paint);
    canvas.drawCircle(Offset(c.dx + s * 0.9, c.dy + s * 0.15), s * 0.8, paint);
    canvas.drawCircle(Offset(c.dx - s * 0.9, c.dy + s * 0.2), s * 0.7, paint);
    canvas.drawCircle(Offset(c.dx + s * 0.1, c.dy + s * 0.5), s * 0.85, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
            c.dx - s * 1.6, c.dy + s * 0.2, c.dx + s * 1.7, c.dy + s * 0.95),
        Radius.circular(s),
      ),
      paint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = (isDark ? primary : Colors.white)
          .withValues(alpha: isDark ? 0.13 : 0.6);
    _cloud(canvas, Offset(w * 0.22, h * 0.34), h * 0.12, paint);
    _cloud(canvas, Offset(w * 0.72, h * 0.22), h * 0.16, paint);
    _cloud(canvas, Offset(w * 0.85, h * 0.66), h * 0.1, paint);
  }

  @override
  bool shouldRepaint(covariant _CloudsPainter old) =>
      old.primary != primary || old.isDark != isDark;
}
