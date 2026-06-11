part of '../header_skins.dart';

// ============================ 樱花(满开花朵 + 飘落花瓣) ============================
// 图案皮肤:亮色白花叠主题色底,暗色淡主题色花叠纯黑底(由 _PatternSkin 决定颜色)。

class _SakuraPainter extends CustomPainter {
  _SakuraPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7); // 固定种子,保持一致性
    // 满开花朵
    for (int i = 0; i < 7; i++) {
      final cx = rnd.nextDouble() * size.width;
      final cy = rnd.nextDouble() * size.height;
      final r = 10.0 + rnd.nextDouble() * 13; // 花半径 10-23
      final rot = rnd.nextDouble() * math.pi;
      final alpha = 0.10 + rnd.nextDouble() * 0.12;
      _drawBlossom(canvas, Offset(cx, cy), r, rot, alpha);
    }
    // 飘落单瓣(旋转的小椭圆)
    for (int i = 0; i < 14; i++) {
      final cx = rnd.nextDouble() * size.width;
      final cy = rnd.nextDouble() * size.height;
      final r = 3.5 + rnd.nextDouble() * 4.5;
      final rot = rnd.nextDouble() * math.pi * 2;
      final alpha = 0.08 + rnd.nextDouble() * 0.12;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: r * 0.9, height: r * 1.6),
        Paint()..color = color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  /// 五瓣花:5 个绕中心旋转的椭圆花瓣 + 花蕊
  void _drawBlossom(
      Canvas canvas, Offset c, double r, double rot, double alpha) {
    final petal = Paint()..color = color.withValues(alpha: alpha);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    for (int i = 0; i < 5; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / 5);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, -r * 0.55), width: r * 0.62, height: r * 0.95),
        petal,
      );
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      r * 0.14,
      Paint()..color = color.withValues(alpha: (alpha * 1.6).clamp(0.0, 1.0)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SakuraPainter old) => old.color != color;
}
