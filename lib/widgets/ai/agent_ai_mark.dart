import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
        child: SvgPicture.asset(
          'assets/icons/ai.svg',
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
      ),
    );
  }
}
