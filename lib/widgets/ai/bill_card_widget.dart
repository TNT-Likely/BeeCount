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
                  isUndone
                      ? AppLocalizations.of(context).billCardUndone
                      : AppLocalizations.of(context).billCardSuccess,
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
              AppLocalizations.of(context).billCardAmount,
              '¥${billInfo.amount?.abs().toStringAsFixed(2) ?? '0.00'}',
            ),
            SizedBox(height: 8.0.scaled(context, ref)),
            _buildInfoRow(
              context,
              ref,
              AppLocalizations.of(context).billCardCategory,
              billInfo.category ?? AppLocalizations.of(context).commonOther,
            ),
            SizedBox(height: 8.0.scaled(context, ref)),
            _buildInfoRow(
              context,
              ref,
              AppLocalizations.of(context).billCardTime,
              _formatTime(context, billInfo.time),
            ),
            if (billInfo.note != null && billInfo.note!.isNotEmpty) ...[
              SizedBox(height: 8.0.scaled(context, ref)),
              _buildInfoRow(
                context,
                ref,
                AppLocalizations.of(context).billCardNote,
                billInfo.note!,
              ),
            ],
            if (billInfo.account != null && billInfo.account!.isNotEmpty) ...[
              SizedBox(height: 8.0.scaled(context, ref)),
              _buildInfoRow(
                context,
                ref,
                AppLocalizations.of(context).billCardAccount,
                billInfo.account!,
              ),
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
