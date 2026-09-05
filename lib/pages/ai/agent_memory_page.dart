import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/memory/agent_memory_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ai_chat_providers.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/primary_header.dart';

/// Lets people inspect and remove explicit Agent memories stored on-device.
///
/// The page is deliberately ledger-scoped: a preference saved for one ledger
/// cannot be accidentally revealed or deleted while viewing another ledger.
final class AgentMemoryPage extends ConsumerStatefulWidget {
  const AgentMemoryPage({super.key, required this.ledgerId});

  final int ledgerId;

  @override
  ConsumerState<AgentMemoryPage> createState() => _AgentMemoryPageState();
}

final class _AgentMemoryPageState extends ConsumerState<AgentMemoryPage> {
  List<AgentMemoryRecord>? _memories;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final memories = await ref
        .read(agentMemoryRepositoryProvider)
        .listActive(ledgerId: widget.ledgerId);
    if (mounted) setState(() => _memories = memories);
  }

  Future<void> _forget(AgentMemoryRecord memory) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.agentMemoryDeleteTitle),
        content: Text(l10n.agentMemoryDeleteDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isMutating = true);
    await ref.read(agentMemoryRepositoryProvider).forget(memory.id);
    if (mounted) {
      setState(() => _isMutating = false);
      await _load();
    }
  }

  Future<void> _clearLedger() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.agentMemoryClearTitle),
        content: Text(l10n.agentMemoryClearDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isMutating = true);
    await ref
        .read(agentMemoryRepositoryProvider)
        .clearForLedger(widget.ledgerId);
    if (mounted) {
      setState(() => _isMutating = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memories = _memories;
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(title: l10n.agentMemoryTitle, showBack: true),
          Expanded(
            child: memories == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _InfoCard(
                        icon: Icons.memory_outlined,
                        text: l10n.agentMemoryIntro,
                      ),
                      if (memories.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _isMutating ? null : _clearLedger,
                            icon: const Icon(Icons.delete_sweep_outlined),
                            label: Text(l10n.agentMemoryClear),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (memories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 36),
                          child: Center(
                            child: Text(
                              l10n.agentMemoryEmpty,
                              style: BeeTextTokens.label(context),
                            ),
                          ),
                        )
                      else
                        for (final memory in memories) ...[
                          _MemoryCard(
                            memory: memory,
                            isMutating: _isMutating,
                            onDelete: () => _forget(memory),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

final class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BeeTokens.surfaceSecondary(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BeeTokens.divider(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: BeeTokens.textSecondary(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: BeeTextTokens.body(context)),
            ),
          ],
        ),
      );
}

final class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.isMutating,
    required this.onDelete,
  });

  final AgentMemoryRecord memory;
  final bool isMutating;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: BeeTokens.surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: BeeTokens.isDark(context) ? null : BeeShadows.card,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BeeTokens.info(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.bookmark_outline, color: BeeTokens.info(context)),
          ),
          title: Text(memory.content, style: BeeTextTokens.body(context)),
          trailing: IconButton(
            key: ValueKey('agent-memory-delete-${memory.id}'),
            tooltip: AppLocalizations.of(context).commonDelete,
            onPressed: isMutating ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      );
}
