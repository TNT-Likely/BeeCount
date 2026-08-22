part of '../header_skins.dart';

// ============ 冬日 · 落雪引擎 ============
//
// 冬日六款(初雪 / 踏雪寻梅 / 雪夜灯火 / 围炉煮茶 / 冰晶初凝 / 日照金山)共用的
// 雪粒、六出冰晶、雪帽与星闪。通用基座(坐标换算 `_ax/_ay/_ap`、动画骨架
// `_AnimSkinShell`/`_AnimTabShell`、纵向渐变底、径向柔光)在 skin_common.dart。
//
// 设计稿:.docs/skin-designs/winter-skins.html —— 那份 HTML 是规格来源,
// 坐标体系(viewBox 0 0 300 208)与 `_ax/_ay` 换算一一对应。
//
// 冬日五原则(设计稿顶部有卡片版,实装同样适用):
//   W1 亮色底不用纯白,雪才有形     W2 每案藏一处暖(窗光 / 梅红 / 蜜金 / 金顶)
//   W3 远景雪 = 圆点视差,主角雪 = 程序生成六出冰晶
//   W4 积雪是有厚度的雪帽(圆润曲线 + 投影蓝),不是一条白线
//   W5 粒子 ≤50 / 不用 blur / 周期频率取整数 / 尊重减弱动态

// ---------------- 六出冰晶 ----------------
// 在 48×48 的局部坐标(中心为原点)里程序生成:六重对称 + 主脉 + 两级分枝 +
// 中心六棱环。fine 版多一层臂尖分叉,给主角用;简版给小尺寸飘落用 ——
// 小于 ~14pt 时臂尖分叉会糊成毛边。

Path _buildCrystalPath({required bool fine}) {
  final path = Path();
  // 中心六棱环
  for (int i = 0; i < 6; i++) {
    final a = (i * 60 - 90) * math.pi / 180;
    final x = 3.4 * math.cos(a), y = 3.4 * math.sin(a);
    i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
  }
  path.close();
  // 六臂
  for (int i = 0; i < 6; i++) {
    final rot = i * math.pi / 3;
    final cos = math.cos(rot), sin = math.sin(rot);
    void seg(double x1, double y1, double x2, double y2) {
      path.moveTo(x1 * cos - y1 * sin, x1 * sin + y1 * cos);
      path.lineTo(x2 * cos - y2 * sin, x2 * sin + y2 * cos);
    }

    seg(0, 3.4, 0, fine ? 21 : 20);
    seg(0, 9, 4.4, 13.4);
    seg(0, 9, -4.4, 13.4);
    seg(0, 14.6, 3.2, 17.8);
    seg(0, 14.6, -3.2, 17.8);
    if (fine) {
      seg(0, 21, 2, 23.6);
      seg(0, 21, -2, 23.6);
    }
  }
  return path;
}

final Path _kCrystalFine = _buildCrystalPath(fine: true);
final Path _kCrystalSimple = _buildCrystalPath(fine: false);

/// 画一枚冰晶:size 为直径(pt),strokeWidth 用局部坐标(48 盒)计,随缩放走。
/// [core] 非空时叠一层细的芯线(冰晶初凝的「蓝骨 + 白芯」质感)。
void _drawCrystal(
  Canvas canvas,
  Offset center,
  double size,
  double rotation, {
  required Color color,
  double strokeWidth = 2,
  double opacity = 1,
  Color? core,
  bool fine = true,
}) {
  if (opacity <= .01 || size <= 2) return;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(rotation);
  canvas.scale(size / 48);
  final path = fine ? _kCrystalFine : _kCrystalSimple;
  // 与调用方预设的透明度**相乘**而非覆盖(线稿雪花靠预设 alpha 变淡)。
  canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: color.a * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round);
  if (core != null) {
    canvas.drawPath(
        path,
        Paint()
          ..color = core.withValues(alpha: core.a * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * .4
          ..strokeCap = StrokeCap.round);
  }
  canvas.restore();
}

// ---------------- 雪粒(远景,三层视差) ----------------

/// 一粒雪的参数(固定种子生成,布局稳定)。
class _SnowDot {
  const _SnowDot({
    required this.xRatio,
    required this.size,
    required this.speed,
    required this.swayFreq,
    required this.phase,
    required this.opacity,
  });
  final double xRatio;
  final double size;

  /// 每个循环下落几次(整数,保证回绕无跳变);大雪近、落得快 = 视差。
  final int speed;
  final int swayFreq;
  final double phase;
  final double opacity;
}

List<_SnowDot> _makeSnowDots({
  required int seed,
  required int count,
  double minSize = 1.6,
  double maxSize = 4.4,
  int speedBase = 1,
  double xMinRatio = 0,
  double xMaxRatio = 1,
}) {
  final rnd = math.Random(seed);
  return List.generate(count, (i) {
    final u = rnd.nextDouble();
    return _SnowDot(
      xRatio: xMinRatio + rnd.nextDouble() * (xMaxRatio - xMinRatio),
      size: minSize + (maxSize - minSize) * u,
      speed: speedBase + (u * 2).round(),
      swayFreq: 2 + rnd.nextInt(3),
      phase: rnd.nextDouble(),
      opacity: .55 + rnd.nextDouble() * .45,
    );
  });
}

void _paintFallingSnow(
  Canvas canvas,
  Size size,
  double t,
  List<_SnowDot> dots, {
  required Color color,
  double maxOpacity = 1,
}) {
  final paint = Paint();
  for (final d in dots) {
    final p = (t * d.speed + d.phase) % 1;
    final y = -d.size * 2 + (size.height + d.size * 4) * p;
    final x = size.width * d.xRatio +
        math.sin((t * d.swayFreq + d.phase) * math.pi * 2) * size.width * .03;
    final fade =
        (p < .08 ? p / .08 : (p > .9 ? (1 - p) / .1 : 1.0)).clamp(0.0, 1.0);
    final op = maxOpacity * d.opacity * fade;
    if (op <= .02) continue;
    paint.color = color.withValues(alpha: op);
    canvas.drawCircle(Offset(x, y), d.size / 2, paint);
  }
}

// ---------------- 飘落的小冰晶(主角雪,摆动 + 自旋) ----------------

class _FallingCrystal {
  const _FallingCrystal({
    required this.size,
    required this.xRatio,
    required this.speed,
    required this.swayFreq,
    required this.spinFreq,
    required this.phase,
  });
  final double size;
  final double xRatio;
  final int speed;
  final int swayFreq;
  final int spinFreq;
  final double phase;
}

List<_FallingCrystal> _makeFallingCrystals({
  required int seed,
  required int count,
  double minSize = 9,
  double maxSize = 14,
  int speedBase = 1,
}) {
  final rnd = math.Random(seed);
  return List.generate(count, (i) {
    final t = count == 1 ? 0.0 : i / (count - 1);
    return _FallingCrystal(
      size: maxSize - (maxSize - minSize) * t,
      xRatio: .18 + t * .58 + (rnd.nextDouble() - .5) * .1,
      speed: speedBase + (i % 2),
      swayFreq: 2 + rnd.nextInt(2),
      spinFreq: 1 + (i % 2),
      phase: rnd.nextDouble(),
    );
  });
}

void _paintFallingCrystals(
  Canvas canvas,
  Size size,
  double t,
  List<_FallingCrystal> crystals, {
  required Color color,
  double maxOpacity = .92,
}) {
  for (final c in crystals) {
    final p = (t * c.speed + c.phase) % 1;
    final y = -c.size + (size.height + c.size * 2) * p;
    final x = size.width * c.xRatio.clamp(.03, .97) +
        math.sin((t * c.swayFreq + c.phase) * math.pi * 2) * size.width * .035;
    final fade =
        (p < .08 ? p / .08 : (p > .9 ? (1 - p) / .1 : 1.0)).clamp(0.0, 1.0);
    _drawCrystal(canvas, Offset(x, y), c.size,
        (t * c.spinFreq + c.phase) * math.pi * 2,
        color: color,
        strokeWidth: 2.4,
        opacity: maxOpacity * fade,
        fine: false);
  }
}

// ---------------- 雪帽(W4:有厚度的积雪) ----------------

/// 在 [center] 处盖一顶半宽 [w] 的雪帽:圆润的双峰曲线 + 可选投影色描边。
void _paintSnowCap(
  Canvas canvas,
  Offset center,
  double w, {
  required Color fill,
  Color? edge,
  double rotDeg = 0,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(rotDeg * math.pi / 180);
  final path = Path()
    ..moveTo(-w, 0)
    ..quadraticBezierTo(-w * .5, -w * .58, 0, -w * .3)
    ..quadraticBezierTo(w * .5, -w * .62, w, 0)
    ..quadraticBezierTo(0, w * .18, -w, 0)
    ..close();
  canvas.drawPath(path, Paint()..color = fill);
  if (edge != null) {
    canvas.drawPath(
        path,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7);
  }
  canvas.restore();
}

// ---------------- 星闪(雪夜灯火 / 日照金山的夜空) ----------------

/// 明灭星点。频率取整数,理由同秋日 twinkle:小数频率对不齐周期。
/// [maxYRatio] 限制星星只出现在画面上部(别落到雪地里)。
void _paintNightStars(
  Canvas canvas,
  Size size,
  double t, {
  required Color color,
  int seed = 7,
  int count = 12,
  double maxYRatio = .55,
  double minR = .7,
  double maxR = 1.8,
  double maxAlpha = .85,
}) {
  final rnd = math.Random(seed);
  for (int i = 0; i < count; i++) {
    final x = rnd.nextDouble() * size.width;
    final y = (0.03 + rnd.nextDouble() * (maxYRatio - .03)) * size.height;
    final r = minR + rnd.nextDouble() * (maxR - minR);
    final freq = 2 + rnd.nextInt(3);
    final phase = rnd.nextDouble() * math.pi * 2;
    final wave = .5 + .5 * math.sin(t * math.pi * 2 * freq + phase);
    canvas.drawCircle(Offset(x, y), r,
        Paint()..color = color.withValues(alpha: .06 + wave * maxAlpha));
  }
}

// ---------------- 设计稿坐标折线 ----------------

/// 按设计稿坐标(300×208)连一条闭合折线(山 / 地面剪影用)。
Path _polyPath(Size s, List<List<double>> pts) {
  final p = Path()..moveTo(_ax(s, pts[0][0]), _ay(s, pts[0][1]));
  for (int i = 1; i < pts.length; i++) {
    p.lineTo(_ax(s, pts[i][0]), _ay(s, pts[i][1]));
  }
  return p..close();
}
