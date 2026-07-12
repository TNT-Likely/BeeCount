part of '../header_skins.dart';

// ============================ 低多边形(三角晶格) ============================

class _LowPolySkin extends StatelessWidget {
  const _LowPolySkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
        : [_lighten(_hueShift(primary, 12), 0.2), _lighten(primary, 0.04)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _LowPolyPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LowPolyPainter extends CustomPainter {
  _LowPolyPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7); // 固定种子
    const cols = 8, rows = 3;
    final cw = size.width / cols, ch = size.height / rows;
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        // 每格切成两个三角,逐块明度微扰形成晶格质感。
        for (int t = 0; t < 2; t++) {
          final sh = (rnd.nextDouble() - 0.5) * 0.18;
          final base = isDark
              ? _lighten(primary, -0.28 + sh)
              : _lighten(primary, 0.14 + sh);
          final path = Path();
          if (t == 0) {
            path
              ..moveTo(x * cw, y * ch)
              ..lineTo((x + 1) * cw, y * ch)
              ..lineTo(x * cw, (y + 1) * ch);
          } else {
            path
              ..moveTo((x + 1) * cw, y * ch)
              ..lineTo((x + 1) * cw, (y + 1) * ch)
              ..lineTo(x * cw, (y + 1) * ch);
          }
          path.close();
          canvas.drawPath(
              path, Paint()..color = base.withValues(alpha: isDark ? 0.9 : 1));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LowPolyPainter old) =>
      old.primary != primary || old.isDark != isDark;
}
