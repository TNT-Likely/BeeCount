part of '../header_skins.dart';

/// Page scenes are independent of business content and never reserve space.
enum HeaderSkinPageRole { home, profile, detail }

@immutable
class HeaderSkinPageLayout {
  const HeaderSkinPageLayout({this.topInset = 0, this.card});
  final double topInset;
  final Rect? card;
}

Offset headerSkinPageAnchor(
        Size size, HeaderSkinPageRole role, HeaderSkinPageLayout layout,
        {bool cake = false}) =>
    Offset(size.width * .8,
        (layout.card?.top ?? layout.topInset + 78) + (cake ? 124 : 119));

/// The original free figures and animation, carried by the entire page rather
/// than individual cards. No content rectangles are used to clip the artwork.
class HeaderSkinPageArtwork extends StatelessWidget {
  const HeaderSkinPageArtwork(
      {super.key,
      required this.skin,
      required this.primary,
      required this.dark,
      required this.role,
      required this.layout});
  final HeaderSkin skin;
  final Color primary;
  final bool dark;
  final HeaderSkinPageRole role;
  final HeaderSkinPageLayout layout;

  @override
  Widget build(BuildContext context) {
    if (skin.isAnimated) {
      return KeyedSubtree(
          key: ValueKey('page-art-${skin.id}'),
          child: _AnimSkinShell(
              seconds: 10,
              staticFrame: skin.id == 'anniversary' ? _kAnnivStaticFrame : .3,
              painterFor: (animation) => _PageSkinPainter(
                  skin.id,
                  skin.boundPrimary ?? primary,
                  dark,
                  role,
                  layout,
                  animation)));
    }
    if (skin.id == 'mountains') {
      return RepaintBoundary(
          child: CustomPaint(
              painter: _PageSkinPainter(skin.id, primary, dark, role, layout,
                  const AlwaysStoppedAnimation<double>(0)),
              child: const SizedBox.expand()));
    }
    // Keep every pre-existing static/SVG design, fading its entire original
    // builder into the page instead of ending at a hard header rectangle.
    return LayoutBuilder(builder: (context, box) {
      final end = math.min(
          box.maxHeight, (layout.card?.bottom ?? layout.topInset + 280) + 190);
      return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
              height: end,
              width: box.maxWidth,
              child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0, .46, 1]).createShader(rect),
                  child: skin.builder(primary, dark))));
    });
  }
}

List<Color> headerSkinPageColors(HeaderSkin skin, Color primary, bool dark) {
  if (skin.id == 'aurora' && dark) {
    return _auroraNightColors(primary);
  }
  if (skin.id == 'anniversary') {
    return dark
        ? const [Color(0xff382c1b), Color(0xff27231c), Color(0xff1b1d1d)]
        : const [Color(0xffffe5a0), Color(0xfffff3cf), Color(0xfffaf8f0)];
  }
  if (skin.id == 'anniv_cake') {
    return dark
        ? const [Color(0xff3c2921), Color(0xff2a221e), Color(0xff1d1d1d)]
        : const [Color(0xffffe2ce), Color(0xfffff0e4), Color(0xfffaf7f2)];
  }
  if (dark) {
    return [
      Color.lerp(const Color(0xff222622), primary, .09)!,
      Color.lerp(const Color(0xff202320), primary, .04)!,
      const Color(0xff1d221d)
    ];
  }
  return [
    Color.lerp(const Color(0xfff1f3ed), primary, .18)!,
    Color.lerp(const Color(0xfff6f7f1), primary, .08)!,
    const Color(0xfff7f7f0)
  ];
}

class _PageSkinPainter extends CustomPainter {
  _PageSkinPainter(
      this.id, this.primary, this.dark, this.role, this.layout, this.animation)
      : super(repaint: animation);
  final String id;
  final Color primary;
  final bool dark;
  final HeaderSkinPageRole role;
  final HeaderSkinPageLayout layout;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final zoom = size.width / 398, t = animation.value;
    final profile = role == HeaderSkinPageRole.profile;
    final end = math.min(size.height - 100,
            (layout.card?.bottom ?? layout.topInset + 280) + 190) /
        zoom;
    final scene = Size(398, end);
    final anchor =
        headerSkinPageAnchor(size, role, layout, cake: id == 'anniv_cake') /
            zoom;
    final h =
        math.min(profile ? 118.0 : 156.0, size.width * (profile ? .36 : .42)) /
            zoom;
    canvas.save();
    canvas.scale(zoom);
    // The scene continues behind the transparent system status bar.
    canvas.clipRect(Rect.fromLTWH(0, 0, 398, size.height / zoom));
    if (id == 'anniversary') {
      final p = _ConstellationPainter(primary, dark, animation, 0);
      canvas.saveLayer(Rect.fromLTWH(0, 0, 398, end + 20), Paint());
      p._paintBaseGlow(canvas, scene, anchor);
      p._paintMilkyWay(canvas, scene, t);
      p._paintNebulae(canvas, scene, t);
      p._paintStardust(canvas, scene, t);
      canvas.save();
      final moon = Offset(size.width * (profile ? .62 : .84) / zoom,
          (layout.topInset + (profile ? 56 : 74)) / zoom);
      canvas.translate(moon.dx - 398 * .13, moon.dy - 208 * .17);
      p._paintMoon(canvas, const Size(398, 208), t);
      canvas.restore();
      p._paintCrossStars(canvas, scene, t);
      p._paintShootingStars(canvas, scene, t);
      _fade(canvas, end);
      canvas.restore();
      final scale = (h / 144).clamp(.5, 1.0);
      p._paintConstellation(canvas, anchor, h, scale, t);
      p._paintBee(canvas, scene, anchor, h, scale, t);
      p._paintBee(canvas, scene, anchor, h, scale * .62, t,
          lag: .055, alphaFactor: .72);
      _inscription(canvas, size, p._inscription, zoom);
    } else if (id == 'anniv_cake') {
      final p = _AnnivCakePainter(dark, animation, 0);
      const original = Size(398, 208);
      canvas.saveLayer(Rect.fromLTWH(0, 0, 398, end + 20), Paint());
      _paintRadialGlow(
          canvas, scene, anchor, 208, _kCakeFlame, dark ? .5 : .25);
      canvas.save();
      canvas.translate(0, (layout.topInset + 46) / zoom);
      p._paintRibbons(canvas, original, t, 1);
      p._paintSprinkles(canvas, Size(398, end - 32 / zoom), t);
      canvas.restore();
      _fade(canvas, end);
      canvas.restore();
      canvas.save();
      canvas.translate(anchor.dx, anchor.dy);
      canvas.scale(profile ? .82 : .78);
      canvas.translate(-_ax(original, 246), -_ay(original, 150));
      p._paintCake(canvas, original, t, 1);
      canvas.restore();
      _inscription(canvas, size, p._mark, zoom);
    } else {
      final top = (layout.topInset + 26) / zoom;
      canvas.saveLayer(Rect.fromLTWH(0, 0, 398, end + 20), Paint());
      canvas.save();
      canvas.translate(0, top);
      _MountainsPainter(primary, dark).paint(canvas, Size(398, end - top));
      canvas.restore();
      _fade(canvas, end);
      canvas.restore();
    }
    canvas.restore();
  }

  void _fade(Canvas canvas, double end) => canvas.drawRect(
      Rect.fromLTWH(-100, -100, 598, end + 200),
      Paint()
        ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent
            ],
            stops: [
              0,
              .14,
              .52,
              1
            ]).createShader(Rect.fromLTWH(0, 0, 398, end))
        ..blendMode = BlendMode.dstIn);

  void _inscription(Canvas canvas, Size size, Color color, double zoom) {
    final scale = .82 / zoom;
    canvas.save();
    canvas.translate(size.width * .46 / zoom - 199 * scale,
        (layout.topInset + 3) / zoom - 22 * scale);
    canvas.scale(scale);
    _paintAnnivInscription(canvas, const Size(398, 208), color, 0);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PageSkinPainter old) =>
      old.id != id ||
      old.primary != primary ||
      old.dark != dark ||
      old.role != role ||
      old.layout.topInset != layout.topInset ||
      old.layout.card != layout.card;
}
