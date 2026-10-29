import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../agent/runtime/agent_execution_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/ai_chat_providers.dart';
import '../../../providers.dart';
import '../../../pages/ai/agent_assistant_settings_page.dart';

class LiveExecutionDepthPreview extends ConsumerWidget {
  const LiveExecutionDepthPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        ledgerId = ref.watch(currentLedgerIdProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实助手执行配置（只读）'),
      const SizedBox(height: 8),
      FutureBuilder<AgentExecutionSettings>(
          future: ref.read(agentExecutionSettingsStoreProvider).read(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('${snapshot.error}');
            if (!snapshot.hasData) return const CircularProgressIndicator();
            return BeeSurface(
                child: Text(l.agentExecutionDepthSelected(
                    snapshot.data!.maximumModelTurns)));
          }),
      BeeButton(
          label: '打开真实AI助手设置',
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) =>
                      AgentAssistantSettingsPage(ledgerId: ledgerId))))
    ]);
  }
}
