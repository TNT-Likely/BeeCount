import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../ai/core/bill_info.dart';
import '../../../../data/repositories/local/local_repository.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../../../providers.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/format_utils.dart';
import '../../../transaction/transaction_move.dart';

final _billLedgerProvider =
    StreamProvider.autoDispose.family<int?, int>((ref, id) {
  final repo = ref.watch(repositoryProvider);
  if (repo is! LocalRepository) {
    return Stream.fromFuture(
        repo.getTransactionById(id).then((row) => row?.ledgerId));
  }
  final tx = repo.db.transactions;
  return (repo.db.selectOnly(tx)
        ..addColumns([tx.ledgerId])
        ..where(tx.id.equals(id)))
      .watchSingleOrNull()
      .map((row) => row?.read(tx.ledgerId));
});

/// 记账成功卡片组件
class BillCardWidget extends ConsumerWidget {
  final BillInfo billInfo;
  final int? transactionId;
  final int? expectedLedgerId;
  final VoidCallback? onUndo;
  final VoidCallback? onEdit;
  final VoidCallback? onChangeLedger; // 修改账本回调
  final bool compact;
  final bool isUndone; // 是否已撤销

  const BillCardWidget({
    super.key,
    required this.billInfo,
    this.transactionId,
    this.expectedLedgerId,
    this.onUndo,
    this.onEdit,
    this.onChangeLedger,
    this.isUndone = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownership = transactionId == null || isUndone
        ? null
        : ref.watch(_billLedgerProvider(transactionId!));
    final liveLedgerId = ownership?.asData?.value;
    final scoped = expectedLedgerId != null;
    final inChatLedger =
        !scoped || ref.watch(currentLedgerIdProvider) == expectedLedgerId;
    final canAct = !scoped ||
        (inChatLedger &&
            ownership?.isLoading == false &&
            ownership?.hasError == false &&
            liveLedgerId == expectedLedgerId);
    final unavailable =
        scoped && !canAct && (!inChatLedger || ownership?.isLoading != true);
    final ledgerId = expectedLedgerId ?? liveLedgerId ?? billInfo.ledgerId;
    final ledger = ledgerId != null
        ? ref.watch(ledgerByIdProvider(ledgerId)).asData?.value
        : null;
    final ledgerName = ledger?.name != null
        ? translateLedgerName(context, ledger!.name)
        : AppLocalizations.of(context).billCardUnknownLedger;
    final currency = (billInfo.currency?.trim().isNotEmpty ?? false)
        ? billInfo.currency!.trim().toUpperCase()
        : ledger?.currency ?? 'CNY';
    final l10n = AppLocalizations.of(context);
    final hidden = ref.watch(hideAmountsProvider);
    final amount = hidden
        ? '****'
        : formatBalanceFull(billInfo.amount?.abs() ?? 0, currency);
    if (compact) {
      final theme = Theme.of(context);
      return BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          BeeLineIcon(isUndone ? 'Undo2' : 'CircleCheck', size: 18),
          const SizedBox(width: 7),
          Expanded(
              child: Text(isUndone ? l10n.billCardUndone : l10n.billCardSuccess,
                  style: theme.textTheme.titleSmall)),
          if (billInfo.time != null)
            Text(
                MaterialLocalizations.of(context)
                    .formatShortMonthDay(billInfo.time!),
                style: theme.textTheme.labelMedium),
        ]),
        if (!isUndone) ...[
          const SizedBox(height: 10),
          Text(amount,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text([
            if (billInfo.category != null) billInfo.category!,
            if (_accountSummary != null) _accountSummary!
          ].join(' · ')),
          const Divider(),
          if (unavailable)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.agentReceiptUnavailable))
          else
            BeeMenuRow(
                title: l10n.aiChatReceiptView,
                leading: const BeeLineIcon('ReceiptText', size: 18),
                onTap: !canAct
                    ? null
                    : () => showBeeSheet<void>(Navigator.of(context).context,
                            title: l10n.aiChatReceiptView,
                            child: Builder(builder: (sheet) {
                          VoidCallback? action(VoidCallback? callback) =>
                              callback == null
                                  ? null
                                  : () {
                                      Navigator.pop(sheet);
                                      callback();
                                    };
                          return SingleChildScrollView(
                              child: BillCardWidget(
                                  billInfo: billInfo,
                                  transactionId: transactionId,
                                  expectedLedgerId: expectedLedgerId,
                                  onEdit: action(onEdit),
                                  onUndo: action(onUndo),
                                  onChangeLedger: action(onChangeLedger)));
                        }))),
        ]
      ]));
    }
    if (unavailable && !isUndone) {
      return BeeEmptyState(
          title: l10n.agentReceiptUnavailable,
          icon: const BeeLineIcon('ReceiptText', size: 28));
    }
    return BeeAssistantBillCard(
        title: isUndone ? l10n.billCardUndone : l10n.billCardSuccess,
        ledger: ledgerName,
        undone: isUndone,
        undoLabel: l10n.billCardUndo,
        editLabel: l10n.billCardEdit,
        tagsLabel: l10n.billCardTags,
        tags: hidden ? const [] : _tags,
        onUndo: canAct ? onUndo : null,
        onEdit: canAct ? onEdit : null,
        onChangeLedger: canAct &&
                ledger != null &&
                isPrivateTransactionMoveLedger(ledger) &&
                ref.watch(transactionMoveAvailableProvider).valueOrNull == true
            ? onChangeLedger
            : null,
        fields: [
          BeeAssistantBillField(l10n.billCardAmount, amount),
          BeeAssistantBillField(
              l10n.billCardCategory, billInfo.category ?? l10n.commonOther),
          BeeAssistantBillField(
              l10n.billCardTime, _formatTime(context, billInfo.time)),
          if (billInfo.type != null)
            BeeAssistantBillField(
                l10n.billCardType, _formatType(l10n, billInfo.type!)),
          BeeAssistantBillField(l10n.billCardCurrency, currency),
          if (!hidden && billInfo.note != null && billInfo.note!.isNotEmpty)
            BeeAssistantBillField(l10n.billCardNote, billInfo.note!),
          if (_accountSummary != null)
            BeeAssistantBillField(
                billInfo.type == BillType.transfer
                    ? l10n.billCardTransferAccounts
                    : l10n.billCardAccount,
                _accountSummary!)
        ]);
  }

  List<String> get _tags {
    final uniqueTags = <String>{};
    for (final tag in billInfo.tags ?? const <String>[]) {
      final normalized = tag.trim();
      if (normalized.isNotEmpty) uniqueTags.add(normalized);
    }
    return uniqueTags.toList();
  }

  String? get _accountSummary {
    if (billInfo.type == BillType.transfer) {
      final from = billInfo.fromAccount?.trim();
      final to = billInfo.toAccount?.trim();
      if (from != null && from.isNotEmpty && to != null && to.isNotEmpty) {
        return '$from → $to';
      }
      if (from != null && from.isNotEmpty) return from;
      if (to != null && to.isNotEmpty) return to;
    }
    final account = billInfo.account?.trim();
    return account == null || account.isEmpty ? null : account;
  }

  String _formatType(AppLocalizations l10n, BillType type) {
    return switch (type) {
      BillType.expense => l10n.billCardExpense,
      BillType.income => l10n.billCardIncome,
      BillType.transfer => l10n.billCardTransfer,
    };
  }

  String _formatTime(BuildContext context, DateTime? time) {
    final l10n = AppLocalizations.of(context);
    if (time == null) return l10n.calendarToday;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(time.year, time.month, time.day);
    final localeName = Localizations.localeOf(context).toLanguageTag();
    final hm = DateFormat('HH:mm').format(time);

    if (targetDay == today) {
      return '${l10n.calendarToday} $hm';
    } else if (targetDay == today.subtract(const Duration(days: 1))) {
      return '${l10n.commonYesterday} $hm';
    } else if (time.year == now.year) {
      return '${DateFormat.MMMd(localeName).format(time)} $hm';
    } else {
      return '${DateFormat.yMMMd(localeName).format(time)} $hm';
    }
  }
}
