part of '../header_skins.dart';

// ============================ 孟菲斯(几何拼贴) ============================
// 图案皮肤:圆环 / 圆点 / 三角 / 波浪线 / 十字 散布拼贴,亮色白叠主题色底,
// 暗色淡主题色叠纯黑底。

class _MemphisPainter extends CustomPainter {
  _MemphisPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = math.Random(2024); // 固定种子,保持一致性

    Offset pos() => Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);

    // 圆环
    for (int i = 0; i < 5; i++) {
      final r = 6.0 + rnd.nextDouble() * 9;
      canvas.drawCircle(
        pos(),
        r,
        Paint()
          ..color = color.withValues(alpha: 0.10 + rnd.nextDouble() * 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
    // 实心圆点
    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(
        pos(),
        2.0 + rnd.nextDouble() * 2.5,
        Paint()..color = color.withValues(alpha: 0.12 + rnd.nextDouble() * 0.10),
      );
    }
    // 空心三角
    for (int i = 0; i < 4; i++) {
      final c = pos();
      final r = 8.0 + rnd.nextDouble() * 7;
      final rot = rnd.nextDouble() * math.pi * 2;
      final path = Path();
      for (int v = 0; v < 3; v++) {
        final a = rot + v * 2 * math.pi / 3;
        final p = c + Offset(r * math.cos(a), r * math.sin(a));
        v == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.10 + rnd.nextDouble() * 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
    // 波浪短线(三个半波)
    for (int i = 0; i < 3; i++) {
      final c = pos();
      final rot = (rnd.nextDouble() - 0.5) * 0.8;
      const seg = 9.0, amp = 5.0;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rot);
      final path = Path()..moveTo(0, 0);
      for (int s = 0; s < 3; s++) {
        path.relativeQuadraticBezierTo(seg / 2, s.isEven ? -amp : amp, seg, 0);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.12 + rnd.nextDouble() * 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
    // 十字
    for (int i = 0; i < 3; i++) {
      final c = pos();
      final r = 4.0 + rnd.nextDouble() * 3;
      final rot = rnd.nextDouble() * math.pi;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.12 + rnd.nextDouble() * 0.08)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rot);
      canvas.drawLine(Offset(-r, 0), Offset(r, 0), paint);
      canvas.drawLine(Offset(0, -r), Offset(0, r), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MemphisPainter old) => old.color != color;
}
