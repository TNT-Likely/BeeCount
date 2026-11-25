import 'package:flutter/widgets.dart';
import 'chat/bindings/ai_chat_controls.dart';

class AIChatPage extends StatelessWidget {
  const AIChatPage({super.key, this.view = const {}});
  final Map<String, Object?> view;
  @override
  Widget build(BuildContext context) => AIChatControls(view: view);
}
