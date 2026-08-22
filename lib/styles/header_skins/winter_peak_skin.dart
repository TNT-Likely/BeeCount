part of '../header_skins.dart';

// ============ 冬日皮肤:日照金山(Golden Summit) ============
//
// 天没全亮,第一缕日光先把雪峰的**上半座**染成金红 —— 日照线以下还是冷的雪。
// 「见者好运」的彩头款;留白派,元素最少。
// 设计稿:.docs/skin-designs/winter-skins.html 的「冬 · F」。
//
// 画法对着真实场景来(设计评审拍板:不许符号化成"峰尖一小块金"):
// 山体 clipPath + 竖向「日出渐变」色带盖住上半座山,往下渐隐回冷雪;
// 阴影面再压一层暗,亮暗两面都被点亮但立体感不丢;峰顶背后一圈晨光光晕。

class _GoldenSummitSkin extends StatelessWidget {
  const _GoldenSummitSkin(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 12,
        painterFor: (a) => _GoldenSummitPainter(isDark, a),
      );
}

/// 主峰轮廓(设计稿坐标),header 与 clip 共用。
const List<List<double>> _kSummitPts = [
  [148, 208], [184, 136], [208, 106], [224, 86], [236, 72],
  [250, 90], [262, 106], [280, 140], [306, 180], [310, 186], [310, 208],
];

/// 阴影面(右侧)。
const List<List<double>> _kSummitShadePts = [
  [236, 72], [250, 90], [262, 106], [280, 140], [306, 180],
  [310, 186], [310, 208], [236, 208],
];

class _GoldenSummitPainter extends CustomPainter {
  _GoldenSummitPainter(this.isDark, this.anim) : super(repaint: anim) {
    _dots = _makeSnowDots(
        seed: isDark ? 67 : 65, count: 8, minSize: 1.2, maxSize: 2.4,
        speedBase: 2);
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_SnowDot> _dots;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final k = (size.height / 208).clamp(.55, 1.0);
    final glow = .7 + .3 * (.5 + .5 * math.sin(t * math.pi * 2 * 3));

    _paintVerticalBase(
      canvas,
      size,
      isDark
          ? const [
              Color(0xFF000000),
              Color(0xFF080F26),
              Color(0xFF131C40),
              Color(0xFF1B2650)
            ]
          : const [
              Color(0xFFE9EDF9),
              Color(0xFFDEE1F2),
              Color(0xFFEBDDE6),
              Color(0xFFF2D7C8)
            ],
      const [0, .45, .78, 1],
    );

    // 峰顶背后的晨光光晕(呼吸)
    final apex = _ap(size, 236, 80);
    _paintRadialGlow(canvas, size, apex, 78 * k, const Color(0xFFFFCE7A),
        (isDark ? .28 : .25) * glow);
    _paintRadialGlow(canvas, size, apex, 42 * k, const Color(0xFFFFCE7A),
        (isDark ? .6 : .55) * glow);

    // 暮星(暗色主场)
    _paintNightStars(canvas, size, t,
        color: Colors.white,
        seed: isDark ? 63 : 61,
        count: isDark ? 16 : 4,
        maxAlpha: isDark ? .6 : .28,
        maxYRatio: .45);

    // 远岭
    canvas.drawPath(
        _polyPath(size, const [
          [-10, 158], [42, 136], [92, 154], [142, 132], [192, 152],
          [240, 134], [310, 150], [310, 208], [-10, 208],
        ]),
        Paint()
          ..color = (isDark ? const Color(0xFF0C1730) : const Color(0xFFC9D5EA))
              .withValues(alpha: isDark ? .92 : .5));

    // 左侧次峰(纯冷雪 —— 金只给主峰,惊艳要克制)
    canvas.drawPath(
        _polyPath(size, const [
          [-10, 208], [28, 160], [64, 190], [106, 148], [148, 194], [176, 208],
        ]),
        Paint()
          ..color = (isDark ? const Color(0xFF0F1B38) : const Color(0xFFD9E4F2))
              .withValues(alpha: isDark ? .96 : .85));

    // 主峰体(冷雪) + 阴影面
    final massif = _polyPath(size, _kSummitPts);
    canvas.drawPath(
        massif,
        Paint()
          ..color =
              isDark ? const Color(0xFF1E2E52) : const Color(0xFFEFF4FC));
    final shade = _polyPath(size, _kSummitShadePts);
    canvas.drawPath(
        shade,
        Paint()
          ..color = (isDark ? const Color(0xFF101D3C) : const Color(0xFFC2D0E8))
              .withValues(alpha: isDark ? .96 : .9));

    // 日照金山:山体裁剪内的日出色带,盖住上半座山、往下渐隐回冷雪
    canvas.save();
    canvas.clipPath(massif);
    final band = Rect.fromLTWH(
        _ax(size, 140), _ay(size, 66), _ax(size, 176), _ay(size, 86));
    canvas.drawRect(
        band,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE18A),
              Color(0xFFF5993A),
              Color(0xFFE87F5A),
              Color(0x00E87F5A),
            ],
            stops: [0, .42, .72, 1],
          ).createShader(band)
          ..color = Colors.white.withValues(alpha: glow));
    // 阴影面把金光压暗一档,立体感不丢
    canvas.drawPath(
        shade,
        Paint()
          ..color = (isDark ? const Color(0xFF0E1B3C) : const Color(0xFF8A7BB0))
              .withValues(alpha: .3));
    canvas.restore();

    // 山脊岩沟(压在金光上,保住山的质感)
    final couloir = Paint()
      ..color = isDark
          ? const Color(0xFF060A1A).withValues(alpha: .75)
          : const Color(0xFF60568C).withValues(alpha: .4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (final c in const [
      [236.0, 72.0, 231.0, 116.0],
      [224.0, 86.0, 216.0, 120.0],
      [250.0, 90.0, 246.0, 126.0],
      [208.0, 106.0, 201.0, 136.0],
      [262.0, 106.0, 259.0, 134.0],
    ]) {
      canvas.drawLine(_ap(size, c[0], c[1]), _ap(size, c[2], c[3]), couloir);
    }
    // 亮脊线
    final ridge = Path()
      ..moveTo(_ax(size, 184), _ay(size, 136))
      ..lineTo(_ax(size, 208), _ay(size, 106))
      ..lineTo(_ax(size, 224), _ay(size, 86))
      ..lineTo(_ax(size, 236), _ay(size, 72));
    canvas.drawPath(
        ridge,
        Paint()
          ..color = const Color(0xFFFFF4DC)
              .withValues(alpha: isDark ? .5 : .75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    // 雪旗:紧贴峰尖、向左下方飘散(真实的雪旗是被风从峰顶扯下来的雪雾),
    // 尾端随风极缓地摆
    canvas.save();
    final apexPt = _ap(size, 236, 72);
    canvas.translate(apexPt.dx, apexPt.dy);
    canvas.rotate(math.sin(t * math.pi * 2 * 2) * .03);
    canvas.translate(-apexPt.dx, -apexPt.dy);
    canvas.drawPath(
        Path()
          ..moveTo(_ax(size, 236), _ay(size, 72))
          ..quadraticBezierTo(_ax(size, 226), _ay(size, 70), _ax(size, 216),
              _ay(size, 72))
          ..quadraticBezierTo(_ax(size, 209), _ay(size, 73.5), _ax(size, 203),
              _ay(size, 77)),
        Paint()
          ..color = (isDark ? const Color(0xFFFFD68A) : const Color(0xFFFFE09E))
              .withValues(alpha: isDark ? .65 : .85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        Path()
          ..moveTo(_ax(size, 233), _ay(size, 74.5))
          ..quadraticBezierTo(_ax(size, 224), _ay(size, 74), _ax(size, 212),
              _ay(size, 78.5)),
        Paint()
          ..color = Colors.white.withValues(alpha: isDark ? .3 : .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round);
    canvas.restore();

    // 云海缓缓游移(频率取整数):沿水平线串一排径向柔光,叠成一条雾带 ——
    // 雾要软,不能是实心白碟(单个宽椭圆会退化成生硬的圆斑)。
    final mistColor = isDark ? const Color(0xFFBCD2F0) : Colors.white;
    final dx1 = math.sin(t * math.pi * 2) * 10 * k;
    for (final x in const [52.0, 96.0, 140.0, 184.0]) {
      _paintRadialGlow(canvas, size, _ap(size, x, 174) + Offset(dx1, 0),
          30 * k, mistColor, isDark ? .07 : .3);
    }
    final dx2 = math.sin(t * math.pi * 2 + 2.6) * 10 * k;
    for (final x in const [196.0, 240.0, 284.0]) {
      _paintRadialGlow(canvas, size, _ap(size, x, 188) + Offset(dx2, 0),
          26 * k, mistColor, isDark ? .06 : .24);
    }

    _paintFallingSnow(canvas, size, t, _dots,
        color: Colors.white, maxOpacity: .6);
  }

  @override
  bool shouldRepaint(covariant _GoldenSummitPainter old) =>
      old.isDark != isDark;
}

class _GoldenSummitTabDeco extends StatelessWidget {
  const _GoldenSummitTabDeco(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 10,
        painterFor: (a) => _GoldenSummitTabPainter(isDark, a),
      );
}

class _GoldenSummitTabPainter extends CustomPainter {
  _GoldenSummitTabPainter(this.isDark, this.anim) : super(repaint: anim) {
    _dots = _makeSnowDots(
        seed: isDark ? 97 : 95, count: 3, minSize: 1.4, maxSize: 2.6);
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_SnowDot> _dots;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final glow = .7 + .3 * (.5 + .5 * math.sin(t * math.pi * 2 * 2));
    Offset d(double x, double y) =>
        Offset(size.width * x / 311, size.height * y / 47);

    // 底部连绵小雪山
    final range = Path()..moveTo(0, size.height);
    for (final p in const [
      [0.0, 34.0], [24.0, 20.0], [44.0, 32.0], [72.0, 12.0], [100.0, 34.0],
      [136.0, 22.0], [170.0, 36.0], [205.0, 24.0], [240.0, 37.0],
      [272.0, 27.0], [311.0, 36.0],
    ]) {
      range.lineTo(d(p[0], p[1]).dx, d(p[0], p[1]).dy);
    }
    range
      ..lineTo(size.width, size.height)
      ..close();

    // 最高峰背后的光晕
    _paintRadialGlow(canvas, size, d(72, 15), 10 * size.height / 47,
        const Color(0xFFFFC966), .45 * glow);

    canvas.drawPath(
        range,
        Paint()
          ..color =
              isDark ? const Color(0xFF16233F) : const Color(0xFFE6EEF8));
    canvas.drawPath(
        range,
        Paint()
          ..color = isDark
              ? const Color(0xFFCDE1FF).withValues(alpha: .3)
              : const Color(0xFFC7D6EA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // 最高峰的尖是金的(裁剪 + 渐变,与 header 同一画法)
    canvas.save();
    canvas.clipPath(range);
    final band = Rect.fromLTWH(
        d(52, 0).dx, d(0, 10).dy, d(40, 0).dx, d(0, 20).dy);
    canvas.drawRect(
        band,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE18A), Color(0xFFF5993A), Color(0x00F5993A)],
            stops: [0, .55, 1],
          ).createShader(band)
          ..color = Colors.white.withValues(alpha: glow));
    canvas.restore();

    // 两粒星子明灭
    for (final g in const [(.1, 8.0, 2), (.19, 14.0, 3), (.28, 6.0, 2)]) {
      final wave = .5 + .5 * math.sin(t * math.pi * 2 * g.$3 + g.$1 * 11);
      canvas.drawCircle(
          Offset(size.width * g.$1, g.$2 * size.height / 47),
          1,
          Paint()..color = Colors.white.withValues(alpha: .12 + wave * .7));
    }

    _paintFallingSnow(canvas, size, t, _dots,
        color: Colors.white, maxOpacity: .7);
  }

  @override
  bool shouldRepaint(covariant _GoldenSummitTabPainter old) =>
      old.isDark != isDark;
}
