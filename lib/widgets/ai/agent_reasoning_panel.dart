import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Independent display data: copying answers continues to use final content.
class AgentReasoningPanel extends StatelessWidget {
  const AgentReasoningPanel({super.key, required this.reasoning});
  final String reasoning;

  @override
  Widget build(BuildContext context) {
    if (reasoning.trim().isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(AppLocalizations.of(context).aiReasoningTitle),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(reasoning)),
        )
      ],
    );
  }
}
