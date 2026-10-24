import 'package:flutter/widgets.dart';

/// The page owns its skin layer. Headers inside it keep their content and
/// dimensions while leaving the original header painter to legacy routes.
class PageSkinBackdropScope extends InheritedWidget {
  const PageSkinBackdropScope({super.key, required super.child});

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageSkinBackdropScope>() !=
      null;

  @override
  bool updateShouldNotify(PageSkinBackdropScope oldWidget) => false;
}
