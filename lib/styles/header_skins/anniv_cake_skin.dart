part of '../header_skins.dart';

// ============ 一周年皮肤:周年蛋糕(Birthday Cake) ============
//
// 绑定奶油金。一块插着数字「1」蜡烛的蛋糕 —— **周年标识和场景主体是同一个
// 东西**,不用额外贴字。烛火一直在摇,暗色模式关灯只剩烛光,氛围最好。
// 设计稿:.docs/skin-designs/anniversary-skins.html 的「方案 A」。
//
// 构图铁律(踩过的坑):蛋糕第一版 120pt 宽压在「收入 / 结余」上,实色块会让
// 数字读不清。现在缩进右侧净空带(设计稿 x 200–300 / y 74–150),
// 铭文缩小后靠**左下角**排 —— 居中横幅会横跨全宽和主体抢视线。

const Color _kCakeCreamL = Color(0xFFFFF6E4);
const Color _kCakeCreamD = Color(0xFFFFE9BE);
const Color _kCakeBodyL = Color(0xFFF3C078);
const Color _kCakeBodyD = Color(0xFFC98F3E);
const Color _kCakeBody2L = Color(0xFFE8A758);
const Color _kCakeBody2D = Color(0xFFA9752C);
const Color _kCakeBerry = Color(0xFFE2453C);
const Color _kCakeFlame = Color(0xFFFFB13B);
const Color _kCakeCandleL = Color(0xFFFF7A45);
const Color _kCakeCandleD = Color(0xFFF8C91C);

class _AnnivCakeSkin extends StatelessWidget {
  const _AnnivCakeSkin(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // 只给铭文用 —— 它要对齐标题行,而标题行的位置由状态栏高度决定。
    // 蛋糕本身仍按设计稿的比例锚点走,不受这个值影响。
    final topInset = MediaQuery.paddingOf(context).top;
    return _AnimSkinShell(
      seconds: 10,
      painterFor: (a) => _AnnivCakePainter(isDark, a, topInset),
    );
  }
}

class _AnnivCakePainter extends CustomPainter {
  _AnnivCakePainter(this.isDark, this.anim, this.topInset)
      : super(repaint: anim);
  final bool isDark;
  final Animation<double> anim;

  /// 状态栏高度,铭文靠它对齐标题行。
  final double topInset;

  Color get _cream => isDark ? _kCakeCreamD : _kCakeCreamL;
  Color get _body => isDark ? _kCakeBodyD : _kCakeBodyL;
  Color get _body2 => isDark ? _kCakeBody2D : _kCakeBody2L;
  Color get _candle => isDark ? _kCakeCandleD : _kCakeCandleL;
  Color get _mark => isDark ? const Color(0xFFF8C91C) : const Color(0xFF8A5A12);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;

    _paintVerticalBase(
      canvas,
      size,
      isDark
          ? const [Color(0xFF000000), Color(0xFF1A1004)]
          : const [Color(0xFFFFFBF0), Color(0xFFFFF0D2), Color(0xFFFFE0AE)],
      isDark ? null : const [0, .6, 1],
    );

    final u = (size.height / 208).clamp(.55, 1.0);
    // 烛光把整个头部染暖(暗色下这就是唯一光源)
    _paintRadialGlow(canvas, size, _ap(size, 246, 102), size.width * .55,
        _kCakeFlame, isDark ? .5 : .35);

    _paintRibbons(canvas, size, t, u);
    _paintCake(canvas, size, t, u);
    _paintSprinkles(canvas, size, t);
    _paintAnnivInscription(canvas, size, _mark, topInset);
  }

  /// 顶部两条彩带,一上一下地飘。
  void _paintRibbons(Canvas canvas, Size size, double t, double u) {
    Offset p(double x, double y) => _ap(size, x, y);
    final w1 = math.sin(t * math.pi * 2 * 2) * 4 * u;
    final w2 = math.sin(t * math.pi * 2 * 2 + math.pi) * 4 * u;
    final s = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * u
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(p(-6, 24).dx, p(-6, 24).dy + w1)
          ..quadraticBezierTo(p(30, 8).dx, p(30, 8).dy + w1, p(66, 24).dx,
              p(66, 24).dy + w1)
          ..quadraticBezierTo(p(102, 40).dx, p(102, 40).dy + w1, p(138, 24).dx,
              p(138, 24).dy + w1),
        s..color = _kCakeBerry.withValues(alpha: .55));
    canvas.drawPath(
        Path()
          ..moveTo(p(176, 14).dx, p(176, 14).dy + w2)
          ..quadraticBezierTo(p(210, 30).dx, p(210, 30).dy + w2, p(244, 14).dx,
              p(244, 14).dy + w2)
          ..quadraticBezierTo(p(278, -2).dx, p(278, -2).dy + w2, p(312, 16).dx,
              p(312, 16).dy + w2),
        s..color = _body.withValues(alpha: .7));
  }

  /// 蛋糕本体 + 数字「1」蜡烛。整体等比缩放,不会随 header 变矮而压扁。
  ///
  /// 锚点压到偏下:首页 header 的收支三列(设计坐标 y 94~140)是整块
  /// header 唯一不能被大色块盖住的地方 —— 蛋糕体是个 120×40 的实心块,
  /// 压上去数字就废了。下沉后蛋糕体落在预算行那条小字带上,只剩细长的
  /// 蜡烛「1」竖着穿过结余列,和一岁星座那道竖线是同一种、可接受的遮挡。
  void _paintCake(Canvas canvas, Size size, double t, double u) {
    final c = _ap(size, 246, 150);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(.72 * u);

    // 投影 + 盘
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 52), width: 144, height: 14),
        Paint()..color = Colors.black.withValues(alpha: isDark ? .3 : .08));
    canvas.drawPath(
        Path()
          ..moveTo(-76, 44)
          ..quadraticBezierTo(0, 62, 76, 44)
          ..lineTo(70, 50)
          ..quadraticBezierTo(0, 68, -70, 50)
          ..close(),
        Paint()
          ..color = isDark ? const Color(0xFF4A3A22) : const Color(0xFFEDE3D2));

    // 两层蛋糕 + 奶油顶
    final rr = Radius.circular(8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-60, 6, 120, 40), rr),
        Paint()..color = _body);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-60, 6, 120, 14), const Radius.circular(7)),
        Paint()..color = _cream);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-42, -26, 84, 34), const Radius.circular(7)),
        Paint()..color = _body2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-42, -26, 84, 12), const Radius.circular(6)),
        Paint()..color = _cream);

    // 奶油挤花
    final creamP = Paint()..color = _cream;
    for (final x in const [-52.0, -34.0, -16.0, 2.0, 20.0, 38.0, 52.0]) {
      canvas.drawCircle(Offset(x, 6), 7, creamP);
    }
    for (final x in const [-34.0, -16.0, 2.0, 20.0, 34.0]) {
      canvas.drawCircle(Offset(x, -26), 6, creamP);
    }
    // 草莓
    final berry = Paint()..color = _kCakeBerry;
    for (final x in const [-30.0, 0.0, 30.0]) {
      canvas.drawPath(
          Path()
            ..moveTo(x, -34)
            ..quadraticBezierTo(x + 7, -32, x + 6, -25)
            ..quadraticBezierTo(x + 5, -17, x, -14)
            ..quadraticBezierTo(x - 5, -17, x - 6, -25)
            ..quadraticBezierTo(x - 7, -32, x, -34)
            ..close(),
          berry);
    }

    // 数字「1」蜡烛:周年标识 = 场景主体,所以再放大一档
    canvas.save();
    canvas.translate(0, -50);
    canvas.scale(1.32);
    canvas.drawPath(
        Path()
          ..moveTo(-9, 0)
          ..lineTo(-9, -6)
          ..lineTo(-2, -6)
          ..lineTo(-2, -34)
          ..lineTo(-9, -30)
          ..lineTo(-12, -36)
          ..lineTo(2, -44)
          ..lineTo(7, -44)
          ..lineTo(7, -6)
          ..lineTo(14, -6)
          ..lineTo(14, 0)
          ..close(),
        Paint()..color = _candle);
    canvas.drawPath(
        Path()
          ..moveTo(-9, 0)
          ..lineTo(-9, -6)
          ..lineTo(-2, -6)
          ..lineTo(-2, -34)
          ..lineTo(-9, -30)
          ..lineTo(-12, -36)
          ..lineTo(2, -44)
          ..lineTo(7, -44)
          ..lineTo(7, -6)
          ..lineTo(14, -6)
          ..lineTo(14, 0)
          ..close(),
        Paint()
          ..color = (isDark ? const Color(0xFFB8860B) : const Color(0xFFC2410C))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round);
    // 烛芯 + 火苗(高频摇曳,频率取整数保证回绕无跳变)
    canvas.drawLine(
        const Offset(2, -44),
        const Offset(2, -50),
        Paint()
          ..color = isDark ? const Color(0xFF8A6605) : const Color(0xFF5A4632)
          ..strokeWidth = 1.6);
    final flick = math.sin(t * math.pi * 2 * 11);
    canvas.save();
    canvas.translate(2, -50);
    canvas.rotate(flick * .1);
    canvas.scale(1 + flick * .08, 1 - flick * .05);
    canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..cubicTo(-6, -6, -5, -14, 0, -22)
          ..cubicTo(5, -14, 6, -6, 0, 0)
          ..close(),
        Paint()..color = _kCakeFlame);
    canvas.drawPath(
        Path()
          ..moveTo(0, -2)
          ..cubicTo(-3, -6, -3, -11, 0, -16)
          ..cubicTo(3, -11, 3, -6, 0, -2)
          ..close(),
        Paint()..color = const Color(0xFFFFF3C4));
    canvas.restore();
    canvas.drawCircle(
        const Offset(2, -62),
        18,
        Paint()
          ..color = _kCakeFlame
              .withValues(alpha: (isDark ? .28 : .18) * (.8 + flick * .2)));
    canvas.restore();
    canvas.restore();
  }

  /// 糖粒 / 彩纸从底部升起(比落下更轻快,也不会挡住蛋糕)。
  void _paintSprinkles(Canvas canvas, Size size, double t) {
    const cols = [_kCakeBerry, _kCakeBodyL, _kCakeCreamL, Color(0xFF7CC6E8)];
    final rnd = math.Random(21);
    for (int i = 0; i < 16; i++) {
      final x = rnd.nextDouble() * size.width * .96;
      final phase = rnd.nextDouble();
      final speed = 1 + (i % 2);
      final p = (t * speed + phase) % 1;
      final y = size.height + 8 - (size.height + 20) * p;
      final w = 3 + rnd.nextDouble() * 3;
      final op = (p < .12 ? p / .12 : (p > .88 ? (1 - p) / .12 : 1)).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((t * 2 + phase) * math.pi * 2);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: w, height: w * 1.4),
              const Radius.circular(1.6)),
          Paint()
            ..color = cols[i % 4]
                .withValues(alpha: op * (isDark ? .5 : .7)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AnnivCakePainter old) => old.isDark != isDark;
}

class _AnnivCakeTabDeco extends StatelessWidget {
  const _AnnivCakeTabDeco(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 9,
        painterFor: (a) => _AnnivCakeTabPainter(isDark, a),
      );
}

class _AnnivCakeTabPainter extends CustomPainter {
  _AnnivCakeTabPainter(this.isDark, this.anim) : super(repaint: anim);
  final bool isDark;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final w = size.width, h = size.height;
    final cream = isDark ? _kCakeCreamD : _kCakeCreamL;

    // 顶部彩带
    final ribbon = Paint()
      ..color = (isDark ? const Color(0xFFE8705F) : _kCakeBerry)
          .withValues(alpha: isDark ? .8 : .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final wob = math.sin(t * math.pi * 2 * 2) * 2;
    canvas.drawPath(
        Path()
          ..moveTo(-6, h * .18 + wob)
          ..quadraticBezierTo(w * .14, h * .04 + wob, w * .28, h * .18 + wob)
          ..quadraticBezierTo(w * .42, h * .32 + wob, w * .56, h * .18 + wob),
        ribbon);

    // 底部奶油带:实心底 + 上沿一排挤花,整条读作「一块蛋糕的顶面」。
    // 之前只画孤立半圆、透明度又压到 .4,暗色下变成一排灰石头。
    // 位置压到最下面一档 —— tab 文字标签的基线大约在 h*.82,奶油带再往上
    // 就会顶到白色标签底下,浅色奶油配 white70 文字读不清。
    // 不透明实色:半透明奶油压在纯黑上会变成脏灰褐(去脏五原则第三条)
    final creamC = isDark ? const Color(0xFFEBD6A6) : cream;
    final bandTop = h * .88;
    canvas.drawRect(
        Rect.fromLTWH(0, bandTop, w, h - bandTop), Paint()..color = creamC);
    final creamP = Paint()..color = creamC;
    const lobes = 15;
    for (int i = 0; i < lobes; i++) {
      canvas.drawCircle(
          Offset(w * ((i + .5) / lobes), bandTop), h * .065, creamP);
    }
    // 奶油带上坐三颗草莓,x 落在 tab 项之间的缝里(5 项等宽,分界在 .2/.4/.6/.8)
    final berry = Paint()..color = _kCakeBerry.withValues(alpha: isDark ? .8 : 1);
    for (final fx in const [.2, .6, .8]) {
      final x = w * fx, y = bandTop;
      canvas.drawPath(
          Path()
            ..moveTo(x, y - h * .17)
            ..quadraticBezierTo(x + 3.6, y - h * .15, x + 3.3, y - h * .07)
            ..quadraticBezierTo(x + 2.9, y, x, y + h * .03)
            ..quadraticBezierTo(x - 2.9, y, x - 3.3, y - h * .07)
            ..quadraticBezierTo(x - 3.6, y - h * .15, x, y - h * .17)
            ..close(),
          berry);
    }

    // 两端各一根点着的小蜡烛(不压图标)
    void candle(double x, double ch, int idx) {
      final col = [_kCakeCandleL, _kCakeBerry, const Color(0xFF7CC6E8)][idx % 3];
      final base = bandTop;  // 蜡烛插在奶油带上,不悬空
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 2.6, base - ch, 5.2, ch + 4),
              const Radius.circular(1.3)),
          Paint()..color = col);
      final flick = math.sin(t * math.pi * 2 * 11 + idx);
      canvas.save();
      canvas.translate(x, base - ch);
      canvas.rotate(flick * .12);
      canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..cubicTo(-2.6, -3, -2.2, -6.4, 0, -9.6)
            ..cubicTo(2.2, -6.4, 2.6, -3, 0, 0)
            ..close(),
          Paint()..color = _kCakeFlame);
      canvas.restore();
      canvas.drawCircle(
          Offset(x, base - ch - 5),
          7,
          Paint()
            ..color = _kCakeFlame
                .withValues(alpha: (isDark ? .26 : .16) * (.8 + flick * .2)));
    }

    candle(w * .04, h * .24, 0);
    candle(w * .96, h * .21, 2);

    // 升起的糖粒
    final rnd = math.Random(7);
    for (int i = 0; i < 5; i++) {
      final x = w * (.28 + i * .12);
      final p = (t * (1 + i % 2) + rnd.nextDouble()) % 1;
      final y = h + 4 - (h + 8) * p;
      final op = (p < .15 ? p / .15 : (p > .85 ? (1 - p) / .15 : 1)).clamp(0.0, 1.0);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, y), width: 3.2, height: 4.4),
              const Radius.circular(1.6)),
          Paint()
            ..color = [_kCakeBerry, _kCakeBodyL, cream, const Color(0xFF7CC6E8)]
                    [i % 4]
                .withValues(alpha: op * .8));
    }
  }

  @override
  bool shouldRepaint(covariant _AnnivCakeTabPainter old) => old.isDark != isDark;
}
