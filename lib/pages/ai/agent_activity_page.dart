import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/memory/agent_memory_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ai_chat_providers.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/primary_header.dart';
import 'agent_tool_presentation.dart';

/// A read-only, on-device audit trail for Agent runs in one ledger.
final class AgentActivityPage extends ConsumerStatefulWidget {
  const AgentActivityPage({super.key, required this.ledgerId});

  final int ledgerId;

  @override
  ConsumerState<AgentActivityPage> createState() => _AgentActivityPageState();
}

final class _AgentActivityPageState extends ConsumerState<AgentActivityPage> {
  List<_ActivityRun>? _runs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(agentMemoryRepositoryProvider);
    final runs = await repository.listRecentRuns(ledgerId: widget.ledgerId);
    final activity = <_ActivityRun>[];
    for (final run in runs) {
      activity.add(
        _ActivityRun(
          run: run,
          toolCalls: await repository.listToolCalls(run.runId),
        ),
      );
    }
    if (mounted) setState(() => _runs = activity);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runs = _runs;
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(title: l10n.agentActivityTitle, showBack: true),
          Expanded(
            child: runs == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        _ActivityInfoCard(
                          icon: Icons.history_outlined,
                          text: l10n.agentActivityIntro,
                        ),
                        const SizedBox(height: 16),
                        if (runs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 36),
                            child: Center(
                              child: Text(
                                l10n.agentActivityEmpty,
                                style: BeeTextTokens.label(context),
                              ),
                            ),
                          )
                        else
                          for (final activity in runs) ...[
                            _ActivityCard(activity: activity),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

final class _ActivityRun {
  const _ActivityRun({required this.run, required this.toolCalls});

  final AgentRunRecord run;
  final List<AgentToolCallRecord> toolCalls;
}

final class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final _ActivityRun activity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _statusPresentation(context, l10n, activity.run.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BeeTokens.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: BeeTokens.isDark(context) ? null : BeeShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  activity.run.userMessage ?? '—',
                  style: BeeTextTokens.strongTitle(context),
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(label: status.label, color: status.color),
            ],
          ),
          if (activity.run.errorMessage case final message?) ...[
            const SizedBox(height: 8),
            Text(message, style: BeeTextTokens.label(context)),
          ],
          if (activity.toolCalls.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(l10n.agentActivityTools, style: BeeTextTokens.label(context)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final call in activity.toolCalls)
                  _ToolPill(
                    label: AgentToolPresentation.label(l10n, call.toolName),
                    status: call.status,
                    callId: call.callId,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  ({String label, Color color}) _statusPresentation(
    BuildContext context,
    AppLocalizations l10n,
    String status,
  ) =>
      switch (status) {
        'completed' => (
            label: l10n.agentActivityCompleted,
            color: BeeTokens.success(context),
          ),
        'cancelled' => (
            label: l10n.agentActivityCancelled,
            color: BeeTokens.warning(context),
          ),
        'failed' => (
            label: l10n.agentActivityFailed,
            color: BeeTokens.error(context),
          ),
        _ => (
            label: l10n.agentActivityRunning,
            color: BeeTokens.info(context),
          ),
      };
}

final class _ActivityInfoCard extends StatelessWidget {
  const _ActivityInfoCard({required this.icon, required this.text});

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
            Expanded(child: Text(text, style: BeeTextTokens.body(context))),
          ],
        ),
      );
}

final class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: BeeTextTokens.label(context).copyWith(color: color),
        ),
      );
}

final class _ToolPill extends StatelessWidget {
  const _ToolPill({
    required this.label,
    required this.status,
    required this.callId,
  });

  final String label;
  final String status;
  final String callId;

  @override
  Widget build(BuildContext context) {
    final color = status == 'completed'
        ? BeeTokens.success(context)
        : status == 'denied'
            ? BeeTokens.warning(context)
            : BeeTokens.textSecondary(context);
    final statusLabel = switch (status) {
      'completed' => AppLocalizations.of(context).agentActivityToolCompleted,
      'denied' => AppLocalizations.of(context).agentActivityToolDenied,
      _ => AppLocalizations.of(context).agentActivityToolFailed,
    };
    return Container(
      key: ValueKey('agent-activity-tool-status-$callId'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: BeeTextTokens.label(context).copyWith(color: color)),
          Text(
            ' · ',
            style: BeeTextTokens.label(context).copyWith(color: color),
          ),
          Text(
            statusLabel,
            style: BeeTextTokens.label(context).copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
