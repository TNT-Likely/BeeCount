part of '../header_skins.dart';

/// Placement only: the original parts still own every figure, colour and motion.
enum HeaderSkinPageRole { home, profile, detail }

@immutable
class HeaderSkinPageLayout {
  const HeaderSkinPageLayout({
    this.topInset = 0,
    this.card,
    this.protectedRegions = const [],
    this.inscription,
  });
  final double topInset;
  final Rect? card;
  final List<Rect> protectedRegions;
  final Offset? inscription;
}

/// Shorter summary cards move artwork upward within its own layer, so the
/// original figure clears the lower metric row without moving any content.
Offset headerSkinPageAnchor(
    Size size, HeaderSkinPageRole role, HeaderSkinPageLayout layout,
    {bool cake = false}) {
  if (role == HeaderSkinPageRole.home) {
    final card = layout.card;
    final offset = card == null
        ? (cake ? 122.0 : 98.0)
        : cake
            ? (card.height * .48).clamp(100.0, 122.0)
            : (card.height * .40).clamp(74.0, 98.0);
    return Offset(
        size.width * .80, (card?.top ?? layout.topInset + 75) + offset);
  }
  return Offset(size.width * .79,
      layout.topInset + (role == HeaderSkinPageRole.profile ? 104 : 86));
}

/// Independent, non-interactive decoration. It never participates in page layout.
/// The host applies its existing animation preference through MediaQuery.
class HeaderSkinPageArtwork extends StatelessWidget {
  const HeaderSkinPageArtwork({
    super.key,
    required this.skin,
    required this.primary,
    required this.dark,
    required this.role,
    required this.layout,
  });
  final HeaderSkin skin;
  final Color primary;
  final bool dark;
  final HeaderSkinPageRole role;
  final HeaderSkinPageLayout layout;

  @override
  Widget build(BuildContext context) {
    final animated = skin.id == 'anniversary' || skin.id == 'anniv_cake';
    if (animated) {
      return KeyedSubtree(
        key: ValueKey('page-art-${skin.id}'),
        child: _AnimSkinShell(
          seconds: 10,
          staticFrame: skin.id == 'anniversary' ? _kAnnivStaticFrame : .3,
          painterFor: (animation) => _PageSkinPainter(skin.id,
              skin.boundPrimary ?? primary, dark, role, layout, animation),
        ),
      );
    }
    if (skin.id == 'mountains') {
      return RepaintBoundary(
          child: CustomPaint(
              painter: _PageSkinPainter(skin.id, primary, dark, role, layout,
                  const AlwaysStoppedAnimation<double>(0)),
              child: const SizedBox.expand()));
    }
    // All 19 static designs and the existing SVG/image builder stay available.
    // Fade the complete original builder at the same boundary as the scene.
    return LayoutBuilder(builder: (context, box) {
      final end =
          layout.topInset + (role == HeaderSkinPageRole.home ? 306 : 264);
      return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
              height: math.min(end, box.maxHeight),
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

/// Approved B carrier colours. Static skins continue to follow the chosen theme.
List<Color> headerSkinPageColors(HeaderSkin skin, Color primary, bool dark) {
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
      const Color(0xff1d221d),
    ];
  }
  return [
    Color.lerp(const Color(0xfff1f3ed), primary, .18)!,
    Color.lerp(const Color(0xfff6f7f1), primary, .08)!,
    const Color(0xfff7f7f0),
  ];
}

/// A clean left/lower financial area with artwork visible at the card's edge.
class HeaderSkinCardScrim extends StatelessWidget {
  const HeaderSkinCardScrim({super.key, required this.surface});
  final Color surface;
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _SkinCardScrimPainter(surface), child: const SizedBox.expand());
}

class _SkinCardScrimPainter extends CustomPainter {
  _SkinCardScrimPainter(this.surface);
  final Color surface;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
              begin: const Alignment(-1, -.2),
              end: const Alignment(1, .2),
              colors: [
                surface.withValues(alpha: .99),
                surface.withValues(alpha: .98),
                surface.withValues(alpha: .02),
                surface.withValues(alpha: 0),
              ],
              stops: const [
                0,
                .54,
                .74,
                1
              ]).createShader(rect));
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                surface.withValues(alpha: 0),
                surface,
                surface
              ],
              stops: [
                (math.min(138.0, size.height * .60) / size.height).clamp(0, 1),
                (math.min(174.0, size.height * .72) / size.height).clamp(0, 1),
                1
              ]).createShader(rect));
  }

  @override
  bool shouldRepaint(covariant _SkinCardScrimPainter old) =>
      old.surface != surface;
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
    final zoom = size.width / 398;
    final top = layout.topInset;
    final home = role == HeaderSkinPageRole.home;
    final profile = role == HeaderSkinPageRole.profile;
    final end = math.min(
            size.height,
            top +
                (home
                    ? 306
                    : profile
                        ? 266
                        : 220)) /
        zoom;
    final rawAnchor =
        headerSkinPageAnchor(size, role, layout, cake: id == 'anniv_cake');
    final anchor = rawAnchor / zoom;
    final h = (home
            ? 88.0
            : profile
                ? 77.0
                : 62.0) /
        zoom;
    final scene = Size(398, end);
    final t = animation.value;
    canvas.save();
    canvas.scale(zoom);
    final all = Path()..addRect(Rect.fromLTWH(0, 0, 398, size.height / zoom));
    final status = Path()..addRect(Rect.fromLTWH(0, 0, 398, top / zoom));
    final clear = Path()..addPath(status, Offset.zero);
    for (final region in layout.protectedRegions) {
      clear.addRect(Rect.fromLTRB(region.left / zoom, region.top / zoom,
          region.right / zoom, region.bottom / zoom));
    }
    // Soft carrier light stays continuous. Only sharp decorative figures avoid
    // text; clipping glow to text boxes would leave visible rectangular holes.
    void protectText() =>
        canvas.clipPath(Path.combine(PathOperation.difference, all, clear));
    if (id == 'anniversary') {
      final painter = _ConstellationPainter(primary, dark, animation, 0);
      canvas.saveLayer(Rect.fromLTWH(0, 0, 398, end + 20), Paint());
      painter._paintBaseGlow(canvas, scene, anchor);
      painter._paintMilkyWay(canvas, scene, t);
      painter._paintNebulae(canvas, scene, t);
      painter._paintStardust(canvas, scene, t);
      canvas.save();
      protectText();
      final moon = Offset(size.width * (profile ? .62 : .84) / zoom,
          (top + (profile ? 56 : 74)) / zoom);
      canvas.translate(moon.dx - 398 * .13, moon.dy - 208 * .17);
      painter._paintMoon(canvas, const Size(398, 208), t);
      canvas.restore();
      canvas.save();
      protectText();
      painter._paintCrossStars(canvas, scene, t);
      painter._paintShootingStars(canvas, scene, t);
      canvas.restore();
      _fade(canvas, end);
      canvas.restore();
      canvas.save();
      protectText();
      final scale = (h / 144).clamp(.5, 1.0);
      painter._paintConstellation(canvas, anchor, h, scale, t);
      painter._paintBee(canvas, scene, anchor, h, scale, t);
      painter._paintBee(canvas, scene, anchor, h, scale * .62, t,
          lag: .055, alphaFactor: .72);
      _inscription(canvas, size, painter._inscription, zoom);
      canvas.restore();
    } else if (id == 'anniv_cake') {
      final painter = _AnnivCakePainter(dark, animation, 0);
      const original = Size(398, 208);
      canvas.saveLayer(Rect.fromLTWH(0, 0, 398, end + 20), Paint());
      _paintRadialGlow(
          canvas, scene, anchor, 208, _kCakeFlame, dark ? .5 : .25);
      canvas.save();
      protectText();
      canvas.translate(0, (top + 46) / zoom);
      painter._paintRibbons(canvas, original, t, 1);
      painter._paintSprinkles(canvas, Size(398, end - 32 / zoom), t);
      canvas.restore();
      _fade(canvas, end);
      canvas.restore();
      canvas.save();
      protectText();
      canvas.translate(anchor.dx, anchor.dy);
      canvas.scale(profile ? .82 : .78);
      canvas.translate(-_ax(original, 246), -_ay(original, 150));
      painter._paintCake(canvas, original, t, 1);
      canvas.restore();
      canvas.save();
      protectText();
      _inscription(canvas, size, painter._mark, zoom);
      canvas.restore();
    } else {
      final y = (top + 26) / zoom;
      canvas.saveLayer(Rect.fromLTWH(0, 0, 398, end + 20), Paint());
      canvas.save();
      canvas.translate(0, y);
      _MountainsPainter(primary, dark).paint(canvas, Size(398, end - y));
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
    final mark =
        layout.inscription ?? Offset(size.width / 2 - 36, layout.topInset + .5);
    final scale = .82 / zoom;
    canvas.save();
    canvas.translate(mark.dx / zoom - 199 * scale, mark.dy / zoom - 22 * scale);
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
      old.layout != layout;
}
