part of '../header_skins.dart';

// ============================ 城市(天际线 + 亮窗 + 月) ============================
// 场景皮肤:亮色在主题色明度区间内渐变,暗色纯黑底 + 淡主题色楼群、主题色亮窗。

class _SkylineSkin extends StatelessWidget {
  const _SkylineSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = isDark
        ? [Colors.black, Colors.black]
        : [_lighten(primary, 0.24), _lighten(primary, 0.05)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _SkylinePainter(primary, isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  _SkylinePainter(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // 月亮 + 光晕(左上,与山峦的右上日月区分)
    final moonColor =
        (isDark ? primary : Colors.white).withValues(alpha: isDark ? 0.25 : 0.5);
    canvas.drawCircle(Offset(w * 0.15, h * 0.26), h * 0.11, Paint()..color = moonColor);
    canvas.drawCircle(
      Offset(w * 0.15, h * 0.26),
      h * 0.18,
      Paint()
        ..color = moonColor.withValues(alpha: isDark ? 0.10 : 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 远景楼群(低透明度)
    final back = Paint()
      ..color = (isDark ? primary : _lighten(primary, -0.02))
          .withValues(alpha: isDark ? 0.14 : 0.40);
    final backRnd = math.Random(31);
    double x = -8;
    while (x < w) {
      final bw = 20.0 + backRnd.nextDouble() * 26;
      final bh = h * (0.28 + backRnd.nextDouble() * 0.26);
      canvas.drawRect(Rect.fromLTWH(x, h - bh, bw, bh), back);
      x += bw + 4 + backRnd.nextDouble() * 10;
    }

    // 近景楼群(更深)+ 亮窗
    final front = Paint()
      ..color = (isDark ? primary : _lighten(primary, -0.10))
          .withValues(alpha: isDark ? 0.26 : 0.62);
    final window = Paint()
      ..color =
          (isDark ? primary : Colors.white).withValues(alpha: isDark ? 0.45 : 0.55);
    final frontRnd = math.Random(17);
    x = -12;
    while (x < w) {
      final bw = 30.0 + frontRnd.nextDouble() * 30;
      final bh = h * (0.14 + frontRnd.nextDouble() * 0.26);
      final top = h - bh;
      canvas.drawRect(Rect.fromLTWH(x, top, bw, bh), front);
      // 亮窗:固定网格小方点,随机点亮
      const ww = 3.4, wh = 4.2, gridX = 11.0, gridY = 13.0;
      for (double wx = x + 5; wx + ww <= x + bw - 4; wx += gridX) {
        for (double wy = top + 7; wy + wh <= h - 6; wy += gridY) {
          if (frontRnd.nextDouble() < 0.45) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, ww, wh), window);
          }
        }
      }
      x += bw + 6 + frontRnd.nextDouble() * 12;
    }
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter old) =>
      old.primary != primary || old.isDark != isDark;
}
