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
  final String? parentCategoryName; // 父级分类名称（二级分类时显示）
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
    this.parentCategoryName,
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

  /// 检查是否有次要信息需要显示（分类标签、时间、账户或附件）
  bool _hasSecondaryInfo(WidgetRef ref) {
    // 有分类名时始终显示标签，保持风格一致性
    if (categoryName != null) return true;

    // 显示完整日期模式
    if (showFullDate && happenedAt != null) return true;

    // 显示时间（设置开启 + 有数据 + 不是00:00:00）
    final showTime = ref.watch(showTransactionTimeProvider) &&
        happenedAt != null &&
        (happenedAt!.hour != 0 ||
            happenedAt!.minute != 0 ||
            happenedAt!.second != 0);

    return showTime || accountName != null || attachmentCount > 0;
  }

  /// 构建次要信息小部件（分类标签 · 时间 · 账户 + 附件图标）
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
          (happenedAt!.hour != 0 ||
              happenedAt!.minute != 0 ||
              happenedAt!.second != 0)) {
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

    // 组装行内容
    final rowChildren = <Widget>[];

    // 前置：分类标签
    if (categoryName != null) {
      rowChildren.add(_buildCategoryLabels(context));
    }

    // 中间：时间 · 账户
    if (parts.isNotEmpty) {
      if (rowChildren.isNotEmpty) {
        rowChildren.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text('·', style: textStyle),
        ));
      }
      rowChildren.add(Text(parts.join(' · '), style: textStyle));
    }

    // 尾部：附件图标
    if (attachmentCount > 0) {
      if (rowChildren.isNotEmpty) {
        rowChildren.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text('·', style: textStyle),
        ));
      }
      rowChildren.add(buildAttachmentWidget());
    }

    if (rowChildren.isEmpty) return const SizedBox.shrink();

    final hasCategory = categoryName != null;
    final hasTimeOrAccount = parts.isNotEmpty;
    final hasAttach = attachmentCount > 0;

    // 用于宽度预估的分类标签样式（与 _buildCategoryLabels 保持一致）
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final labelTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: primaryColor,
          height: 1.2,
          fontWeight: FontWeight.w500,
        );
    final parentTextStyle = parentCategoryName != null
        ? labelTextStyle?.copyWith(color: primaryColor.withValues(alpha: 0.8))
        : null;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final availableWidth = constraints.maxWidth;

        // 预估一行总宽度
        double totalWidth = 0;

        // 分类标签宽度（Container padding 6+6=12 + 文字 + 间距）
        if (hasCategory) {
          totalWidth += 12;
          if (parentCategoryName != null) {
            totalWidth += _textWidth(parentCategoryName!, parentTextStyle, ctx);
            totalWidth += _textWidth('>', labelTextStyle, ctx) + 2;
          }
          totalWidth += _textWidth(categoryName!, labelTextStyle, ctx);
          totalWidth += 12;
        }

        // 分隔符 · 和 时间·账户
        if (hasCategory && hasTimeOrAccount) {
          totalWidth += _textWidth('·', textStyle, ctx) + 4;
        }
        if (hasTimeOrAccount) {
          totalWidth += _textWidth(parts.join(' · '), textStyle, ctx);
        }

        // 分隔符 · 和附件图标
        if (hasAttach) {
          if (hasTimeOrAccount || hasCategory) {
            totalWidth += _textWidth('·', textStyle, ctx) + 4;
          }
          totalWidth += 12 + 2 + _textWidth('$attachmentCount', textStyle, ctx);
        }

        // 留 8px 余量
        if (totalWidth <= availableWidth + 8) {
          // 一行放得下
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: rowChildren,
          );
        }

        // 放不下 → 拆两行：分类标签一行，时间·账户·附件一行
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasCategory) _buildCategoryLabels(context),
            if (hasTimeOrAccount || hasAttach)
              Padding(
                padding: EdgeInsets.only(top: hasCategory ? 2 : 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasTimeOrAccount)
                      Text(parts.join(' · '), style: textStyle),
                    if (hasAttach) ...[
                      if (hasTimeOrAccount)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text('·', style: textStyle),
                        ),
                      buildAttachmentWidget(),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// 测量文本宽度（TextPainter）
  double _textWidth(String text, TextStyle? style, BuildContext context) {
    if (text.isEmpty || style == null) return 0;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return tp.width;
  }

  /// 构建分类标签小部件（用于内嵌在次要信息行中）
  /// 风格：单一标签 + 统一样式，二级分类用「 > 」分隔
  Widget _buildCategoryLabels(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;

    // 统一样式：浅底色 + 主色文字
    final labelTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: primaryColor,
          height: 1.2,
          fontWeight: FontWeight.w500,
        );

    // 有二级分类时，父类文字稍淡
    final parentTextStyle = parentCategoryName != null
        ? labelTextStyle?.copyWith(color: primaryColor.withValues(alpha: 0.8))
        : null;

    // 构建标签文字样式
    final TextStyle? labelStyle = labelTextStyle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: parentCategoryName != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  parentCategoryName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: parentTextStyle,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 1, right: 1),
                  child: Text(
                    '>',
                    style: labelStyle?.copyWith(
                      color: primaryColor.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                Text(
                  categoryName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ],
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: Text(
                categoryName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
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
            // 左侧：分类名称 + 备注 + 分类标签 + 时间·账户
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (categoryName != null &&
                        categoryName != title &&
                        title.isNotEmpty)
                      // 有备注时：第一行显示备注，分类名作为标签显示在下面
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BeeTextTokens.title(context),
                      )
                    else
                      // 无备注时：显示分类名称（或transfer等标题）
                      Text(
                        categoryName ?? title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BeeTextTokens.title(context),
                      ),
                    // 时间 · 账户 · 附件 · 分类标签
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
                        : isExpense
                            ? -amount
                            : amount,
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
              ) ??
              false;
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
