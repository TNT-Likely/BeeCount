import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/theme_providers.dart';
import '../../../../styles/header_skins.dart';
import '../skin_animation_scope.dart';

bool isOriginalAnniversarySkin(HeaderSkin? skin) =>
    skin?.id == 'anniversary' || skin?.id == 'anniv_cake';

/// Legacy full-art thumbnail for previews and byte-for-byte source checks.
/// Real page backgrounds use HeaderSkinPageArtwork instead of this bounded scene.
class V4OriginalSkinScene extends StatelessWidget {
  const V4OriginalSkinScene(
      {super.key,
      required this.skin,
      this.inCard = false,
      this.alignForHome = false,
      this.centerCardArtwork = false});
  final HeaderSkin skin;
  final bool inCard, alignForHome, centerCardArtwork;
  static const logicalSize = Size(398, 208);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = skin.boundPrimary ?? Theme.of(context).colorScheme.primary;
    return LayoutBuilder(builder: (context, bounds) {
      final width = bounds.maxWidth, height = bounds.maxHeight;
      final artWidth = inCard
          ? math.min(240.0, math.max(0.0, width - 96))
          : math.min(width, height * logicalSize.aspectRatio);
      final artHeight = artWidth / logicalSize.aspectRatio;
      final left = inCard
          ? width - artWidth - 12
          : alignForHome
              ? math.min(math.max(0.0, (width - 320) * .43), width - artWidth)
              : (width - artWidth) / 2;
      final top = inCard
          ? (centerCardArtwork
              ? math.max(0.0, (height - artHeight) / 2)
              : math.min(48.0, math.max(0.0, height - artHeight)))
          : 0.0;
      final cake = skin.id == 'anniv_cake';
      final topColor = dark
          ? Colors.black
          : cake
              ? const Color(0xfffffbf0)
              : primary;
      final bottom = dark
          ? cake
              ? const Color(0xff1a1004)
              : Colors.black
          : cake
              ? const Color(0xffffe0ae)
              : primary;
      return DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: cake && !dark
                      ? [
                          topColor,
                          topColor,
                          const Color(0xfffff0d2),
                          bottom,
                          bottom
                        ]
                      : [topColor, topColor, bottom, bottom],
                  stops: cake && !dark
                      ? [
                          0,
                          (top / height).clamp(0, 1),
                          ((top + artHeight * .6) / height).clamp(0, 1),
                          ((top + artHeight) / height).clamp(0, 1),
                          1
                        ]
                      : [
                          0,
                          (top / height).clamp(0, 1),
                          ((top + artHeight) / height).clamp(0, 1),
                          1
                        ])),
          child: Stack(children: [
            Positioned(
                left: left,
                top: top,
                width: artWidth,
                height: artHeight,
                child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                        key: const ValueKey('v4-original-skin-canvas'),
                        width: logicalSize.width,
                        height: logicalSize.height,
                        child: MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(padding: EdgeInsets.zero),
                            child: ColoredBox(
                                color: dark ? Colors.black : primary,
                                child: SkinAnimationScope(
                                    child: skin.builder(primary, dark)))))))
          ]));
    });
  }
}

/// Identity keeps exactly the same geometry with and without a skin.
class V4HomeSkinHeader extends StatelessWidget {
  const V4HomeSkinHeader({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

Widget? homeSkinCardBackground(BuildContext context, WidgetRef ref) {
  if (headerSkinById(ref.watch(headerSkinProvider)) == null) return null;
  return _HomeSkinCardScrim(surface: BeeCardTheme.of(context).surface);
}

class _HomeSkinCardScrim extends StatelessWidget {
  const _HomeSkinCardScrim({required this.surface});
  final Color surface;
  @override
  Widget build(BuildContext context) {
    final layout = V4PageSkinLayoutScope.maybeOf(context);
    layout?.scheduleMeasure();
    return LayoutBuilder(builder: (context, bounds) {
      layout?.scheduleMeasure();
      return RepaintBoundary(
          key: layout?.cardKey, child: HeaderSkinCardScrim(surface: surface));
    });
  }
}

Gradient pageSkinGradient(BuildContext context, HeaderSkin skin,
    {required double headerHeight,
    required double pageHeight,
    required bool locallyComposed}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final primary = skin.boundPrimary ?? Theme.of(context).colorScheme.primary;
  return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        ...headerSkinPageColors(skin, primary, dark),
        BeeCardTheme.of(context).canvas
      ],
      stops: const [
        0,
        .25,
        .61,
        1
      ]);
}

/// Measures render geometry only, after layout. No data reads or page rebuilds
/// occur on animation ticks; the painter receives a stable decoration snapshot.
class V4PageSkinLayoutController extends ValueNotifier<HeaderSkinPageLayout> {
  V4PageSkinLayoutController() : super(const HeaderSkinPageLayout());
  final rootKey = GlobalKey(), bodyKey = GlobalKey(), cardKey = GlobalKey();
  double topInset = 0;
  bool _queued = false, _disposed = false;
  void scheduleMeasure() {
    if (_queued || _disposed) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (_disposed) return;
      final root = rootKey.currentContext?.findRenderObject();
      final body = bodyKey.currentContext?.findRenderObject();
      if (root is! RenderBox || !root.hasSize || body == null) return;
      final clear = <Rect>[];
      final marks = <Rect>[];
      final limit = topInset + 340;
      Rect? boundsOf(RenderObject object) {
        if (object is! RenderBox || !object.hasSize || !object.attached) {
          return null;
        }
        return MatrixUtils.transformRect(
            object.getTransformTo(root), Offset.zero & object.size);
      }

      void visit(RenderObject object) {
        if (object is RenderParagraph && object.hasSize) {
          final rect = boundsOf(object);
          if (rect != null &&
              rect.top < limit &&
              rect.bottom > topInset &&
              !rect.isEmpty) {
            clear.add(rect.inflate(3));
            if (rect.left < root.size.width * .52 && rect.top < topInset + 35) {
              marks.add(rect);
            }
          }
        }
        object.visitChildren(visit);
      }

      visit(body);
      // Header icon hit areas remain clear as well as the actual text glyphs.
      clear.add(Rect.fromLTWH(
          root.size.width * .57, topInset + 20, root.size.width * .43, 44));
      var markX = root.size.width / 2 - 36;
      for (final text in marks) {
        if (text.right < root.size.width * .62) {
          markX = math.max(markX, text.right + 4);
        }
      }
      markX = markX.clamp(20, math.max(20, root.size.width - 80));
      final card = cardKey.currentContext?.findRenderObject();
      final next = HeaderSkinPageLayout(
          topInset: topInset,
          card: card == null ? null : boundsOf(card),
          protectedRegions: List.unmodifiable(clear),
          inscription: Offset(markX, topInset + .5));
      bool same() {
        if (value.topInset != next.topInset ||
            value.card != next.card ||
            value.inscription != next.inscription ||
            value.protectedRegions.length != clear.length) {
          return false;
        }
        for (var i = 0; i < clear.length; i++) {
          if (clear[i] != value.protectedRegions[i]) return false;
        }
        return true;
      }

      if (!same()) value = next;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class V4PageSkinLayoutScope extends InheritedWidget {
  const V4PageSkinLayoutScope(
      {super.key, required this.controller, required super.child});
  final V4PageSkinLayoutController controller;
  static V4PageSkinLayoutController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<V4PageSkinLayoutScope>()
      ?.controller;
  @override
  bool updateShouldNotify(V4PageSkinLayoutScope oldWidget) =>
      oldWidget.controller != controller;
}
