part of '../header_skins.dart';

// ============ 秋日皮肤:枫叶清秋(Maple) ============
//
// 固定枫色(不跟随主题色):暖白的天、两种颜色的枫叶慢慢转着落下、一道白风线。
// 设计稿:.docs/skin-designs/autumn-skins.html 的「秋 · B」。
//
// 「干净」是这一款的核心诉求(初版被评价「脏」),做法见 autumn_common.dart 顶部
// 的去脏五原则:底色暖白而非深橙、叶子只用枫红 + 金黄两色、背景用线稿而非
// 半透明色块、每片叶带白叶脉、底部叶堆是清晰剪影。

const Color _kMapleRedL = Color(0xFFE0451F);
const Color _kMapleRedD = Color(0xFFF4643C);
const Color _kMapleGoldL = Color(0xFFF5A623);
const Color _kMapleGoldD = Color(0xFFFFC24D);

class _MapleSkin extends StatelessWidget {
  const _MapleSkin(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 14,
        painterFor: (a) => _MaplePainter(isDark, a),
      );
}

class _MaplePainter extends CustomPainter {
  _MaplePainter(this.isDark, this.anim) : super(repaint: anim) {
    _leaves = _makeFallingLeaves(
      seed: 41,
      count: 5,
      kinds: const [_LeafKind.maple, _LeafKind.maple, _LeafKind.ginkgo],
      colorCount: 2,
      minSize: 20,
      maxSize: 46,
    );
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_FallingLeaf> _leaves;

  List<Color> get _palette =>
      isDark ? const [_kMapleRedD, _kMapleGoldD] : const [_kMapleRedL, _kMapleGoldL];
  Color get _vein =>
      isDark ? Colors.black.withValues(alpha: .5) : Colors.white.withValues(alpha: .85);
  Color get _line => isDark
      ? const Color(0xFFFFC24D).withValues(alpha: .26)
      : const Color(0xFFE0451F).withValues(alpha: .42);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;

    _paintVerticalBase(
      canvas,
      size,
      isDark
          ? const [Color(0xFF000000), Color(0xFF160A02)]
          : const [Color(0xFFFFFCF5), Color(0xFFFFF0DA), Color(0xFFFFE3BE)],
      isDark ? null : const [0, .55, 1],
    );

    // 背景大枫叶线稿(去脏原则 3:线稿代替半透明色块),落在右侧安全区
    final scale = (size.height / 208).clamp(.5, 1.0);
    _paintOutlineLeaf(canvas, _ap(size, 240, 116), 90 * scale, .35);

    // 底部清晰叶剪影
    _paintLeafPile(canvas, size, _LeafKind.maple,
        palette: _palette, opacity: isDark ? .2 : .16);

    // 一道缓慢横移的风线
    final drift = ((t * 1) % 1) * size.width * 1.3 - size.width * .15;
    final wind = Path()
      ..moveTo(drift - size.width * .1, _ay(size, 168))
      ..cubicTo(drift + size.width * .1, _ay(size, 158), drift + size.width * .22,
          _ay(size, 176), drift + size.width * .42, _ay(size, 166));
    canvas.drawPath(
        wind,
        Paint()
          ..color = _line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round);

    _paintFallingLeaves(canvas, size, t, _leaves,
        palette: _palette, vein: _vein, maxOpacity: isDark ? .82 : .95);
  }

  void _paintOutlineLeaf(Canvas canvas, Offset center, double sz, double rot) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rot);
    canvas.scale(sz / 48);
    canvas.translate(-24, -24);
    canvas.drawPath(
        _leafPath(_LeafKind.maple),
        Paint()
          ..color = _line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * 48 / sz
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaplePainter old) => old.isDark != isDark;
}

class _MapleTabDeco extends StatelessWidget {
  const _MapleTabDeco(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 9,
        painterFor: (a) => _MapleTabPainter(isDark, a),
      );
}

class _MapleTabPainter extends CustomPainter {
  _MapleTabPainter(this.isDark, this.anim) : super(repaint: anim);
  final bool isDark;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final palette = isDark
        ? const [_kMapleRedD, _kMapleGoldD]
        : const [_kMapleRedL, _kMapleGoldL];
    final vein =
        isDark ? Colors.black.withValues(alpha: .45) : Colors.white.withValues(alpha: .8);
    // 左端伸入的细枝
    final branch = Path()
      ..moveTo(-size.width * .02, size.height * .08)
      ..cubicTo(size.width * .05, size.height * .16, size.width * .1,
          size.height * .3, size.width * .15, size.height * .45);
    canvas.drawPath(
        branch,
        Paint()
          ..color = (isDark ? const Color(0xFFB98A4A) : const Color(0xFF7A4A1E))
              .withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round);
    _paintTabLeafScene(canvas, size, anim.value,
        kind: _LeafKind.maple,
        palette: palette,
        vein: vein,
        cornerOpacity: isDark ? .42 : .5,
        pileOpacity: isDark ? .24 : .3);
  }

  @override
  bool shouldRepaint(covariant _MapleTabPainter old) => old.isDark != isDark;
}
