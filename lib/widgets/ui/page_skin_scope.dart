import 'package:flutter/widgets.dart';

/// The page owns its skin layer. Headers inside it keep their content and
/// dimensions while leaving the original header painter to legacy routes.
class PageSkinBackdropScope extends InheritedWidget {
  const PageSkinBackdropScope(
      {super.key, required super.child, this.topInset = 0});

  final double topInset;
  static double? topInsetOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PageSkinBackdropScope>()
      ?.topInset;

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageSkinBackdropScope>() !=
      null;

  @override
  bool updateShouldNotify(PageSkinBackdropScope oldWidget) =>
      topInset != oldWidget.topInset;
}
