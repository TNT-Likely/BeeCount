import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../providers.dart';
import '../../../../providers/ai_chat_providers.dart';
import '../../../shared/formatting/amount_text.dart';

typedef AgentStartPrompt = void Function(String text,
    {required bool readOnly, required bool review});

enum _StartAction { review, food, record, compare, shopping, categories }

extension on _StartAction {
  String label(AppLocalizations l) => switch (this) {
        _StartAction.review => l.aiChatStartReview,
        _StartAction.food => l.aiChatStartFood,
        _StartAction.record => l.aiChatStartRecord,
        _StartAction.compare => l.aiChatStartCompare,
        _StartAction.shopping => l.aiChatStartShopping,
        _StartAction.categories => l.agentFollowUpCategoryTitle,
      };

  String get icon => switch (this) {
        _StartAction.review => 'ChartColumn',
        _StartAction.food => 'Utensils',
        _StartAction.record => 'PencilLine',
        _StartAction.compare => 'TrendingDown',
        _StartAction.shopping => 'ShoppingBag',
        _StartAction.categories => 'ChartPie',
      };

  void run(AppLocalizations l, AiChatStartRange range,
      AgentStartPrompt? onPrompt, VoidCallback? onRecord) {
    final start = _isoDay(range.start);
    final end = _isoDay(_inclusiveEnd(range));
    final prompt = switch (this) {
      _StartAction.review => l.aiChatStartReviewPrompt(start, end),
      _StartAction.food => l.aiChatStartFoodPrompt(start, end),
      _StartAction.compare => l.aiChatStartComparePrompt(start, end),
      _StartAction.shopping => l.aiChatStartShoppingPrompt(start, end),
      _StartAction.categories => l.agentFollowUpCategoryPrompt(
          l.agentFollowUpRange(start, _isoDay(range.end))),
      _StartAction.record => null,
    };
    if (prompt == null) {
      onRecord?.call();
    } else {
      onPrompt?.call(prompt,
          readOnly: true, review: this == _StartAction.review);
    }
  }
}

DateTime _inclusiveEnd(AiChatStartRange range) =>
    range.end.subtract(const Duration(microseconds: 1));

String _isoDay(DateTime value) => value.toIso8601String().split('T').first;

String _periodLabel(
    BuildContext context, AiChatStartRange range, AppLocalizations l) {
  if (range.scope == 'all') return l.v4DetailAllTime;
  final locale = Localizations.localeOf(context).toString();
  final start = range.start, last = _inclusiveEnd(range);
  final sameYear = start.year == last.year;
  final sameMonth = sameYear && start.month == last.month;
  final startFormat = start.year == DateTime.now().year && sameYear
      ? DateFormat.MMMd(locale)
      : DateFormat.yMMMd(locale);
  if (DateUtils.isSameDay(start, last)) return startFormat.format(start);
  final endFormat = sameMonth
      ? DateFormat.d(locale)
      : sameYear
          ? DateFormat.MMMd(locale)
          : DateFormat.yMMMd(locale);
  return '${startFormat.format(start)} – ${endFormat.format(last)}';
}

Future<void> showAgentQuickActions(BuildContext context,
    {required Map<String, Object?> view,
    required AgentStartPrompt onPrompt,
    required VoidCallback onRecord}) async {
  final l = AppLocalizations.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final current = container.read(aiChatCurrentStartRangeProvider);
  final range = aiChatInsightsRange(view, current.ledgerId) ?? current;
  final chosen = await showBeeSheet<_StartAction>(
    Navigator.of(context).context,
    title: l.aiChatStartQuickActions,
    child: Builder(
        builder: (sheetContext) => ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final action in [
                  _StartAction.review,
                  _StartAction.record,
                  _StartAction.food
                ])
                  BeeMenuRow(
                      title: action.label(l),
                      leading: BeeLineIcon(action.icon),
                      onTap: () => Navigator.pop(sheetContext, action)),
              ],
            )),
  );
  if (!context.mounted ||
      chosen == null ||
      container.read(currentLedgerIdProvider) != range.ledgerId) {
    return;
  }
  chosen.run(l, range, onPrompt, onRecord);
}

/// The empty thread has its own local data and never sends a prompt on mount.
final class AgentEmptyConversation extends ConsumerStatefulWidget {
  const AgentEmptyConversation(
      {super.key,
      this.view = const {},
      this.onPrompt,
      this.onConfigureModel,
      this.onRecord});
  final Map<String, Object?> view;
  final AgentStartPrompt? onPrompt;
  final VoidCallback? onConfigureModel, onRecord;

  @override
  ConsumerState<AgentEmptyConversation> createState() =>
      _AgentEmptyConversationState();
}

class _AgentEmptyConversationState
    extends ConsumerState<AgentEmptyConversation> {
  bool _secondGroup = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final scope = aiChatInsightsRange(widget.view, ledgerId);
    final summaryProvider = aiChatStartSummaryProvider(scope);
    final configuration = ref.watch(aiChatTextModelConfiguredProvider);
    Widget loading() => BeeEmptyState(
        icon: const BeeLineIcon('Clock', size: 30),
        title: l.aiChatStartLoading);
    Widget failure(VoidCallback retry) => BeeEmptyState(
          icon: const BeeLineIcon('TriangleAlert', size: 32),
          title: l.aiChatStartLoadError,
          action: BeeButton(label: l.helpCenterRetry, onPressed: retry),
        );
    return configuration.when(
      skipLoadingOnRefresh: false,
      loading: loading,
      error: (_, __) =>
          failure(() => ref.invalidate(aiChatTextModelConfiguredProvider)),
      data: (ready) {
        if (!ready) {
          return BeeEmptyState(
              icon: const BeeLineIcon('SlidersHorizontal', size: 34),
              title: l.aiChatStartNoModel,
              message: l.aiChatStartNoModelDetail,
              action: BeeButton(
                  label: l.aiChatStartModelSettings,
                  onPressed: widget.onConfigureModel));
        }
        return ref.watch(summaryProvider).when(
              skipLoadingOnRefresh: false,
              loading: loading,
              error: (_, __) => failure(() => ref.invalidate(summaryProvider)),
              data: (summary) {
                if (!summary.ledgerHasTransactions) {
                  return BeeEmptyState(
                      icon: const BeeLineIcon('BookOpen', size: 34),
                      title: l.aiChatStartNoBills,
                      message: l.aiChatStartNoBillsDetail,
                      action: BeeButton(
                          label: l.aiChatStartRecord,
                          onPressed: widget.onRecord));
                }
                return _overview(context, l, summary);
              },
            );
      },
    );
  }

  Widget _overview(BuildContext context, AppLocalizations l,
      AiChatEmptyLedgerSummary summary) {
    final range = summary.range;
    final theme = Theme.of(context);
    final hidden = ref.watch(hideAmountsProvider);
    final group = _secondGroup
        ? [
            range.scope == 'all'
                ? _StartAction.categories
                : _StartAction.compare,
            _StartAction.shopping
          ]
        : [_StartAction.food, _StartAction.record];
    VoidCallback? run(_StartAction action) {
      if (action == _StartAction.record
          ? widget.onRecord == null
          : widget.onPrompt == null) {
        return null;
      }
      return () => action.run(l, range, widget.onPrompt, widget.onRecord);
    }

    return ListView(
      key: const ValueKey('ai-chat-start-overview'),
      padding: const EdgeInsets.fromLTRB(17, 18, 17, 14),
      children: [
        Text(l.aiChatStartTitle,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.5)),
        const SizedBox(height: 15),
        BeeConversationOverviewCard(
          period: _periodLabel(context, range, l),
          amountLabel: l.aiChatStartExpense,
          amount: AmountText(
              value: summary.expense,
              signed: false,
              showCurrency: true,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          countLabel: l.aiChatStartExpenseCount(summary.expenseCount),
          trendLabel: l.aiChatStartTrend,
          points: summary.cumulativeExpense,
          showTrend: !hidden,
          reviewLabel: l.aiChatStartReview,
          onReview: run(_StartAction.review),
        ),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(
              child: Text(l.aiChatStartTopics,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700))),
          TextButton.icon(
              style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant),
              onPressed: () => setState(() => _secondGroup = !_secondGroup),
              icon: const BeeLineIcon('RefreshCw', size: 14),
              label: Text(l.agentFollowUpRotate)),
        ]),
        BeeSurface(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final action in group)
                BeeMenuRow(
                  title: action.label(l),
                  leading: BeeLineIcon(action.icon),
                  trailing: const BeeLineIcon('ArrowUpRight', size: 16),
                  divider: action != group.last,
                  onTap: run(action),
                ),
            ])),
      ],
    );
  }
}
