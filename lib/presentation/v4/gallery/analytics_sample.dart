import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

class AnalyticsSample extends StatefulWidget {
  const AnalyticsSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<AnalyticsSample> createState() => _AnalyticsSampleState();
}

class _AnalyticsSampleState extends State<AnalyticsSample> {
  String view = 'expense';
  bool pie = false;
  int selected = -1;
  final expanded = <String>{};
  @override
  Widget build(BuildContext context) {
    final total = view == 'expense'
            ? '¥3,286.5'
            : view == 'income'
                ? '¥12,000'
                : '¥8,713.5',
        label = view == 'expense'
            ? '支出'
            : view == 'income'
                ? '收入'
                : '结余';
    const categories = [
      BeeRankItem(
          id: 'food',
          label: '餐饮',
          amount: '1,199.57',
          fraction: .365,
          description: '36.5%',
          icon: BeeCategoryIcon(name: 'Utensils'),
          children: [
            BeeRankItem(
                id: 'lunch',
                label: '午餐',
                amount: '800',
                fraction: .2434,
                description: '24.3%',
                icon: BeeCategoryIcon(name: 'Soup'))
          ]),
      BeeRankItem(
          id: 'shopping',
          label: '购物',
          amount: '920.22',
          fraction: .28,
          description: '28.0%',
          icon: BeeCategoryIcon(name: 'ShoppingBasket'))
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSegmented<String>(
          value: view,
          items: const [
            BeeSegment('expense', '支出'),
            BeeSegment('income', '收入'),
            BeeSegment('balance', '结余')
          ],
          onChanged: (v) => setState(() => view = v)),
      const SizedBox(height: 12),
      BeeAnalyticsSummary(
          period: '2026-10',
          viewLabel: label,
          totalLabel: '总$label：',
          total: total,
          countLabel: '记账笔数',
          count: '27',
          averageLabel: '日均',
          average: '¥164.33',
          onView: () =>
              setState(() => view = view == 'expense' ? 'income' : 'expense')),
      const SizedBox(height: 12),
      BeeSurface(
          child: SizedBox(
              height: 240,
              child: BeeLineChart(
                  values: const [32, 68, 20, 120, 80, 208],
                  xLabels: const ['1', '5', '10', '15', '18', '20'],
                  highlightIndex: null,
                  onSwipeLeft: () {},
                  onSwipeRight: () {},
                  themeColor: Theme.of(context).colorScheme.primary,
                  whiteBg: false))),
      if (view != 'balance') ...[
        const SizedBox(height: 12),
        BeeSurface(
            child: Column(children: [
          Row(children: [
            const Expanded(child: Text('分类排行')),
            BeeIconButton(
                label: pie ? '显示分类排行' : '显示分类环图',
                icon: BeeLineIcon(pie ? 'List' : 'ChartPie'),
                onPressed: () => setState(() => pie = !pie))
          ]),
          if (pie)
            BeeDonutChart(
                items: const [
                  BeeChartSlice(
                      label: '餐饮',
                      value: 1199.57,
                      valueLabel: '36.5%',
                      color: Color(0xff5b8ff9)),
                  BeeChartSlice(
                      label: '购物',
                      value: 920.22,
                      valueLabel: '28%',
                      color: Color(0xff5ad8a6))
                ],
                centerLabel: selected < 0
                    ? '总计\n2,119.79'
                    : selected == 0
                        ? '餐饮\n1,199.57'
                        : '购物\n920.22',
                selected: selected,
                onSelected: (i) => setState(() => selected = i))
          else
            BeeCategoryRanking(
                items: categories,
                expanded: expanded,
                onExpand: (id) => setState(() => expanded.contains(id)
                    ? expanded.remove(id)
                    : expanded.add(id)),
                onDetail: (id) => ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('示例分类 $id'))))
        ]))
      ],
      const SizedBox(height: 16),
      widget.liveData ?? const Text('在App中读取当前账本真实收支、平均值和分类聚合；样例不写数据。')
    ]);
  }
}
