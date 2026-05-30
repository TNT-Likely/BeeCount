import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/category_icon.dart';
import '../../providers/theme_providers.dart';
import 'amount_text.dart';
import 'tag_chip.dart';

class TransactionListItem extends ConsumerWidget {
  final IconData icon;
  final db.Category? category; // 可选的分类对象，用于显示自定义图标
  final String title;
  final double amount;
  final bool isExpense; // 决定正负号
  final bool isTransfer; // 是否为转账（转账不显示正负号）
  final bool isAdjustment; // 是否为估值调整
  final bool? hide; // 改为可选,null时使用全局状态
  final VoidCallback? onTap;
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

  const TransactionListItem({
      super.key,
      required this.icon,
      this.category,
      required this.title,
      required this.amount,
      required this.isExpense,
      this.isTransfer = false,
      this.isAdjustment = false,
      this.hide,
      this.onTap,
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
  });


  /// 检查是否有次要信息需要显示（时间、账户或附件）
  bool _hasSecondaryInfo(WidgetRef ref) {
    // 显示完整日期模式
    if (showFullDate && happenedAt != null) return true;

    // 显示时间（设置开启 + 有数据 + 不是00:00:00）
    final showTime = ref.watch(showTransactionTimeProvider) &&
        happenedAt != null &&
        (happenedAt!.hour != 0 || happenedAt!.minute != 0 || happenedAt!.second != 0);

    return showTime || accountName != null || attachmentCount > 0;
  }

  /// 构建次要信息小部件（时间 · 账户 + 附件图标）
  Widget _buildSecondaryInfo(BuildContext context, WidgetRef ref) {
    final parts = <String>[];

    // 时间部分
    if (happenedAt != null) {
      if (showFullDate) {
        // 完整日期模式
        parts.add(
          '${happenedAt!.year}-${happenedAt!.month.toString().padLeft(2, '0')}-${happenedAt!.day.toString().padLeft(2, '0')} '
          '${happenedAt!.hour.toString().padLeft(2, '0')}:${happenedAt!.minute.toString().padLeft(2, '0')}',
        );
      } else if (ref.watch(showTransactionTimeProvider) &&
          (happenedAt!.hour != 0 || happenedAt!.minute != 0 || happenedAt!.second != 0)) {
        // 完整时间模式（HH:mm:ss）
        parts.add(
          '${happenedAt!.hour.toString().padLeft(2, '0')}:${happenedAt!.minute.toString().padLeft(2, '0')}:${happenedAt!.second.toString().padLeft(2, '0')}',
        );
      }
    }

    // 账户部分
    if (accountName != null) {
      parts.add(accountName!);
    }

    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: BeeTokens.textTertiary(context),
      fontSize: 11,
    );

    // 构建附件图标部件（可点击）
    Widget buildAttachmentWidget() {
      final widget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 12,
            color: BeeTokens.textTertiary(context),
          ),
          const SizedBox(width: 2),
          Text('$attachmentCount', style: textStyle),
        ],
      );
      if (onAttachmentTap != null) {
        return GestureDetector(
          onTap: onAttachmentTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: widget,
          ),
        );
      }
      return widget;
    }

    // 如果只有附件，没有其他信息
    if (parts.isEmpty && attachmentCount > 0) {
      return buildAttachmentWidget();
    }

    // 有其他信息时
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(parts.join(' · '), style: textStyle),
        if (attachmentCount > 0) ...[
          Text(' · ', style: textStyle),
          buildAttachmentWidget(),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget child = InkWell(
      onTap: isSelectionMode ? onSelectionChanged : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: BeeDimens.listRowVertical),
        child: Row(
          children: [
            // 选择模式下显示复选框，否则显示分类图标
            if (isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onSelectionChanged?.call(),
                activeColor: Theme.of(context).colorScheme.primary,
              )
            else
              // 分类图标，支持点击跳转
              GestureDetector(
                onTap: onCategoryTap,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: CategoryIconWidget(
                    category: category,
                    size: 18,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            // 左侧：分类名称 + 备注 + 时间·账户
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 第一行：分类名（常驻）+ 备注接在后面（括号、次要色、整体单行省略，对齐 web 端）
                    Row(
                      children: [
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              text: categoryName ?? title,
                              style: BeeTextTokens.title(context),
                              children: [
                                if (categoryName != null && title.isNotEmpty && title != categoryName)
                                  TextSpan(
                                    text: '  ($title)',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: BeeTokens.textSecondary(context),
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 全部账本模式：展示账本名标签（参考账户详情页）
                        if (ledgerName != null && ledgerName!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ref.watch(primaryColorProvider).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ledgerName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: ref.watch(primaryColorProvider),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // 第三行：时间 · 账户 · 附件
                    if (_hasSecondaryInfo(ref))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _buildSecondaryInfo(context, ref),
                      ),
                  ],
                ),
              ),
            ),
            // 右侧：金额 + 标签
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 金额（转账不显示正负号）
                AmountText(
                    value: isAdjustment
                        ? amount // adjustment 直接显示原始值（含正负）
                        : isExpense ? -amount : amount,
                    hide: hide,
                    signed: !isTransfer, // 转账不显示正负号
                    decimals: 2,
                    style: BeeTextTokens.title(context).copyWith(
                      color: isAdjustment
                          ? (amount >= 0
                              ? BeeTokens.incomeColor(context, ref)
                              : BeeTokens.expenseColor(context, ref))
                          : isTransfer
                              ? BeeTokens.textPrimary(context)
                              : isExpense
                                  ? BeeTokens.expenseColor(context, ref)
                                  : BeeTokens.incomeColor(context, ref),
                    )),
                // 标签（显示在金额下方）
                if (tags != null && tags!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TagChipList(
                      tags: tags!,
                      maxDisplay: 2,
                      size: TagChipSize.small,
                      spacing: 4,
                      onTagTap: onTagTap,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    // 如果提供了删除回调，则包装在Dismissible中支持侧滑删除
    if (onDelete != null) {
      return Dismissible(
        key: ValueKey('transaction_$title${amount.toString()}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 24,
          ),
        ),
        confirmDismiss: (direction) async {
          // 显示确认对话框
          return await AppDialog.confirm<bool>(
            context,
            title: '确认删除',
            message: '确定要删除这笔交易吗？此操作无法撤销。',
          ) ?? false;
        },
        onDismissed: (direction) {
          onDelete!();
        },
        child: child,
      );
    }

    return child;
  }
}
