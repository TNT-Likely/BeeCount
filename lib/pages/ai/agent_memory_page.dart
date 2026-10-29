import 'package:flutter/material.dart';
import 'memory/bindings/ai_advanced_memory.dart';

final class AgentMemoryPage extends StatelessWidget {
  const AgentMemoryPage({super.key, required this.ledgerId});
  final int ledgerId;
  @override
  Widget build(BuildContext context) =>
      AIAdvancedMemoryControls(ledgerId: ledgerId);
}
