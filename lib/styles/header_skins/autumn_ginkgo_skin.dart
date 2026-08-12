part of '../header_skins.dart';

// ============ 秋日皮肤:银杏金秋(Ginkgo Gold) ============
//
// 固定单色金黄。「全屏只有一个色相,靠明度分层次」—— 六款秋日里最干净的一款,
// 而金黄正是 BeeCount 的品牌色。设计稿:autumn-skins.html 的「秋 · D」。
//
// 单色相的陷阱是「叶子融进底色」:底色必须提到接近白、叶子用饱和金橙,
// 把明度差拉开(初版亮色就栽在这里)。

const List<Color> _kGinkgoTonesL = [
  Color(0xFFE8890B),
  Color(0xFFF5A623),
  Color(0xFFD97706),
];
const List<Color> _kGinkgoTonesD = [
  Color(0xFFFFC94D),
  Color(0xFFF8C91C),
  Color(0xFFD9A00C),
];

class _GinkgoSkin extends StatelessWidget {
  const _GinkgoSkin(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimSkinShell(
        seconds: 14,
        painterFor: (a) => _GinkgoPainter(isDark, a),
      );
}

class _GinkgoPainter extends CustomPainter {
  _GinkgoPainter(this.isDark, this.anim) : super(repaint: anim) {
    _leaves = _makeFallingLeaves(
      seed: 71,
      count: 5,
      kinds: const [_LeafKind.ginkgo],
      colorCount: 3,
      minSize: 22,
      maxSize: 44,
    );
  }
  final bool isDark;
  final Animation<double> anim;
  late final List<_FallingLeaf> _leaves;

  List<Color> get _palette => isDark ? _kGinkgoTonesD : _kGinkgoTonesL;
  Color get _vein => isDark
      ? Colors.black.withValues(alpha: .42)
      : const Color(0xFFFFFAEB).withValues(alpha: .9);
  Color get _line => isDark
      ? const Color(0xFFF8C91C).withValues(alpha: .2)
      : const Color(0xFFD97706).withValues(alpha: .22);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;

    _paintVerticalBase(
      canvas,
      size,
      isDark
          ? const [Color(0xFF000000), Color(0xFF181000)]
          : const [Color(0xFFFFFEFA), Color(0xFFFFF8E2), Color(0xFFFFEDBC)],
      isDark ? null : const [0, .55, 1],
    );

    // 阳光斑驳:三块柔光缓慢游移(频率整数,回绕无跳变)
    const spots = [
      [.2, .34, .26],
      [.66, .74, .19],
      [.9, .24, .14],
    ];
    for (int i = 0; i < spots.length; i++) {
      final s = spots[i];
      final drift = math.sin((t * (1 + i) + i * .3) * math.pi * 2);
      final c = Offset(size.width * s[0] + drift * 10, size.height * s[1] - drift * 6);
      _paintRadialGlow(canvas, size, c, size.width * s[2],
          isDark ? const Color(0xFFF8C91C) : Colors.white, isDark ? .16 : .55);
    }

    // 背景大扇叶线稿 ×2
    final scale = (size.height / 208).clamp(.5, 1.0);
    _outline(canvas, _ap(size, 242, 112), 106 * scale, .31, 1);
    _outline(canvas, _ap(size, 46, 166), 72 * scale, -.45, .7);

    _paintLeafPile(canvas, size, _LeafKind.ginkgo,
        palette: _palette, opacity: isDark ? .22 : .18);

    _paintFallingLeaves(canvas, size, t, _leaves,
        palette: _palette, vein: _vein, maxOpacity: isDark ? .85 : .95);
  }

  void _outline(Canvas canvas, Offset center, double sz, double rot, double opFactor) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rot);
    canvas.scale(sz / 48);
    canvas.translate(-24, -24);
    canvas.drawPath(
        _leafPath(_LeafKind.ginkgo),
        Paint()
          ..color = _line.withValues(alpha: _line.a * opFactor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3 * 48 / sz);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GinkgoPainter old) => old.isDark != isDark;
}

class _GinkgoTabDeco extends StatelessWidget {
  const _GinkgoTabDeco(this.isDark);
  final bool isDark;

  @override
  Widget build(BuildContext context) => _AnimTabShell(
        seconds: 9,
        painterFor: (a) => _GinkgoTabPainter(isDark, a),
      );
}

class _GinkgoTabPainter extends CustomPainter {
  _GinkgoTabPainter(this.isDark, this.anim) : super(repaint: anim);
  final bool isDark;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    // 一块缓慢游移的光斑
    final drift = math.sin(t * math.pi * 2);
    _paintRadialGlow(
        canvas,
        size,
        Offset(size.width * (.5 + drift * .12), size.height * .5),
        size.height * 1.6,
        isDark ? const Color(0xFFF8C91C) : Colors.white,
        isDark ? .1 : .4);
    _paintTabLeafScene(canvas, size, t,
        kind: _LeafKind.ginkgo,
        palette: isDark ? _kGinkgoTonesD : _kGinkgoTonesL,
        vein: isDark
            ? Colors.black.withValues(alpha: .4)
            : Colors.white.withValues(alpha: .8),
        cornerOpacity: isDark ? .42 : .5,
        pileOpacity: isDark ? .24 : .3);
  }

  @override
  bool shouldRepaint(covariant _GinkgoTabPainter old) => old.isDark != isDark;
}
