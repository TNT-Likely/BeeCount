import 'package:flutter/material.dart';
import 'prompt/bindings/ai_prompt_workspace.dart';

/// Production route; App bindings own drafts, clipboard/share and original persistence.
class AIPromptEditPage extends StatelessWidget {
  const AIPromptEditPage({super.key});
  @override
  Widget build(BuildContext context) => const AIPromptWorkspace();
}
