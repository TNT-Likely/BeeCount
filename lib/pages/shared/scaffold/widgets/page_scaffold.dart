import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/theme_providers.dart';
import '../../../../styles/header_skins.dart';
import '../../appearance/page_skin_scope.dart';
import '../../appearance/skin_animation_scope.dart';
import '../../appearance/bindings/page_skin_composition.dart';

/// The skin is a background sibling: switching it never adds header space,
/// changes body constraints or recreates the page's scroll/data subtree.
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
  final layout = V4PageSkinLayoutController();
  @override
  void dispose() {
    layout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = headerSkinById(ref.watch(headerSkinProvider));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = skin?.boundPrimary ?? Theme.of(context).colorScheme.primary;
    final top = MediaQuery.paddingOf(context).top;
    final role = widget.locallyComposedSkin
        ? HeaderSkinPageRole.home
        : widget.profileHeaderSkin
            ? HeaderSkinPageRole.profile
            : HeaderSkinPageRole.detail;
    layout.topInset = top;
    layout.scheduleMeasure();
    return PageSkinBackdropScope(
      topInset: top,
      child: V4PageSkinLayoutScope(
        controller: layout,
        child: ColoredBox(
          color: widget.backgroundColor ?? BeeCardTheme.of(context).canvas,
          child: LayoutBuilder(builder: (context, bounds) {
            final gradient = skin == null
                ? null
                : pageSkinGradient(context, skin,
                    headerHeight: top + 208,
                    pageHeight: bounds.maxHeight,
                    locallyComposed: true);
            final art = skin == null
                ? null
                : SkinAnimationScope(
                    child: ValueListenableBuilder<HeaderSkinPageLayout>(
                      valueListenable: layout,
                      builder: (context, geometry, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          if (skin.id == 'anniversary' && !dark)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(
                                      .60,
                                      headerSkinPageAnchor(bounds.biggest, role,
                                                      geometry)
                                                  .dy /
                                              bounds.maxHeight *
                                              2 -
                                          1),
                                  radius: .55,
                                  colors: const [
                                    Color(0xfff8c91c),
                                    Color(0xf2f8c91c),
                                    Color(0x8ff8c91c),
                                    Color(0x00f8c91c)
                                  ],
                                  stops: const [0, .30, .58, .94],
                                ),
                              ),
                            ),
                          HeaderSkinPageArtwork(
                              skin: skin,
                              primary: primary,
                              dark: dark,
                              role: role,
                              layout: geometry),
                        ],
                      ),
                    ),
                  );
            Widget decoration(Widget child) => Positioned.fill(
                child: IgnorePointer(child: ExcludeSemantics(child: child)));
            return Stack(
              key: layout.rootKey,
              fit: StackFit.expand,
              children: [
                if (gradient != null)
                  decoration(DecoratedBox(
                      decoration: BoxDecoration(gradient: gradient))),
                if (art != null) decoration(art),
                Scaffold(
                  backgroundColor: Colors.transparent,
                  bottomNavigationBar: widget.bottomNavigationBar,
                  body: NotificationListener<ScrollNotification>(
                    onNotification: (_) {
                      layout.scheduleMeasure();
                      return false;
                    },
                    child:
                        KeyedSubtree(key: layout.bodyKey, child: widget.body),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
