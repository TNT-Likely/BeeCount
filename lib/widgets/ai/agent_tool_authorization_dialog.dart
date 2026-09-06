import 'package:flutter/material.dart';

import '../../agent/permission/agent_authorization_gate.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/ai/agent_tool_presentation.dart';

final class AgentToolAuthorizationDialog {
  const AgentToolAuthorizationDialog._();

  static Future<AgentToolAuthorizationChoice> show({
    required BuildContext context,
    required AgentToolAuthorizationRequest request,
  }) =>
      showAgentToolAuthorizationDialog(context: context, request: request);
}

/// Requests a one-time choice from the user. Dismissing this dialog fails
/// closed: callers always receive [AgentToolAuthorizationChoice.deny].
Future<AgentToolAuthorizationChoice> showAgentToolAuthorizationDialog({
  required BuildContext context,
  required AgentToolAuthorizationRequest request,
}) async {
  final choice = await showDialog<AgentToolAuthorizationChoice>(
    context: context,
    builder: (context) => _AgentToolAuthorizationDialog(request: request),
  );
  return choice ?? AgentToolAuthorizationChoice.deny;
}

final class _AgentToolAuthorizationDialog extends StatelessWidget {
  const _AgentToolAuthorizationDialog({required this.request});

  final AgentToolAuthorizationRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final arguments = AgentToolPresentation.safeArguments(
      l10n,
      request.toolName,
      request.arguments,
    );
    return AlertDialog(
      title: Text(l10n.agentAuthorizationTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AgentToolPresentation.label(l10n, request.toolName),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(AgentToolPresentation.description(l10n, request.toolName)),
            const SizedBox(height: 12),
            Text(
              request.ledgerId == null
                  ? l10n.agentAuthorizationAllLedgers
                  : l10n.agentAuthorizationCurrentLedger(request.ledgerId!),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.agentAuthorizationParameters,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            if (arguments.isEmpty)
              Text(l10n.agentAuthorizationNoParameters)
            else
              for (final argument in arguments) ...[
                Text(argument.label,
                    style: Theme.of(context).textTheme.labelMedium),
                SelectableText(argument.value),
                const SizedBox(height: 6),
              ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            AgentToolAuthorizationChoice.deny,
          ),
          child: Text(l10n.agentAuthorizationDeny),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            AgentToolAuthorizationChoice.allowOnce,
          ),
          child: Text(l10n.agentAuthorizationAllowOnce),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            AgentToolAuthorizationChoice.alwaysAllow,
          ),
          child: Text(l10n.agentAuthorizationAlwaysAllow),
        ),
      ],
    );
  }
}
