import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/database_providers.dart';
import 'chat/bindings/ai_chat_controls.dart';

class AIChatPage extends ConsumerWidget {
  const AIChatPage({super.key, this.view = const {}});
  final Map<String, Object?> view;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerId = ref.watch(currentLedgerIdProvider);
    return AIChatControls(key: ValueKey(ledgerId), view: view);
  }
}
