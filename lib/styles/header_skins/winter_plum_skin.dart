part of '../header_skins.dart';

// ============ 冬日皮肤:踏雪寻梅(Plum in Snow) ============
//
// 疏影横斜:一枝墨梅从右上探进来(入画点压低,让开状态栏与右上图标),
// 枝上压着厚雪帽,红梅一朵一朵开,右下落一方朱文小印。
// 与樱花(春)凑成「春樱冬梅」的对仗;固定梅红,不跟随主题色。
// 设计稿:.docs/skin-designs/winter-skins.html 的「冬 · B」。

const Color _kPlumRedL = Color(0xFFD6455E);
const Color _kPlumRedD = Color(0xFFE8607A);
const Color _kPlumDeepL = Color(0xFFB93850);
const Color _kPlumDeepD = Color(0xFFD14562);
const Color _kPlumGoldL = Color(0xFFE8B54A);
const Color _kPlumGoldD = Color(0xFFF2C14E);
const Color _kPlumSeal = Color(0xFFC0392B);

class _PlumSnowSkin extends StatelessWidget {
  const _PlumSnowSkin(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 12,
        painterFor: (a) => _PlumSnowPainter(isDark, a),
      );
}

/// 一朵五瓣梅:五枚圆瓣 + 金蕊 + 三粒蕊点(小于 5pt 时省略蕊点)。
void _drawPlumBloom(Canvas canvas, Offset center, double s,
    {required Color petal, required Color gold, required Color edge}) {
  final petalPaint = Paint()..color = petal;
  final edgePaint = Paint()
    ..color = edge
    ..style = PaintingStyle.stroke
    ..strokeWidth = .7;
  for (int i = 0; i < 5; i++) {
    final a = (270 + i * 72) * math.pi / 180;
    final c = center + Offset(math.cos(a), math.sin(a)) * s * .62;
    canvas.drawCircle(c, s * .5, petalPaint);
    canvas.drawCircle(c, s * .5, edgePaint);
  }
  canvas.drawCircle(center, s * .3, Paint()..color = gold);
  if (s >= 5) {
    final stamen = Paint()..color = const Color(0xFFFFF7E0);
    for (int i = 0; i < 3; i++) {
      final a = (30 + i * 120) * math.pi / 180;
      canvas.drawCircle(
          center + Offset(math.cos(a), math.sin(a)) * s * .16, .9, stamen);
    }
  }
}

class _PlumSnowPainter extends CustomPainter {
  _PlumSnowPainter(this.isDark, this.anim) : super(repaint: anim) {
    _dots = _makeSnowDots(seed: isDark ? 23 : 21, count: 16);
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_SnowDot> _dots;

  Color get _ink => isDark
      ? const Color(0xFFECDEDA).withValues(alpha: .85)
      : const Color(0xFF4A3A3E);
  Color get _red => isDark ? _kPlumRedD : _kPlumRedL;
  Color get _deep => isDark ? _kPlumDeepD : _kPlumDeepL;
  Color get _gold => isDark ? _kPlumGoldD : _kPlumGoldL;
  Color get _petalEdge => isDark
      ? Colors.black.withValues(alpha: .35)
      : Colors.white.withValues(alpha: .7);
  Color get _capEdge => isDark
      ? const Color(0xFF96B4D7).withValues(alpha: .4)
      : const Color(0xFFCBDAEB);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final k = (size.height / 208).clamp(.55, 1.0);

    _paintVerticalBase(
      canvas,
      size,
      isDark
          ? const [Color(0xFF000000), Color(0xFF170709)]
          : const [Color(0xFFFCFDFF), Color(0xFFF0F4FA), Color(0xFFE1E9F4)],
      isDark ? null : const [0, .5, 1],
    );
    if (isDark) {
      // 夜梅的一圈红晕
      _paintRadialGlow(canvas, size, _ap(size, 262, 74), 60 * k, _kPlumRedD, .14);
    }

    // 左下淡梅线稿(呼应主枝)
    final linePaint = Paint()
      ..color = _red.withValues(alpha: isDark ? .12 : .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (int i = 0; i < 5; i++) {
      final a = (270 + i * 72) * math.pi / 180;
      canvas.drawCircle(
          _ap(size, 52, 170) + Offset(math.cos(a), math.sin(a)) * 15 * k,
          12 * k,
          linePaint);
    }

    // 墨梅主枝:整体绕入画点极缓地摇(频率取整数,回绕无跳变)
    canvas.save();
    final pivot = _ap(size, 300, 32);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(math.sin(t * math.pi * 2 * 2) * .035);
    canvas.translate(-pivot.dx, -pivot.dy);

    final branchPaint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    void stroke(Path p, double w) =>
        canvas.drawPath(p, branchPaint..strokeWidth = w);
    stroke(
        Path()
          ..moveTo(_ax(size, 306), _ay(size, 34))
          ..cubicTo(_ax(size, 284), _ay(size, 46), _ax(size, 266),
              _ay(size, 64), _ax(size, 250), _ay(size, 86))
          ..cubicTo(_ax(size, 240), _ay(size, 100), _ax(size, 232),
              _ay(size, 112), _ax(size, 220), _ay(size, 122)),
        3.4);
    stroke(
        Path()
          ..moveTo(_ax(size, 277), _ay(size, 54))
          ..cubicTo(_ax(size, 269), _ay(size, 64), _ax(size, 263),
              _ay(size, 76), _ax(size, 261), _ay(size, 90)),
        2.1);
    stroke(
        Path()
          ..moveTo(_ax(size, 245), _ay(size, 94))
          ..cubicTo(_ax(size, 251), _ay(size, 104), _ax(size, 255),
              _ay(size, 116), _ax(size, 255), _ay(size, 130)),
        1.7);
    stroke(
        Path()
          ..moveTo(_ax(size, 227), _ay(size, 115))
          ..cubicTo(_ax(size, 221), _ay(size, 122), _ax(size, 217),
              _ay(size, 130), _ax(size, 215), _ay(size, 139)),
        1.4);

    // 枝上积雪(W4 厚雪帽)
    for (final c in const [
      (290.0, 42.0, 8.0, -26.0),
      (262.0, 71.0, 7.0, -38.0),
      (247.0, 97.0, 6.0, -50.0),
      (233.0, 111.0, 5.0, -42.0),
    ]) {
      _paintSnowCap(canvas, _ap(size, c.$1, c.$2), c.$3 * k,
          fill: Colors.white, edge: _capEdge, rotDeg: c.$4);
    }

    // 红梅六朵 + 三粒花苞
    for (final b in [
      (293.0, 52.0, 6.5, _red),
      (268.0, 66.0, 8.5, _red),
      (258.0, 90.0, 6.0, _deep),
      (244.0, 109.0, 7.5, _red),
      (221.0, 125.0, 5.5, _deep),
      (259.0, 125.0, 4.5, _deep),
    ]) {
      _drawPlumBloom(canvas, _ap(size, b.$1, b.$2), b.$3 * k,
          petal: b.$4, gold: _gold, edge: _petalEdge);
    }
    final budPaint = Paint()..color = _deep;
    canvas.drawCircle(_ap(size, 281, 58), 2.6 * k, budPaint);
    canvas.drawCircle(_ap(size, 235, 117), 2.2 * k, budPaint);
    canvas.drawCircle(_ap(size, 252, 136), 2 * k, budPaint);
    canvas.restore();

    // 朱文小印(落款,压住画面)
    canvas.save();
    final seal = _ap(size, 280, 188);
    canvas.translate(seal.dx, seal.dy);
    canvas.rotate(-7 * math.pi / 180);
    canvas.scale(k);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-10, -10, 20, 20), const Radius.circular(2.5)),
        Paint()..color = _kPlumSeal.withValues(alpha: isDark ? 1 : .92));
    canvas.drawPath(
        Path()
          ..moveTo(-4.5, -4.5)
          ..lineTo(4.5, -4.5)
          ..moveTo(-4.5, 0)
          ..lineTo(2, 0)
          ..moveTo(-4.5, 4.5)
          ..lineTo(4.5, 4.5)
          ..moveTo(-4.5, -4.5)
          ..lineTo(-4.5, 4.5)
          ..moveTo(4.5, -4.5)
          ..lineTo(4.5, 0),
        Paint()
          ..color = const Color(0xFFFFF6EC).withValues(alpha: .95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
    canvas.restore();

    // 雪与偶尔飘落的梅瓣
    _paintFallingSnow(canvas, size, t, _dots,
        color: Colors.white, maxOpacity: isDark ? .8 : .9);
    _paintPlumPetals(canvas, size, t, _red, isDark ? .8 : .85);
  }

  @override
  bool shouldRepaint(covariant _PlumSnowPainter old) => old.isDark != isDark;
}

/// 飘落的梅瓣:右半屏为主(从枝头来),圆瓣带一点竖向压扁 + 自旋。
void _paintPlumPetals(
    Canvas canvas, Size size, double t, Color color, double maxOpacity) {
  final rnd = math.Random(25);
  for (int i = 0; i < 5; i++) {
    final xr = .55 + rnd.nextDouble() * .42;
    final s = 3.4 + rnd.nextDouble() * 2.4;
    final speed = 1 + (i % 2);
    final swayFreq = 2 + rnd.nextInt(2);
    final phase = rnd.nextDouble();
    final p = (t * speed + phase) % 1;
    final y = -s + (size.height + s * 2) * p;
    final x = size.width * xr +
        math.sin((t * swayFreq + phase) * math.pi * 2) * size.width * .03;
    final fade =
        (p < .08 ? p / .08 : (p > .9 ? (1 - p) / .1 : 1.0)).clamp(0.0, 1.0);
    if (fade <= .02) continue;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate((t * (1 + (i % 2)) + phase) * math.pi * 2);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 2, height: s * 1.5),
        Paint()..color = color.withValues(alpha: maxOpacity * fade));
    canvas.restore();
  }
}

class _PlumSnowTabDeco extends StatelessWidget {
  const _PlumSnowTabDeco(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 10,
        painterFor: (a) => _PlumSnowTabPainter(isDark, a),
      );
}

class _PlumSnowTabPainter extends CustomPainter {
  _PlumSnowTabPainter(this.isDark, this.anim) : super(repaint: anim) {
    _dots = _makeSnowDots(
        seed: isDark ? 77 : 75, count: 4, minSize: 1.6, maxSize: 3.4);
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_SnowDot> _dots;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final ink = isDark
        ? const Color(0xFFECDEDA).withValues(alpha: .8)
        : const Color(0xFF4A3A3E);
    final red = isDark ? _kPlumRedD : _kPlumRedL;
    final deep = isDark ? _kPlumDeepD : _kPlumDeepL;
    final gold = isDark ? _kPlumGoldD : _kPlumGoldL;
    final edge = isDark
        ? Colors.black.withValues(alpha: .35)
        : Colors.white.withValues(alpha: .7);
    final capEdge = isDark
        ? const Color(0xFF96B4D7).withValues(alpha: .4)
        : const Color(0xFFCBDAEB);
    Offset d(double x, double y) =>
        Offset(size.width * x / 311, size.height * y / 47);

    // 左端探入的一小截梅枝(带雪帽 + 两朵梅 + 一粒苞)
    canvas.save();
    canvas.rotate(math.sin(t * math.pi * 2 * 2) * .03);
    final branch = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(d(-4, 6).dx, d(-4, 6).dy)
          ..cubicTo(d(16, 10).dx, d(16, 10).dy, d(32, 18).dx, d(32, 18).dy,
              d(46, 30).dx, d(46, 30).dy),
        branch..strokeWidth = 2.6);
    canvas.drawPath(
        Path()
          ..moveTo(d(20, 11).dx, d(20, 11).dy)
          ..cubicTo(d(24, 17).dx, d(24, 17).dy, d(25, 23).dx, d(25, 23).dy,
              d(24, 29).dx, d(24, 29).dy),
        branch..strokeWidth = 1.5);
    _paintSnowCap(canvas, d(14, 8.5), 6,
        fill: Colors.white, edge: capEdge, rotDeg: -18);
    _paintSnowCap(canvas, d(34, 20), 5,
        fill: Colors.white, edge: capEdge, rotDeg: -32);
    _drawPlumBloom(canvas, d(26, 16), 5.5, petal: red, gold: gold, edge: edge);
    _drawPlumBloom(canvas, d(42, 28), 4.5, petal: deep, gold: gold, edge: edge);
    canvas.drawCircle(d(20, 26), 1.8, Paint()..color = deep);
    canvas.restore();

    // 右端一朵独梅 + 一粒苞
    _drawPlumBloom(canvas, d(288, 14), 5, petal: red, gold: gold, edge: edge);
    canvas.drawCircle(d(297, 23), 1.9, Paint()..color = deep);

    // 三片梅瓣与四粒雪飘落
    _paintPlumPetals(canvas, size, t, red, .85);
    _paintFallingSnow(canvas, size, t, _dots,
        color: Colors.white, maxOpacity: .85);

    // 金蕊光点
    for (final g in const [(.19, 8.0, 2), (.62, 30.0, 3)]) {
      final wave = .5 + .5 * math.sin(t * math.pi * 2 * g.$3 + g.$1 * 7);
      canvas.drawCircle(Offset(size.width * g.$1, g.$2 * size.height / 47),
          1.1, Paint()..color = gold.withValues(alpha: .15 + wave * .75));
    }
  }

  @override
  bool shouldRepaint(covariant _PlumSnowTabPainter old) =>
      old.isDark != isDark;
}
