part of '../header_skins.dart';

// ============================ 流星(星点 + 拖尾流星) ============================
// 图案皮肤:亮色白色星与流星叠主题色底,暗色淡主题色叠纯黑底。

class _MeteorPainter extends CustomPainter {
  _MeteorPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rnd = math.Random(99); // 固定种子,保持一致性

    // 背景星点
    for (int i = 0; i < 24; i++) {
      final x = rnd.nextDouble() * w;
      final y = rnd.nextDouble() * h;
      final r = 1.2 + rnd.nextDouble() * 2.0;
      final alpha = 0.10 + rnd.nextDouble() * 0.15;
      canvas.drawCircle(
          Offset(x, y), r, Paint()..color = color.withValues(alpha: alpha));
    }

    // 三道流星:头亮尾淡,向左下划过(尾巴指向右上)
    const streaks = [
      (0.72, 0.22, 130.0, 0.45),
      (0.46, 0.58, 90.0, 0.35),
      (0.20, 0.30, 64.0, 0.30),
    ];
    const angle = 0.55; // 弧度,约 31.5°
    final dir = Offset(math.cos(angle), -math.sin(angle)); // 指向右上(尾巴方向)
    for (final (fx, fy, len, headAlpha) in streaks) {
      final head = Offset(w * fx, h * fy);
      final tail = head + dir * len;
      final streak = Paint()
        ..shader = ui.Gradient.linear(head, tail, [
          color.withValues(alpha: headAlpha),
          color.withValues(alpha: 0.0),
        ])
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(head, tail, streak);
      // 流星头部光点 + 光晕
      canvas.drawCircle(head, 2.4,
          Paint()..color = color.withValues(alpha: headAlpha + 0.15));
      canvas.drawCircle(
        head,
        5.0,
        Paint()
          ..color = color.withValues(alpha: headAlpha * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeteorPainter old) => old.color != color;
}
