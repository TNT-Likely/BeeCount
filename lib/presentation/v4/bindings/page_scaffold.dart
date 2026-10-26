import 'dart:math' as math;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/theme_providers.dart';
import '../../../styles/header_skins.dart';
import '../../../widgets/ui/page_skin_scope.dart';
import 'page_skin_composition.dart';

/// The canvas transition is static; original artwork remains in a bounded slot.
class V4PageScaffold extends ConsumerWidget {
  const V4PageScaffold(
      {super.key,
      required this.body,
      this.backgroundColor,
      this.bottomNavigationBar,
      this.locallyComposedSkin = false,
      this.profileHeaderSkin = false});
  final Widget body;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final bool locallyComposedSkin, profileHeaderSkin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = headerSkinById(ref.watch(headerSkinProvider));
    final local = locallyComposedSkin && isOriginalAnniversarySkin(skin);
    final profile = profileHeaderSkin && isOriginalAnniversarySkin(skin);
    final profileCard =
        profile && Theme.of(context).brightness == Brightness.light;
    return PageSkinBackdropScope(
        topInset: MediaQuery.paddingOf(context).top,
        child: ColoredBox(
            color: backgroundColor ?? BeeCardTheme.of(context).canvas,
            child: LayoutBuilder(builder: (context, bounds) {
              final height = math.min(
                  208.0,
                  MediaQuery.paddingOf(context).top +
                      (local
                          ? 75
                          : profile
                              ? 140
                              : 64));
              return Stack(fit: StackFit.expand, children: [
                Positioned.fill(
                    child: IgnorePointer(
                        child: ExcludeSemantics(
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: skin == null
                                        ? null
                                        : pageSkinGradient(context, skin,
                                            headerHeight: height,
                                            pageHeight: bounds.maxHeight,
                                            locallyComposed:
                                                local || profile)))))),
                Positioned(
                    top: profileCard ? MediaQuery.paddingOf(context).top : 0,
                    left: profileCard ? 17 : 0,
                    right: profileCard ? 17 : 0,
                    height: profileCard ? 140 : height,
                    child: IgnorePointer(
                        child: ExcludeSemantics(
                            child: skin == null || local
                                ? const SizedBox.expand()
                                : ClipRRect(
                                    borderRadius: profileCard
                                        ? BorderRadius.circular(22)
                                        : BorderRadius.zero,
                                    child: V4OriginalSkinScene(
                                        skin: skin,
                                        inCard: profileCard,
                                        centerCardArtwork: profileCard))))),
                Scaffold(
                    backgroundColor: Colors.transparent,
                    bottomNavigationBar: bottomNavigationBar,
                    body: body),
              ]);
            })));
  }
}
