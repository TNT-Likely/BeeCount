import 'dart:math' as math;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/theme_providers.dart';
import '../../../styles/header_skins.dart';
import '../../../widgets/ui/skin_animation_scope.dart';
import '../../../widgets/ui/page_skin_scope.dart';

bool isOriginalAnniversarySkin(HeaderSkin? skin) =>
    skin?.id == 'anniversary' || skin?.id == 'anniv_cake';

/// Only placement is new. The original builder owns all artwork and timing.
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

/// Dark home: retain the complete scene above the first card, including safe area.
class V4HomeSkinHeader extends ConsumerWidget {
  const V4HomeSkinHeader({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = headerSkinById(ref.watch(headerSkinProvider));
    if (!isOriginalAnniversarySkin(skin) ||
        Theme.of(context).brightness != Brightness.dark) {
      return child;
    }
    final bleed = (PageSkinBackdropScope.topInsetOf(context) ??
            MediaQuery.paddingOf(context).top) +
        6;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(
          top: -bleed,
          left: -17,
          right: -17,
          height: 69 + bleed,
          child: IgnorePointer(
              child: ExcludeSemantics(
                  child:
                      V4OriginalSkinScene(skin: skin!, alignForHome: true)))),
      child,
    ]);
  }
}

Widget? homeSkinCardBackground(BuildContext context, WidgetRef ref) {
  final skin = headerSkinById(ref.watch(headerSkinProvider));
  return isOriginalAnniversarySkin(skin) &&
          Theme.of(context).brightness == Brightness.light
      ? IgnorePointer(
          child: ExcludeSemantics(
              child: V4OriginalSkinScene(skin: skin!, inCard: true)))
      : null;
}

Gradient pageSkinGradient(BuildContext context, HeaderSkin skin,
    {required double headerHeight,
    required double pageHeight,
    required bool locallyComposed}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final canvas = BeeCardTheme.of(context).canvas;
  final cake = skin.id == 'anniv_cake';
  final primary = skin.boundPrimary ?? Theme.of(context).colorScheme.primary;
  if (locallyComposed && !dark) {
    return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          cake ? const Color(0xfffff8ee) : const Color(0xfffff9df),
          canvas,
          canvas
        ],
        stops: [
          0,
          (540 / pageHeight).clamp(.1, 1),
          1
        ]);
  }
  final top = dark
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
  final stop = (headerHeight / pageHeight).clamp(0.0, .6);
  return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, bottom, canvas, canvas],
      stops: [0, stop, math.max(stop, (540 / pageHeight).clamp(0.0, 1.0)), 1]);
}
