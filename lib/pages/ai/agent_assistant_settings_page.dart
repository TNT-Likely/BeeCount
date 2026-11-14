import 'package:flutter/material.dart';
import 'assistant/bindings/assistant_settings_controls.dart';

/// Original entry and ledger identity; App binding owns local execution settings.
final class AgentAssistantSettingsPage extends StatelessWidget {
  const AgentAssistantSettingsPage({super.key, required this.ledgerId});
  final int ledgerId;
  @override
  Widget build(BuildContext context) =>
      AssistantSettingsControls(ledgerId: ledgerId);
}
