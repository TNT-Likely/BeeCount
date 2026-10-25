import 'package:flutter/material.dart';
import '../beecount_ui.dart' show BeeCardTheme, BeeSurface;

/// A surface with the subtle outline shared by dense v4 summary cards.
class BeeCardFrame extends StatelessWidget {
  const BeeCardFrame(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
          border: Border.all(color: BeeCardTheme.of(context).divider),
          borderRadius: BorderRadius.circular(22)),
      child: BeeSurface(padding: padding, child: child));
}
