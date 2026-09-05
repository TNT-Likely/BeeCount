import 'package:flutter/material.dart';

/// Compact AI wordmark used for the home-page entry point.
///
/// The asset is intentionally independent from Agent availability and provider
/// state. This keeps the home entry lightweight while the chat page can use
/// [AgentBrandMark] for the richer branded avatar.
final class AgentAiMark extends StatelessWidget {
  const AgentAiMark({
    super.key,
    required this.size,
    this.color,
    this.semanticLabel,
  });

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: ExcludeSemantics(
            child: Text(
              'AI',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: iconColor,
                // A two-letter mark has less visual mass than a 24px Material
                // icon. Increase the glyph, not its tap target, so it aligns
                // optically with the adjacent home header icons.
                fontSize: size * 0.9,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.8,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
