import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/ai_chat_providers.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../biz/amount_text.dart';
import 'agent_brand_mark.dart';

/// Quiet, ledger-aware starting point for an empty AI conversation.
///
/// The input composer remains the primary action. This widget only gives the
/// user enough current-ledger context to start a useful conversation.
final class AgentEmptyConversation extends ConsumerWidget {
  const AgentEmptyConversation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(aiChatEmptyLedgerSummaryProvider);
    return summary.when(
      data: (data) => _AgentEmptyConversationContent(summary: data),
      loading: () => const _AgentEmptyConversationContent(),
      error: (_, __) => const _AgentEmptyConversationContent(),
    );
  }
}

final class _AgentEmptyConversationContent extends ConsumerWidget {
  const _AgentEmptyConversationContent({this.summary});

  final AiChatEmptyLedgerSummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasSummary = summary?.hasTransactionData ?? false;
    // Do not briefly present the "first transaction" copy for a populated
    // ledger while Drift resolves its initial stream event.
    final showGeneralStart = summary == null || hasSummary;
    final maxWidth = 280.0.scaled(context, ref);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.0.scaled(context, ref)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSummary) ...[
                Text(
                  '${MaterialLocalizations.of(context).formatMonthYear(summary!.period)} '
                  '· ${l10n.aiChatEmptyCurrentLedger}',
                  style: BeeTextTokens.label(context).copyWith(
                    color: BeeTokens.textTertiary(context),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 16.0.scaled(context, ref)),
              ],
              AgentBrandMark(
                size: 32.0.scaled(context, ref),
                showBackground: true,
              ),
              SizedBox(height: 14.0.scaled(context, ref)),
              Text(
                showGeneralStart
                    ? l10n.aiChatEmptyStartTitle
                    : l10n.aiChatEmptyFirstTransactionTitle,
                textAlign: TextAlign.center,
                style: BeeTextTokens.boldTitle(context).copyWith(
                  fontSize: 19.0.scaled(context, ref),
                  letterSpacing: -0.35,
                ),
              ),
              SizedBox(height: 8.0.scaled(context, ref)),
              Text(
                showGeneralStart
                    ? l10n.aiChatEmptyStartDescription
                    : l10n.aiChatEmptyFirstTransactionDescription,
                textAlign: TextAlign.center,
                style: BeeTextTokens.label(context).copyWith(
                  color: BeeTokens.textSecondary(context),
                  height: 1.45,
                ),
              ),
              if (hasSummary) ...[
                SizedBox(height: 20.0.scaled(context, ref)),
                _LedgerBrief(summary: summary!),
              ],
              SizedBox(
                  height: hasSummary
                      ? 18.0.scaled(context, ref)
                      : 23.0.scaled(context, ref)),
              _ExamplePrompt(
                text: hasSummary
                    ? l10n.aiChatEmptyQuestionExample
                    : l10n.aiChatEmptyFirstTransactionExample,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _LedgerBrief extends ConsumerWidget {
  const _LedgerBrief({required this.summary});

  final AiChatEmptyLedgerSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final border = BeeTokens.divider(context);
    return Container(
      width: 238.0.scaled(context, ref),
      padding: EdgeInsets.symmetric(vertical: 13.0.scaled(context, ref)),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _LedgerMetric(
              value: AmountText(
                value: summary.expense,
                signed: false,
                decimals: 2,
                showCurrency: true,
                style: BeeTextTokens.strongTitle(context).copyWith(
                  fontSize: 16.0.scaled(context, ref),
                  fontWeight: FontWeight.w700,
                ),
              ),
              label: l10n.aiChatEmptyMonthExpense,
            ),
          ),
          Container(width: 1, height: 35.0.scaled(context, ref), color: border),
          Expanded(
            child: _LedgerMetric(
              value: Text(
                l10n.aiChatEmptyTransactionCount(summary.transactionCount),
                textAlign: TextAlign.center,
                style: BeeTextTokens.strongTitle(context).copyWith(
                  fontSize: 16.0.scaled(context, ref),
                  fontWeight: FontWeight.w700,
                ),
              ),
              label: l10n.aiChatEmptyRecordedTransactions,
            ),
          ),
        ],
      ),
    );
  }
}

final class _LedgerMetric extends StatelessWidget {
  const _LedgerMetric({required this.value, required this.label});

  final Widget value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        value,
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: BeeTextTokens.label(context).copyWith(
            color: BeeTokens.textTertiary(context),
          ),
        ),
      ],
    );
  }
}

final class _ExamplePrompt extends StatelessWidget {
  const _ExamplePrompt({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.north_east_rounded,
          size: 15,
          color: BeeTokens.textTertiary(context),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: BeeTextTokens.label(context).copyWith(
              color: BeeTokens.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }
}
