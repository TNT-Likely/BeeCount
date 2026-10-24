import 'dart:ui' show ImageFilter;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'workflow_components.dart';

/// Controlled overlay. Geometry is shared with the host's release hit testing;
/// platform permissions and recording actions remain in the App.
class BeeQuickAddFan extends StatelessWidget {
  const BeeQuickAddFan({
    super.key,
    required this.origin,
    required this.actions,
    required this.title,
    required this.hint,
    required this.cancelLabel,
    required this.onSelected,
    required this.onDismiss,
    this.disabled = const {},
    this.hoveredIndex,
    this.progress = 1,
  });
  final Offset origin;
  final List<BeeAction> actions;
  final String title, hint, cancelLabel;
  final ValueChanged<String> onSelected;
  final VoidCallback onDismiss;
  final Set<String> disabled;
  final int? hoveredIndex;
  final double progress;

  static const offsets = [Offset(-97, -56), Offset(0, -112), Offset(97, -56)];
  static Offset centerFor(Offset origin, int index, {double progress = 1}) =>
      origin + offsets[index] * progress;
  static Offset safeOrigin(Offset anchor, Size viewport) => Offset(
      anchor.dx.clamp(math.min(129, viewport.width / 2),
          math.max(viewport.width - 129, viewport.width / 2)),
      anchor.dy
          .clamp(math.min(240, viewport.height - 40), viewport.height - 40));

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    if (p == 0) return const SizedBox.shrink();
    final theme = Theme.of(context), cards = BeeCardTheme.of(context);
    final accentInk =
        ThemeData.estimateBrightnessForColor(theme.colorScheme.primary) ==
                Brightness.light
            ? const Color(0xff262829)
            : Colors.white;
    return Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Positioned.fill(
              child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: ModalBarrier(
                      color: Colors.black.withValues(alpha: .3 * p),
                      dismissible: true,
                      onDismiss: onDismiss,
                      semanticsLabel: cancelLabel))),
          Positioned(
              left: 17,
              right: 17,
              top: math.max(8, origin.dy - 199),
              child: Center(
                  child: Opacity(
                      opacity: p,
                      child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                              color: cards.surface,
                              borderRadius: BorderRadius.circular(15)),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(hint,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11, color: theme.hintColor)),
                          ]))))),
          for (var i = 0; i < actions.length && i < offsets.length; i++)
            Positioned(
                left: centerFor(origin, i, progress: p).dx - 32,
                top: centerFor(origin, i, progress: p).dy - 27,
                child: Transform.scale(
                    scale: p,
                    child: Opacity(
                        opacity: p,
                        child: Semantics(
                            key: ValueKey('quick-fan-${actions[i].id}'),
                            container: true,
                            button: true,
                            enabled: !disabled.contains(actions[i].id),
                            selected: i == hoveredIndex,
                            label: actions[i].label,
                            excludeSemantics: true,
                            onTap: disabled.contains(actions[i].id)
                                ? null
                                : () => onSelected(actions[i].id),
                            child: InkWell(
                                onTap: disabled.contains(actions[i].id)
                                    ? null
                                    : () => onSelected(actions[i].id),
                                child: SizedBox(
                                    width: 64,
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AnimatedScale(
                                              duration: const Duration(
                                                  milliseconds: 150),
                                              scale: i == hoveredIndex
                                                  ? 1.12
                                                  : 1,
                                              child: Container(
                                                  width: 54,
                                                  height: 54,
                                                  decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: i == hoveredIndex
                                                          ? theme.colorScheme
                                                              .primary
                                                          : cards.surface,
                                                      boxShadow: [
                                                        BoxShadow(
                                                            color: Colors.black
                                                                .withValues(
                                                                    alpha: .1),
                                                            blurRadius: 15,
                                                            offset:
                                                                const Offset(
                                                                    0, 4))
                                                      ]),
                                                  child: IconTheme(
                                                      data: IconThemeData(
                                                          size: 24,
                                                          color: disabled
                                                                  .contains(
                                                                      actions[i]
                                                                          .id)
                                                              ? theme
                                                                  .disabledColor
                                                              : i ==
                                                                      hoveredIndex
                                                                  ? accentInk
                                                                  : theme
                                                                      .colorScheme
                                                                      .onSurface),
                                                      child: Center(
                                                          child: actions[i]
                                                              .icon)))),
                                          const SizedBox(height: 6),
                                          Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                  color: cards.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(7)),
                                              child: Text(actions[i].label,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: theme.colorScheme
                                                          .onSurface))),
                                        ]))))))),
          Positioned(
              left: origin.dx - 25,
              top: origin.dy - 25,
              child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Material(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(17),
                      child: BeeIconButton(
                          key: const ValueKey('quick-fan-dismiss'),
                          label: cancelLabel,
                          icon: BeeLineIcon('X', color: accentInk),
                          onPressed: onDismiss)))),
        ]));
  }
}
