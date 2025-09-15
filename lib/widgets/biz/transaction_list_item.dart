import 'package:flutter/material.dart';
import '../../styles/design.dart';
import 'amount_text.dart';

class TransactionListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final double amount;
  final bool isExpense; // 决定正负号
  final bool hide;
  final VoidCallback? onTap;
  final VoidCallback? onCategoryTap; // 点击分类图标/名称的回调
  final String? categoryName; // 分类名称，用于显示
  const TransactionListItem(
      {super.key,
      required this.icon,
      required this.title,
      required this.amount,
      required this.isExpense,
      this.hide = false,
      this.onTap,
      this.onCategoryTap,
      this.categoryName});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: AppDimens.listRowVertical),
        child: Row(
          children: [
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
                child: Icon(icon,
                    color: Theme.of(context).colorScheme.primary, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextTokens.title(context)),
                  // 如果有分类名称且与标题不同，则显示分类名称
                  if (categoryName != null && categoryName != title)
                    GestureDetector(
                      onTap: onCategoryTap,
                      child: Text(
                        categoryName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AmountText(
                value: isExpense ? -amount : amount,
                hide: hide,
                signed: true,
                decimals: 2,
                style: AppTextTokens.title(context)),
          ],
        ),
      ),
    );
  }
}
