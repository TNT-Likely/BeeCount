import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../app_profile/brand_mark.dart';

/// Presentation of an actual recording operation. Hosts own stages and timing;
/// this view never estimates completion percentages or writes a transaction.
class RecordingProgressCard extends StatelessWidget {
  const RecordingProgressCard({
    super.key,
    required this.title,
    required this.description,
    required this.mark,
    required this.contextLabel,
    this.contextIcon = const BeeLineIcon('Image', size: 12),
    this.waitHint,
  });
  final String title, description, contextLabel;
  final Widget mark, contextIcon;
  final String? waitHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), cards = BeeCardTheme.of(context);
    return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: Material(
            color: cards.overlay,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  BeeBrandMark(mark: mark, size: 68, corner: 22),
                  const SizedBox(height: 19),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconTheme(
                        data: IconThemeData(color: theme.hintColor, size: 12),
                        child: contextIcon),
                    const SizedBox(width: 5),
                    Flexible(
                        child: Text(contextLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10, color: theme.hintColor)))
                  ]),
                  const SizedBox(height: 12),
                  Semantics(
                      liveRegion: true,
                      child: Text(title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 19,
                              height: 1.4,
                              fontWeight: FontWeight.w600))),
                  const SizedBox(height: 8),
                  Text(description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, height: 1.7, color: theme.hintColor)),
                  if (waitHint != null) ...[
                    const SizedBox(height: 18),
                    BeeStatus(
                        label: waitHint!,
                        icon: const BeeLineIcon('Clock', size: 15))
                  ],
                  const SizedBox(height: 24),
                  TickerMode(
                      enabled: TickerMode.of(context) &&
                          !MediaQuery.disableAnimationsOf(context),
                      child: LinearProgressIndicator(
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(3),
                          backgroundColor: cards.soft)),
                ]))));
  }
}
