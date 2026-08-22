part of '../header_skins.dart';

// ============ 冬日皮肤:雪夜灯火(Cabin Glow) ============
//
// 屋外落雪,屋里灯亮:近景大木屋占满右侧、右缘出画(推近才有代入感),
// 厚雪屋顶、两扇蜜金暖窗、窗光在雪地上烘出两团暖光池,烟囱炊烟循环上升,
// 门口一个戴红围巾的小雪人。冷蓝夜 + 蜜金窗光 = W2 冷暖对比的教科书。
// 设计稿:.docs/skin-designs/winter-skins.html 的「冬 · C」。
//
// 两个实装要点(设计稿评审时踩过的坑):
// - 暗色屋顶不用纯白:屋顶正垫在白色统计数字(收入 / 结余)下面,
//   改「月光蓝雪」#93ACD2 白字才可读(W1 的反向应用);
// - 烟囱贴右缘(x≈294),让开「结余」数字,炊烟向左飘。

const Color _kCabinWoodL = Color(0xFF6E4B38);
const Color _kCabinWoodD = Color(0xFF3E2B20);
const Color _kCabinRoofL = Color(0xFF4A332A);
const Color _kCabinRoofD = Color(0xFF2A1C14);
const Color _kCabinWinTop = Color(0xFFFFD97A);
const Color _kCabinWinBottom = Color(0xFFF5A623);

class _CabinGlowSkin extends StatelessWidget {
  const _CabinGlowSkin(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 12,
        painterFor: (a) => _CabinGlowPainter(isDark, a),
      );
}

class _CabinGlowPainter extends CustomPainter {
  _CabinGlowPainter(this.isDark, this.anim) : super(repaint: anim) {
    _dots = _makeSnowDots(seed: isDark ? 37 : 35, count: 22);
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_SnowDot> _dots;

  Color get _wood => isDark ? _kCabinWoodD : _kCabinWoodL;
  Color get _roofWood => isDark ? _kCabinRoofD : _kCabinRoofL;
  Color get _roofSnow => isDark ? const Color(0xFF93ACD2) : Colors.white;
  Color get _snowEdge => isDark
      ? const Color(0xFF96B4D7).withValues(alpha: .4)
      : const Color(0xFFD5E1EF);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final k = (size.height / 208).clamp(.55, 1.0);
    // 窗光 / 暖光池的呼吸(整数频率)
    final glow = .62 + .38 * (.5 + .5 * math.sin(t * math.pi * 2 * 3));

    _paintVerticalBase(
      canvas,
      size,
      isDark
          ? const [Color(0xFF000000), Color(0xFF081020), Color(0xFF0E1830)]
          : const [
              Color(0xFFEEF3FB),
              Color(0xFFE2E9F6),
              Color(0xFFDCDDF0),
              Color(0xFFD6D2E8)
            ],
      isDark ? const [0, .5, 1] : const [0, .45, .78, 1],
    );

    // 星与月(暗色主场;亮色只留三两颗极淡的暮星)
    _paintNightStars(canvas, size, t,
        color: Colors.white,
        seed: isDark ? 33 : 31,
        count: isDark ? 13 : 3,
        maxAlpha: isDark ? .55 : .28,
        maxYRatio: .5);
    if (isDark) {
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: _ap(size, 207, 50), radius: 8.5 * k)),
        Path()
          ..addOval(Rect.fromCircle(
              center: _ap(size, 207, 50) + Offset(3.5 * k, -2.5 * k),
              radius: 7.8 * k)),
      );
      canvas.drawPath(
          moon, Paint()..color = const Color(0xFFF4E9C8).withValues(alpha: .92));
    }

    // 远山
    canvas.drawPath(
        _polyPath(size, const [
          [-10, 168], [58, 138], [120, 164], [182, 140], [242, 166],
          [310, 148], [310, 208], [-10, 208],
        ]),
        Paint()
          ..color = (isDark ? const Color(0xFF0A1526) : const Color(0xFFC3CFE4))
              .withValues(alpha: isDark ? .92 : .55));

    // 雪地
    final ground = Path()
      ..moveTo(_ax(size, -10), _ay(size, 208))
      ..lineTo(_ax(size, -10), _ay(size, 176))
      ..quadraticBezierTo(
          _ax(size, 70), _ay(size, 162), _ax(size, 150), _ay(size, 174))
      ..quadraticBezierTo(
          _ax(size, 230), _ay(size, 184), _ax(size, 310), _ay(size, 170))
      ..lineTo(_ax(size, 310), _ay(size, 208))
      ..close();
    canvas.drawPath(
        ground,
        Paint()
          ..color = (isDark ? const Color(0xFFDCE7F5) : Colors.white)
              .withValues(alpha: isDark ? .94 : .97));
    final crest = Path()
      ..moveTo(_ax(size, -10), _ay(size, 176))
      ..quadraticBezierTo(
          _ax(size, 70), _ay(size, 162), _ax(size, 150), _ay(size, 174))
      ..quadraticBezierTo(
          _ax(size, 230), _ay(size, 184), _ax(size, 310), _ay(size, 170));
    canvas.drawPath(
        crest,
        Paint()
          ..color = isDark
              ? const Color(0xFF8CAAD2).withValues(alpha: .35)
              : const Color(0xFFD9E4F2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    _paintCabin(canvas, size, glow);
    _paintSnowman(canvas, size);
    _paintSmoke(canvas, size, t, k);

    _paintFallingSnow(canvas, size, t, _dots,
        color: Colors.white, maxOpacity: isDark ? .85 : .92);
  }

  void _paintCabin(Canvas canvas, Size size, double glow) {
    Rect r(double x, double y, double w, double h) =>
        Rect.fromLTWH(_ax(size, x), _ay(size, y), _ax(size, w), _ay(size, h));

    // 墙体 + 原木横缝
    canvas.drawRect(r(222, 142, 82, 36), Paint()..color = _wood);
    final seam = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? .3 : .13)
      ..strokeWidth = 1;
    for (final y in const [152.0, 162.0, 172.0]) {
      canvas.drawLine(_ap(size, 222, y), _ap(size, 304, y), seam);
    }

    // 烟囱(贴右缘,让开「结余」数字)
    canvas.drawRect(r(294, 114, 9, 26), Paint()..color = _wood);
    canvas.drawOval(
        Rect.fromCenter(
            center: _ap(size, 298.5, 113),
            width: _ax(size, 12.4),
            height: _ay(size, 4.8)),
        Paint()..color = isDark ? const Color(0xFFC9D9F0) : Colors.white);

    // 厚雪屋顶(暗色用月光蓝,见文件头注释)
    final roof = _polyPath(size, const [
      [212, 144], [262, 104], [310, 142], [310, 144],
    ]);
    canvas.drawPath(roof, Paint()..color = _roofSnow);
    canvas.drawPath(
        roof,
        Paint()
          ..color = _snowEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    final ridge = Path()
      ..moveTo(_ax(size, 212), _ay(size, 144))
      ..lineTo(_ax(size, 262), _ay(size, 104))
      ..lineTo(_ax(size, 310), _ay(size, 142));
    canvas.drawPath(
        ridge,
        Paint()
          ..color = isDark ? const Color(0xFFC9D9F0) : Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = isDark ? 4 : 5
          ..strokeCap = StrokeCap.round);
    // 檐口木板
    canvas.drawLine(_ap(size, 214, 145.5), _ap(size, 306, 145.5),
        Paint()
          ..color = _roofWood
          ..strokeWidth = 2.6);
    // 檐角雪团
    final lump = Paint()
      ..color = isDark ? const Color(0xFFD5E3F5) : Colors.white;
    for (final x in const [230.0, 290.0]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: _ap(size, x, 140.5),
              width: _ax(size, 13),
              height: _ay(size, 5.5)),
          lump);
    }

    // 暖窗光晕(呼吸)
    final haloAlpha = (isDark ? .5 : .4) * glow;
    _paintRadialGlow(canvas, size, _ap(size, 239.5, 158),
        _ax(size, 15), const Color(0xFFFFC94D), haloAlpha);
    _paintRadialGlow(canvas, size, _ap(size, 269.5, 158),
        _ax(size, 15), const Color(0xFFFFC94D), haloAlpha);

    // 两扇暖窗 + 木门
    final winShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [_kCabinWinTop, _kCabinWinBottom],
    );
    final mullion = Paint()
      ..color = _roofWood
      ..strokeWidth = 1.2;
    for (final x in const [232.0, 262.0]) {
      final win = r(x, 150, 15, 16);
      canvas.drawRRect(
          RRect.fromRectAndRadius(win, const Radius.circular(1.6)),
          Paint()..shader = winShader.createShader(win));
      canvas.drawLine(_ap(size, x + 7.5, 150), _ap(size, x + 7.5, 166), mullion);
      canvas.drawLine(_ap(size, x, 158), _ap(size, x + 15, 158), mullion);
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(r(283, 148, 13, 30), const Radius.circular(1.6)),
        Paint()..color = _roofWood);
    canvas.drawCircle(_ap(size, 293.5, 163), 1,
        Paint()..color = _kCabinWinTop);

    // 窗光落在雪地上的暖光池(与窗同频呼吸)
    final pool = Paint()
      ..color = (isDark ? const Color(0xFFFFBE50) : const Color(0xFFF5A623))
          .withValues(alpha: (isDark ? .42 : .34) * glow);
    for (final x in const [240.0, 270.0]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: _ap(size, x, 183),
              width: _ax(size, 28),
              height: _ay(size, 8.4)),
          pool);
    }
  }

  void _paintSnowman(Canvas canvas, Size size) {
    final k = (size.height / 208).clamp(.55, 1.0);
    final body = Paint()..color = Colors.white;
    final outline = Paint()
      ..color = _snowEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9;
    final bodyC = _ap(size, 206, 168);
    final headC = _ap(size, 206, 158.5);
    canvas.drawCircle(bodyC, 6 * k, body);
    canvas.drawCircle(bodyC, 6 * k, outline);
    canvas.drawCircle(headC, 4.2 * k, body);
    canvas.drawCircle(headC, 4.2 * k, outline);
    final feature = Paint()..color = const Color(0xFF3A3A3E);
    canvas.drawCircle(_ap(size, 204.6, 157.6), .7 * k, feature);
    canvas.drawCircle(_ap(size, 207.6, 157.6), .7 * k, feature);
    final nose = Path()
      ..moveTo(_ax(size, 206), _ay(size, 159))
      ..lineTo(_ax(size, 209.4), _ay(size, 160))
      ..lineTo(_ax(size, 206), _ay(size, 160.9))
      ..close();
    canvas.drawPath(nose, Paint()..color = const Color(0xFFF59A2E));
    final scarf = Paint()
      ..color = _kPlumRedL
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(_ax(size, 202.4), _ay(size, 161.8))
          ..quadraticBezierTo(_ax(size, 206), _ay(size, 163.8),
              _ax(size, 209.6), _ay(size, 161.8)),
        scarf);
    canvas.drawLine(_ap(size, 209.2, 162.2), _ap(size, 208.6, 165), scarf);
  }

  void _paintSmoke(Canvas canvas, Size size, double t, double k) {
    final color =
        isDark ? Colors.white : const Color(0xFF8C92A4);
    for (int i = 0; i < 3; i++) {
      // 每循环升两缕,三缕错相(2 为整数频率)
      final p = (t * 2 + i / 3) % 1;
      final alphaMax = isDark ? .38 : .4;
      final alpha =
          p < .14 ? alphaMax * p / .14 : alphaMax * (1 - (p - .14) / .86);
      if (alpha <= .02) continue;
      final center = _ap(size, 298.5, 108) + Offset(-15 * k * p, -56 * k * p);
      _paintRadialGlow(canvas, size, center, (4.5 + i * 1.2 + 9 * p) * k,
          color, alpha);
    }
  }

  @override
  bool shouldRepaint(covariant _CabinGlowPainter old) => old.isDark != isDark;
}

class _CabinGlowTabDeco extends StatelessWidget {
  const _CabinGlowTabDeco(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 10,
        painterFor: (a) => _CabinGlowTabPainter(isDark, a),
      );
}

class _CabinGlowTabPainter extends CustomPainter {
  _CabinGlowTabPainter(this.isDark, this.anim) : super(repaint: anim) {
    _dots = _makeSnowDots(
        seed: isDark ? 83 : 81, count: 5, minSize: 1.6, maxSize: 3.4);
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_SnowDot> _dots;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    Offset d(double x, double y) =>
        Offset(size.width * x / 311, size.height * y / 47);

    // 底部一条雪地
    final ground = Path()
      ..moveTo(d(0, 44).dx, d(0, 44).dy)
      ..quadraticBezierTo(d(60, 40).dx, d(60, 40).dy, d(130, 43).dx, d(130, 43).dy)
      ..quadraticBezierTo(d(200, 46).dx, d(200, 46).dy, d(311, 42).dx, d(311, 42).dy)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        ground,
        Paint()
          ..color = (isDark ? const Color(0xFFDCE7F5) : const Color(0xFFEDF3FA))
              .withValues(alpha: isDark ? .85 : .9));

    // 右端迷你雪松
    final pine = Paint()
      ..color = isDark ? const Color(0xFF3A5A4A) : const Color(0xFF4E6E5C);
    final base = d(299, 26);
    final u = size.height / 47;
    canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..lineTo(base.dx - 6 * u, base.dy + 12 * u)
          ..lineTo(base.dx + 6 * u, base.dy + 12 * u)
          ..close(),
        pine);
    canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy + 6 * u)
          ..lineTo(base.dx - 7.5 * u, base.dy + 19 * u)
          ..lineTo(base.dx + 7.5 * u, base.dy + 19 * u)
          ..close(),
        pine);
    _paintSnowCap(canvas, base + Offset(0, 10.4 * u), 4.6 * u,
        fill: Colors.white.withValues(alpha: .9));

    // 签名:一串小暖灯挂过整条胶囊,逐个错相呼吸
    final wire = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: .28)
          : const Color(0xFF6E6054).withValues(alpha: .6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(
        Path()
          ..moveTo(d(-4, 8).dx, d(-4, 8).dy)
          ..quadraticBezierTo(d(40, 17).dx, d(40, 17).dy, d(78, 9).dx, d(78, 9).dy)
          ..quadraticBezierTo(d(118, 2).dx, d(118, 2).dy, d(155, 11).dx, d(155, 11).dy)
          ..quadraticBezierTo(d(194, 18).dx, d(194, 18).dy, d(232, 9).dx, d(232, 9).dy)
          ..quadraticBezierTo(d(270, 2).dx, d(270, 2).dy, d(314, 11).dx, d(314, 11).dy),
        wire);
    final bulbColor = isDark ? const Color(0xFFFFC94D) : const Color(0xFFE8A23C);
    final haloColor = (isDark ? const Color(0xFFFFC94D) : const Color(0xFFE8A23C))
        .withValues(alpha: isDark ? .38 : .3);
    const xs = [16.0, 46.0, 78.0, 108.0, 140.0, 172.0, 204.0, 236.0, 268.0, 296.0];
    const ys = [11.0, 14.0, 9.5, 13.0, 9.0, 13.5, 9.5, 13.0, 9.0, 12.5];
    for (int i = 0; i < xs.length; i++) {
      final c = d(xs[i], ys[i] + 3.4);
      // 频率取整数(2),相位逐灯错开
      final wave = .5 + .5 * math.sin(t * math.pi * 2 * 2 + i * 1.1);
      final a = .3 + .7 * wave;
      canvas.drawLine(d(xs[i], ys[i]), d(xs[i], ys[i] + 1.6), wire);
      canvas.drawCircle(c, 5.2 * u, Paint()..color = haloColor.withValues(alpha: haloColor.a * a));
      canvas.drawCircle(c, 2.3 * u, Paint()..color = bulbColor.withValues(alpha: a));
    }

    _paintFallingSnow(canvas, size, t, _dots,
        color: Colors.white, maxOpacity: .85);
  }

  @override
  bool shouldRepaint(covariant _CabinGlowTabPainter old) =>
      old.isDark != isDark;
}
