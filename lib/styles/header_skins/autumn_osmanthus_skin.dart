part of '../header_skins.dart';

// ============ 秋日皮肤:桂月中秋(Osmanthus Moon) ============
//
// **跟随主题色**(秋日六款里唯一一款):月下折桂 —— 一轮满月挂右侧,桂枝从右上
// 垂到月前,金桂簌簌落一屏,月中有嫦娥与捣药玉兔。中秋 2026-09-25 联动。
// 设计稿:autumn-skins.html 的「秋 · C」。
//
// 嫦娥的画法要点:月径只有 ~68pt,人形画在月内必然糊。解法是让嫦娥**跨越月亮
// 边界** —— 月内部分深色剪影、月外飘带反成亮色(saveLayer + clip 两遍绘制),
// 人形尺寸就不再受月径限制。剪影只保留可辨认特征:双高髻、收腰上身、
// 前伸捧物的手、分成两条的细长裙裾。玉兔则靠「头大 + 身圆 + 耳比身长」。

class _OsmanthusMoonSkin extends StatelessWidget {
  const _OsmanthusMoonSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 12,
        painterFor: (a) => _OsmanthusPainter(primary, isDark, a),
      );
}

class _OsmanthusPainter extends CustomPainter {
  _OsmanthusPainter(this.primary, this.isDark, this.anim) : super(repaint: anim);
  final Color primary;
  final bool isDark;
  final Animation<double> anim;

  Color get _moon => isDark ? _lighten(primary, .08) : const Color(0xFFFFFDF5);
  Color get _flower => isDark ? const Color(0xFFFFD54F) : Colors.white;
  Color get _branch => isDark
      ? _lighten(primary, .05).withValues(alpha: .78)
      : const Color(0xFF6A3E10).withValues(alpha: .8);

  /// 月面剪影色:亮色白月上用暖金、暗色金月上用近黑,两边都清晰。
  Color get _shadow => isDark ? const Color(0xFF1A1206) : const Color(0xFFD89A12);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final moonC = _ap(size, 238, 104);
    final moonR = _ax(size, 34);

    // 底:亮色主题色 / 暗色纯黑
    canvas.drawRect(Offset.zero & size,
        Paint()..color = isDark ? Colors.black : primary);
    // 亮色下白月与主题色底对比不足,月周压一圈暗环让它「浮」起来
    if (!isDark) {
      canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = RadialGradient(colors: [
              Colors.black.withValues(alpha: .16),
              Colors.black.withValues(alpha: 0),
            ], stops: const [.42, 1])
                .createShader(Rect.fromCircle(center: moonC, radius: moonR * 2.6)));
    }
    _paintRadialGlow(canvas, size, moonC, size.width * .6, _moon, isDark ? .28 : .45);

    // 月亮(呼吸)
    final breathe = 1 + .03 * math.sin(t * math.pi * 2 * 2);
    final r = moonR * breathe;
    canvas.drawCircle(moonC, r, Paint()..color = _moon.withValues(alpha: .96));
    canvas.drawCircle(moonC + Offset(-r * .5, -r * .45), r * .19,
        Paint()..color = _shadow.withValues(alpha: .09));

    _paintCelestials(canvas, size, moonC, r);
    _paintBranch(canvas, size, t);
    _paintPetals(canvas, size, t);
    _paintTwinkles(canvas, size, t,
        color: isDark ? _lighten(primary, .08) : Colors.white,
        seed: 61,
        count: 14,
        maxAlpha: .55);
  }

  /// 嫦娥 + 玉兔。嫦娥跨月边界:月内深色、月外亮色。
  void _paintCelestials(Canvas canvas, Size size, Offset moonC, double r) {
    final k = r / 34; // 相对设计稿的缩放

    void drawChangE(Color color, double opacity) {
      canvas.save();
      canvas.translate(moonC.dx - 2 * k, moonC.dy - 2 * k);
      canvas.scale(k * .88);
      final fill = Paint()..color = color.withValues(alpha: opacity);
      final stroke = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // 绕身飘带(斜向右上,和飞行方向一致)
      canvas.drawPath(
          Path()
            ..moveTo(19, -21)
            ..cubicTo(26.5, -25.5, 34, -21, 32, -12.5)
            ..cubicTo(30.4, -6.5, 24.4, -7.6, 23.4, -12.6),
          stroke..strokeWidth = 1.9);
      canvas.drawPath(
          Path()
            ..moveTo(-23, 11.5)
            ..cubicTo(-30.5, 14.5, -38.5, 11, -40.5, 3.5),
          stroke..strokeWidth = 1.7);
      // 裙裾:两条细长飘带(一整块会像鱼尾)
      canvas.drawPath(
          Path()
            ..moveTo(5.6, -1.6)
            ..cubicTo(3.4, 2.6, -1.4, 6.6, -8.4, 9.8)
            ..cubicTo(-13.4, 12, -18.6, 12.8, -23.4, 12)
            ..cubicTo(-18.4, 8.6, -12.4, 5.4, -8, 2)
            ..cubicTo(-4.6, -.6, -1.8, -2.4, .6, -3.4)
            ..close(),
          fill);
      canvas.drawPath(
          Path()
            ..moveTo(1.4, -2.2)
            ..cubicTo(-2.6, 1.4, -8.4, 5, -15.4, 8.2)
            ..cubicTo(-19.8, 10, -24.2, 10.8, -28, 10.4)
            ..cubicTo(-23.6, 7.8, -18.2, 4.8, -14, 1.8)
            ..cubicTo(-10.6, -.6, -7.4, -2.2, -5, -2.8)
            ..close(),
          fill);
      // 收腰上身
      canvas.drawPath(
          Path()
            ..moveTo(9, -18)
            ..cubicTo(11.2, -14, 11.2, -9.6, 9.4, -5.6)
            ..cubicTo(8.4, -3.4, 7, -2, 5.6, -1.4)
            ..lineTo(2.8, -3)
            ..cubicTo(4.8, -6, 6.2, -10, 6.2, -13.8)
            ..cubicTo(6.2, -16, 7.2, -17.4, 9, -18)
            ..close(),
          fill);
      // 前伸捧物的手 + 后摆的手
      canvas.drawPath(
          Path()
            ..moveTo(8.6, -17)
            ..cubicTo(12.2, -19.6, 16, -21, 19, -20.6),
          stroke..strokeWidth = 2.4);
      canvas.drawCircle(const Offset(20.8, -20.6), 2, fill);
      canvas.drawPath(
          Path()
            ..moveTo(6.4, -15.4)
            ..cubicTo(3, -13.4, .6, -10.4, -1, -6.8),
          stroke..strokeWidth = 2.1);
      // 头 + 双高髻
      canvas.drawCircle(const Offset(8.4, -21.8), 4.1, fill);
      canvas.drawCircle(const Offset(5.8, -26.2), 2.6, fill);
      canvas.drawCircle(const Offset(10.8, -26.4), 2.1, fill);
      canvas.restore();
    }

    // 月内:深色剪影
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: moonC, radius: r)));
    drawChangE(_shadow, .78);
    canvas.restore();
    // 月外:亮色(飘带伸进夜空)
    canvas.save();
    canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          Path()..addOval(Rect.fromCircle(center: moonC, radius: r)),
        ));
    drawChangE(_moon, isDark ? .72 : .9);
    canvas.restore();

    // 玉兔(月内右下):头大、身圆、耳比身长
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: moonC, radius: r)));
    canvas.translate(moonC.dx + 16 * k, moonC.dy + 16 * k);
    canvas.scale(k * .72);
    final rf = Paint()..color = _shadow.withValues(alpha: .6);
    final rs = Paint()
      ..color = _shadow.withValues(alpha: .6)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(Rect.fromCenter(center: const Offset(-1, 1), width: 13.6, height: 11.2), rf);
    canvas.drawCircle(const Offset(-8, 0), 2.4, rf);
    canvas.drawCircle(const Offset(6.2, -6.4), 5, rf);
    canvas.drawPath(
        Path()
          ..moveTo(4, -11)
          ..cubicTo(1.6, -19, 3, -24.5, 5.4, -23.8)
          ..cubicTo(7.8, -23.2, 7.6, -17, 6.8, -10.2)
          ..close(),
        rf);
    canvas.drawPath(
        Path()
          ..moveTo(8, -11.2)
          ..cubicTo(9, -18.6, 11.8, -23, 13.8, -21.8)
          ..cubicTo(15.9, -20.6, 14.2, -15.4, 10.6, -10)
          ..close(),
        rf);
    canvas.drawPath(
        Path()
          ..moveTo(5.4, -1.6)
          ..cubicTo(8.2, -2.6, 10.6, -1.4, 11, .8),
        rs..strokeWidth = 2);
    canvas.drawPath(Path()..moveTo(8.4, -.6)..lineTo(15.6, -9.2), rs..strokeWidth = 2.8);
    canvas.drawPath(
        Path()
          ..moveTo(12.4, 5)
          ..lineTo(20.4, 5)
          ..lineTo(19, 9.6)
          ..lineTo(13.8, 9.6)
          ..close(),
        rf);
    canvas.restore();
  }

  /// 桂枝:从右上垂到月前,左侧整片留白给标题(轻微摇曳)。
  /// 位置按比例映射、尺寸等比缩放 —— 非等比会把叶片和花瓣压扁。
  void _paintBranch(Canvas canvas, Size size, double t) {
    final sway = math.sin(t * math.pi * 2 * 2) * .022;
    final u = (size.height / 208).clamp(.55, 1.0);
    Offset p(double x, double y) => _ap(size, x, y);

    canvas.save();
    final pivot = p(300, 0);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(sway);
    canvas.translate(-pivot.dx, -pivot.dy);

    final stroke = Paint()
      ..color = _branch
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8 * u
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(p(302, 4).dx, p(302, 4).dy)
          ..cubicTo(p(290, 30).dx, p(290, 30).dy, p(274, 58).dx, p(274, 58).dy,
              p(252, 84).dx, p(252, 84).dy)
          ..moveTo(p(280, 38).dx, p(280, 38).dy)
          ..cubicTo(p(268, 50).dx, p(268, 50).dy, p(260, 66).dx, p(260, 66).dy,
              p(258, 82).dx, p(258, 82).dy)
          ..moveTo(p(262, 70).dx, p(262, 70).dy)
          ..cubicTo(p(270, 82).dx, p(270, 82).dy, p(274, 96).dx, p(274, 96).dy,
              p(274, 110).dx, p(274, 110).dy),
        stroke);
    final leafP = Paint()..color = _branch;
    for (final l in const [
      [286.0, 30.0, 34.0],
      [268.0, 56.0, 52.0],
      [264.0, 92.0, -40.0],
      [296.0, 14.0, 20.0],
      [274.0, 74.0, 10.0],
    ]) {
      canvas.save();
      final c = p(l[0], l[1]);
      canvas.translate(c.dx, c.dy);
      canvas.rotate(l[2] * math.pi / 180);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 21 * u, height: 8 * u), leafP);
      canvas.restore();
    }
    final fp = Paint()..color = _flower;
    final cp = Paint()
      ..color = isDark ? const Color(0xFFB8860B) : const Color(0xFFE8A317);
    for (final f in const [
      [276.0, 42.0],
      [260.0, 68.0],
      [270.0, 100.0],
      [292.0, 24.0],
      [254.0, 86.0],
    ]) {
      final c = p(f[0], f[1]);
      for (final d in const [
        [0.0, -2.6],
        [2.6, 0.0],
        [0.0, 2.6],
        [-2.6, 0.0],
      ]) {
        canvas.drawCircle(c + Offset(d[0] * u, d[1] * u), 2.2 * u, fp);
      }
      canvas.drawCircle(c, 1.1 * u, cp);
    }
    canvas.restore();
  }

  /// 桂花簌簌飘落。
  void _paintPetals(Canvas canvas, Size size, double t) {
    final rnd = math.Random(67);
    for (int i = 0; i < 14; i++) {
      final xr = rnd.nextDouble() * .92;
      final phase = rnd.nextDouble();
      final speed = 1 + (i % 2);
      final swayF = 3 + rnd.nextInt(3);
      final r = 1.8 + rnd.nextDouble() * 1.5;
      final p = (t * speed + phase) % 1;
      final y = -6 + (size.height + 12) * p;
      final x = size.width * xr +
          math.sin((t * swayF + phase) * math.pi * 2) * size.width * .035;
      final op = (p < .08 ? p / .08 : (p > .9 ? (1 - p) / .1 : 1)).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = _flower.withValues(alpha: op * (isDark ? .85 : .95)));
    }
  }

  @override
  bool shouldRepaint(covariant _OsmanthusPainter old) =>
      old.primary != primary || old.isDark != isDark;
}

class _OsmanthusMoonTabDeco extends StatelessWidget {
  const _OsmanthusMoonTabDeco(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 10,
        painterFor: (a) => _OsmanthusTabPainter(primary, isDark, a),
      );
}

class _OsmanthusTabPainter extends CustomPainter {
  _OsmanthusTabPainter(this.primary, this.isDark, this.anim) : super(repaint: anim);
  final Color primary;
  final bool isDark;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final moon = isDark ? _lighten(primary, .08) : primary;
    final flower = isDark ? const Color(0xFFFFD54F) : Colors.white;
    final branch = (isDark ? _lighten(primary, .05) : const Color(0xFF6A3E10))
        .withValues(alpha: .55);
    final h = size.height;

    // 右端小满月 + 兔影
    final mc = Offset(size.width * .93, h * .3);
    final mr = h * .28 * (1 + .04 * math.sin(t * math.pi * 2 * 2));
    canvas.drawCircle(mc, mr, Paint()..color = moon.withValues(alpha: isDark ? .9 : .55));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: mc, radius: mr)));
    canvas.translate(mc.dx + mr * .1, mc.dy + mr * .25);
    canvas.scale(mr / 34);
    final sh = Paint()
      ..color = (isDark ? const Color(0xFF1A1206) : const Color(0xFFD89A12))
          .withValues(alpha: .55);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 13, height: 10), sh);
    canvas.drawCircle(const Offset(5.4, -3.4), 3, sh);
    canvas.drawPath(
        Path()
          ..moveTo(4.6, -6)
          ..cubicTo(3.6, -11, 5, -14.5, 6.6, -14)
          ..cubicTo(8, -13.6, 8, -10, 6.8, -5.6)
          ..close(),
        sh);
    canvas.drawPath(
        Path()
          ..moveTo(7, -6.2)
          ..cubicTo(7.4, -11, 9.4, -13.6, 10.8, -12.8)
          ..cubicTo(12, -12, 11.2, -8.8, 9, -5.2)
          ..close(),
        sh);
    canvas.restore();

    // 左端桂枝(带叶带花)
    canvas.save();
    final sway = math.sin(t * math.pi * 2 * 2) * .03;
    canvas.rotate(sway);
    final bs = Paint()
      ..color = branch
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(-size.width * .02, -h * .04)
          ..cubicTo(size.width * .04, h * .13, size.width * .085, h * .34,
              size.width * .13, h * .6)
          ..moveTo(size.width * .058, h * .17)
          ..cubicTo(size.width * .052, h * .3, size.width * .052, h * .43,
              size.width * .058, h * .55),
        bs);
    final lp = Paint()..color = branch;
    for (final l in const [
      [.039, .13, 26.0],
      [.084, .34, 32.0],
      [.055, .47, -24.0],
      [.119, .64, 40.0],
    ]) {
      canvas.save();
      canvas.translate(size.width * l[0], h * l[1]);
      canvas.rotate(l[2] * math.pi / 180);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: h * .3, height: h * .12), lp);
      canvas.restore();
    }
    final fp = Paint()..color = flower;
    for (final f in const [
      [.064, .26],
      [.1, .49],
      [.039, .38],
      [.129, .72],
    ]) {
      final c = Offset(size.width * f[0], h * f[1]);
      for (final d in const [
        [0.0, -1.0],
        [1.0, 0.0],
        [0.0, 1.0],
        [-1.0, 0.0],
      ]) {
        canvas.drawCircle(c + Offset(d[0] * h * .07, d[1] * h * .07), h * .055, fp);
      }
    }
    canvas.restore();

    // 花瓣飘落 6 片 + 微星
    final rnd = math.Random(29);
    for (int i = 0; i < 6; i++) {
      final phase = rnd.nextDouble();
      final p = (t * (1 + i % 2) + phase) % 1;
      final x = size.width * (.22 + i * .13) +
          math.sin((t * 3 + phase) * math.pi * 2) * size.width * .02;
      final y = -4 + (h + 8) * p;
      final op = (p < .12 ? p / .12 : (p > .85 ? (1 - p) / .15 : 1)).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(x, y), h * (.045 + (i % 2) * .012),
          Paint()..color = flower.withValues(alpha: op * .9));
    }
    for (int i = 0; i < 5; i++) {
      final wave = .5 + .5 * math.sin((t * (2 + i) + i * .4) * math.pi * 2);
      canvas.drawCircle(
          Offset(size.width * (.34 + i * .12), h * (i.isEven ? .2 : .74)),
          h * .028,
          Paint()..color = flower.withValues(alpha: .15 + wave * .7));
    }
  }

  @override
  bool shouldRepaint(covariant _OsmanthusTabPainter old) =>
      old.primary != primary || old.isDark != isDark;
}
