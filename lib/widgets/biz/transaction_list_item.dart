import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../presentation/v4/bindings/recording_category_icon.dart';
import '../../utils/currencies.dart';
import '../../providers/database_providers.dart';
import '../../providers/theme_providers.dart';
import 'format_money.dart';
import 'transaction_row_title.dart';

class TransactionListItem extends ConsumerWidget {
  final IconData icon;
  final db.Category? category; // 可选的分类对象，用于显示自定义图标
  final String title;
  final double amount;

  /// v30 多币种:交易原币种(null/等于账本本位币 → 维持无符号纯数字;
  /// 外币 → 金额前显示其币种符号,如 JP¥/US$,一眼区分原币)。
  final String? currencyCode;

  /// v30 多币种:折账本本位币快照。外币交易在金额右下角显示 ≈ 折算小字(反馈13)。
  final double? nativeAmount;
  final bool isExpense; // 决定正负号
  final bool isTransfer; // 是否为转账（转账不显示正负号）
  final bool? hide; // 改为可选,null时使用全局状态
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final VoidCallback? onCategoryTap; // 点击分类图标/名称的回调
  final String? categoryName; // 分类名称，用于显示
  final String? ledgerName; // 账本名称（仅"全部账本"模式下显示标签）
  final VoidCallback? onDelete; // 删除回调
  final String? accountName; // 账户名称，用于显示
  final DateTime? happenedAt; // 交易时间，用于显示时分

  // 批量选择模式相关
  final bool isSelectionMode; // 是否处于选择模式
  final bool isSelected; // 是否被选中
  final VoidCallback? onSelectionChanged; // 选中状态改变回调
  final bool showFullDate; // 是否显示完整日期（年-月-日 时:分）

  // 标签相关
  final List<({int id, String name, String? color})>? tags; // 关联的标签
  final void Function(int tagId, String tagName)? onTagTap; // 点击标签回调

  // 附件相关
  final int attachmentCount; // 附件数量
  final VoidCallback? onAttachmentTap; // 点击附件图标回调

  final bool excludeFromStats; // 不计入收支:第二行显示「不计收支」标签
  final bool excludeFromBudget; // 不计入预算:第二行显示「不计预算」标签

  const TransactionListItem({
    super.key,
    required this.icon,
    this.category,
    required this.title,
    required this.amount,
    this.currencyCode,
    this.nativeAmount,
    required this.isExpense,
    this.isTransfer = false,
    this.hide,
    this.onTap,
    this.onLongPressStart,
    this.onCategoryTap,
    this.categoryName,
    this.ledgerName,
    this.onDelete,
    this.accountName,
    this.happenedAt,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionChanged,
    this.showFullDate = false,
    this.tags,
    this.onTagTap,
    this.attachmentCount = 0,
    this.onAttachmentTap,
    this.excludeFromStats = false,
    this.excludeFromBudget = false,
  });

  Color _tagColor(String? value, BuildContext context) {
    if (value == null) return Theme.of(context).colorScheme.primary;
    final hex = value.replaceFirst('#', '');
    final parsed = int.tryParse(hex.length == 6 ? 'ff$hex' : hex, radix: 16);
    return parsed == null
        ? Theme.of(context).colorScheme.primary
        : Color(parsed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hidden = hide ?? ref.watch(hideAmountsProvider) ?? false;
    final base = currencyCode == null || currencyCode!.isEmpty
        ? 'CNY'
        : ref.watch(currentLedgerProvider).valueOrNull?.currency ?? 'CNY';
    final foreign = currencyCode != null &&
        currencyCode!.isNotEmpty &&
        currencyCode!.toUpperCase() != base.toUpperCase();
    final composed = composeTransactionRowTitle(
        mode: ref.watch(noteDisplayModeProvider),
        categoryName: categoryName,
        title: title);
    final value = isTransfer ? amount : (isExpense ? -amount : amount);
    final money =
        '${foreign ? getCurrencySymbol(currencyCode!.toUpperCase()) : ''}'
        '${formatMoneyCompact(value, signed: !isTransfer)}';
    final hasConversion =
        foreign && nativeAmount != null && nativeAmount != amount;
    final row = BeeTransactionRow(
      title: composed.primary,
      note: composed.parenNote,
      amount: money,
      hidden: hidden,
      amountColor: isTransfer
          ? BeeTokens.textPrimary(context)
          : isExpense
              ? BeeTokens.expenseColor(context, ref)
              : BeeTokens.incomeColor(context, ref),
      converted: hasConversion ? '≈${nativeAmount!.toStringAsFixed(2)}' : null,
      icon: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: BeeCardTheme.of(context).soft,
              borderRadius: BorderRadius.circular(12)),
          child: Center(
              child: category == null
                  ? Icon(icon,
                      size: 19, color: Theme.of(context).colorScheme.onSurface)
                  : RecordingCategoryIcon(
                      category: category!,
                      size: 19,
                      color: Theme.of(context).colorScheme.onSurface))),
      kind: isTransfer
          ? BeeTransactionKind.transfer
          : isExpense
              ? BeeTransactionKind.expense
              : BeeTransactionKind.income,
      accountName: accountName,
      ledgerName: ledgerName,
      happenedAt: happenedAt,
      showTime: ref.watch(showTransactionTimeProvider),
      showFullDate: showFullDate,
      selected: isSelectionMode ? isSelected : null,
      onSelected: (_) => onSelectionChanged?.call(),
      tags: (tags ?? [])
          .map(
              (t) => BeeTagData('${t.id}', t.name, _tagColor(t.color, context)))
          .toList(),
      onTagTap: (t) => onTagTap?.call(int.parse(t.id), t.label),
      attachmentCount: attachmentCount,
      onAttachmentTap: onAttachmentTap,
      statusLabels: [
        if (excludeFromStats) l10n.txFlagExcludedTag,
        if (excludeFromBudget) l10n.txFlagBudgetExcludedTag
      ],
      onTap: onTap ?? () {},
      onCategoryTap: onCategoryTap ?? () {},
      deleteLabel: l10n.commonDelete,
      onDeleteRequested: onDelete == null || isSelectionMode
          ? null
          : () async {
              final confirmed = await AppDialog.confirm<bool>(context,
                  title: l10n.deleteConfirmTitle,
                  message: l10n.deleteConfirmMessage);
              if (confirmed == true) onDelete!();
            },
    );
    return GestureDetector(
      onLongPressStart: isSelectionMode ? null : onLongPressStart,
      child: Padding(padding: const EdgeInsets.only(right: 12), child: row),
    );
  }
}
