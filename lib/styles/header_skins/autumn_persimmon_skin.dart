part of '../header_skins.dart';

// ============ 秋日皮肤:柿柿如意(Persimmon Wishes) ============
//
// 固定柿橙 + 青萼(互补色,天然清爽不脏)。枝头挂满红柿子随风轻晃,一只小鸟
// 停在枝上。名字自带吉祥话 —— 记账 App 讨「事事如意」的口彩。
// 设计稿:autumn-skins.html 的「秋 · E」。
//
// 构图注意:枝条整体下移让开状态栏(0–30)与账本行(30–74),柿子落在
// 右侧安全区 y=78–140,小鸟停在中部横枝上。

const Color _kPersimSkinL = Color(0xFFF4581F);
const Color _kPersimSkinD = Color(0xFFFF7A45);
const Color _kPersimDeepL = Color(0xFFE23E10);
const Color _kPersimDeepD = Color(0xFFF4643C);
const Color _kCalyxL = Color(0xFF4F7A2E);
const Color _kCalyxD = Color(0xFF6FA84A);

class _PersimmonSkin extends StatelessWidget {
  const _PersimmonSkin(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 12,
        painterFor: (a) => _PersimmonPainter(isDark, a),
      );
}

class _PersimmonPainter extends CustomPainter {
  _PersimmonPainter(this.isDark, this.anim) : super(repaint: anim) {
    _leaves = _makeFallingLeaves(
      seed: 81,
      count: 3,
      kinds: const [_LeafKind.pointed],
      colorCount: 1,
      minSize: 17,
      maxSize: 26,
    );
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_FallingLeaf> _leaves;

  Color get _skin => isDark ? _kPersimSkinD : _kPersimSkinL;
  Color get _skinDeep => isDark ? _kPersimDeepD : _kPersimDeepL;
  Color get _calyx => isDark ? _kCalyxD : _kCalyxL;
  Color get _branch => (isDark ? const Color(0xFFB98A4A) : const Color(0xFF7A4A1E))
      .withValues(alpha: isDark ? .72 : .85);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;

    _paintVerticalBase(
      canvas,
      size,
      isDark
          ? const [Color(0xFF000000), Color(0xFF170800)]
          : const [Color(0xFFFFFBF3), Color(0xFFFFF0DC), Color(0xFFFFDFB8)],
      isDark ? null : const [0, .6, 1],
    );

    // 尺寸用**等比**缩放(矮 header 上元素变小但不变形 —— 非等比会把柿子压成
    // 椭圆);位置仍按各自比例映射,构图关系不变。
    final u = (size.height / 208).clamp(.55, 1.0);
    Offset p(double x, double y) => _ap(size, x, y);

    // 主枝(设计稿坐标,已整体下移)
    final bs = Paint()
      ..color = _branch
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(p(308, 34).dx, p(308, 34).dy)
          ..cubicTo(p(280, 42).dx, p(280, 42).dy, p(256, 58).dx, p(256, 58).dy,
              p(238, 78).dx, p(238, 78).dy)
          ..cubicTo(p(226, 92).dx, p(226, 92).dy, p(216, 102).dx, p(216, 102).dy,
              p(202, 108).dx, p(202, 108).dy),
        bs..strokeWidth = 4 * u);
    canvas.drawPath(
        Path()
          ..moveTo(p(268, 52).dx, p(268, 52).dy)
          ..cubicTo(p(260, 66).dx, p(260, 66).dy, p(258, 80).dx, p(258, 80).dy,
              p(260, 94).dx, p(260, 94).dy),
        bs..strokeWidth = 2.4 * u);
    canvas.drawPath(
        Path()
          ..moveTo(p(230, 86).dx, p(230, 86).dy)
          ..cubicTo(p(224, 98).dx, p(224, 98).dy, p(222, 110).dx, p(222, 110).dy,
              p(224, 122).dx, p(224, 122).dy),
        bs..strokeWidth = 2 * u);

    // 枝上的青叶(与柿橙互补)
    final lp = Paint()..color = _calyx.withValues(alpha: isDark ? .68 : .82);
    for (final l in const [
      [284.0, 44.0, -18.0, 25.0],
      [250.0, 70.0, 22.0, 23.0],
      [212.0, 104.0, -12.0, 21.0],
    ]) {
      canvas.save();
      final c = p(l[0], l[1]);
      canvas.translate(c.dx, c.dy);
      canvas.rotate(l[2] * math.pi / 180);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: l[3] * u, height: l[3] * .42 * u),
          lp);
      canvas.restore();
    }

    // 四颗柿子,各自错相摇晃
    _fruit(canvas, t, p(262, 108), 15 * u, _skin, 0, u);
    _fruit(canvas, t, p(228, 134), 12.5 * u, _skinDeep, .35, u);
    _fruit(canvas, t, p(292, 78), 11.5 * u, _skinDeep, .62, u);
    _fruit(canvas, t, p(200, 122), 9.5 * u, _skin, .18, u);

    // 小鸟停横枝(右下,避开左侧统计数字)
    canvas.drawPath(
        Path()
          ..moveTo(p(150, 152).dx, p(150, 152).dy)
          ..cubicTo(p(164, 156).dx, p(164, 156).dy, p(180, 156).dx, p(180, 156).dy,
              p(196, 152).dx, p(196, 152).dy),
        bs
          ..strokeWidth = 2.2 * u
          ..color = _branch.withValues(alpha: isDark ? .58 : .72));
    _bird(canvas, t, p(168, 143), u);

    _paintFallingLeaves(canvas, size, t, _leaves,
        palette: [_calyx],
        vein: isDark
            ? Colors.black.withValues(alpha: .42)
            : Colors.white.withValues(alpha: .8),
        maxOpacity: isDark ? .65 : .82);
  }

  /// 一颗柿子:果 + 高光 + 五瓣青萼 + 果柄,绕柄摆动。
  /// [center] 已是画布坐标,[s] 已含等比缩放 —— 果实永远是正圆比例。
  void _fruit(Canvas canvas, double t, Offset center, double s, Color c,
      double phase, double u) {
    final sway = math.sin((t * 2 + phase) * math.pi * 2) * .038;
    final pivot = center - Offset(0, s * 1.3);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(sway);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy - s * 1.3)
          ..lineTo(center.dx, center.dy - s * .8),
        Paint()
          ..color = _branch
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * u
          ..strokeCap = StrokeCap.round);
    canvas.drawOval(
        Rect.fromCenter(center: center, width: s * 2, height: s * 1.72),
        Paint()..color = c);
    canvas.drawOval(
        Rect.fromCenter(
            center: center + Offset(-s * .3, -s * .3),
            width: s * .56,
            height: s * .36),
        Paint()..color = Colors.white.withValues(alpha: .3));
    final cp = Paint()..color = _calyx;
    final calyxC = center - Offset(0, s * .78);
    for (int i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(calyxC.dx, calyxC.dy);
      canvas.rotate(i * 72 * math.pi / 180);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: s * .8, height: s * .36), cp);
      canvas.restore();
    }
    canvas.drawCircle(calyxC, s * .16, cp);
    canvas.restore();
  }

  /// 停枝小鸟(轻微点头)。同样等比缩放,不随 header 变矮而压扁。
  void _bird(Canvas canvas, double t, Offset at, double u) {
    final nod = math.sin(t * math.pi * 2 * 3) * .05;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(nod);
    canvas.scale(u);
    final body = Paint()
      ..color = isDark ? const Color(0xFFC3A585) : const Color(0xFF5A4632);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 20, height: 14), body);
    canvas.drawCircle(const Offset(8.4, -3.8), 4.6, body);
    canvas.drawPath(
        Path()
          ..moveTo(12.2, -4.4)
          ..lineTo(17.6, -2.7)
          ..lineTo(12.2, -1)
          ..close(),
        Paint()..color = isDark ? const Color(0xFFF8C91C) : const Color(0xFFE8961E));
    canvas.drawCircle(const Offset(9.6, -4.6), 1.1,
        Paint()..color = isDark ? Colors.black : Colors.white);
    canvas.drawPath(
        Path()
          ..moveTo(-9, 1)
          ..lineTo(-18, 5.4)
          ..lineTo(-10.2, 6.1)
          ..close(),
        Paint()..color = isDark ? const Color(0xFFA88A6C) : const Color(0xFF4A3927));
    canvas.drawPath(
        Path()
          ..moveTo(-1, 6)
          ..lineTo(-1, 11)
          ..moveTo(3.4, 6)
          ..lineTo(3.4, 11),
        Paint()
          ..color = body.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PersimmonPainter old) => old.isDark != isDark;
}

class _PersimmonTabDeco extends StatelessWidget {
  const _PersimmonTabDeco(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 10,
        painterFor: (a) => _PersimmonTabPainter(isDark, a),
      );
}

class _PersimmonTabPainter extends CustomPainter {
  _PersimmonTabPainter(this.isDark, this.anim) : super(repaint: anim);
  final bool isDark;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final skin = isDark ? _kPersimSkinD : _kPersimSkinL;
    final deep = isDark ? _kPersimDeepD : _kPersimDeepL;
    final calyx = isDark ? _kCalyxD : _kCalyxL;
    final branch = (isDark ? const Color(0xFFB98A4A) : const Color(0xFF7A4A1E))
        .withValues(alpha: .68);
    final h = size.height, w = size.width;

    final bs = Paint()
      ..color = branch
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // 左端主枝 + 右端呼应
    canvas.drawPath(
        Path()
          ..moveTo(-w * .02, h * .05)
          ..cubicTo(w * .05, h * .12, w * .11, h * .22, w * .17, h * .38),
        bs..strokeWidth = 2.4);
    canvas.drawPath(
        Path()
          ..moveTo(w * 1.02, h * .09)
          ..cubicTo(w * .97, h * .16, w * .92, h * .26, w * .88, h * .42),
        bs..strokeWidth = 2);
    final lp = Paint()..color = calyx.withValues(alpha: .82);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * .052, h * .12), width: h * .32, height: h * .13),
        lp);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * .952, h * .19), width: h * .28, height: h * .12),
        lp);

    void fruit(double fx, double fy, double s, Color c, double phase) {
      final sway = math.sin((t * 2 + phase) * math.pi * 2) * .05;
      canvas.save();
      canvas.translate(fx, fy - s * 1.3);
      canvas.rotate(sway);
      canvas.translate(-fx, -(fy - s * 1.3));
      canvas.drawPath(
          Path()
            ..moveTo(fx, fy - s * 1.3)
            ..lineTo(fx, fy - s * .8),
          bs..strokeWidth = 1.3);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(fx, fy), width: s * 2, height: s * 1.72),
          Paint()..color = c);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(fx - s * .3, fy - s * .3), width: s * .5, height: s * .32),
          Paint()..color = Colors.white.withValues(alpha: .3));
      final cp = Paint()..color = calyx;
      for (int i = 0; i < 4; i++) {
        canvas.save();
        canvas.translate(fx, fy - s * .78);
        canvas.rotate(i * 90 * math.pi / 180);
        canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: s * .8, height: s * .36), cp);
        canvas.restore();
      }
      canvas.restore();
    }

    fruit(w * .1, h * .46, h * .14, skin, 0);
    fruit(w * .16, h * .58, h * .11, deep, .35);
    fruit(w * .04, h * .55, h * .1, deep, .6);
    fruit(w * .91, h * .5, h * .12, skin, .2);
    fruit(w * .975, h * .62, h * .09, deep, .45);

    // 底部落叶带 + 两片飘落
    for (int i = 0; i < 6; i++) {
      _drawLeaf(canvas, _LeafKind.pointed,
          Offset(w * (.24 + i * .1), h * (.86 + (i % 2) * .06)), h * .3,
          ((i * 63) % 100 - 50) * math.pi / 180,
          fill: calyx, opacity: isDark ? .28 : .35);
    }
    for (int i = 0; i < 2; i++) {
      final p = (t * (1 + i) + i * .5) % 1;
      final op = (p < .12 ? p / .12 : (p > .85 ? (1 - p) / .15 : 1)).clamp(0.0, 1.0);
      _drawLeaf(canvas, _LeafKind.pointed,
          Offset(w * (.58 + i * .18), -h * .2 + h * 1.5 * p), h * (.28 - i * .05),
          (t * 2 + i) * math.pi * 2,
          fill: calyx, opacity: op * .8);
    }
    // 两颗光点
    for (int i = 0; i < 2; i++) {
      final wave = .5 + .5 * math.sin((t * (2 + i) + i * .5) * math.pi * 2);
      canvas.drawCircle(Offset(w * (.62 + i * .26), h * (i.isEven ? .18 : .26)), h * .03,
          Paint()..color = skin.withValues(alpha: .15 + wave * .6));
    }
  }

  @override
  bool shouldRepaint(covariant _PersimmonTabPainter old) => old.isDark != isDark;
}
