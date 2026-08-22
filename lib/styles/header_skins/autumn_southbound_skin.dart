part of '../header_skins.dart';

// ============ 秋日皮肤:雁阵南飞(Southbound) ============
//
// 固定霞光渐变。元素最少、留白最多的一款 —— 霞光本身就好看,不靠堆元素:
// 低垂的落日、人字雁阵横穿、底部芦苇摇曳、地平线薄雾。
// 设计稿:autumn-skins.html 的「秋 · G」。
//
// 雁阵横穿一整圈 = 一个动画周期,所以周期取长(26s),避免频繁掠过打扰。

class _SouthboundSkin extends StatelessWidget {
  const _SouthboundSkin(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 26,
        painterFor: (a) => _SouthboundPainter(isDark, a),
        staticFrame: .42,
      );
}

class _SouthboundPainter extends CustomPainter {
  _SouthboundPainter(this.isDark, this.anim) : super(repaint: anim);
  final bool isDark;
  final Animation<double> anim;

  Color get _goose => isDark
      ? const Color(0xFFE6D2BE).withValues(alpha: .85)
      : const Color(0xFF5A4637).withValues(alpha: .82);
  Color get _reed => isDark
      ? const Color(0xFFD2B48C).withValues(alpha: .4)
      : const Color(0xFF785A37).withValues(alpha: .5);
  Color get _sun => isDark ? const Color(0xFFF8C91C) : const Color(0xFFFFB877);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;

    _paintVerticalBase(
      canvas,
      size,
      isDark
          ? const [Color(0xFF000000), Color(0xFF0A1024), Color(0xFF16203F)]
          : const [
              Color(0xFFFFF7EF),
              Color(0xFFFFE1CB),
              Color(0xFFFFC9A3),
              Color(0xFFF7B183)
            ],
      isDark ? const [0, .55, 1] : const [0, .42, .76, 1],
    );
    // 落日方向的暖光
    final sunC = _ap(size, 70, 168);
    _paintRadialGlow(canvas, size, sunC, size.width * .52, _sun, isDark ? .38 : .95);

    // 低垂落日(呼吸)。半沉在地平雾里,但雾要压得住又盖不死
    final breathe = 1 + .03 * math.sin(t * math.pi * 2 * 3);
    canvas.drawCircle(sunC, _ax(size, 30) * breathe,
        Paint()..color = _sun.withValues(alpha: isDark ? .7 : 1));

    // 地平雾
    canvas.drawOval(
        Rect.fromCenter(
            center: _ap(size, 150, 198),
            width: _ax(size, 340),
            height: _ay(size, 26)),
        Paint()
          ..color = (isDark ? const Color(0xFF16203F) : Colors.white)
              .withValues(alpha: isDark ? .5 : .42));

    _paintReeds(canvas, size, t);
    _paintFlock(canvas, size, t, gy: .34, cycles: 1, phase: 0, scale: 1.35, count: 7);
    _paintFlock(canvas, size, t, gy: .56, cycles: 1, phase: .45, scale: .85, count: 5);

    if (isDark) {
      _paintTwinkles(canvas, size, t,
          color: Colors.white, seed: 103, count: 10, maxAlpha: .55);
    }
  }

  /// 底部芦苇:两端密、中段稀,随风摇。
  void _paintReeds(Canvas canvas, Size size, double t) {
    const xs = [12.0, 26.0, 40.0, 54.0, 250.0, 264.0, 278.0, 292.0];
    final u = (size.height / 208).clamp(.55, 1.0);
    final sp = Paint()
      ..color = _reed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * u
      ..strokeCap = StrokeCap.round;
    final fp = Paint()..color = _reed;
    for (int i = 0; i < xs.length; i++) {
      final sway = math.sin((t * 3 + i * .3) * math.pi * 2) * .05;
      final base = _ap(size, xs[i], 208);
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(sway);
      final h = _ay(size, 38);
      canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..cubicTo(2 * u, -h * .4, -1 * u, -h * .7, 3 * u, -h),
          sp);
      canvas.save();
      canvas.translate(3 * u, -h - 7 * u);
      canvas.rotate((i.isEven ? 8 : -8) * math.pi / 180);
      canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 9 * u, height: 20 * u), fp);
      canvas.restore();
      canvas.restore();
    }
  }

  /// 人字雁阵:整体横穿 + 每只翅膀各自扇动。
  void _paintFlock(Canvas canvas, Size size, double t,
      {required double gy,
      required int cycles,
      required double phase,
      required double scale,
      required int count}) {
    final p = (t * cycles + phase) % 1;
    final x = -size.width * .25 + size.width * 1.5 * p;
    final y = size.height * gy - size.height * .12 * p;
    final op = (p < .08 ? p / .08 : (p > .88 ? (1 - p) / .12 : 1)).clamp(0.0, 1.0);
    if (op <= .01) return;

    const v = [
      [0.0, 0.0],
      [-10.0, -5.0],
      [-20.0, -10.0],
      [-30.0, -15.0],
      [10.0, -5.0],
      [20.0, -10.0],
      [30.0, -15.0],
    ];
    final unit = _ax(size, 1) * scale;
    final paint = Paint()
      ..color = _goose.withValues(alpha: _goose.a * op)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < count && i < v.length; i++) {
      // 翅膀扇动:每只错相,频率取整数
      final flap = .55 + .6 * (.5 + .5 * math.sin((t * (26 + i) + i * .2) * math.pi * 2));
      final cx = x + v[i][0] * unit;
      final cy = y + v[i][1] * unit;
      final w = 4.6 * unit;
      canvas.drawPath(
          Path()
            ..moveTo(cx - w, cy)
            ..quadraticBezierTo(cx - w * .5, cy - 3.4 * unit * flap, cx, cy - .8 * unit)
            ..quadraticBezierTo(cx + w * .5, cy - 3.4 * unit * flap, cx + w, cy),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SouthboundPainter old) => old.isDark != isDark;
}

class _SouthboundTabDeco extends StatelessWidget {
  const _SouthboundTabDeco(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 22,
        painterFor: (a) => _SouthboundTabPainter(isDark, a),
        staticFrame: .4,
      );
}

class _SouthboundTabPainter extends CustomPainter {
  _SouthboundTabPainter(this.isDark, this.anim) : super(repaint: anim);
  final bool isDark;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final h = size.height, w = size.width;
    final goose = isDark
        ? const Color(0xFFE6D2BE).withValues(alpha: .8)
        : const Color(0xFF5A4637).withValues(alpha: .75);
    final reed = isDark
        ? const Color(0xFFD2B48C).withValues(alpha: .4)
        : const Color(0xFF785A37).withValues(alpha: .48);
    final sun = isDark ? const Color(0xFFF8C91C) : const Color(0xFFFFB877);

    // 右端落日
    canvas.drawCircle(Offset(w * .95, h * .28), h * .22,
        Paint()..color = sun.withValues(alpha: isDark ? .55 : .75));

    // 两支雁阵
    void flock(double gy, double phase, double scale, int count) {
      final p = (t + phase) % 1;
      final x = -w * .2 + w * 1.4 * p;
      final y = h * gy - h * .12 * p;
      final op = (p < .08 ? p / .08 : (p > .88 ? (1 - p) / .12 : 1)).clamp(0.0, 1.0);
      if (op <= .01) return;
      const v = [
        [0.0, 0.0],
        [-9.0, -4.5],
        [-18.0, -9.0],
        [9.0, -4.5],
        [18.0, -9.0],
      ];
      final unit = h * .036 * scale;
      final paint = Paint()
        ..color = goose.withValues(alpha: goose.a * op)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 * scale
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < count && i < v.length; i++) {
        final flap =
            .55 + .6 * (.5 + .5 * math.sin((t * (24 + i) + i * .2) * math.pi * 2));
        final cx = x + v[i][0] * unit, cy = y + v[i][1] * unit;
        final ww = 4.4 * unit;
        canvas.drawPath(
            Path()
              ..moveTo(cx - ww, cy)
              ..quadraticBezierTo(cx - ww * .5, cy - 3.2 * unit * flap, cx, cy - .8 * unit)
              ..quadraticBezierTo(cx + ww * .5, cy - 3.2 * unit * flap, cx + ww, cy),
            paint);
      }
    }

    flock(.34, 0, 1, 5);
    flock(.6, .5, .64, 3);

    // 底部芦苇(两端密)
    const xs = [.02, .07, .12, .17, .42, .55, .82, .88, .93, .97];
    final sp = Paint()
      ..color = reed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final fp = Paint()..color = reed;
    for (int i = 0; i < xs.length; i++) {
      final sway = math.sin((t * 6 + i * .35) * math.pi * 2) * .06;
      canvas.save();
      canvas.translate(w * xs[i], h);
      canvas.rotate(sway);
      final len = h * .46;
      canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..cubicTo(1.5, -len * .4, -1, -len * .7, 2.5, -len),
          sp);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(2.5, -len - h * .07), width: h * .1, height: h * .22),
          fp);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SouthboundTabPainter old) => old.isDark != isDark;
}
