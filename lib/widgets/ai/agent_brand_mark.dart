import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_providers.dart';
import '../../styles/tokens.dart';
import '../biz/bee_icon.dart';

/// Shared visual identity for the local Agent entry points.
///
/// This widget intentionally has no knowledge of AI configuration or network
/// state. Callers decide whether to show [showStatus] so the mark remains a
/// lightweight, reusable visual component.
final class AgentBrandMark extends ConsumerWidget {
  const AgentBrandMark({
    super.key,
    required this.size,
    this.showBackground = true,
    this.showStatus = false,
    this.semanticLabel,
  });

  final double size;
  final bool showBackground;
  final bool showStatus;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = ref.watch(primaryColorProvider);
    final iconSize = size * 0.58;
    final mark = SizedBox.square(
      key: const ValueKey('agent-brand-mark-frame'),
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (showBackground)
            DecoratedBox(
              decoration: BoxDecoration(
                color: primary.withValues(
                  alpha: BeeTokens.isDark(context) ? 0.22 : 0.12,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: primary.withValues(alpha: 0.2)),
              ),
              child: const SizedBox.expand(),
            ),
          BeeIcon(color: primary, size: iconSize),
          if (showStatus)
            Positioned(
              right: size * 0.02,
              bottom: size * 0.04,
              child: Container(
                width: size * 0.23,
                height: size * 0.23,
                decoration: BoxDecoration(
                  color: BeeTokens.success(context),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: BeeTokens.surface(context),
                    width: size * 0.06,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      label: semanticLabel,
      image: true,
      child: mark,
    );
  }
}
