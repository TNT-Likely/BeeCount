import 'package:flutter/material.dart';

import '../../utils/currencies.dart' show getCurrencySymbol;
import '../../widgets/biz/format_money.dart' show formatMoneyCompact;
import '../widget_data_service.dart'
    show DashboardWidgetData, GlanceWidgetData, QuickAddCategoryItem;
import '../widget_spec.dart' show HWSize;
import 'recent_view.dart' show RecentTransactionRow;
import 'widget_view_style.dart';

/// 综合仪表盘(dashboard)小组件视图:仅大号一档,`WidgetSpec.dashboardLarge`
/// 对应渲染。
///
/// headless 组件(见 `widget_view_style.dart` 顶部注释)——消费
/// `WidgetDataService.gatherDashboard` 返回的 [DashboardWidgetData](收支速览
/// + 近 30 日净值趋势 + 最近交易 + 快速记账常用分类的组合),一屏内依次排布
/// 四个区块:
///
/// 1. 顶部本月支出/收入(左右并排,数值来自 [data.glance])。
/// 2. 净值趋势 sparkline(取 [data.netWorthTrend] 的 net 序列,面积渐变画法
///    与 `NetWorthView` 一致,见共享的 [WidgetSparkline])。
/// 3. "最近交易"标签 + 最近 2 笔(直接复用 `RecentView` 的行组件
///    [RecentTransactionRow],不重新实现一遍单行长什么样)。
/// 4. 底部快捷记账行(quickAdd 前 3 个分类 + 固定的「记一笔」按钮,视觉语言
///    与 `QuickAddView` 的分类格一致:圆角矩形 + 主题色浅底 + 图标 + 名称;
///    因大号高度紧张,这里是按同一视觉语言独立实现的紧凑横向单行,不是直接
///    复用 `QuickAddView` 的 155×155/364×169 整卡片布局——那两档本身是自成
///    一体的卡片,直接内嵌会在 dashboard 里画出"卡中卡"的双层圆角背景)。
///
/// **防溢出**:大号高度有限(382pt),第 2/3 区块(趋势图/最近交易列表)用
/// `Expanded` 吸收剩余空间、按自然高度排布其余定长区块,不给任何区块写死
/// 高度——这是 `NetWorthView` medium/large 踩过 `RenderFlex` 溢出后总结的
/// 教训(见该文件文档),这里从一开始就照此原则实现。最近交易列表额外包一层
/// [WidgetOverflowClip] 裁切兜底(同 `RecentView` 的技术;**禁用 Scrollable**,
/// 离屏树无 View 会炸,见其文档),双重保险防止真实设备字体度量差异导致溢出。
class DashboardView extends StatelessWidget {
  /// dashboard 目前只有大号一档(见 `WidgetSpec.catalog`),这里保留字段是
  /// 为了与其它 View 的构造参数风格保持一致(便于未来若新增中号档位时不用
  /// 改调用方的字段名),`build()` 目前不依据它分支。
  final HWSize size;

  final DashboardWidgetData data;

  /// 账本自身币种,用于本月支出/收入格式化;同时作为最近交易行金额的兜底
  /// 币种(交易自身 currencyCode 缺失时用它,见
  /// `RecentTransactionRow.defaultCurrency` 文档)。
  final String defaultCurrency;

  final Color themeColor;
  final bool redForIncome;
  final bool dark;

  /// 顶部本月支出/收入文案,复用 `WidgetManager.updateAllWidgets` 里
  /// glance 视图已有的同名默认值(同一份数据的同一种称呼,不重新造词)。
  final String monthExpenseLabel;
  final String monthIncomeLabel;

  /// "最近交易"区块标题。
  final String recentLabel;

  final String uncategorizedLabel;

  /// 最近交易为空时的占位文案。
  final String noTransactionsLabel;

  /// 「记一笔」按钮文案。
  final String quickAddLabel;

  final double width;
  final double height;

  const DashboardView({
    super.key,
    this.size = HWSize.large,
    required this.data,
    required this.defaultCurrency,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    this.monthExpenseLabel = '本月支出',
    this.monthIncomeLabel = '本月收入',
    this.recentLabel = '最近交易',
    this.uncategorizedLabel = '未分类',
    this.noTransactionsLabel = '暂无交易',
    this.quickAddLabel = '记一笔',
    required this.width,
    required this.height,
  });

  String _money(double v) =>
      '${getCurrencySymbol(defaultCurrency)}${formatMoneyCompact(v)}';

  @override
  Widget build(BuildContext context) {
    final recent = data.recent.take(2).toList();
    final quickAdd = data.quickAdd.take(3).toList();
    final netSeries = data.netWorthTrend.map((e) => e.net).toList();

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widgetCardBackground(dark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow(data.glance),
          const SizedBox(height: 8),
          Expanded(
            flex: 2,
            child: WidgetSparkline(
              values: netSeries,
              color: themeColor,
              filled: true,
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: widgetDivider(dark)),
          const SizedBox(height: 6),
          Text(
            recentLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widgetTextSecondary(dark),
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            flex: 3,
            child: recent.isEmpty
                ? Center(
                    child: Text(
                      noTransactionsLabel,
                      style: TextStyle(fontSize: 11, color: widgetTextTertiary(dark)),
                    ),
                  )
                : WidgetOverflowClip(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in recent)
                          RecentTransactionRow(
                            item: item,
                            defaultCurrency: defaultCurrency,
                            uncategorizedLabel: uncategorizedLabel,
                            themeColor: themeColor,
                            redForIncome: redForIncome,
                            dark: dark,
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: widgetDivider(dark)),
          const SizedBox(height: 8),
          _quickAddRow(quickAdd),
        ],
      ),
    );
  }

  Widget _statsRow(GlanceWidgetData glance) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _statBlock(
            monthExpenseLabel,
            glance.monthExpenseTotal,
            widgetExpenseColor(redForIncome),
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 30, color: widgetDivider(dark)),
        const SizedBox(width: 12),
        Expanded(
          child: _statBlock(
            monthIncomeLabel,
            glance.monthIncomeTotal,
            widgetIncomeColor(redForIncome),
          ),
        ),
      ],
    );
  }

  Widget _statBlock(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: widgetTextSecondary(dark)),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 22,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(value),
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.0,
                fontFeatures: const [kWidgetTabularFeature],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 底部快捷记账行:quickAdd 前 3 个分类格 + 固定「记一笔」按钮,等分铺满
  /// 一行(视觉语言同 `QuickAddView`,见类文档"防溢出"上一段的说明)。
  Widget _quickAddRow(List<QuickAddCategoryItem> categories) {
    final cells = <Widget>[
      for (final c in categories) _quickAddCategoryCell(c),
      _quickAddButtonCell(),
    ];
    return Row(
      children: [
        for (final cell in cells)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: cell,
            ),
          ),
      ],
    );
  }

  Widget _quickAddCategoryCell(QuickAddCategoryItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: dark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widgetCategoryIcon(icon: item.icon, color: themeColor, size: 16),
          const SizedBox(height: 2),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: widgetTextPrimary(dark)),
          ),
        ],
      ),
    );
  }

  Widget _quickAddButtonCell() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: themeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, color: Colors.white, size: 16),
          const SizedBox(height: 2),
          Text(
            quickAddLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
