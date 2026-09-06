import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../ai/core/bill_info.dart';
import '../../widgets/biz/section_card.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
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

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 8.0.scaled(context, ref),
      ),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题（账本名称在右上角）
            Row(
              children: [
                Icon(
                  isUndone ? Icons.cancel : Icons.check_circle,
                  color: isUndone ? Colors.grey : Colors.green,
                  size: 20.0.scaled(context, ref),
                ),
                SizedBox(width: 8.0.scaled(context, ref)),
                Text(
                  isUndone ? l10n.billCardUndone : l10n.billCardSuccess,
                  style: TextStyle(
                    fontSize: 16.0.scaled(context, ref),
                    fontWeight: FontWeight.w600,
                    color: isUndone
                        ? BeeTokens.textSecondary(context)
                        : BeeTokens.textPrimary(context),
                  ),
                ),
                const Spacer(),
                // 账本名称（右上角，可点击修改）
                _buildLedgerChip(context, ref, ledgerName),
              ],
            ),

            SizedBox(height: 12.0.scaled(context, ref)),
            Divider(color: BeeTokens.divider(context)),
            SizedBox(height: 12.0.scaled(context, ref)),

            // 信息行
            _buildInfoRow(
              context,
              ref,
              l10n.billCardAmount,
              formatBalanceFull(billInfo.amount?.abs() ?? 0, currency),
            ),
            SizedBox(height: 8.0.scaled(context, ref)),
            _buildInfoRow(
              context,
              ref,
              l10n.billCardCategory,
              billInfo.category ?? l10n.commonOther,
            ),
            SizedBox(height: 8.0.scaled(context, ref)),
            _buildInfoRow(
              context,
              ref,
              l10n.billCardTime,
              _formatTime(context, billInfo.time),
            ),
            if (billInfo.type != null) ...[
              SizedBox(height: 8.0.scaled(context, ref)),
              _buildInfoRow(
                context,
                ref,
                l10n.billCardType,
                _formatType(l10n, billInfo.type!),
              ),
            ],
            SizedBox(height: 8.0.scaled(context, ref)),
            _buildInfoRow(context, ref, l10n.billCardCurrency, currency),
            if (billInfo.note != null && billInfo.note!.isNotEmpty) ...[
              SizedBox(height: 8.0.scaled(context, ref)),
              _buildInfoRow(
                context,
                ref,
                l10n.billCardNote,
                billInfo.note!,
              ),
            ],
            if (_accountSummary != null) ...[
              SizedBox(height: 8.0.scaled(context, ref)),
              _buildInfoRow(
                context,
                ref,
                billInfo.type == BillType.transfer
                    ? l10n.billCardTransferAccounts
                    : l10n.billCardAccount,
                _accountSummary!,
              ),
            ],
            if (_tags.isNotEmpty) ...[
              SizedBox(height: 8.0.scaled(context, ref)),
              _buildTagsRow(context, ref, l10n.billCardTags, _tags),
            ],

            SizedBox(height: 16.0.scaled(context, ref)),

            // 操作按钮
            if (!isUndone)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onUndo != null)
                    TextButton(
                      onPressed: onUndo,
                      child: Text(
                        AppLocalizations.of(context).billCardUndo,
                        style: TextStyle(
                          color: BeeTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  if (onUndo != null && onEdit != null)
                    SizedBox(width: 8.0.scaled(context, ref)),
                  if (onEdit != null)
                    TextButton(
                      onPressed: onEdit,
                      child: Text(
                        AppLocalizations.of(context).billCardEdit,
                        style: TextStyle(
                          color: ref.watch(primaryColorProvider),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
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

  Widget _buildInfoRow(
    BuildContext context,
    WidgetRef ref,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80.0.scaled(context, ref),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.0.scaled(context, ref),
              color: BeeTokens.textSecondary(context),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14.0.scaled(context, ref),
              color: BeeTokens.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsRow(
    BuildContext context,
    WidgetRef ref,
    String label,
    List<String> tags,
  ) {
    final primaryColor = ref.watch(primaryColorProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80.0.scaled(context, ref),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.0.scaled(context, ref),
              color: BeeTokens.textSecondary(context),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6.0.scaled(context, ref),
            runSpacing: 6.0.scaled(context, ref),
            children: [
              for (final tag in tags)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.0.scaled(context, ref),
                    vertical: 3.0.scaled(context, ref),
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(10.0.scaled(context, ref)),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12.0.scaled(context, ref),
                      color: primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatType(AppLocalizations l10n, BillType type) {
    return switch (type) {
      BillType.expense => l10n.billCardExpense,
      BillType.income => l10n.billCardIncome,
      BillType.transfer => l10n.billCardTransfer,
    };
  }

  /// 账本芯片（显示在右上角）
  Widget _buildLedgerChip(
    BuildContext context,
    WidgetRef ref,
    String ledgerName,
  ) {
    final canChange = onChangeLedger != null && !isUndone;

    return GestureDetector(
      onTap: canChange ? onChangeLedger : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 8.0.scaled(context, ref),
          vertical: 4.0.scaled(context, ref),
        ),
        decoration: BoxDecoration(
          color: canChange
              ? ref.watch(primaryColorProvider).withOpacity(0.1)
              : BeeTokens.textSecondary(context).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.0.scaled(context, ref)),
          border: canChange
              ? Border.all(
                  color: ref.watch(primaryColorProvider).withOpacity(0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book,
              size: 12.0.scaled(context, ref),
              color: canChange
                  ? ref.watch(primaryColorProvider)
                  : BeeTokens.textSecondary(context),
            ),
            SizedBox(width: 4.0.scaled(context, ref)),
            Text(
              ledgerName,
              style: TextStyle(
                fontSize: 12.0.scaled(context, ref),
                color: canChange
                    ? ref.watch(primaryColorProvider)
                    : BeeTokens.textSecondary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (canChange) ...[
              SizedBox(width: 2.0.scaled(context, ref)),
              Icon(
                Icons.edit,
                size: 10.0.scaled(context, ref),
                color: ref.watch(primaryColorProvider),
              ),
            ],
          ],
        ),
      ),
    );
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
