part of '../header_skins.dart';

// ============ 秋日 · 落叶引擎 ============
//
// 枫叶清秋 / 银杏金秋 / 柿柿如意 / 秋雨梧桐 四款共用的叶形与飘落。
// 桂月中秋和雁阵南飞画的是月夜与雁群,不落叶,所以不引这个文件 ——
// 拆开是为了让每款皮肤只带自己用得上的代码,单独成支时不留「未使用」告警。
//
// 通用基座(坐标换算 `_ax/_ay/_ap`、动画骨架 `_AnimSkinShell`/`_AnimTabShell`、
// 纵向渐变底、径向柔光)在 skin_common.dart —— 那些周年皮肤也在用,不是秋日专有。
//
// 设计稿见 .docs/skin-designs/autumn-skins.html,那份 HTML 是规格来源,
// 坐标体系(viewBox 0 0 300 208)与 `_ax/_ay` 换算一一对应。
//
// 「去脏五原则」(设计稿顶部有卡片版,实装同样适用):
//   1 底色高明度低饱和  2 只用两种高纯度色  3 不用半透明大色块(改线稿)
//   4 加白描边与叶脉    5 留白 >= 40%
// ---------------- 叶形 ----------------
// 三种叶形都在 48×48 的局部坐标里定义,画的时候平移缩放。
// 形状经过小尺寸可辨认性验证(见设计稿 README 的「叶形」条):
// 枫叶必须**深凹陷**否则像星星;银杏顶边必须**外凸**否则像蝙蝠翅膀;
// 复杂掌状叶(梧桐)在小尺寸下不可靠,统一用简洁尖叶。

enum _LeafKind { maple, ginkgo, pointed }

Path _leafPath(_LeafKind kind) {
  switch (kind) {
    case _LeafKind.maple:
      // 五裂掌状,凹陷深到接近叶柄(加拿大枫比例)
      return Path()
        ..moveTo(24, 46)
        ..lineTo(24, 33)
        ..quadraticBezierTo(20, 33.5, 16.5, 32.5)
        ..quadraticBezierTo(8.5, 30.5, 2, 26)
        ..quadraticBezierTo(7.5, 24, 13, 22.5)
        ..quadraticBezierTo(9, 16, 8, 9)
        ..quadraticBezierTo(14, 12, 19.5, 15.5)
        ..quadraticBezierTo(21, 9, 24, 3)
        ..quadraticBezierTo(27, 9, 28.5, 15.5)
        ..quadraticBezierTo(34, 12, 40, 9)
        ..quadraticBezierTo(39, 16, 35, 22.5)
        ..quadraticBezierTo(40.5, 24, 46, 26)
        ..quadraticBezierTo(39.5, 30.5, 31.5, 32.5)
        ..quadraticBezierTo(28, 33.5, 24, 33)
        ..close();
    case _LeafKind.ginkgo:
      // 扇形:顶边外凸 + 中央一道浅裂 + 细长柄
      return Path()
        ..moveTo(24, 45)
        ..lineTo(22.6, 31)
        ..cubicTo(14, 30, 4, 24, 2.5, 12)
        ..cubicTo(8, 6, 15, 3, 22, 4.5)
        ..lineTo(24, 9.5)
        ..lineTo(26, 4.5)
        ..cubicTo(33, 3, 40, 6, 45.5, 12)
        ..cubicTo(44, 24, 34, 30, 25.4, 31)
        ..close();
    case _LeafKind.pointed:
      // 简洁尖叶(柿叶 / 梧桐通用),小尺寸下最可靠
      return Path()
        ..moveTo(24, 2)
        ..cubicTo(37, 13, 41, 30, 24, 46)
        ..cubicTo(7, 30, 11, 13, 24, 2)
        ..close();
  }
}

/// 叶脉(与叶形配套,提升精致度 —— 去脏原则 4)
Path _leafVeins(_LeafKind kind) {
  final p = Path();
  switch (kind) {
    case _LeafKind.maple:
      p
        ..moveTo(24, 44)
        ..lineTo(24, 8)
        ..moveTo(24, 20)
        ..lineTo(11, 11)
        ..moveTo(24, 20)
        ..lineTo(37, 11)
        ..moveTo(24, 28)
        ..lineTo(6.5, 24)
        ..moveTo(24, 28)
        ..lineTo(41.5, 24);
    case _LeafKind.ginkgo:
      // 放射状平行脉是银杏最强的辨识特征
      p.moveTo(24, 44);
      p.lineTo(24, 30);
      for (final e in const [
        [6.0, 14.0],
        [12.0, 6.5],
        [21.0, 5.5],
        [27.0, 5.5],
        [36.0, 6.5],
        [42.0, 14.0],
      ]) {
        p.moveTo(24, 30);
        p.lineTo(e[0], e[1]);
      }
    case _LeafKind.pointed:
      p.moveTo(24, 4);
      p.lineTo(24, 45);
      for (final y in const [14.0, 24.0, 34.0]) {
        p.moveTo(24, y);
        p.lineTo(24 - (38 - y) * .32, y - 2);
        p.moveTo(24, y);
        p.lineTo(24 + (38 - y) * .32, y - 2);
      }
  }
  return p;
}

/// 画一片叶:kind 形状、size 边长(pt)、center 中心、rotation 弧度。
void _drawLeaf(
  Canvas canvas,
  _LeafKind kind,
  Offset center,
  double size,
  double rotation, {
  required Color fill,
  Color? vein,
  double opacity = 1,
}) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(rotation);
  final k = size / 48;
  canvas.scale(k);
  canvas.translate(-24, -24);
  canvas.drawPath(_leafPath(kind), Paint()..color = fill.withValues(alpha: opacity));
  if (vein != null && size >= 12) {
    canvas.drawPath(
      _leafVeins(kind),
      Paint()
        ..color = vein.withValues(alpha: opacity * .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * (48 / size).clamp(.6, 1.6)
        ..strokeCap = StrokeCap.round,
    );
  }
  canvas.restore();
}

/// 一片飘落叶的参数(固定种子生成,布局稳定)。
class _FallingLeaf {
  const _FallingLeaf({
    required this.kind,
    required this.size,
    required this.xRatio,
    required this.phase,
    required this.speed,
    required this.swayFreq,
    required this.spinFreq,
    required this.colorIndex,
  });
  final _LeafKind kind;
  final double size;
  final double xRatio;
  final double phase;

  /// 每个循环下落几次(整数,保证回绕无跳变)
  final int speed;
  final int swayFreq;
  final int spinFreq;
  final int colorIndex;
}

/// 生成一组飘落叶:大小差异拉开(去脏原则 5:少而精)。
List<_FallingLeaf> _makeFallingLeaves({
  required int seed,
  required int count,
  required List<_LeafKind> kinds,
  required int colorCount,
  double minSize = 20,
  double maxSize = 46,
}) {
  final rnd = math.Random(seed);
  return List.generate(count, (i) {
    final t = count == 1 ? 0.0 : i / (count - 1);
    // 大小按序列拉开而不是纯随机,避免一堆同尺寸
    final size = maxSize - (maxSize - minSize) * ((i * 0.37 + t) % 1);
    return _FallingLeaf(
      kind: kinds[i % kinds.length],
      size: size,
      xRatio: (i + 0.5) / count + (rnd.nextDouble() - .5) * .12,
      phase: rnd.nextDouble(),
      speed: 1 + (i % 2),
      swayFreq: 3 + rnd.nextInt(3),
      spinFreq: 1 + rnd.nextInt(2),
      colorIndex: i % colorCount,
    );
  });
}

/// 绘制飘落叶群。t 为 0..1 的循环进度。
void _paintFallingLeaves(
  Canvas canvas,
  Size size,
  double t,
  List<_FallingLeaf> leaves, {
  required List<Color> palette,
  Color? vein,
  double maxOpacity = .95,
}) {
  for (final l in leaves) {
    final p = (t * l.speed + l.phase) % 1;
    // 从上方进场、下方出画;首尾淡入淡出
    final y = -l.size + (size.height + l.size * 2) * p;
    final swayX = math.sin((t * l.swayFreq + l.phase) * math.pi * 2) * (size.width * .04);
    final x = size.width * l.xRatio.clamp(0.02, 0.98) + swayX;
    final op = maxOpacity *
        (p < .08 ? p / .08 : (p > .9 ? (1 - p) / .1 : 1)).clamp(0.0, 1.0);
    if (op <= 0.01) continue;
    _drawLeaf(
      canvas,
      l.kind,
      Offset(x, y),
      l.size,
      (t * l.spinFreq + l.phase) * math.pi * 2,
      fill: palette[l.colorIndex % palette.length],
      vein: vein,
      opacity: op,
    );
  }
}
