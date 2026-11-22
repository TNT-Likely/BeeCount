import 'package:flutter/widgets.dart';

/// Lets a page backdrop measure the surfaces painted over it.
class BeeSurfaceScope extends InheritedWidget {
  const BeeSurfaceScope({super.key, required this.wrap, required super.child});

  final Widget Function(BuildContext context, Widget surface) wrap;

  static BeeSurfaceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BeeSurfaceScope>();

  @override
  bool updateShouldNotify(BeeSurfaceScope oldWidget) => wrap != oldWidget.wrap;
}
