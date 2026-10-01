import 'package:agentcore/agentcore.dart' show AgentNativeModelPhase;
import 'package:flutter/material.dart';
import 'package:flutter_agent_ui/flutter_agent_ui.dart';

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
/// 对话展示和历史快照只使用白名单内的可读摘要。
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

/// A thin BeeCount adapter around the reusable execution disclosure.
/// The streaming Markdown remains outside the collapsible process area.
final class AgentExecutionTimeline extends StatelessWidget {
  const AgentExecutionTimeline({
    super.key,
    required this.steps,
    required this.isStreaming,
    this.streamingText,
    this.displaySteps,
    this.modelPhase,
  });

  final List<AgentExecutionStep> steps;
  final bool isStreaming;
  final String? streamingText;
  final List<AgentActivityStep>? displaySteps;
  final AgentNativeModelPhase? modelPhase;

  static List<AgentActivityStep> projectSteps(
          AppLocalizations l10n, List<AgentExecutionStep> steps,
          {bool finished = false}) =>
      [
        for (final step in steps.take(24))
          AgentActivityStep(
            title: AgentToolPresentation.activityTitle(l10n, step.toolName),
            status: finished &&
                    (step.status == AgentExecutionStepStatus.waiting ||
                        step.status == AgentExecutionStepStatus.running)
                ? AgentActivityStatus.failed
                : switch (step.status) {
                    AgentExecutionStepStatus.waiting =>
                      AgentActivityStatus.waiting,
                    AgentExecutionStepStatus.running =>
                      AgentActivityStatus.running,
                    AgentExecutionStepStatus.completed =>
                      AgentActivityStatus.completed,
                    AgentExecutionStepStatus.failed =>
                      AgentActivityStatus.failed,
                  },
            details: [
              if (step.status == AgentExecutionStepStatus.failed ||
                  (finished &&
                      step.status != AgentExecutionStepStatus.completed))
                l10n.agentToolFailed(
                    AgentToolPresentation.activityTitle(l10n, step.toolName)),
              ...AgentToolPresentation.activityDetails(
                  l10n, step.toolName, step.arguments, step.result),
            ].take(8).toList(growable: false),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = streamingText?.trim() ?? '';
    final visibleSteps =
        displaySteps ?? projectSteps(l10n, steps, finished: !isStreaming);
    if (visibleSteps.isEmpty && text.isEmpty && !isStreaming) {
      return const SizedBox.shrink();
    }
    final active = visibleSteps.reversed
        .where((step) =>
            step.status == AgentActivityStatus.running ||
            step.status == AgentActivityStatus.waiting)
        .firstOrNull;
    final failed =
        visibleSteps.any((step) => step.status == AgentActivityStatus.failed);
    final status = active?.status ??
        (isStreaming
            ? switch (modelPhase) {
                AgentNativeModelPhase.awaitingResponse =>
                  AgentActivityStatus.awaitingModel,
                AgentNativeModelPhase.thinking => AgentActivityStatus.thinking,
                AgentNativeModelPhase.generating =>
                  AgentActivityStatus.generating,
                null => visibleSteps.isEmpty && text.isEmpty
                    ? AgentActivityStatus.preparing
                    : AgentActivityStatus.generating,
              }
            : failed
                ? AgentActivityStatus.failed
                : AgentActivityStatus.completed);
    final summary = switch (status) {
      AgentActivityStatus.preparing => l10n.agentActivityPreparing,
      AgentActivityStatus.awaitingModel => l10n.agentActivityAwaitingModel,
      AgentActivityStatus.thinking => l10n.agentActivityThinking,
      AgentActivityStatus.generating => l10n.agentActivityGenerating,
      AgentActivityStatus.waiting => l10n.agentPermissionWaiting,
      AgentActivityStatus.running => l10n.agentExecutingTool(active!.title),
      AgentActivityStatus.failed => l10n.agentExecutionFailedSummary,
      AgentActivityStatus.completed =>
        l10n.agentExecutionCompletedSummary(visibleSteps.length),
    };
    return Column(
        key: const ValueKey('agent-execution-timeline'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isStreaming || visibleSteps.isNotEmpty)
            AgentActivityView(
                summary: summary,
                status: status,
                steps: visibleSteps,
                expandWhileActive: isStreaming),
          if (text.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: AgentMarkdownText(
                    data: streamingText!,
                    style: TextStyle(
                        color: BeeTokens.textPrimary(context),
                        fontSize: 14,
                        height: 1.5))),
        ]);
  }
}
