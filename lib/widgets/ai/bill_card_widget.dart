import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ai/core/bill_info.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../providers.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/format_utils.dart';

/// 记账成功卡片组件
class BillCardWidget extends ConsumerWidget {
  final BillInfo billInfo;
  final int? transactionId;
  final VoidCallback? onUndo;
  final VoidCallback? onEdit;
  final VoidCallback? onChangeLedger; // 修改账本回调
  final bool isUndone; // 是否已撤销

  const BillCardWidget({
    super.key,
    required this.billInfo,
    this.transactionId,
    this.onUndo,
    this.onEdit,
    this.onChangeLedger,
    this.isUndone = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取账本名称
    final ledger = billInfo.ledgerId != null
        ? ref.watch(ledgerByIdProvider(billInfo.ledgerId!)).asData?.value
        : null;
    final ledgerName = ledger?.name != null
        ? translateLedgerName(context, ledger!.name)
        : AppLocalizations.of(context).billCardUnknownLedger;
    final currency = (billInfo.currency?.trim().isNotEmpty ?? false)
        ? billInfo.currency!.trim().toUpperCase()
        : ledger?.currency ?? 'CNY';
    final l10n = AppLocalizations.of(context);

    return BeeAssistantBillCard(
        title: isUndone ? l10n.billCardUndone : l10n.billCardSuccess,
        ledger: ledgerName,
        undone: isUndone,
        undoLabel: l10n.billCardUndo,
        editLabel: l10n.billCardEdit,
        tagsLabel: l10n.billCardTags,
        tags: _tags,
        onUndo: onUndo,
        onEdit: onEdit,
        onChangeLedger: onChangeLedger,
        fields: [
          BeeAssistantBillField(l10n.billCardAmount,
              formatBalanceFull(billInfo.amount?.abs() ?? 0, currency)),
          BeeAssistantBillField(
              l10n.billCardCategory, billInfo.category ?? l10n.commonOther),
          BeeAssistantBillField(
              l10n.billCardTime, _formatTime(context, billInfo.time)),
          if (billInfo.type != null)
            BeeAssistantBillField(
                l10n.billCardType, _formatType(l10n, billInfo.type!)),
          BeeAssistantBillField(l10n.billCardCurrency, currency),
          if (billInfo.note != null && billInfo.note!.isNotEmpty)
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
