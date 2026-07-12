part of '../header_skins.dart';

// ============================ 棱镜(斜向光谱色带) ============================

class _PrismSkin extends StatelessWidget {
  const _PrismSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
        : [_lighten(primary, 0.2), _lighten(primary, 0.04)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _PrismPainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PrismPainter extends CustomPainter {
  _PrismPainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 7 条斜向平行四边形,沿色相扫过一段光谱(hueShift 派生)。
    for (int i = 0; i < 7; i++) {
      final c = _hueShift(primary, i * 18.0 - 30);
      final col = isDark ? _lighten(c, 0.05) : _lighten(c, 0.18);
      final x0 = w * (i / 7) - w * 0.2;
      final path = Path()
        ..moveTo(x0, 0)
        ..lineTo(x0 + w * 0.16, 0)
        ..lineTo(x0 + w * 0.16 - h * 0.6, h)
        ..lineTo(x0 - h * 0.6, h)
        ..close();
      canvas.drawPath(
          path, Paint()..color = col.withValues(alpha: isDark ? 0.4 : 0.7));
    }
  }

  @override
  bool shouldRepaint(covariant _PrismPainter old) =>
      old.primary != primary || old.isDark != isDark;
}
