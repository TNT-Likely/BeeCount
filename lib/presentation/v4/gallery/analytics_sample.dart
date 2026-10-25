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
  int selectedShare = 0;
  int? selectedBar;
  final expanded = <String>{};
  @override
  Widget build(BuildContext context) {
    final income = view == 'income', balance = view == 'balance';
    final total = balance
        ? '¥8,713.50'
        : income
            ? '¥12,000.00'
            : '¥3,286.50';
    final average = balance
        ? 348.54
        : income
            ? 480.0
            : 131.46;
    const expenses = [
      65.0,
      100.0,
      160.0,
      90.0,
      120.0,
      140.0,
      80.0,
      190.0,
      100.0,
      95.0,
      120.0,
      210.0,
      60.0,
      135.0,
      250.0,
      80.0,
      130.0,
      100.0,
      180.0,
      145.0,
      155.0,
      100.0,
      190.0,
      120.0,
      171.5
    ];
    final values = List.generate(
        25,
        (i) => balance
            ? (i == 0 ? 12000.0 : 0.0) - expenses[i]
            : income
                ? i == 0
                    ? 12000.0
                    : 0.0
                : expenses[i]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeAnalyticsSummary(
          period: '2026年10月',
          viewLabel: balance
              ? '结余'
              : income
                  ? '收入'
                  : '支出',
          totalLabel: balance
              ? '本期结余'
              : income
                  ? '总收入'
                  : '总支出',
          total: total,
          ledgerLabel: '日常生活',
          countLabel: '记账笔数',
          count: '26',
          averageLabel: '日均',
          average: '¥${average.toStringAsFixed(2)}',
          views: const [
            BeeSegment('expense', '支出'),
            BeeSegment('income', '收入'),
            BeeSegment('balance', '结余')
          ],
          selectedView: view,
          onViewChanged: (v) => setState(() {
                view = v;
                selectedBar = null;
              })),
      const SizedBox(height: 12),
      BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('收支趋势',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 15),
        BeeColumnChart(
            values: values,
            labels: List.generate(25, (i) => '10.${i + 1}'),
            valueLabels: values.map((v) => '¥${v.toStringAsFixed(2)}').toList(),
            average: average,
            averageLabel: '日均 ¥${average.toStringAsFixed(2)}',
            selected: selectedBar,
            onSelected: (i) => setState(() => selectedBar = i))
      ])),
      const SizedBox(height: 12),
      if (balance)
        BeeSurface(
            child: BeeAnalyticsComposition(
                incomeLabel: '本期收入',
                expenseLabel: '本期支出',
                income: '¥12,000.00',
                expense: '¥3,286.50',
                onIncome: () => setState(() => view = 'income'),
                onExpense: () => setState(() => view = 'expense')))
      else ...[
        BeeSurface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              const Text('分类占比',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              BeeAnalyticsProportion(
                  items: income
                      ? const [
                          BeeAnalyticsShare(
                              label: '工资', fraction: 1, valueLabel: '100%')
                        ]
                      : const [
                          BeeAnalyticsShare(
                              label: '餐饮', fraction: .358, valueLabel: '35.8%'),
                          BeeAnalyticsShare(
                              label: '购物', fraction: .247, valueLabel: '24.7%'),
                          BeeAnalyticsShare(
                              label: '居家', fraction: .176, valueLabel: '17.6%'),
                          BeeAnalyticsShare(
                              label: '其他分类',
                              fraction: .219,
                              valueLabel: '21.9%')
                        ],
                  selected: income ? 0 : selectedShare,
                  onSelected: (i) => setState(() => selectedShare = i),
                  hint: '点选分类，查看它在总额中的占比')
            ])),
        const SizedBox(height: 12),
        BeeSurface(
            child: BeeAnalyticsRankingList(
                items: [
              BeeRankItem(
                  id: 'food',
                  label: income ? '工资' : '餐饮',
                  amount: income ? '12,000.00' : '1,176.57',
                  fraction: income ? 1 : .358,
                  description: income ? '100%' : '35.8%',
                  icon: const BeeCategoryIcon(name: 'Utensils'),
                  children: income
                      ? const []
                      : const [
                          BeeRankItem(
                              id: 'lunch',
                              label: '午餐',
                              amount: '800.00',
                              fraction: .2434,
                              icon: BeeCategoryIcon(name: 'Soup'))
                        ]),
              if (!income)
                const BeeRankItem(
                    id: 'shopping',
                    label: '购物',
                    amount: '811.77',
                    fraction: .247,
                    description: '24.7%',
                    icon: BeeCategoryIcon(name: 'ShoppingBasket'))
            ],
                expanded: expanded,
                onExpand: (id) => setState(() => expanded.contains(id)
                    ? expanded.remove(id)
                    : expanded.add(id)),
                onDetail: (id) => ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('示例分类 $id')))))
      ],
      const SizedBox(height: 16),
      widget.liveData ?? const Text('在App中读取当前账本真实收支、平均值和分类聚合；样例不写数据。')
    ]);
  }
}
