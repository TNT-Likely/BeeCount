import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';

import '../../../agent/permission/agent_authorization_gate.dart';
import '../../../l10n/app_localizations.dart';
import '../agent_tool_presentation.dart';

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
    return BeeDialog(
      title: Text(l10n.agentAuthorizationTitle),
      stackActions: true,
      content: BeeToolRequestDetails(
          label: AgentToolPresentation.label(l10n, request.toolName),
          description:
              AgentToolPresentation.description(l10n, request.toolName),
          scope: request.ledgerId == null
              ? l10n.agentAuthorizationAllLedgers
              : l10n.agentAuthorizationCurrentLedger(request.ledgerId!),
          parametersLabel: l10n.agentAuthorizationParameters,
          emptyLabel: l10n.agentAuthorizationNoParameters,
          fields: [
            for (final argument in arguments)
              BeeAssistantBillField(argument.label, argument.value)
          ]),
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
