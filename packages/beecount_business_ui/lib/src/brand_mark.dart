import 'package:flutter/material.dart';

/// The app supplies its original brand artwork; no image or theme preferences are loaded here.
class BeeBrandMark extends StatelessWidget {
  const BeeBrandMark({
    super.key,
    required this.mark,
    this.size = 76,
    this.corner = 24,
    this.background,
  });
  final Widget mark;
  final double size, corner;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: background ??
              Theme.of(context).colorScheme.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(corner)),
      child: Center(child: ExcludeSemantics(child: mark)));
}
