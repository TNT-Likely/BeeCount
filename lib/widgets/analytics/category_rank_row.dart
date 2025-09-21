import 'package:flutter/material.dart';
import '../../styles/colors.dart';
import '../../widgets/category_icon.dart';
import '../biz/biz.dart';

class CategoryRankRow extends StatelessWidget {
  final String name;
  final double value;
  final double percent; // 0..1
  final Color color;
  final bool isIncome; // 是否为收入分类
  final bool isExpense; // 是否为支出分类

  const CategoryRankRow({
    super.key,
    required this.name,
    required this.value,
    required this.percent,
    required this.color,
    this.isIncome = false,
    this.isExpense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(iconForCategory(name), color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium),
                          if (isIncome) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                '收入',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.green,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                          if (isExpense) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                '支出',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AmountText(value: value, signed: false, decimals: 0),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('${(percent * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: BeeColors.hintText)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                          height: 6, color: color.withValues(alpha: 0.15)),
                      FractionallySizedBox(
                        widthFactor: percent.clamp(0, 1),
                        child: Container(
                            height: 6, color: color.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}