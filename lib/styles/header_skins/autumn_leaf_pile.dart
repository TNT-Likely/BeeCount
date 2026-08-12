part of '../header_skins.dart';

// ============ 秋日 · 落叶堆与 tab 落叶场景 ============
//
// 只有枫叶清秋和银杏金秋用:这两款的构图是「树下积了一地叶」,
// 柿柿如意(枝头柿子)和秋雨梧桐(雨中梧桐)没有这个层次。
// 依赖 autumn_leaves.dart 的 `_drawLeaf`。
/// 底部落叶堆:清晰剪影(不是半透明糊团 —— 去脏原则 3/5)。
void _paintLeafPile(
  Canvas canvas,
  Size size,
  _LeafKind kind, {
  required List<Color> palette,
  double opacity = .18,
  int count = 7,
}) {
  final rnd = math.Random(31);
  for (int i = 0; i < count; i++) {
    final x = size.width * ((i + .5) / count) + (rnd.nextDouble() - .5) * 14;
    final y = size.height - 4 + (i.isEven ? 0 : 4);
    _drawLeaf(
      canvas,
      kind,
      Offset(x, y),
      size.height * (.11 + (i % 3) * .02),
      ((i * 67) % 100 - 50) * math.pi / 180,
      fill: palette[i % palette.length],
      opacity: opacity,
    );
  }
}
/// tab 装饰的通用构件:两端大叶 + 底部堆叠 + 飘落 + 光点。
/// 大元素透明度压到 .45~.55,保证不干扰图标点按。
void _paintTabLeafScene(
  Canvas canvas,
  Size size,
  double t, {
  required _LeafKind kind,
  required List<Color> palette,
  Color? vein,
  double cornerOpacity = .5,
  double pileOpacity = .3,
}) {
  final h = size.height;
  // 左右两端大叶(半出画)
  _drawLeaf(canvas, kind, Offset(size.width * .02, h * .1), h * .8, -.38,
      fill: palette[0], vein: vein, opacity: cornerOpacity);
  _drawLeaf(canvas, kind, Offset(size.width * .965, h * .92), h * .5, .7,
      fill: palette[1 % palette.length], vein: vein, opacity: cornerOpacity * .9);
  // 底部堆叠
  final rnd = math.Random(17);
  for (int i = 0; i < 11; i++) {
    final x = size.width * ((i + .5) / 11) + (rnd.nextDouble() - .5) * 10;
    _drawLeaf(canvas, kind, Offset(x, h * (.92 + (i % 3) * .05)), h * (.26 + (i % 4) * .05),
        ((i * 71) % 120 - 60) * math.pi / 180,
        fill: palette[i % palette.length], opacity: pileOpacity);
  }
  // 飘落 3 片
  for (int i = 0; i < 3; i++) {
    final p = (t * (1 + i % 2) + i * .37) % 1;
    final x = size.width * (.3 + i * .22);
    final y = -h * .3 + (h * 1.6) * p;
    final op = (p < .1 ? p / .1 : (p > .85 ? (1 - p) / .15 : 1)).clamp(0.0, 1.0);
    _drawLeaf(canvas, kind, Offset(x, y), h * (.3 - i * .04),
        (t * 2 + i) * math.pi * 2,
        fill: palette[i % palette.length], vein: vein, opacity: op * .85);
  }
}
