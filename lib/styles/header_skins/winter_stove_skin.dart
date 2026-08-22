part of '../header_skins.dart';

// ============ 冬日皮肤:围炉煮茶(Fireside Tea) ============
//
// 炭炉上一把奶白侧把壶咕嘟着:壶嘴白汽循环上升、炉口炭光呼吸、细小火星上飘、
// 炉沿两颗烤橘;左上角留一块「窗外的寒色」+ 几粒落雪 —— W2 冷暖同框。
// 与雪夜灯火是「屋外看灯火 / 屋内围炉煮茶」的一外一内。
// 设计稿:.docs/skin-designs/winter-skins.html 的「冬 · D」。

const Color _kStoveClayL = Color(0xFFB9714A);
const Color _kStoveClayD = Color(0xFF8A4E30);
const Color _kStoveClayDarkL = Color(0xFF9C5A38);
const Color _kStoveClayDarkD = Color(0xFF6B3A22);
const Color _kStovePotL = Color(0xFFF4EADA);
const Color _kStovePotD = Color(0xFFEADFC9);
const Color _kStovePotLineL = Color(0xFFC9B89E);
const Color _kStovePotLineD = Color(0xFFB9A583);

class _FiresideTeaSkin extends StatelessWidget {
  const _FiresideTeaSkin(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 12,
        painterFor: (a) => _FiresideTeaPainter(isDark, a),
      );
}

/// 奶白侧把壶:以壶身中心为原点绘制,header 与 tab 共用(tab 缩小复用)。
void _drawTeapot(Canvas canvas,
    {required Color body,
    required Color line,
    required Color wood,
    Color? rimLight}) {
  final bodyPaint = Paint()..color = body;
  final linePaint = Paint()
    ..color = line
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  // 壶身
  final bodyRect =
      Rect.fromCenter(center: Offset.zero, width: 31, height: 25);
  canvas.drawOval(bodyRect, bodyPaint);
  canvas.drawOval(bodyRect, linePaint);
  // 壶身高光弧
  canvas.drawPath(
      Path()
        ..moveTo(-13, -6)
        ..quadraticBezierTo(-7, 2, 13, 0),
      Paint()
        ..color = line.withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9);
  // 壶嘴(向左上)
  final spout = Path()
    ..moveTo(-14, -4)
    ..cubicTo(-19, -6, -21.5, -10, -22, -15)
    ..lineTo(-17.5, -16)
    ..cubicTo(-16.5, -12, -14, -8.5, -10, -6.5)
    ..close();
  canvas.drawPath(spout, bodyPaint);
  canvas.drawPath(spout, linePaint..strokeWidth = .9);
  // 壶盖 + 木钮
  final lid = Rect.fromCenter(center: const Offset(0, -11.5), width: 16, height: 5.6);
  canvas.drawOval(lid, bodyPaint);
  canvas.drawOval(lid, linePaint);
  canvas.drawCircle(const Offset(0, -14.5), 2.4, Paint()..color = wood);
  // 侧把(木柄)
  canvas.drawLine(
      const Offset(14, -5),
      const Offset(30, -14.5),
      Paint()
        ..color = wood
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round);
  // 暗色:炉火在壶底描一道暖边
  if (rimLight != null) {
    canvas.drawPath(
        Path()
          ..moveTo(-13, 6)
          ..quadraticBezierTo(-9, 11, 0, 12),
        Paint()
          ..color = rimLight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round);
  }
}

/// 烤橘:圆果 + 高光 + 顶叶。
void _drawOrange(Canvas canvas, Offset center, double r,
    {required Color skin, required Color leaf, bool withLeaf = true}) {
  canvas.drawCircle(center, r, Paint()..color = skin);
  canvas.drawOval(
      Rect.fromCenter(
          center: center + Offset(-r * .35, -r * .35),
          width: r * .64,
          height: r * .38),
      Paint()..color = Colors.white.withValues(alpha: .4));
  if (withLeaf) {
    canvas.drawOval(
        Rect.fromCenter(
            center: center + Offset(0, -r * 1.05), width: r * .75, height: r * .36),
        Paint()..color = leaf);
  }
}

class _FiresideTeaPainter extends CustomPainter {
  _FiresideTeaPainter(this.isDark, this.anim) : super(repaint: anim) {
    _corner = _makeSnowDots(
        seed: isDark ? 47 : 45, count: 6, xMaxRatio: .24, minSize: 1.6, maxSize: 3.2);
    final rnd = math.Random(isDark ? 43 : 41);
    _embers = List.generate(5, (i) {
      return (
        244 + rnd.nextDouble() * 18, // x(设计稿坐标)
        140 + rnd.nextDouble() * 8, // y
        1.4 + rnd.nextDouble() * 1.2, // 半径
        2 + (i % 2), // 每循环上飘次数(整数)
        rnd.nextDouble(), // 相位
        rnd.nextDouble() * 12 - 6, // 横向漂移
      );
    });
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_SnowDot> _corner;
  late final List<(double, double, double, int, double, double)> _embers;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final k = (size.height / 208).clamp(.55, 1.0);
    final glow = .62 + .38 * (.5 + .5 * math.sin(t * math.pi * 2 * 3));

    _paintVerticalBase(
      canvas,
      size,
      isDark
          ? const [Color(0xFF000000), Color(0xFF190D03)]
          : const [Color(0xFFFFFBF4), Color(0xFFFBF0E0), Color(0xFFF6E3C8)],
      isDark ? null : const [0, .55, 1],
    );

    // 左上角:窗外的寒色(W2 冷暖同框)
    _paintRadialGlow(canvas, size, _ap(size, 42, 12), size.width * .5,
        const Color(0xFFC9D9EC), isDark ? .12 : .3);

    // 炉火暖光圈(呼吸)
    _paintRadialGlow(canvas, size, _ap(size, 254, 146), 62 * k,
        const Color(0xFFF5913A), (isDark ? .42 : .28) * glow);

    // 左下茶杯线稿
    final sketch = Paint()
      ..color = isDark
          ? const Color(0xFFFFB478).withValues(alpha: .2)
          : const Color(0xFFB9714A).withValues(alpha: .32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(_ax(size, 40), _ay(size, 178))
          ..lineTo(_ax(size, 62), _ay(size, 178))
          ..quadraticBezierTo(_ax(size, 63), _ay(size, 190), _ax(size, 51),
              _ay(size, 190))
          ..quadraticBezierTo(_ax(size, 39), _ay(size, 190), _ax(size, 40),
              _ay(size, 178))
          ..close(),
        sketch);
    canvas.drawPath(
        Path()
          ..moveTo(_ax(size, 62), _ay(size, 181))
          ..quadraticBezierTo(
              _ax(size, 69), _ay(size, 182), _ax(size, 62), _ay(size, 187)),
        sketch);
    for (final x in const [46.0, 54.0]) {
      canvas.drawPath(
          Path()
            ..moveTo(_ax(size, x), _ay(size, 170))
            ..quadraticBezierTo(
                _ax(size, x - 2), _ay(size, 166), _ax(size, x + 1), _ay(size, 163)),
          sketch);
    }

    _paintStove(canvas, size, glow);

    // 奶白侧把壶(壶底坐进炉沿,不悬空)
    canvas.save();
    final potC = _ap(size, 249, 118);
    canvas.translate(potC.dx, potC.dy);
    canvas.scale(k);
    _drawTeapot(canvas,
        body: isDark ? _kStovePotD : _kStovePotL,
        line: isDark ? _kStovePotLineD : _kStovePotLineL,
        wood: isDark ? const Color(0xFFA8845C) : const Color(0xFF8A6A4A),
        rimLight:
            isDark ? const Color(0xFFF5A05A).withValues(alpha: .55) : null);
    canvas.restore();

    // 炉沿烤橘
    _drawOrange(canvas, _ap(size, 276, 124), 6.2 * k,
        skin: isDark ? const Color(0xFFFFA940) : const Color(0xFFF59A2E),
        leaf: isDark ? const Color(0xFF6FA84A) : const Color(0xFF4F7A2E));
    _drawOrange(canvas, _ap(size, 286, 128), 5.2 * k,
        skin: isDark ? const Color(0xFFF59A2E) : const Color(0xFFED8A1E),
        leaf: isDark ? const Color(0xFF6FA84A) : const Color(0xFF4F7A2E),
        withLeaf: false);

    _paintSteam(canvas, size, t, k);
    _paintEmbers(canvas, size, t, k);

    // 窗外那角的落雪
    _paintFallingSnow(canvas, size, t, _corner,
        color: isDark ? const Color(0xFFD9E4F0) : Colors.white,
        maxOpacity: isDark ? .7 : .9);
  }

  void _paintStove(Canvas canvas, Size size, double glow) {
    final clay = isDark ? _kStoveClayD : _kStoveClayL;
    final clayDark = isDark ? _kStoveClayDarkD : _kStoveClayDarkL;

    // 炉身
    canvas.drawPath(
        Path()
          ..moveTo(_ax(size, 228), _ay(size, 130))
          ..quadraticBezierTo(
              _ax(size, 225), _ay(size, 160), _ax(size, 240), _ay(size, 169))
          ..lineTo(_ax(size, 268), _ay(size, 169))
          ..quadraticBezierTo(
              _ax(size, 283), _ay(size, 160), _ax(size, 280), _ay(size, 130))
          ..close(),
        Paint()..color = clay);
    // 炉脚
    final feet = Paint()..color = clayDark;
    canvas.drawRect(
        Rect.fromLTWH(
            _ax(size, 236), _ay(size, 169), _ax(size, 6), _ay(size, 4)),
        feet);
    canvas.drawRect(
        Rect.fromLTWH(
            _ax(size, 262), _ay(size, 169), _ax(size, 6), _ay(size, 4)),
        feet);
    // 炉口沿(两圈)
    canvas.drawOval(
        Rect.fromCenter(
            center: _ap(size, 254, 130),
            width: _ax(size, 54),
            height: _ay(size, 11)),
        Paint()..color = clayDark);
    canvas.drawOval(
        Rect.fromCenter(
            center: _ap(size, 254, 129),
            width: _ax(size, 42),
            height: _ay(size, 7.2)),
        Paint()
          ..color = isDark ? const Color(0xFF4A2614) : const Color(0xFF7A4226));

    // 炉口炭光(呼吸)
    final mouth = Rect.fromLTWH(
        _ax(size, 245), _ay(size, 146), _ax(size, 18), _ay(size, 13));
    canvas.drawRRect(
        RRect.fromRectAndRadius(mouth, Radius.circular(_ay(size, 6))),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFFFFD35E), Color(0xFFE85A20)],
          ).createShader(mouth)
          ..color = Colors.white.withValues(alpha: glow));
    final inner = Rect.fromLTWH(
        _ax(size, 248.5), _ay(size, 150), _ax(size, 11), _ay(size, 6));
    canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(_ay(size, 3))),
        Paint()
          ..color = const Color(0xFFFFE9A8)
              .withValues(alpha: .8 * (1.24 - glow).clamp(0, 1)));
  }

  void _paintSteam(Canvas canvas, Size size, double t, double k) {
    final color = isDark
        ? Colors.white
        : const Color(0xFF949CB6);
    for (int i = 0; i < 2; i++) {
      final p = (t * 2 + i / 2) % 1;
      final alphaMax = isDark ? .4 : .55;
      final alpha =
          p < .14 ? alphaMax * p / .14 : alphaMax * (1 - (p - .14) / .86);
      if (alpha <= .02) continue;
      final center = _ap(size, 224, 98) + Offset(-9 * k * p, -46 * k * p);
      _paintRadialGlow(
          canvas, size, center, (3.5 + i * 1.2 + 7 * p) * k, color, alpha);
    }
  }

  void _paintEmbers(Canvas canvas, Size size, double t, double k) {
    final color = isDark ? const Color(0xFFFFB347) : const Color(0xFFF08A2E);
    for (final e in _embers) {
      final p = (t * e.$4 + e.$5) % 1;
      final alphaMax = isDark ? .95 : .75;
      final alpha =
          p < .15 ? alphaMax * p / .15 : alphaMax * (1 - (p - .15) / .85);
      if (alpha <= .02) continue;
      final center = _ap(size, e.$1, e.$2) + Offset(e.$6 * k * p, -50 * k * p);
      canvas.drawCircle(center, e.$3 * (1 - p * .55) * k,
          Paint()..color = color.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(covariant _FiresideTeaPainter old) =>
      old.isDark != isDark;
}

class _FiresideTeaTabDeco extends StatelessWidget {
  const _FiresideTeaTabDeco(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 10,
        painterFor: (a) => _FiresideTeaTabPainter(isDark, a),
      );
}

class _FiresideTeaTabPainter extends CustomPainter {
  _FiresideTeaTabPainter(this.isDark, this.anim) : super(repaint: anim);
  final bool isDark;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final u = size.height / 47;
    final glow = .62 + .38 * (.5 + .5 * math.sin(t * math.pi * 2 * 2));

    // 底部一条炭光微亮
    final band = Rect.fromLTWH(0, size.height - 14 * u, size.width, 14 * u);
    canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFE85A20)
                  .withValues(alpha: (isDark ? .34 : .22) * glow),
              const Color(0xFFE85A20).withValues(alpha: 0),
            ],
          ).createShader(band));

    // 左端迷你侧把壶(冒蒸汽)
    canvas.save();
    canvas.translate(18 * u + 6, size.height * .62);
    canvas.scale(.62 * u);
    _drawTeapot(canvas,
        body: isDark ? _kStovePotD : _kStovePotL,
        line: isDark ? _kStovePotLineD : _kStovePotLineL,
        wood: isDark ? const Color(0xFFA8845C) : const Color(0xFF8A6A4A));
    canvas.restore();
    final steamColor = isDark ? Colors.white : const Color(0xFF949CB6);
    for (int i = 0; i < 2; i++) {
      final p = (t * 2 + i / 2) % 1;
      final alphaMax = isDark ? .42 : .6;
      final alpha =
          p < .14 ? alphaMax * p / .14 : alphaMax * (1 - (p - .14) / .86);
      if (alpha <= .02) continue;
      final center = Offset(9 * u + 6, size.height * .36) +
          Offset(6 * u * p, -16 * u * p);
      _paintRadialGlow(
          canvas, size, center, (2.6 + 3.5 * p) * u, steamColor, alpha);
    }

    // 右端两颗烤橘
    _drawOrange(canvas, Offset(size.width - 19 * u, size.height * .72),
        5.4 * u,
        skin: isDark ? const Color(0xFFFFA940) : const Color(0xFFF59A2E),
        leaf: isDark ? const Color(0xFF6FA84A) : const Color(0xFF4F7A2E));
    _drawOrange(canvas, Offset(size.width - 10 * u, size.height * .8), 4.4 * u,
        skin: isDark ? const Color(0xFFF59A2E) : const Color(0xFFED8A1E),
        leaf: isDark ? const Color(0xFF6FA84A) : const Color(0xFF4F7A2E),
        withLeaf: false);

    // 三粒火星上飘
    final ember = isDark ? const Color(0xFFFFB347) : const Color(0xFFF08A2E);
    for (int i = 0; i < 3; i++) {
      final p = (t * (2 + i % 2) + i * .37) % 1;
      final alpha = (p < .15 ? p / .15 : (1 - p) / .85) * .85;
      if (alpha <= .02) continue;
      canvas.drawCircle(
          Offset(size.width * (.3 + i * .19) + (i.isEven ? 5 : -5) * u * p,
              size.height - 6 * u - size.height * .8 * p),
          (1.2 - p * .5) * u,
          Paint()..color = ember.withValues(alpha: alpha));
    }

    // 金橘光点
    for (final g in const [(.42, 12.0, 2), (.62, 34.0, 3), (.8, 10.0, 2)]) {
      final wave = .5 + .5 * math.sin(t * math.pi * 2 * g.$3 + g.$1 * 8);
      canvas.drawCircle(
          Offset(size.width * g.$1, g.$2 * u),
          1.1 * u,
          Paint()
            ..color = (isDark ? const Color(0xFFFFA940) : const Color(0xFFF59A2E))
                .withValues(alpha: .15 + wave * .7));
    }
  }

  @override
  bool shouldRepaint(covariant _FiresideTeaTabPainter old) =>
      old.isDark != isDark;
}
