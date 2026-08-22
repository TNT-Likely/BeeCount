part of '../header_skins.dart';

// ============ 冬日皮肤:冰晶初凝(Frostwork) ============
//
// 单色冰蓝的干净派天花板:霜蕨从屏幕底边长上来,一枚六出冰晶在光里缓缓转
// (蓝骨 + 白芯双层描边 = 冰的质感),四芒碎钻错相明灭。
// 全库唯一晶体系;「素」用碎钻与双层描边解(与银杏金秋的单色相逻辑同源)。
// 设计稿:.docs/skin-designs/winter-skins.html 的「冬 · E」。

const Color _kFrostLineL = Color(0xFF4A90C2);
const Color _kFrostLineD = Color(0xFFA6D8F8);

class _FrostworkSkin extends StatelessWidget {
  const _FrostworkSkin(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 30, // 主冰晶一个循环恰转一圈:30s 的慢,是「冷得很贵」的慢
        painterFor: (a) => _FrostworkPainter(isDark, a),
      );
}

/// 霜蕨:一支主脉 + 六根侧针,原点在根部、向上生长(局部坐标,画时平移缩放)。
final Path _kFrostFern = Path()
  ..moveTo(0, 0)
  ..cubicTo(2, -8, 1, -16, 4, -24)
  ..moveTo(.8, -6)
  ..lineTo(-4.6, -10)
  ..moveTo(.8, -6)
  ..lineTo(5.6, -10.6)
  ..moveTo(1.6, -13)
  ..lineTo(-2.8, -17.6)
  ..moveTo(1.6, -13)
  ..lineTo(6.6, -16.6)
  ..moveTo(3, -19)
  ..lineTo(0, -23.6)
  ..moveTo(3, -19)
  ..lineTo(7.6, -21.6);

void _drawFrostFern(Canvas canvas, Offset root, double scale, double rotDeg,
    {required Color color, bool mirror = false}) {
  canvas.save();
  canvas.translate(root.dx, root.dy);
  canvas.rotate(rotDeg * math.pi / 180);
  canvas.scale(mirror ? -scale : scale, scale);
  canvas.drawPath(
      _kFrostFern,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round);
  canvas.restore();
}

/// 四芒碎钻(局部坐标,半径 5.4)。
final Path _kSparkStar = Path()
  ..moveTo(0, -5.4)
  ..lineTo(1.1, -1.1)
  ..lineTo(5.4, 0)
  ..lineTo(1.1, 1.1)
  ..lineTo(0, 5.4)
  ..lineTo(-1.1, 1.1)
  ..lineTo(-5.4, 0)
  ..lineTo(-1.1, -1.1)
  ..close();

/// 一组四芒碎钻错相明灭:pts 为(设计稿 x, y, 尺寸, 整数频率)。
void _paintSparkStars(Canvas canvas, Size size, double t,
    List<(double, double, double, int)> pts,
    {required Color color, double k = 1}) {
  for (int i = 0; i < pts.length; i++) {
    final s = pts[i];
    final wave = .5 + .5 * math.sin(t * math.pi * 2 * s.$4 + i * .9);
    final alpha = .12 + wave * .88;
    final scale = (.55 + .55 * wave) * (s.$3 / 10.8) * k;
    canvas.save();
    final c = _ap(size, s.$1, s.$2);
    canvas.translate(c.dx, c.dy);
    canvas.rotate(wave * .3);
    canvas.scale(scale);
    canvas.drawPath(
        _kSparkStar, Paint()..color = color.withValues(alpha: alpha));
    canvas.restore();
  }
}

class _FrostworkPainter extends CustomPainter {
  _FrostworkPainter(this.isDark, this.anim) : super(repaint: anim) {
    _dots = _makeSnowDots(
        seed: isDark ? 53 : 51, count: 10, minSize: 1.2, maxSize: 2.6,
        speedBase: 3);
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_SnowDot> _dots;

  Color get _line => isDark ? _kFrostLineD : _kFrostLineL;
  Color get _fern => isDark
      ? const Color(0xFF92CCF4).withValues(alpha: .5)
      : const Color(0xFF9FC2E2);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final k = (size.height / 208).clamp(.55, 1.0);

    _paintVerticalBase(
      canvas,
      size,
      isDark
          ? const [Color(0xFF000000), Color(0xFF03101E), Color(0xFF06182C)]
          : const [Color(0xFFFDFEFF), Color(0xFFF0F6FC), Color(0xFFE2EDF8)],
      isDark ? const [0, .55, 1] : const [0, .5, 1],
    );

    // 底边霜蕨:从边缘往上长
    for (final f in const [
      (16.0, 1.1, 4.0),
      (58.0, .9, -8.0),
      (104.0, 1.2, 10.0),
      (148.0, .85, -5.0),
      (196.0, 1.05, 7.0),
      (244.0, .9, -10.0),
      (286.0, 1.15, 5.0),
    ]) {
      _drawFrostFern(canvas, _ap(size, f.$1, 208), f.$2 * k, f.$3,
          color: _fern.withValues(alpha: isDark ? .55 : .6));
    }

    // 左下大冰晶线稿
    _drawCrystal(canvas, _ap(size, 52, 176), 60 * k, .3,
        color: _line.withValues(alpha: isDark ? .1 : .13), strokeWidth: 1.6);

    // 主冰晶:柔光 + 蓝骨白芯,30s 一圈
    final hero = _ap(size, 242, 102);
    _paintRadialGlow(canvas, size, hero, 46 * k,
        isDark ? const Color(0xFF8CC8F5) : Colors.white, isDark ? .26 : .5);
    _drawCrystal(canvas, hero, 70 * k, t * math.pi * 2,
        color: _line,
        strokeWidth: 1.7,
        core: isDark ? const Color(0xFFE6F5FF) : Colors.white);
    // 两枚小冰晶反向陪转
    _drawCrystal(canvas, _ap(size, 203, 152), 29 * k, -t * math.pi * 2 + 1.2,
        color: _line, strokeWidth: 2.2, opacity: .6, fine: false);
    _drawCrystal(canvas, _ap(size, 288, 148), 20 * k, t * math.pi * 2 + 2.6,
        color: _line, strokeWidth: 2.4, opacity: .55, fine: false);

    // 碎钻(防素的关键一层)
    _paintSparkStars(
        canvas,
        size,
        t,
        const [
          (196, 62, 10, 2),
          (268, 58, 8, 3),
          (216, 128, 9, 3),
          (284, 108, 11, 2),
          (252, 158, 8, 4),
          (172, 96, 7, 2),
          (66, 132, 8, 3),
          (118, 168, 7, 2),
        ],
        color: isDark ? const Color(0xFFCFEBFF) : const Color(0xFF6FA8D6),
        k: k);

    _paintFallingSnow(canvas, size, t, _dots,
        color: isDark ? const Color(0xFFD9EEFF) : Colors.white,
        maxOpacity: .7);
  }

  @override
  bool shouldRepaint(covariant _FrostworkPainter old) => old.isDark != isDark;
}

class _FrostworkTabDeco extends StatelessWidget {
  const _FrostworkTabDeco(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 10,
        painterFor: (a) => _FrostworkTabPainter(isDark, a),
      );
}

class _FrostworkTabPainter extends CustomPainter {
  _FrostworkTabPainter(this.isDark, this.anim) : super(repaint: anim) {
    _dots = _makeSnowDots(
        seed: isDark ? 93 : 91, count: 3, minSize: 1.4, maxSize: 2.8);
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_SnowDot> _dots;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final u = size.height / 47;
    final line = isDark ? _kFrostLineD : _kFrostLineL;
    final fern = isDark
        ? const Color(0xFF92CCF4).withValues(alpha: .55)
        : const Color(0xFF9FC2E2);

    // 两端霜蕨向内长
    _drawFrostFern(canvas, Offset(6, size.height), 1.1 * u, 14,
        color: fern.withValues(alpha: .65));
    _drawFrostFern(canvas, Offset(24 * u, size.height), .8 * u, -6,
        color: fern.withValues(alpha: .5));
    _drawFrostFern(canvas, Offset(size.width - 6, size.height), 1.1 * u, -14,
        color: fern.withValues(alpha: .65), mirror: true);
    _drawFrostFern(
        canvas, Offset(size.width - 24 * u, size.height), .75 * u, 8,
        color: fern.withValues(alpha: .5), mirror: true);

    // 右端一枚小冰晶慢转(一个循环一圈)
    _drawCrystal(canvas, Offset(size.width - 50 * u, 13 * u), 13 * u,
        t * math.pi * 2,
        color: line, strokeWidth: 2.2, opacity: .8, fine: false);

    // 四粒碎钻明灭
    for (final s in const [
      (.19, 11.0, 8.0, 2),
      (.42, 32.0, 7.0, 3),
      (.64, 9.0, 8.0, 2),
      (.81, 30.0, 7.0, 3),
    ]) {
      final wave = .5 + .5 * math.sin(t * math.pi * 2 * s.$4 + s.$1 * 9);
      canvas.save();
      canvas.translate(size.width * s.$1, s.$2 * u);
      canvas.scale((.55 + .55 * wave) * (s.$3 / 10.8) * u);
      canvas.drawPath(
          _kSparkStar,
          Paint()
            ..color = (isDark
                    ? const Color(0xFFCFEBFF)
                    : const Color(0xFF6FA8D6))
                .withValues(alpha: .12 + wave * .88));
      canvas.restore();
    }

    _paintFallingSnow(canvas, size, t, _dots,
        color: isDark ? const Color(0xFFD9EEFF) : const Color(0xFFDCEBF8),
        maxOpacity: .8);
  }

  @override
  bool shouldRepaint(covariant _FrostworkTabPainter old) =>
      old.isDark != isDark;
}
