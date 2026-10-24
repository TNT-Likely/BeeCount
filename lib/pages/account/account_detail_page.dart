import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../presentation/v4/bindings/account_detail.dart';
import '../../presentation/v4/bindings/account_detail_sections.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../presentation/v4/bindings/transaction_tile.dart';
import '../../providers.dart';
import '../../utils/account_type_utils.dart';
import '../transaction/transaction_editor_page.dart';
import 'account_edit_page.dart';

export '../../presentation/v4/bindings/account_detail.dart'
    show
        AccountTransactionsPaginationState,
        AccountTransactionsPaginationNotifier,
        accountTransactionsPaginatedProvider,
        accountCategoryStatsProvider;

class AccountDetailPage extends ConsumerStatefulWidget {
  const AccountDetailPage({super.key, required this.account});
  final db.Account account;
  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {
  final _scroll = ScrollController();
  String? _flow;
  String _chart = 'expense';
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 200) {
      ref
          .read(accountTransactionsPaginatedProvider(
              (accountId: widget.account.id, flow: _flow)).notifier)
          .loadMore();
    }
  }

  void _refresh() {
    ref.invalidate(accountStatsProvider(widget.account.id));
    ref.invalidate(accountCategoryStatsProvider);
    ref.invalidate(accountDetailReferencesProvider);
    ref.invalidate(accountRowMetadataProvider);
    ref
        .read(accountTransactionsPaginatedProvider(
            (accountId: widget.account.id, flow: _flow)).notifier)
        .refresh();
  }

  Future<void> _edit() async {
    final ledger = ref.read(currentLedgerProvider).valueOrNull;
    if (ledger == null) return;
    final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                AccountEditPage(account: widget.account, ledgerId: ledger.id)));
    if (changed == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _repay() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TransactionEditorPage(
                initialKind: 'transfer',
                initialToAccountId: widget.account.id,
                quickAdd: true)));
    if (mounted) _refresh();
  }

  Future<void> _value() async {
    final value = await showAccountValuationDialog(context, widget.account);
    if (value == null || !mounted) return;
    final l = AppLocalizations.of(context);
    try {
      await ref.read(repositoryProvider).updateAccountValuation(
          widget.account.id,
          isLiabilityType(widget.account.type) ? -value.abs() : value);
      if (!mounted) return;
      // The parent doesn't consume this route's result. Refresh its balances
      // through the shared tick while retaining its current scroll state.
      ref.read(statsRefreshProvider.notifier).state++;
      _refresh();
      showBeeToast(context, l.commonSave, tone: BeeTone.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${l.commonError}: $e', tone: BeeTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), account = widget.account;
    final valuation = isValuationOnlyType(account.type);
    final stats = ref.watch(accountStatsProvider(account.id));
    final page = ref.watch(accountTransactionsPaginatedProvider(
        (accountId: account.id, flow: _flow)));
    final refs = ref.watch(accountDetailReferencesProvider);
    final metadata = ref.watch(accountRowMetadataProvider(
        page.transactions.map((t) => t.id).join(',')));
    return V4PageScaffold(
      body: Column(children: [
        BeePageHeader(
            title: l.v4AccountDetailTitle,
            leading: const BackButton(),
            actions: [
              BeeIconButton(
                  label: l.accountEditTitle,
                  icon: const BeeLineIcon('PencilLine'),
                  onPressed: _edit)
            ]),
        Expanded(
            child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(17, 4, 17, 28),
                itemCount: valuation ? 1 : page.transactions.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AccountDetailSummary(
                              account: account,
                              stats: stats,
                              onRetry: () => ref
                                  .invalidate(accountStatsProvider(account.id)),
                              onRepay: _repay,
                              onValue: _value),
                          if (!valuation) ...[
                            const SizedBox(height: 12),
                            AccountDetailDistribution(
                                accountId: account.id,
                                credit: account.type == 'credit_card',
                                value: _chart,
                                onChanged: (value) =>
                                    setState(() => _chart = value)),
                            const SizedBox(height: 12),
                            BeeSegmented<String>(
                                value: _flow ?? 'all',
                                items: [
                                  BeeSegment('all', l.accountAllFlows),
                                  BeeSegment('expense', l.accountOutflows),
                                  BeeSegment('income', l.accountInflows)
                                ],
                                onChanged: (value) => setState(() =>
                                    _flow = value == 'all' ? null : value)),
                            const SizedBox(height: 12),
                            if (refs.hasError || metadata.hasError)
                              BeeStatus(
                                  label: l.commonError,
                                  tone: BeeTone.error,
                                  action: BeeButton(
                                      label: l.v4RecordingRetry,
                                      onPressed: () {
                                        ref.invalidate(
                                            accountDetailReferencesProvider);
                                        ref.invalidate(
                                            accountRowMetadataProvider);
                                      })),
                            BeeTransactionStreamHeader(
                                title: l.accountTransactionHistory,
                                count:
                                    '${page.transactions.length}${page.hasMore ? '+' : ''}',
                                actions: const []),
                          ],
                        ]);
                  }
                  if (index == page.transactions.length + 1) {
                    return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: page.error != null
                            ? BeeStatus(
                                label: l.commonError,
                                tone: BeeTone.error,
                                action: BeeButton(
                                    label: l.v4RecordingRetry,
                                    onPressed: () => ref
                                        .read(
                                            accountTransactionsPaginatedProvider((
                                          accountId: account.id,
                                          flow: _flow
                                        )).notifier)
                                        .loadMore()))
                            : page.isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : page.transactions.isEmpty
                                    ? BeeEmptyState(
                                        title: l.accountNoTransactions,
                                        icon: const BeeLineIcon('ReceiptText',
                                            size: 34))
                                    : page.hasMore
                                        ? const SizedBox(height: 20)
                                        : Center(
                                            child: Text(l.accountNoMoreData,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Theme.of(context)
                                                        .hintColor))));
                  }
                  final i = index - 1,
                      t = page.transactions[i],
                      resources = refs.valueOrNull;
                  final direction = t.accountId == account.id &&
                          t.toAccountId != account.id
                      ? -1
                      : t.toAccountId == account.id && t.accountId != account.id
                          ? 1
                          : 0;
                  return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                          color: BeeCardTheme.of(context).surface,
                          borderRadius: BorderRadius.vertical(
                              top: i == 0
                                  ? const Radius.circular(22)
                                  : Radius.zero,
                              bottom: i == page.transactions.length - 1
                                  ? const Radius.circular(22)
                                  : Radius.zero)),
                      child: Column(children: [
                        TransactionTileBinding(
                            key: ValueKey('account-transaction-${t.id}'),
                            row: (
                              t: t,
                              category: resources?.categoryFor(t),
                              account: resources?.accounts[t.accountId],
                              toAccount: resources?.accounts[t.toAccountId]
                            ),
                            tags: metadata.valueOrNull?.tags[t.id] ?? const [],
                            attachmentCount:
                                metadata.valueOrNull?.attachments[t.id] ?? 0,
                            fullDate: true,
                            allLedgers: true,
                            ledgerName: resources?.ledgers[t.ledgerId]?.name,
                            baseCurrency:
                                resources?.ledgers[t.ledgerId]?.currency,
                            transferDirection: direction,
                            onReturned: _refresh),
                        if (i < page.transactions.length - 1)
                          const Divider(height: 1, indent: 46),
                      ]));
                })),
      ]),
    );
  }
}
