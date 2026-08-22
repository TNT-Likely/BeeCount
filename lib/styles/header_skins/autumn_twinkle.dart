part of '../header_skins.dart';

// ============ 秋日 · 明灭光点 ============
//
// 桂月中秋(月下星尘)与雁阵南飞(暮色光斑)专用。曾经放在 skin_common.dart,
// 但周年皮肤并不用它 —— 那是秋日专有,挪到这里,免得公共基座越长越杂。
/// 明灭光点(星尘 / 光斑通用)。频率取整数 —— 取小数的话多个点的周期永远对不齐,
/// 整片光点会显得毫无节奏。
///
/// 只有桂月中秋(月下星尘)和雁阵南飞(暮色光斑)用它,所以住在秋日专有文件里,
/// 不在 skin_common.dart。
void _paintTwinkles(
  Canvas canvas,
  Size size,
  double t, {
  required Color color,
  int seed = 14,
  int count = 22,
  double minR = .8,
  double maxR = 2.2,
  double maxAlpha = .8,
}) {
  final rnd = math.Random(seed);
  for (int i = 0; i < count; i++) {
    final x = rnd.nextDouble() * size.width;
    final y = rnd.nextDouble() * size.height;
    final r = minR + rnd.nextDouble() * (maxR - minR);
    final freq = 2 + rnd.nextInt(3);
    final phase = rnd.nextDouble() * math.pi * 2;
    final wave = .5 + .5 * math.sin(t * math.pi * 2 * freq + phase);
    canvas.drawCircle(Offset(x, y), r,
        Paint()..color = color.withValues(alpha: .06 + wave * maxAlpha));
  }
}
