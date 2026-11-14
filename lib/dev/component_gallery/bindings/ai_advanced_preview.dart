import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/ai_advanced.dart';
import '../../../agent/permission/agent_tool_permission.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/ai_chat_providers.dart';
import '../../../providers/database_providers.dart';

/// Reads only existing local records and tool preferences. No agent is started.
final aiAdvancedPreviewProvider = FutureProvider.autoDispose
    .family<({int memories, int runs, int changed}), int>((ref, ledger) async {
  final memory = ref.read(agentMemoryRepositoryProvider);
  final permissions = ref.read(agentToolPermissionStoreProvider);
  final values = await permissions.readAll();
  final memories = await memory.listActive(ledgerId: ledger);
  final runs = await memory.listRecentRuns(ledgerId: ledger);
  return (
    memories: memories.length,
    runs: runs.length,
    changed: AgentToolPermissionCatalog.descriptors
        .where((d) =>
            (values[d.toolName] ?? d.defaultPermission) != d.defaultPermission)
        .length
  );
});

class AIAdvancedPreview extends ConsumerWidget {
  const AIAdvancedPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        ledger = ref.watch(currentLedgerIdProvider);
    if (ledger <= 0) return Text(l.aiOcrNoLedger);
    return ref.watch(aiAdvancedPreviewProvider(ledger)).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Text(l.commonFailed),
        data: (counts) =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              BeeAIAdvancedNotice(
                  text:
                      '${l.agentMemoryTitle}: ${counts.memories}\n${l.agentActivityTitle}: ${counts.runs}',
                  icon: const BeeLineIcon('Brain', size: 22)),
              const SizedBox(height: 12),
              BeeAIAdvancedNotice(
                  text: counts.changed == 0
                      ? l.agentPermissionsDefaultsActive
                      : l.agentPermissionsModifiedCount(counts.changed),
                  icon: const BeeLineIcon('ShieldCheck', size: 22)),
            ]));
  }
}
