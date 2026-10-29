import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Informational content shared by image, camera, voice and share guides.
/// The App owns availability, localized copy and the enclosing dialog.
class BeeBillingGuide extends StatelessWidget {
  const BeeBillingGuide(
      {super.key,
      required this.description,
      required this.requirement,
      required this.actionHint,
      this.requiresAI = true});
  final String description, requirement, actionHint;
  final bool requiresAI;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(description, style: const TextStyle(fontSize: 13, height: 1.65)),
        const SizedBox(height: 16),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: BeeCardTheme.of(context).soft,
                borderRadius: BorderRadius.circular(12)),
            child: BeeStatus(
                label: requirement,
                tone: requiresAI ? BeeTone.warning : BeeTone.neutral)),
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12)),
            child: BeeStatus(
                label: actionHint, icon: const BeeLineIcon('Hand', size: 20)))
      ]);
}
