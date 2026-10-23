import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/theme_providers.dart';
import '../../../styles/header_skins.dart';
import '../../../widgets/ui/skin_animation_scope.dart';

/// Reuses the original skin preference and painter across the full card canvas.
/// Background stays in a fixed slot so switching skins preserves page state.
class V4PageScaffold extends ConsumerWidget {
  const V4PageScaffold({
    super.key,
    required this.body,
    this.backgroundColor,
    this.bottomNavigationBar,
  });
  final Widget body;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = headerSkinById(ref.watch(headerSkinProvider));
    final theme = Theme.of(context);
    final decoration = skin == null
        ? const SizedBox.expand()
        : SkinAnimationScope(
            child: (skin.pageBuilder ?? skin.builder)(theme.colorScheme.primary,
                theme.brightness == Brightness.dark));
    return ColoredBox(
        color: skin == null
            ? backgroundColor ?? BeeCardTheme.of(context).canvas
            : theme.brightness == Brightness.dark
                ? Colors.black
                : theme.colorScheme.primary,
        child: Stack(fit: StackFit.expand, children: [
          Positioned.fill(
              child: IgnorePointer(
                  child: ExcludeSemantics(
                      child: RepaintBoundary(child: decoration)))),
          Scaffold(
              backgroundColor: Colors.transparent,
              bottomNavigationBar: bottomNavigationBar,
              body: body)
        ]));
  }
}
