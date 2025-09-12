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
  const TransactionListItem(
      {super.key,
      required this.icon,
      required this.title,
      required this.amount,
      required this.isExpense,
      this.hide = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: AppDimens.listRowVertical),
        child: Row(
          children: [
            Container(
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
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextTokens.title(context)),
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
