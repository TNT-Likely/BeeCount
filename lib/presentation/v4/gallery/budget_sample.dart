import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

class BudgetSample extends StatelessWidget {
  const BudgetSample({super.key, this.liveData, this.onEdit});
  final Widget? liveData;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (tone, used, remaining) in [
          (BeeBudgetTone.normal, 60, 40),
          (BeeBudgetTone.warning, 75, 25),
          (BeeBudgetTone.danger, 95, 5),
          (BeeBudgetTone.exceeded, 125, -25)
        ]) ...[
          BeeBudgetOverview(
              title: '本月预算 · ${tone.name}',
              totalLabel: '总预算',
              amount: '¥100.00',
              usedLabel: '已用',
              used: '¥$used.00',
              remainingLabel: '剩余',
              remaining: '¥$remaining.00',
              daysLabel: '剩余6天',
              dailyLabel:
                  '日均可用 ¥${remaining > 0 ? (remaining / 6).round() : 0}',
              progress: used / 100,
              progressLabel: '$used%',
              tone: tone,
              negativeRemaining: remaining < 0,
              editLabel: '编辑',
              onEdit: tone == BeeBudgetTone.exceeded ? null : onEdit),
          const SizedBox(height: 12)
        ],
        BeeSurface(
            child: Column(children: [
          BeeBudgetCategoryRow(
              name: '自定义咖啡预算',
              amounts: '¥215 / ¥100',
              percent: '215%',
              progress: 2.15,
              tone: BeeBudgetTone.exceeded,
              icon: Image.asset('assets/v4_gallery/category-coffee.png',
                  width: 20, height: 20),
              onTap: onEdit),
          const BeeBudgetCategoryRow(
              name: '这是完整的长分类预算名称，窄屏会保留分类和金额',
              amounts: 'US\$123456 / US\$500000',
              percent: '25%',
              progress: .25,
              tone: BeeBudgetTone.normal,
              icon: BeeLineIcon('Utensils', size: 20))
        ])),
        const SizedBox(height: 16),
        liveData ?? const Text('从App内组件验收读取真实预算、分类和本位币。')
      ]);
}
