import 'dart:math' as math;
import 'package:flutter/material.dart';
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
