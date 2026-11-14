import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/ai_advanced.dart';
import '../../../../agent/memory/agent_memory_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/ai_chat_providers.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';

class AIAdvancedMemoryControls extends ConsumerStatefulWidget {
  const AIAdvancedMemoryControls({super.key, required this.ledgerId});
  final int ledgerId;
  @override
  ConsumerState<AIAdvancedMemoryControls> createState() => _MemoryState();
}

class _MemoryState extends ConsumerState<AIAdvancedMemoryControls> {
  List<AgentMemoryRecord>? _memories;
  bool _busy = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant AIAdvancedMemoryControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ledgerId != widget.ledgerId) {
      _memories = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation, ledger = widget.ledgerId;
    final repository = ref.read(agentMemoryRepositoryProvider);
    try {
      final values = await repository.listActive(ledgerId: ledger);
      if (mounted && generation == _generation && ledger == widget.ledgerId) {
        setState(() {
          _memories = values;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = AppLocalizations.of(context).commonFailed);
      }
    }
  }

  Future<void> _remove({AgentMemoryRecord? memory}) async {
    if (_busy) return;
    final ledger = widget.ledgerId,
        repository = ref.read(agentMemoryRepositoryProvider),
        l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => BeeDialog(
                  showClose: false,
                  title: Text(memory == null
                      ? l.agentMemoryClearTitle
                      : l.agentMemoryDeleteTitle),
                  content: Text(memory == null
                      ? l.agentMemoryClearDescription
                      : l.agentMemoryDeleteDescription),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.commonCancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.commonDelete))
                  ]));
      if (confirmed != true || !mounted || widget.ledgerId != ledger) return;
      if (memory == null) {
        await repository.clearForLedger(ledger);
      } else {
        final removed = await repository.forget(memory.id, ledgerId: ledger);
        if (!removed) throw StateError('Scoped memory not removed');
      }
      if (mounted && widget.ledgerId == ledger) await _load();
    } catch (_) {
      if (mounted && widget.ledgerId == ledger) {
        setState(() => _error = l.commonFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), memories = _memories;
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.agentMemoryTitle, leading: const BackButton()),
      Expanded(
          child: memories == null && _error == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(17, 16, 17, 28),
                  children: [
                      BeeAIAdvancedNotice(
                          text: l.agentMemoryIntro,
                          icon: const BeeLineIcon('Brain', size: 22)),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        BeeStatus(label: _error!, tone: BeeTone.error),
                        const SizedBox(height: 10),
                        BeeButton(
                            label: l.v4RecordingRetry,
                            kind: BeeButtonKind.secondary,
                            onPressed: _busy ? null : _load)
                      ],
                      if (memories != null && memories.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Align(
                            alignment: Alignment.centerRight,
                            child: BeeButton(
                                label: l.agentMemoryClear,
                                icon: const BeeLineIcon('Trash2', size: 18),
                                kind: BeeButtonKind.quiet,
                                onPressed: _busy ? null : () => _remove()))
                      ],
                      const SizedBox(height: 12),
                      if (memories != null && memories.isEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 36),
                            child: Text(l.agentMemoryEmpty,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).hintColor))),
                      for (final memory
                          in memories ?? <AgentMemoryRecord>[]) ...[
                        BeeAIAdvancedMemoryCard(
                            content: memory.content,
                            deleteLabel: l.commonDelete,
                            deleteKey:
                                ValueKey('agent-memory-delete-${memory.id}'),
                            busy: _busy,
                            onDelete: () => _remove(memory: memory)),
                        const SizedBox(height: 10)
                      ],
                    ]))
    ]));
  }
}
