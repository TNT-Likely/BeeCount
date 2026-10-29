import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';
import '../../../providers/theme_providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../../styles/header_skins.dart';
import 'skin_animation_scope.dart';
import 'page_skin_scope.dart';

class PrimaryHeader extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final Key? backButtonKey;
  final List<Widget>? actions;
  final Widget? bottom;
  final Widget? content;
  final EdgeInsetsGeometry padding;
  final Widget? titleTrailing;
  final Widget? subtitleTrailing;
  final Widget? center;
  final IconData? leadingIcon;
  final bool compact;
  final Brightness? statusBarIconBrightness;
  final BoxDecoration? decoration;
  final bool leadingPlain;
  // 隐藏内置标题/副标题行，仅渲染自定义 content（用于首页）
  final bool showTitleSection;

  const PrimaryHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.backButtonKey,
    this.actions,
    this.bottom,
    this.content,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 8),
    this.titleTrailing,
    this.subtitleTrailing,
    this.center,
    this.leadingIcon,
    this.compact = false,
    this.statusBarIconBrightness,
    this.decoration,
    this.leadingPlain = false,
    this.showTitleSection = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = ref.watch(primaryColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final skin = headerSkinById(ref.watch(headerSkinProvider));
    final pageOwnsSkin = PageSkinBackdropScope.contains(context);
    final header = BeePageHeader(
      title: title,
      subtitle: subtitle,
      compact: compact,
      showTitle: showTitleSection,
      padding: padding == const EdgeInsets.fromLTRB(8, 8, 8, 8)
          ? const EdgeInsets.symmetric(horizontal: 17, vertical: 8)
          : padding,
      leading: showBack
          ? BeeIconButton(
              key: backButtonKey,
              label: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const BeeLineIcon('ChevronLeft', size: 21),
              onPressed: onBack ?? () => Navigator.of(context).maybePop())
          : leadingIcon == null
              ? null
              : Icon(leadingIcon, size: 24),
      actions: (actions ?? const <Widget>[]).map((action) {
        if (action is IconButton && action.tooltip != null) {
          return Semantics(
              label: action.tooltip,
              button: true,
              enabled: action.onPressed != null,
              onTap: action.onPressed,
              excludeSemantics: true,
              child: action);
        }
        return action;
      }).toList(),
      content: content,
      bottom: bottom,
      titleTrailing: titleTrailing,
      subtitleTrailing: subtitleTrailing,
      center: center,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemStatusBarContrastEnforced: false,
            statusBarIconBrightness: statusBarIconBrightness ??
                (isDark ? Brightness.light : Brightness.dark),
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light),
        child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
                decoration: decoration ??
                    BoxDecoration(
                        color: pageOwnsSkin
                            ? Colors.transparent
                            : BeeCardTheme.of(context).canvas),
                child: Stack(children: [
                  if (skin != null && !pageOwnsSkin)
                    Positioned.fill(
                        child: SkinAnimationScope(
                            child: skin.builder(primary, isDark))),
                  header,
                ]))));
  }
}
