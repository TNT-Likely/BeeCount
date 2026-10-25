import 'package:flutter/material.dart';
import '../../presentation/v4/bindings/ai_advanced_memory.dart';

final class AgentMemoryPage extends StatelessWidget {
  const AgentMemoryPage({super.key, required this.ledgerId});
  final int ledgerId;
  @override
  Widget build(BuildContext context) =>
      AIAdvancedMemoryControls(ledgerId: ledgerId);
}
