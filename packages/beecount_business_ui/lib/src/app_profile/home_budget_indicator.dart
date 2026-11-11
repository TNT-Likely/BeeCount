import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Controlled home-budget affordance. The host owns usage, localization and
/// navigation; this ring never queries data or starts an indeterminate spinner.
class BeeHomeBudgetIndicator extends StatelessWidget {
  const BeeHomeBudgetIndicator({
    super.key,
    required this.value,
    required this.label,
    required this.progress,
    required this.semanticLabel,
    required this.onTap,
    this.diameter = 86,
    this.exceeded = false,
  });

  final String value, label, semanticLabel;
  final double progress, diameter;
  final bool exceeded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
              dimension: diameter,
              child: Stack(alignment: Alignment.center, children: [
                Positioned.fill(
                    child: Padding(
                        padding: EdgeInsets.all(diameter * 6 / 86),
                        child: CircularProgressIndicator(
                            value: progress.isFinite ? progress.clamp(0, 1) : 0,
                            strokeWidth: 1.75,
                            color: exceeded
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                            backgroundColor: BeeCardTheme.of(context).soft))),
                Padding(
                    padding: const EdgeInsets.all(14),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(value,
                              style: TextStyle(
                                  fontSize: 22,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: exceeded
                                      ? Theme.of(context).colorScheme.error
                                      : null)),
                          const SizedBox(height: 2),
                          Text(label,
                              style: TextStyle(
                                  fontSize: 9,
                                  height: 1.5,
                                  color: Theme.of(context).hintColor))
                        ])))
              ]))));
}
