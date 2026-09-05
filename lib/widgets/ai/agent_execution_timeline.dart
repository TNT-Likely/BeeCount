import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../pages/ai/agent_tool_presentation.dart';
import '../../styles/tokens.dart';
import 'agent_markdown_text.dart';

enum AgentExecutionStepStatus {
  waiting,
  running,
  completed,
  failed,
}

/// 一次工具调用在前台对话中的安全展示模型。
///
/// 参数在渲染前仍会经过 [AgentToolPresentation.safeArguments] 白名单过滤，
/// 结果只展示有限长度的摘要，避免把原始调用对象直接暴露给 UI。
final class AgentExecutionStep {
  const AgentExecutionStep({
    required this.toolName,
    required this.arguments,
    required this.status,
    this.callId,
    this.result,
    this.error,
  });

  final String toolName;
  final Map<String, Object?> arguments;
  final AgentExecutionStepStatus status;
  final String? callId;
  final Map<String, Object?>? result;
  final String? error;

  AgentExecutionStep copyWith({
    String? callId,
    AgentExecutionStepStatus? status,
    Map<String, Object?>? arguments,
    Map<String, Object?>? result,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return AgentExecutionStep(
      toolName: toolName,
      arguments: arguments ?? this.arguments,
      status: status ?? this.status,
      callId: callId ?? this.callId,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 展示 Agent 当前回合的工具调用链和实时文本。
///
/// 它是唯一的“思考中”承载组件，调用方不应再额外叠加独立 loading 行。
final class AgentExecutionTimeline extends StatelessWidget {
  const AgentExecutionTimeline({
    super.key,
    required this.steps,
    required this.isStreaming,
    this.streamingText,
  });

  final List<AgentExecutionStep> steps;
  final bool isStreaming;
  final String? streamingText;

  @override
  Widget build(BuildContext context) {
    final text = streamingText?.trim() ?? '';
    if (steps.isEmpty && text.isEmpty && !isStreaming) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    return Container(
      key: const ValueKey('agent-execution-timeline'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: BeeTokens.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BeeTokens.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isStreaming || steps.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  size: 17,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 7),
                Text(
                  l10n.aiChatThinking,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (isStreaming) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          for (var index = 0; index < steps.length; index++) ...[
            if (index == 0) const SizedBox(height: 8),
            _StepView(step: steps[index], l10n: l10n),
          ],
          if (text.isNotEmpty) ...[
            if (steps.isNotEmpty) const SizedBox(height: 10),
            AgentMarkdownText(
              data: streamingText!,
              style: TextStyle(
                color: BeeTokens.textPrimary(context),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step, required this.l10n});

  final AgentExecutionStep step;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = AgentToolPresentation.label(l10n, step.toolName);
    final statusText = switch (step.status) {
      AgentExecutionStepStatus.waiting => l10n.agentPermissionWaiting,
      AgentExecutionStepStatus.running => l10n.agentExecutingTool(label),
      AgentExecutionStepStatus.completed => l10n.agentToolCompleted(label),
      AgentExecutionStepStatus.failed => l10n.agentToolFailed(label),
    };
    final safeArgs = AgentToolPresentation.safeArguments(
      l10n,
      step.toolName,
      step.arguments,
    );

    final (IconData icon, Color color) = switch (step.status) {
      AgentExecutionStepStatus.waiting => (
          Icons.hourglass_top_rounded,
          Colors.orange,
        ),
      AgentExecutionStepStatus.running => (
          Icons.sync_rounded,
          Theme.of(context).colorScheme.primary,
        ),
      AgentExecutionStepStatus.completed => (
          Icons.check_circle_rounded,
          Colors.green,
        ),
      AgentExecutionStepStatus.failed => (
          Icons.error_rounded,
          Theme.of(context).colorScheme.error,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (safeArgs.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      for (final argument in safeArgs)
                        _ArgumentChip(argument: argument),
                    ],
                  ),
                ],
                if (step.result != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _resultText(step.result!),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BeeTokens.textSecondary(context),
                          height: 1.35,
                        ),
                  ),
                ],
                if (step.error != null && step.error!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _truncate(step.error!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _resultText(Map<String, Object?> result) {
    final entries = result.entries.take(5).map((entry) {
      final value = _truncate(entry.value?.toString() ?? '—');
      return '${entry.key}: $value';
    });
    return entries.join(' · ');
  }

  String _truncate(String value) {
    const maxLength = 220;
    final normalized = value.trim();
    return normalized.length <= maxLength
        ? normalized
        : '${normalized.substring(0, maxLength)}…';
  }
}

class _ArgumentChip extends StatelessWidget {
  const _ArgumentChip({required this.argument});

  final ({String label, String value}) argument;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: BeeTokens.surface(context),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '${argument.label}: ${argument.value}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
