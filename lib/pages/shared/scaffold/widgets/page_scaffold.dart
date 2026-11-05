import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/theme_providers.dart';
import '../../../../styles/header_skins.dart';
import '../../appearance/page_skin_scope.dart';
import '../../appearance/skin_animation_scope.dart';

/// The scene and shared material never reserve header space, change the body's
/// constraints, or recreate its scroll/data subtree when a skin changes.
class V4PageScaffold extends ConsumerStatefulWidget {
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
  ConsumerState<V4PageScaffold> createState() => _V4PageScaffoldState();
}

class _V4PageScaffoldState extends ConsumerState<V4PageScaffold> {
  final scene = BeeSceneController();
  @override
  void dispose() {
    scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = headerSkinById(ref.watch(effectiveHeaderSkinProvider));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = skin?.boundPrimary ?? Theme.of(context).colorScheme.primary;
    final top = MediaQuery.paddingOf(context).top;
    final role = widget.locallyComposedSkin
        ? HeaderSkinPageRole.home
        : widget.profileHeaderSkin
            ? HeaderSkinPageRole.profile
            : HeaderSkinPageRole.detail;
    final canvas = widget.backgroundColor ?? BeeCardTheme.of(context).canvas;
    scene.scheduleMeasure();
    Widget decoration(Widget child) => Positioned.fill(
        child: IgnorePointer(child: ExcludeSemantics(child: child)));
    return PageSkinBackdropScope(
        topInset: top,
        child: BeeSceneScope(
            controller: scene,
            child: ColoredBox(
                color: canvas,
                child: Stack(
                    key: scene.canvasKey,
                    fit: StackFit.expand,
                    children: [
                      if (skin != null)
                        decoration(DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      ...headerSkinPageColors(
                                          skin, primary, dark),
                                      canvas
                                    ],
                                    stops: dark
                                        ? const [0, .34, .76, 1]
                                        : const [0, .29, .68, 1])))),
                      if (skin != null)
                        decoration(SkinAnimationScope(
                          child: ValueListenableBuilder<Rect?>(
                              valueListenable: scene,
                              builder: (context, card, _) =>
                                  LayoutBuilder(builder: (context, box) {
                                    final geometry = HeaderSkinPageLayout(
                                        topInset: top, card: card);
                                    return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (skin.id == 'anniversary' && !dark)
                                            DecoratedBox(
                                                decoration: BoxDecoration(
                                                    gradient: RadialGradient(
                                                        center: Alignment(
                                                            .66,
                                                            225 /
                                                                    box.maxHeight *
                                                                    2 -
                                                                1),
                                                        // An ellipse matching the approved 330×340 canopy.
                                                        radius: 340 / box.biggest.shortestSide,
                                                        colors: const [
                                                  Color(0xe8f8c91c),
                                                  Color(0x7df8c91c),
                                                  Color(0x00f8c91c)
                                                ],
                                                        stops: const [
                                                  0,
                                                  .39,
                                                  .9
                                                ]))),
                                          HeaderSkinPageArtwork(
                                              skin: skin,
                                              primary: primary,
                                              dark: dark,
                                              role: role,
                                              layout: geometry),
                                        ]);
                                  })),
                        )),
                      BeePageMaterial(
                          enabled: skin != null,
                          child: Scaffold(
                              backgroundColor: Colors.transparent,
                              bottomNavigationBar: widget.bottomNavigationBar,
                              body: widget.body)),
                    ]))));
  }
}
