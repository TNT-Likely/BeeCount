import 'package:flutter/material.dart';

/// The app supplies its original brand artwork; no image or theme preferences are loaded here.
class BeeBrandMark extends StatelessWidget {
  const BeeBrandMark({
    super.key,
    required this.mark,
    this.size = 76,
    this.corner = 24,
  });
  final Widget mark;
  final double size, corner;

  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(corner)),
      child: Center(child: ExcludeSemantics(child: mark)));
}
