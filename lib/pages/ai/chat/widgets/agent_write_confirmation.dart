import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// The quote is the original user message, never a model-generated draft.
class AgentWriteConfirmation extends StatelessWidget {
  const AgentWriteConfirmation(
      {super.key,
      required this.quote,
      required this.onCancel,
      required this.onConfirm});
  final String quote;
  final VoidCallback onCancel, onConfirm;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BeeSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const BeeLineIcon('LockKeyhole', size: 16),
          const SizedBox(width: 6),
          Expanded(
              child: Text(l.aiChatWriteAccess,
                  style: theme.textTheme.labelMedium)),
        ]),
        const SizedBox(height: 8),
        Text(l.aiChatWriteQuestion, style: theme.textTheme.titleMedium),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    border: BorderDirectional(
                        start: BorderSide(
                            color: theme.colorScheme.primary, width: 3))),
                child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: Text(quote)))),
        OverflowBar(alignment: MainAxisAlignment.end, children: [
          TextButton(
              key: const ValueKey('agent-write-cancel'),
              onPressed: onCancel,
              child: Text(l.commonCancel)),
          BeeButton(
              key: const ValueKey('agent-write-confirm'),
              onPressed: onConfirm,
              label: l.aiChatConfirmWrite),
        ]),
      ]),
    );
  }
}
