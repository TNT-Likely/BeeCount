import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/ai_advanced.dart';
import '../../../agent/memory/agent_memory_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/ai_chat_providers.dart';
import '../../../pages/ai/agent_tool_presentation.dart';
import 'page_scaffold.dart';

class AIAdvancedActivityControls extends ConsumerStatefulWidget {
  const AIAdvancedActivityControls({super.key, required this.ledgerId});
  final int ledgerId;
  @override
  ConsumerState<AIAdvancedActivityControls> createState() => _ActivityState();
}

class _ActivityState extends ConsumerState<AIAdvancedActivityControls> {
  List<({AgentRunRecord run, List<AgentToolCallRecord> calls})>? _runs;
  String? _error;
  int _generation = 0;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant AIAdvancedActivityControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ledgerId != widget.ledgerId) {
      _runs = null;
      _error = null;
      _load(force: true);
    }
  }

  Future<void> _load({bool force = false}) async {
    if (_loading && !force) return;
    final generation = ++_generation,
        ledger = widget.ledgerId,
        repository = ref.read(agentMemoryRepositoryProvider);
    _loading = true;
    try {
      final runs = await repository.listRecentRuns(ledgerId: ledger),
          rows = <({AgentRunRecord run, List<AgentToolCallRecord> calls})>[];
      for (final run in runs) {
        rows.add((run: run, calls: await repository.listToolCalls(run.runId)));
      }
      if (mounted && generation == _generation && ledger == widget.ledgerId) {
        setState(() {
          _runs = rows;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = AppLocalizations.of(context).commonFailed);
      }
    } finally {
      if (generation == _generation) _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), runs = _runs;
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.agentActivityTitle, leading: const BackButton()),
      Expanded(
          child: runs == null && _error == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(17, 16, 17, 28),
                      children: [
                        BeeAIAdvancedNotice(
                            text: l.agentActivityIntro,
                            icon: const BeeLineIcon('History', size: 22)),
                        const SizedBox(height: 16),
                        if (_error != null) ...[
                          BeeStatus(label: _error!, tone: BeeTone.error),
                          const SizedBox(height: 10),
                          BeeButton(
                              label: l.v4RecordingRetry,
                              kind: BeeButtonKind.secondary,
                              onPressed: () => _load()),
                          const SizedBox(height: 12)
                        ],
                        if (runs != null && runs.isEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 36),
                              child: Text(l.agentActivityEmpty,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).hintColor))),
                        for (final row in runs ??
                            <({
                              AgentRunRecord run,
                              List<AgentToolCallRecord> calls
                            })>[]) ...[
                          BeeAIAdvancedActivityCard(
                              message: row.run.userMessage ?? '—',
                              status: switch (row.run.status) {
                                'completed' => l.agentActivityCompleted,
                                'cancelled' => l.agentActivityCancelled,
                                'failed' => l.agentActivityFailed,
                                _ => l.agentActivityRunning
                              },
                              tone: switch (row.run.status) {
                                'completed' => BeeTone.success,
                                'cancelled' => BeeTone.warning,
                                'failed' => BeeTone.error,
                                _ => BeeTone.neutral
                              },
                              error: row.run.errorMessage,
                              toolsLabel: l.agentActivityTools,
                              tools: [
                                for (final call in row.calls)
                                  BeeAIAdvancedToolBadge(
                                      key: ValueKey(
                                          'agent-activity-tool-status-${call.callId}'),
                                      label: AgentToolPresentation.label(
                                          l, call.toolName),
                                      status: switch (call.status) {
                                        'completed' =>
                                          l.agentActivityToolCompleted,
                                        'denied' => l.agentActivityToolDenied,
                                        _ => l.agentActivityToolFailed
                                      },
                                      tone: switch (call.status) {
                                        'completed' => BeeTone.success,
                                        'denied' => BeeTone.warning,
                                        _ => BeeTone.neutral
                                      })
                              ]),
                          const SizedBox(height: 10),
                        ],
                      ])))
    ]));
  }
}
