part of '../header_skins.dart';

// ============ 冬日皮肤:初雪(First Snow) ============
//
// 冬日六款里唯一**跟随主题色**的基本款:今冬第一场雪,落在用户选的颜色上。
// 亮色 = 白雪叠主题色底(底透明,同 pattern 皮肤);暗色 = 偏淡主题色的雪叠纯黑。
// 设计稿:.docs/skin-designs/winter-skins.html 的「冬 · A」。
//
// 主角是一枚缓缓自转的六出冰晶(70s 一圈的气质,循环 24s 转一圈),
// 雪粒三层视差飘落,底部两层圆润雪坡;tab 签名是「雪帽盖住整条胶囊顶边」。

class _FirstSnowSkin extends StatelessWidget {
  const _FirstSnowSkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 24,
        painterFor: (a) => _FirstSnowPainter(primary, isDark, a),
      );
}

class _FirstSnowPainter extends CustomPainter {
  _FirstSnowPainter(this.primary, this.isDark, this.anim)
      : super(repaint: anim) {
    _dots = _makeSnowDots(seed: isDark ? 13 : 11, count: 22, speedBase: 2);
    _crystals = _makeFallingCrystals(
        seed: 5, count: 2, minSize: 9, maxSize: 13, speedBase: 2);
  }
  final Color primary;
  final bool isDark;
  final Animation<double> anim;
  late final List<_SnowDot> _dots;
  late final List<_FallingCrystal> _crystals;

  /// 雪色:亮 = 纯白(主题色底上天然成立);暗 = 主题色掺白(W1 的暗色版)。
  Color get _flake =>
      isDark ? Color.lerp(primary, Colors.white, .5)! : Colors.white;
  Color get _drift =>
      isDark ? Color.lerp(primary, Colors.white, .32)! : Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final k = (size.height / 208).clamp(.55, 1.0);

    // 底透明:亮色透出主题色底,暗色透出纯黑(同 pattern 皮肤的约定)。

    // 左下白色线稿大雪花(呼应主角,去脏原则 3 的线稿用法)
    _drawCrystal(canvas, _ap(size, 50, 172), 72 * k, .5,
        color: isDark
            ? Color.lerp(primary, Colors.white, .4)!.withValues(alpha: .14)
            : Colors.white.withValues(alpha: .3),
        strokeWidth: 1.6);

    // 底部两层雪坡
    final d1 = Path()
      ..moveTo(_ax(size, -10), _ay(size, 196))
      ..quadraticBezierTo(
          _ax(size, 60), _ay(size, 178), _ax(size, 130), _ay(size, 192))
      ..quadraticBezierTo(
          _ax(size, 200), _ay(size, 206), _ax(size, 310), _ay(size, 188))
      ..lineTo(_ax(size, 310), _ay(size, 208))
      ..lineTo(_ax(size, -10), _ay(size, 208))
      ..close();
    canvas.drawPath(
        d1, Paint()..color = _drift.withValues(alpha: isDark ? .09 : .55));
    final d2 = Path()
      ..moveTo(_ax(size, -10), _ay(size, 202))
      ..quadraticBezierTo(
          _ax(size, 90), _ay(size, 188), _ax(size, 170), _ay(size, 198))
      ..quadraticBezierTo(
          _ax(size, 250), _ay(size, 208), _ax(size, 310), _ay(size, 196))
      ..lineTo(_ax(size, 310), _ay(size, 208))
      ..lineTo(_ax(size, -10), _ay(size, 208))
      ..close();
    canvas.drawPath(
        d2, Paint()..color = _drift.withValues(alpha: isDark ? .16 : .95));

    // 主角冰晶:右侧安全区,一圈柔光,缓缓自转(一个循环恰好一圈,回绕无跳变)
    final hero = _ap(size, 240, 100);
    _paintRadialGlow(
        canvas, size, hero, 42 * k, Colors.white, isDark ? .12 : .5);
    _drawCrystal(canvas, hero, 65 * k, t * math.pi * 2,
        color: _flake, strokeWidth: 2);
    // 两枚小冰晶反向陪转
    _drawCrystal(canvas, _ap(size, 205, 150), 30 * k, -t * math.pi * 2 + .8,
        color: _flake, strokeWidth: 2.4, opacity: .65, fine: false);
    _drawCrystal(canvas, _ap(size, 286, 146), 19 * k, t * math.pi * 2 + 2.1,
        color: _flake, strokeWidth: 2.6, opacity: .55, fine: false);

    _paintFallingSnow(canvas, size, t, _dots,
        color: _flake, maxOpacity: isDark ? .8 : .95);
    _paintFallingCrystals(canvas, size, t, _crystals, color: _flake);
  }

  @override
  bool shouldRepaint(covariant _FirstSnowPainter old) =>
      old.isDark != isDark || old.primary != primary;
}

class _FirstSnowTabDeco extends StatelessWidget {
  const _FirstSnowTabDeco(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 10,
        painterFor: (a) => _FirstSnowTabPainter(primary, isDark, a),
      );
}

class _FirstSnowTabPainter extends CustomPainter {
  _FirstSnowTabPainter(this.primary, this.isDark, this.anim)
      : super(repaint: anim) {
    _dots = _makeSnowDots(
        seed: isDark ? 73 : 71, count: 4, minSize: 1.6, maxSize: 3.6);
  }
  final Color primary;
  final bool isDark;
  final Animation<double> anim;
  late final List<_SnowDot> _dots;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final flake = isDark
        ? Color.lerp(primary, Colors.white, .5)!
        : Color.lerp(primary, Colors.white, .3)!;

    // 签名:起伏的雪帽盖住整条胶囊顶边。
    // W1:白底 tab 上纯白雪帽会隐形,亮色雪帽掺一点主题色 + 投影色描边。
    final brimFill = Color.lerp(primary, Colors.white, isDark ? .55 : .88)!;
    final brimEdge = isDark
        ? Colors.black.withValues(alpha: .35)
        : Color.lerp(primary, Colors.white, .45)!;
    final hr = size.height / 47;
    final brim = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 3.5 * hr);
    const seg = 13;
    for (int i = seg; i > 0; i--) {
      final x2 = size.width * (i - 1) / seg;
      brim.quadraticBezierTo(
          size.width * (i - .5) / seg,
          (8.5 + (i % 3) * 1.8) * hr,
          x2,
          (3.2 + (i % 2) * 1.6) * hr);
    }
    brim.close();
    canvas.drawPath(brim, Paint()..color = brimFill);
    canvas.drawPath(
        brim,
        Paint()
          ..color = brimEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8);

    // 两枚小冰晶飘落穿过胶囊
    for (final c in const [(.3, 9.0, 0.0), (.6, 7.0, .45)]) {
      final p = (t + c.$3) % 1;
      final y = -c.$2 + (size.height + c.$2 * 2) * p;
      final x = size.width * c.$1 +
          math.sin((t * 2 + c.$3) * math.pi * 2) * size.width * .02;
      _drawCrystal(canvas, Offset(x, y), c.$2, (t + c.$3) * math.pi * 2,
          color: flake, strokeWidth: 2.6, opacity: .9, fine: false);
    }

    // 右端一枚小冰晶慢转
    _drawCrystal(canvas, Offset(size.width - 14, size.height - 11), 13,
        t * math.pi * 2,
        color: flake, strokeWidth: 2.4, opacity: .75, fine: false);

    // 光点明灭
    for (final g in const [(.14, 30.0, 2), (.48, 34.0, 3), (.82, 28.0, 2)]) {
      final wave = .5 + .5 * math.sin(t * math.pi * 2 * g.$3 + g.$1 * 9);
      canvas.drawCircle(Offset(size.width * g.$1, g.$2 * hr), 1.1,
          Paint()..color = flake.withValues(alpha: .15 + wave * .75));
    }

    _paintFallingSnow(canvas, size, t, _dots,
        color: isDark ? Colors.white : flake, maxOpacity: .85);
  }

  @override
  bool shouldRepaint(covariant _FirstSnowTabPainter old) =>
      old.isDark != isDark || old.primary != primary;
}
