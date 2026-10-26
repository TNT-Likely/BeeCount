import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../presentation/v4/bindings/account_detail.dart';
import '../../presentation/v4/bindings/account_detail_controller.dart';
import '../../presentation/v4/bindings/account_detail_sections.dart';
import '../../presentation/v4/bindings/detail_period_controls.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../presentation/v4/bindings/transaction_tile.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/currencies.dart';
import '../../widgets/biz/format_money.dart';
import '../transaction/transaction_editor_page.dart';
import 'account_edit_page.dart';

export '../../presentation/v4/bindings/account_detail.dart'
    show
        AccountTransactionsPaginationState,
        AccountTransactionsPaginationNotifier,
        accountTransactionsPaginatedProvider,
        accountCategoryStatsProvider;

part '../../presentation/v4/bindings/account_detail_actions.dart';

class AccountDetailPage extends ConsumerStatefulWidget {
  const AccountDetailPage({super.key, required this.account});
  final db.Account account;
  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage>
    with _AccountDetailActions {
  final _scroll = ScrollController();
  @override
  late final AccountDetailController c;
  @override
  int? _point;
  @override
  void initState() {
    super.initState();
    c = AccountDetailController(
        repository: ref.read(repositoryProvider), account: widget.account);
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 200) {
        unawaited(c.loadMore());
      }
    });
    unawaited(c.refresh());
  }

  @override
  void dispose() {
    _scroll.dispose();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    ref.listen(statsRefreshProvider, (_, __) => unawaited(c.refresh()));
    ref.listen(syncGenerationProvider, (_, __) => unawaited(c.refresh()));
    final refs = ref.watch(accountDetailReferencesProvider);
    return AnimatedBuilder(
        animation: c,
        builder: (context, _) => Consumer(builder: (context, ref, _) {
              final metadata = ref.watch(accountRowMetadataProvider(
                  c.rows.map((t) => t.id).join(',')));
              final valuation = isValuationOnlyType(c.account.type),
                  hidden = ref.watch(hideAmountsProvider);
              String money(double v) => hidden
                  ? '••••'
                  : '${getDistinctCurrencySymbol(c.account.currency)}${formatMoneyCompact(v, trimZeros: false)}';
              return V4PageScaffold(
                  body: Column(children: [
                BeePageHeader(
                    title: l.v4AccountDetailTitle,
                    leading: const BackButton(),
                    actions: [
                      BeeIconButton(
                          label: l.commonMore,
                          icon: const BeeLineIcon('Ellipsis'),
                          onPressed: () => _perform(_menu))
                    ]),
                Expanded(
                    child: c.error != null && c.rows.isEmpty
                        ? Center(
                            child: BeeStatus(
                                label: l.commonError,
                                tone: BeeTone.error,
                                action: BeeButton(
                                    label: l.v4RecordingRetry,
                                    onPressed: _refresh)))
                        : c.loading && c.rows.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                controller: _scroll,
                                padding:
                                    const EdgeInsets.fromLTRB(17, 4, 17, 28),
                                itemCount: valuation ? 1 : c.rows.length + 2,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          AccountDetailSummary(
                                              account: c.account,
                                              stats: AsyncData(c.stats),
                                              onRetry: _refresh,
                                              onRepay: () =>
                                                  _perform(_transfer),
                                              onValue: () => _perform(_value),
                                              ledgerCount: c.usage.length,
                                              onLedgers: () =>
                                                  _perform(_ledgers),
                                              onInfo: () => _perform(_info),
                                              actions: valuation
                                                  ? null
                                                  : Row(children: [
                                                      Expanded(
                                                          child: BeeButton(
                                                              label: c.account
                                                                          .type ==
                                                                      'credit_card'
                                                                  ? l
                                                                      .creditCardQuickRepay
                                                                  : l
                                                                      .transferTitle,
                                                              kind: BeeButtonKind
                                                                  .secondary,
                                                              icon: const BeeLineIcon(
                                                                  'ArrowLeftRight'),
                                                              onPressed: c.account
                                                                          .hidden ||
                                                                      c.account
                                                                              .id <
                                                                          0
                                                                  ? null
                                                                  : () => _perform(
                                                                      _transfer))),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                          child: BeeButton(
                                                              label: l
                                                                  .widgetQuickAddLabel,
                                                              icon:
                                                                  const BeeLineIcon(
                                                                      'Plus'),
                                                              onPressed: c.account
                                                                          .hidden ||
                                                                      c.account
                                                                              .id <
                                                                          0
                                                                  ? null
                                                                  : () => _perform(
                                                                      _record)))
                                                    ])),
                                          if (!valuation) ...[
                                            const SizedBox(height: 8),
                                            BeeCompactTabs<String>(
                                                items:
                                                    detailPeriodItems(context),
                                                value: c.period,
                                                trackHeight: 32,
                                                tapHeight: 44,
                                                onChanged: (v) {
                                                  setState(() => _point = null);
                                                  unawaited(c.choosePeriod(v));
                                                }),
                                            BeeDateRangeBar(
                                                label: detailRangeLabel(context,
                                                    c.period, c.anchor),
                                                onChoose: _period,
                                                previousLabel: c.period == 'all'
                                                    ? null
                                                    : MaterialLocalizations.of(context)
                                                        .previousMonthTooltip,
                                                nextLabel: c.period == 'all'
                                                    ? null
                                                    : MaterialLocalizations.of(context)
                                                        .nextMonthTooltip,
                                                onPrevious: () => c.choosePeriod(
                                                    c.period,
                                                    date: c.period == 'year'
                                                        ? DateTime(
                                                            c.anchor.year - 1,
                                                            c.anchor.month)
                                                        : DateTime(
                                                            c.anchor.year,
                                                            c.anchor.month -
                                                                1)),
                                                onNext: () => c.choosePeriod(c.period,
                                                    date: c.period == 'year' ? DateTime(c.anchor.year + 1, c.anchor.month) : DateTime(c.anchor.year, c.anchor.month + 1))),
                                            BeeAccountCashflowCard(
                                                title: l.v4AccountCashflow,
                                                currency: c.account.currency,
                                                incomeLabel: l.homeIncome,
                                                income: money(c.totals.income),
                                                expenseLabel: l.homeExpense,
                                                expense:
                                                    money(c.totals.expense),
                                                netLabel: l.v4AccountNetFlow,
                                                net: money(c.totals.income -
                                                    c.totals.expense),
                                                detailLabel:
                                                    l.accountCategoryBreakdown,
                                                onDetail: _distribution,
                                                note: l.v4AccountFlowRules,
                                                onNote: _info),
                                            const SizedBox(height: 12),
                                            BeeBalanceHistoryCard(
                                                title: l.accountBalanceTrend,
                                                currency: c.account.currency,
                                                values: hidden
                                                    ? const []
                                                    : c.history
                                                        .map((p) => p.balance)
                                                        .toList(),
                                                axisLabels: c.history.isEmpty
                                                    ? []
                                                    : [
                                                        MaterialLocalizations
                                                                .of(context)
                                                            .formatShortDate(c
                                                                .history
                                                                .first
                                                                .date),
                                                        '',
                                                        MaterialLocalizations
                                                                .of(context)
                                                            .formatShortDate(c
                                                                .history
                                                                .last
                                                                .date)
                                                      ],
                                                selectedLabel: c.history.isEmpty
                                                    ? ''
                                                    : money(c
                                                        .history[(_point ??
                                                                c.history
                                                                        .length -
                                                                    1)
                                                            .clamp(
                                                                0,
                                                                c.history
                                                                        .length -
                                                                    1)]
                                                        .balance),
                                                emptyLabel: hidden
                                                    ? '••••'
                                                    : l.v4AccountNoTrend,
                                                selectedIndex: _point,
                                                onSelected: (i) =>
                                                    setState(() => _point = i)),
                                            const SizedBox(height: 12),
                                            Row(children: [
                                              Expanded(
                                                  child: Text(
                                                      l
                                                          .accountTransactionHistory,
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight
                                                              .w600))),
                                              BeeIconButton(
                                                  label: l.searchTitle,
                                                  icon: const BeeLineIcon(
                                                      'Search'),
                                                  onPressed: _search),
                                              BeeIconButton(
                                                  label: l.accountAllFlows,
                                                  icon: const BeeLineIcon(
                                                      'SlidersHorizontal'),
                                                  onPressed: _filter)
                                            ]),
                                            if (c.query.isNotEmpty ||
                                                c.flow != null)
                                              Wrap(spacing: 6, children: [
                                                if (c.query.isNotEmpty)
                                                  BeeChoiceChip(
                                                      label: c.query,
                                                      selected: true,
                                                      onSelected: (_) =>
                                                          c.filter(
                                                              direction: c.flow,
                                                              text: '',
                                                              order: c.sort)),
                                                if (c.flow != null)
                                                  BeeChoiceChip(
                                                      label: c.flow == 'income'
                                                          ? l.accountInflows
                                                          : l.accountOutflows,
                                                      selected: true,
                                                      onSelected: (_) =>
                                                          c.filter(
                                                              direction: null,
                                                              text: c.query,
                                                              order: c.sort))
                                              ]),
                                          ],
                                        ]);
                                  }
                                  if (index == c.rows.length + 1) {
                                    return Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: c.error != null
                                            ? BeeStatus(
                                                label: l.commonError,
                                                tone: BeeTone.error,
                                                action: BeeButton(
                                                    label: l.v4RecordingRetry,
                                                    onPressed: _refresh))
                                            : c.loadingMore
                                                ? const Center(
                                                    child:
                                                        CircularProgressIndicator())
                                                : c.rows.isEmpty
                                                    ? BeeEmptyState(
                                                        title: l
                                                            .accountNoTransactions)
                                                    : Text(l.accountNoMoreData,
                                                        textAlign:
                                                            TextAlign.center));
                                  }
                                  final t = c.rows[index - 1],
                                      resources = refs.valueOrNull;
                                  final direction =
                                      t.accountId == c.account.id &&
                                              t.toAccountId != c.account.id
                                          ? -1
                                          : t.toAccountId == c.account.id &&
                                                  t.accountId != c.account.id
                                              ? 1
                                              : 0;
                                  return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      decoration: BoxDecoration(
                                          color:
                                              BeeCardTheme.of(context).surface,
                                          borderRadius: BorderRadius.vertical(
                                              top: index == 1
                                                  ? const Radius.circular(22)
                                                  : Radius.zero,
                                              bottom: index == c.rows.length
                                                  ? const Radius.circular(22)
                                                  : Radius.zero)),
                                      child: Column(children: [
                                        TransactionTileBinding(
                                            key: ValueKey(
                                                'account-transaction-${t.id}'),
                                            row: (
                                              t: t,
                                              category:
                                                  resources?.categoryFor(t),
                                              account: resources
                                                  ?.accounts[t.accountId],
                                              toAccount: resources
                                                  ?.accounts[t.toAccountId]
                                            ),
                                            tags: metadata
                                                    .valueOrNull?.tags[t.id] ??
                                                const [],
                                            attachmentCount: metadata
                                                    .valueOrNull
                                                    ?.attachments[t.id] ??
                                                0,
                                            fullDate: true,
                                            allLedgers: true,
                                            ledgerName: resources
                                                ?.ledgers[t.ledgerId]?.name,
                                            baseCurrency: resources
                                                ?.ledgers[t.ledgerId]?.currency,
                                            transferDirection: direction,
                                            onReturned: _refresh),
                                        if (index < c.rows.length)
                                          const Divider(height: 1, indent: 46)
                                      ]));
                                }))
              ]));
            }));
  }
}
