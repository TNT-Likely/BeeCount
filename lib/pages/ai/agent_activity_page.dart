import 'package:flutter/material.dart';
import 'activity/bindings/ai_advanced_activity.dart';

final class AgentActivityPage extends StatelessWidget {
  const AgentActivityPage({super.key, required this.ledgerId});
  final int ledgerId;
  @override
  Widget build(BuildContext context) =>
      AIAdvancedActivityControls(ledgerId: ledgerId);
}
