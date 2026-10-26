import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ai_chat_providers.dart';
import '../biz/amount_text.dart';
import 'agent_brand_mark.dart';

/// Real ledger summary is loaded here; the presentational package owns no data.
final class AgentEmptyConversation extends ConsumerWidget {
  const AgentEmptyConversation({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget content(AiChatEmptyLedgerSummary? summary) {
      final l = AppLocalizations.of(context),
          hasSummary = summary?.hasTransactionData ?? false;
      final general = summary == null || hasSummary;
      return BeeConversationStart(
          title: general
              ? l.aiChatEmptyStartTitle
              : l.aiChatEmptyFirstTransactionTitle,
          description: general
              ? l.aiChatEmptyStartDescription
              : l.aiChatEmptyFirstTransactionDescription,
          example: hasSummary
              ? l.aiChatEmptyQuestionExample
              : l.aiChatEmptyFirstTransactionExample,
          brand: const AgentBrandMark(size: 32, showBackground: true),
          period: hasSummary
              ? '${MaterialLocalizations.of(context).formatMonthYear(summary!.period)} · ${l.aiChatEmptyCurrentLedger}'
              : null,
          summary: hasSummary
              ? BeeConversationLedgerBrief(
                  amount: AmountText(
                      value: summary!.expense,
                      signed: false,
                      decimals: 2,
                      showCurrency: true,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  count:
                      l.aiChatEmptyTransactionCount(summary.transactionCount),
                  amountLabel: l.aiChatEmptyMonthExpense,
                  countLabel: l.aiChatEmptyRecordedTransactions)
              : null);
    }

    return ref.watch(aiChatEmptyLedgerSummaryProvider).when(
        data: content,
        loading: () => content(null),
        error: (_, __) => content(null));
  }
}
