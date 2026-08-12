part of '../header_skins.dart';

// ============ 秋日皮肤:秋雨梧桐(Autumn Rain) ============
//
// 固定冷调青灰 —— **全皮肤库唯一一款冷色**,补上了空缺的色系,也是唯一的
// 「清冷派」,适合长期挂着。雨丝斜织、涟漪一圈圈散开、玻璃上挂着水珠、
// 梧桐叶打着旋落下。设计稿:autumn-skins.html 的「秋 · F」。

const Color _kRainLeafL = Color(0xFFC2762B);
const Color _kRainLeafD = Color(0xFFE0A75C);

class _AutumnRainSkin extends StatelessWidget {
  const _AutumnRainSkin(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 12,
        painterFor: (a) => _AutumnRainPainter(isDark, a),
      );
}

class _AutumnRainPainter extends CustomPainter {
  _AutumnRainPainter(this.isDark, this.anim) : super(repaint: anim) {
    _leaves = _makeFallingLeaves(
      seed: 91,
      count: 3,
      kinds: const [_LeafKind.pointed],
      colorCount: 1,
      minSize: 26,
      maxSize: 42,
    );
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_FallingLeaf> _leaves;

  Color get _rain => isDark
      ? const Color(0xFF96C8EB).withValues(alpha: .6)
      : const Color(0xFF587C98).withValues(alpha: .75);
  Color get _leafC => isDark ? _kRainLeafD : _kRainLeafL;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;

    _paintVerticalBase(
      canvas,
      size,
      isDark
          ? const [Color(0xFF000000), Color(0xFF050E16)]
          : const [Color(0xFFF7FAFC), Color(0xFFE6EFF4), Color(0xFFCFDEE8)],
      isDark ? null : const [0, .5, 1],
    );

    // 远处雨雾山影
    final sx = size.width / 300, sy = size.height / 208;
    canvas.save();
    canvas.scale(sx, sy);
    canvas.drawPath(
        Path()
          ..moveTo(-10, 190)
          ..lineTo(40, 158)
          ..lineTo(78, 178)
          ..lineTo(118, 148)
          ..lineTo(160, 180)
          ..lineTo(210, 152)
          ..lineTo(250, 176)
          ..lineTo(310, 156)
          ..lineTo(310, 208)
          ..lineTo(-10, 208)
          ..close(),
        Paint()
          ..color = (isDark ? const Color(0xFF0C1B27) : const Color(0xFFB7CBD8))
              .withValues(alpha: isDark ? .85 : .5));
    canvas.restore();
    _paintRadialGlow(canvas, size, _ap(size, 90, 182), size.width * .45,
        isDark ? const Color(0xFF7FB2D6) : Colors.white, isDark ? .05 : .5);
    canvas.drawLine(
        Offset(0, _ay(size, 196)),
        Offset(size.width, _ay(size, 196)),
        Paint()
          ..color = _rain.withValues(alpha: isDark ? .2 : .35)
          ..strokeWidth = 1);

    _paintRain(canvas, size, t);
    _paintRipples(canvas, size, t);
    _paintDrops(canvas, size, t);
    _paintFallingLeaves(canvas, size, t, _leaves,
        palette: [_leafC],
        vein: isDark
            ? Colors.black.withValues(alpha: .4)
            : const Color(0xFFFFFAF0).withValues(alpha: .85),
        maxOpacity: isDark ? .78 : .92);
  }

  /// 三层雨丝(远细近粗),斜向左下。
  void _paintRain(Canvas canvas, Size size, double t) {
    final rnd = math.Random(97);
    final u = (size.height / 208).clamp(.55, 1.0);
    for (int i = 0; i < 40; i++) {
      final layer = i % 3;
      // 细而短才像秋雨;粗长会变成「条形码」
      final len = [9.0, 13.0, 18.0][layer] * u;
      final x0 = rnd.nextDouble() * size.width * 1.1;
      final phase = rnd.nextDouble();
      // 每循环下落 8~12 次(整数,回绕无跳变)
      final cycles = 8 + layer * 2;
      final p = (t * cycles + phase) % 1;
      final y = -len + (size.height + len * 2) * p;
      final x = x0 - p * size.width * .13;
      final alpha = (.26 + layer * .14) *
          (p < .1 ? p / .1 : (p > .9 ? (1 - p) / .1 : 1)).clamp(0.0, 1.0);
      final rect = Rect.fromLTWH(x, y, (.9 + layer * .3) * u, len);
      canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_rain.withValues(alpha: 0), _rain.withValues(alpha: alpha)],
            ).createShader(rect));
    }
  }

  /// 水面涟漪:一圈圈扩散淡出。
  void _paintRipples(Canvas canvas, Size size, double t) {
    // 涟漪只在底部那条水面上,半径克制 —— 之前铺满半屏像水波纹壁纸
    const spots = [
      [.2, .955],
      [.46, .975],
      [.7, .95],
      [.88, .972],
    ];
    for (int i = 0; i < spots.length; i++) {
      for (int k = 0; k < 2; k++) {
        final p = (t * 4 + i * .25 + k * .5) % 1;
        final base = size.width * (.042 + i * .008);
        final rx = base * (.2 + p * 1.4);
        final alpha = (1 - p) * .5;
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(size.width * spots[i][0], size.height * spots[i][1]),
                width: rx * 2,
                height: rx * .68),
            Paint()
              ..color = _rain.withValues(alpha: alpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
      }
    }
  }

  /// 玻璃上的挂壁水珠(明灭)。
  void _paintDrops(Canvas canvas, Size size, double t) {
    final rnd = math.Random(93);
    for (int i = 0; i < 10; i++) {
      final x = rnd.nextDouble() * size.width * .96;
      final y = rnd.nextDouble() * size.height * .72;
      final r = 1.8 + rnd.nextDouble() * 2.5;
      final freq = 2 + rnd.nextInt(2);
      final wave = .5 + .5 * math.sin((t * freq + rnd.nextDouble()) * math.pi * 2);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r * 2.3),
          Paint()
            ..color = (isDark
                    ? const Color(0xFFB4DCF5).withValues(alpha: .55)
                    : Colors.white.withValues(alpha: .95))
                .withValues(alpha: (.25 + wave * .7) * (isDark ? .55 : .95)));
    }
  }

  @override
  bool shouldRepaint(covariant _AutumnRainPainter old) => old.isDark != isDark;
}

class _AutumnRainTabDeco extends StatelessWidget {
  const _AutumnRainTabDeco(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 8,
        painterFor: (a) => _AutumnRainTabPainter(isDark, a),
      );
}

class _AutumnRainTabPainter extends CustomPainter {
  _AutumnRainTabPainter(this.isDark, this.anim) : super(repaint: anim);
  final bool isDark;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final rain = isDark
        ? const Color(0xFF96C8EB).withValues(alpha: .6)
        : const Color(0xFF587C98).withValues(alpha: .7);
    final leafC = isDark ? _kRainLeafD : _kRainLeafL;
    final h = size.height, w = size.width;

    // 雨丝
    final rnd = math.Random(11);
    for (int i = 0; i < 22; i++) {
      final layer = i % 3;
      final len = h * (.2 + layer * .1);
      final phase = rnd.nextDouble();
      final p = (t * (6 + layer * 2) + phase) % 1;
      final x = w * ((i * 4.6 + 2) / 100) - p * w * .08;
      final y = -len + (h + len * 2) * p;
      final rect = Rect.fromLTWH(x, y, 1.1 + layer * .35, len);
      canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [rain.withValues(alpha: 0), rain.withValues(alpha: .35 + layer * .18)],
            ).createShader(rect));
    }
    // 水珠
    for (int i = 0; i < 8; i++) {
      final wave = .5 + .5 * math.sin((t * (2 + i % 3) + i * .3) * math.pi * 2);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * (.08 + i * .12), h * (i.isEven ? .2 : .68)),
              width: h * (.07 + (i % 3) * .02),
              height: h * (.085 + (i % 3) * .02)),
          Paint()
            ..color = (isDark ? const Color(0xFFB4DCF5) : Colors.white)
                .withValues(alpha: (.3 + wave * .65) * (isDark ? .6 : .95)));
    }
    // 涟漪
    for (int i = 0; i < 3; i++) {
      final p = (t * 3 + i * .33) % 1;
      final rx = h * (.15 + p * .5);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * (.26 + i * .26), h * .84), width: rx * 2, height: rx * .6),
          Paint()
            ..color = rain.withValues(alpha: (1 - p) * .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
    // 水面波纹线
    final wave1 = Path()..moveTo(0, h * .95);
    for (double x = 0; x <= w; x += w / 8) {
      wave1.quadraticBezierTo(x + w / 16, h * .92, x + w / 8, h * .95);
    }
    canvas.drawPath(
        wave1,
        Paint()
          ..color = rain.withValues(alpha: .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    // 两端梧桐叶 + 一片飘落
    _drawLeaf(canvas, _LeafKind.pointed, Offset(w * .02, h * .1), h * .62, -.52,
        fill: leafC, opacity: isDark ? .45 : .55);
    _drawLeaf(canvas, _LeafKind.pointed, Offset(w * .965, h * .88), h * .46, .7,
        fill: leafC, opacity: isDark ? .42 : .5);
    final p = (t * 1) % 1;
    _drawLeaf(canvas, _LeafKind.pointed, Offset(w * .42, -h * .3 + h * 1.6 * p),
        h * .3, t * math.pi * 4,
        fill: leafC,
        opacity: (p < .12 ? p / .12 : (p > .85 ? (1 - p) / .15 : 1)).clamp(0.0, 1.0) * .8);
  }

  @override
  bool shouldRepaint(covariant _AutumnRainTabPainter old) => old.isDark != isDark;
}
