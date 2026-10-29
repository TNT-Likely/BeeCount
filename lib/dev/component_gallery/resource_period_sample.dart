import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../utils/account_type_utils.dart';

class ResourcePeriodSample extends StatefulWidget {
  const ResourcePeriodSample({super.key});
  @override
  State<ResourcePeriodSample> createState() => _ResourcePeriodSampleState();
}

class _ResourcePeriodSampleState extends State<ResourcePeriodSample> {
  String period = 'all', category = '咖啡';
  DateTime anchor = DateTime(2026, 10);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BeeCompactTabs<String>(
            items: const [
              BeeSegment('month', '月'),
              BeeSegment('year', '年'),
              BeeSegment('all', '全部')
            ],
            value: period,
            trackHeight: 32,
            tapHeight: 44,
            onChanged: (value) => setState(() => period = value)),
        if (period != 'all')
          BeeDateRangeBar(
              label: period == 'all'
                  ? '全部时间'
                  : period == 'year'
                      ? '${anchor.year} 年'
                      : '${anchor.year} 年 ${anchor.month} 月',
              onChoose: () async {
                var draft = anchor;
                final value = await showBeeSheet<DateTime>(context,
                    title: '选择统计时间',
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BeeYearMonthWheel(
                              value: anchor,
                              showMonth: period != 'year',
                              onChanged: (value) => draft = value),
                          BeeButton(
                              label: '确认',
                              onPressed: () => Navigator.pop(context, draft)),
                        ]));
                if (mounted && value != null) {
                  setState(() {
                    anchor = value;
                    if (period == 'all') period = 'month';
                  });
                }
              }),
        BeeResourceHero(
            title: category,
            beforeIdentity: category == '咖啡'
                ? BeeResourceParentLink(
                    label: '上级',
                    name: '饮品',
                    onPressed: () => setState(() => category = '饮品'))
                : null,
            caption: category == '咖啡' ? '二级分类 · 日常生活' : '一级分类 · 日常生活',
            icon: const BeeLineIcon('Coffee', size: 22),
            amountLabel: '累计支出',
            prefix: '¥',
            amount: '514.00',
            metrics: const [
              BeeResourceMetric(label: '记录笔数', value: '16 笔'),
              BeeResourceMetric(label: '单笔均额', value: '¥32.13'),
              BeeResourceMetric(label: '占总支出', value: '59.9%'),
            ]),
        const SizedBox(height: 12),
        BeeButton(
            label: '交易记录筛选',
            kind: BeeButtonKind.secondary,
            onPressed: () async {
              var flow = 'all', sort = 'timeDesc';
              await showBeeSheet<void>(context,
                  title: '交易记录筛选',
                  child: StatefulBuilder(
                      builder: (ctx, update) => BeeAccountFlowFilter(
                          flow: flow,
                          sort: sort,
                          sortLabel: '排序',
                          flows: const [
                            BeeSegment('all', '全部流水'),
                            BeeSegment('expense', '支出与转出'),
                            BeeSegment('income', '收入与转入')
                          ],
                          sorts: const [
                            BeeSegment('timeDesc', '时间从新到旧'),
                            BeeSegment('timeAsc', '时间从旧到新'),
                            BeeSegment('amountDesc', '金额从高到低'),
                            BeeSegment('amountAsc', '金额从低到高')
                          ],
                          onFlowChanged: (v) => update(() => flow = v),
                          onSortChanged: (v) => update(() => sort = v),
                          confirmLabel: '确认',
                          onConfirm: () => Navigator.pop(ctx))));
            }),
      ]);
}

class AccountDetailComponentsSample extends StatefulWidget {
  const AccountDetailComponentsSample({super.key});
  @override
  State<AccountDetailComponentsSample> createState() =>
      _AccountDetailComponentsState();
}

class _AccountDetailComponentsState
    extends State<AccountDetailComponentsSample> {
  int? point;
  String query = '';
  String sort = 'timeDesc';
  String? flowLabel = '支出与转出';
  Future<void> chooseFilters() async {
    var direction = flowLabel == null
        ? 'all'
        : flowLabel == '收入与转入'
            ? 'income'
            : 'expense';
    var order = sort;
    final applied = await showBeeSheet<bool>(context,
        title: '筛选账户交易',
        child: StatefulBuilder(
            builder: (ctx, update) => BeeAccountFlowFilter(
                flow: direction,
                sort: order,
                sortLabel: '排序',
                flows: const [
                  BeeSegment('all', '全部流水'),
                  BeeSegment('expense', '支出与转出'),
                  BeeSegment('income', '收入与转入')
                ],
                sorts: const [
                  BeeSegment('timeDesc', '时间↓'),
                  BeeSegment('timeAsc', '时间↑'),
                  BeeSegment('amountDesc', '金额↓'),
                  BeeSegment('amountAsc', '金额↑')
                ],
                onFlowChanged: (v) => update(() => direction = v),
                onSortChanged: (v) => update(() => order = v),
                confirmLabel: '确认',
                onConfirm: () => Navigator.pop(ctx, true))));
    if (mounted && applied == true) {
      setState(() {
        sort = order;
        flowLabel = direction == 'all'
            ? null
            : direction == 'income'
                ? '收入与转入'
                : '支出与转出';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const BeeAccountSummaryCard(
            title: '微信',
            caption: '钱包 · CNY',
            icon: AccountTypeIcon(type: 'wechat', size: 32),
            balanceLabel: '当前余额',
            amount: '8,760.50',
            prefix: '¥',
            currency: 'CNY',
            properties: [
              BeeAccountProperty(label: '计入净资产', value: '已计入'),
              BeeAccountProperty(label: '关联账本', value: '3 个账本'),
            ]),
        const SizedBox(height: 12),
        BeeAccountCashflowCard(
            title: '账户收支',
            currency: 'CNY',
            incomeLabel: '收入',
            income: '12,200.00',
            expenseLabel: '支出',
            expense: '6,439.50',
            netLabel: '净流入',
            net: '+5,760.50',
            detailLabel: '分类占比',
            onDetail: () => showBeeSheet<void>(context,
                title: '分类占比', child: const Text('受控回调；真实数据由 App 绑定层提供。'))),
        const SizedBox(height: 12),
        BeeBalanceHistoryCard(
            title: '余额趋势',
            currency: 'CNY',
            values: const [3000, 13000, 12000, 11500, 8760.50],
            axisLabels: const ['10.01', '', '10.20'],
            selectedLabel:
                point == null ? '期末余额 ¥8,760.50' : '选中第 ${point! + 1} 个历史节点',
            emptyLabel: '暂无历史记录',
            selectedIndex: point,
            onSelected: (value) => setState(() => point = value)),
        const SizedBox(height: 12),
        BeeAccountTransactionTools(
            title: '交易记录',
            searchLabel: '搜索',
            filterLabel: '筛选',
            query: query,
            sortLabel: '排序 · ${{
              'timeDesc': '时间↓',
              'timeAsc': '时间↑',
              'amountDesc': '金额↓',
              'amountAsc': '金额↑'
            }[sort]}',
            flowLabel: flowLabel,
            onClearQuery: () => setState(() => query = ''),
            onClearFlow: () => setState(() => flowLabel = null),
            onSearch: () async {
              final result = await showBeeSheet<String>(context,
                  title: '搜索',
                  child: BeeAccountTransactionSearch(
                      initialQuery: query,
                      hint: '搜索账户交易',
                      confirmLabel: '确认',
                      clearLabel: '清空',
                      onConfirm: (value) => Navigator.pop(context, value)));
              if (mounted && result != null) setState(() => query = result);
            },
            onFilter: chooseFilters),
        BeeButton(
            label: '交易记录筛选',
            kind: BeeButtonKind.secondary,
            onPressed: () async {
              var flow = 'all', sort = 'timeDesc';
              await showBeeSheet<void>(context,
                  title: '交易记录筛选',
                  child: StatefulBuilder(
                      builder: (ctx, update) => BeeAccountFlowFilter(
                          flow: flow,
                          sort: sort,
                          sortLabel: '排序',
                          flows: const [
                            BeeSegment('all', '全部流水'),
                            BeeSegment('expense', '支出与转出'),
                            BeeSegment('income', '收入与转入')
                          ],
                          sorts: const [
                            BeeSegment('timeDesc', '时间从新到旧'),
                            BeeSegment('timeAsc', '时间从旧到新'),
                            BeeSegment('amountDesc', '金额从高到低'),
                            BeeSegment('amountAsc', '金额从低到高')
                          ],
                          onFlowChanged: (v) => update(() => flow = v),
                          onSortChanged: (v) => update(() => sort = v),
                          confirmLabel: '确认',
                          onConfirm: () => Navigator.pop(ctx))));
            }),
      ]);
}
