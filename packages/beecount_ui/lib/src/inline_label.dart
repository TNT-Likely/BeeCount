import 'package:flutter/material.dart';

/// Small inline label. The host owns semantic colors, content and navigation.
/// Visual size stays compact; optional hit padding does not enlarge the pill.
class BeeInlineLabel extends StatelessWidget {
  const BeeInlineLabel({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.onTap,
    this.maxWidth = double.infinity,
    this.fontSize = 10,
    this.hitPadding = EdgeInsets.zero,
    this.radius = 6,
  });
  final String label;
  final Color foreground, background;
  final VoidCallback? onTap;
  final double maxWidth, fontSize, radius;
  final EdgeInsetsGeometry hitPadding;

  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: Padding(
                padding: hitPadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: DecoratedBox(
                    key: const ValueKey('bee-inline-label-visual'),
                    decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(radius)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: fontSize,
                              // Match intrinsic inline-token measurement even
                              // inside Material's spaced/weighted body styles.
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              height: 1.2,
                              color: foreground)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
