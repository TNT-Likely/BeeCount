import 'package:flutter/material.dart';

import '../../utils/currencies.dart' show getCurrencySymbol;
import '../../widgets/biz/format_money.dart' show formatMoneyCompact;
import '../widget_data_service.dart' show RecentTransactionItem;
import '../widget_spec.dart' show HWSize;
import 'widget_view_style.dart';

/// 最近交易(recent)小组件视图:中/大两档,`WidgetSpec.recentMedium` /
/// `recentLarge` 对应渲染。
///
/// headless 组件(见 `widget_view_style.dart` 顶部注释)——消费
/// `WidgetDataService.gatherRecent` 返回的 `List<RecentTransactionItem>`
/// (分类/账户可能为 null:转账无分类、或分类/账户已被删除,由本文件负责
/// 兜底展示,不依赖上游保证非空)。
///
/// 每行的展示逻辑抽成公开的 [RecentTransactionRow],供本视图自身与
/// dashboard 综合仪表盘(`DashboardView`,Phase B2b 同批次新增)直接复用,
/// 避免"最近交易一行长什么样"在两个文件里各写一遍。
///
/// - medium:最近 3 笔;large:最近 6 笔(`WidgetDataService.gatherRecent` 的
///   `limit` 已按此截断,这里 `take(_limit)` 属防御性重复,同 QuickAddView/
///   BudgetView 的约定)。
/// - 空列表(全新账本还没有任何交易)显示 [emptyLabel] 占位文案。
class RecentView extends StatelessWidget {
  final HWSize size;

  final List<RecentTransactionItem> items;

  /// 交易自身 `currencyCode` 为 null 时的兜底币种(账本自身币种,见
  /// `WidgetDataService.gatherLedgerCurrency`)。
  final String defaultCurrency;

  final Color themeColor;
  final bool redForIncome;
  final bool dark;

  /// 分类/转账账户都缺失时的兜底名称。对应 arb key `commonUncategorized`——
  /// 本文件不依赖 BuildContext,取不到真正的 l10n,由调用方(`WidgetManager`,
  /// 见其 `resolveWidgetLocalizations`/`updateAllWidgetsLocalized`)显式传入
  /// 真实文案;这里的默认值只是彻底拿不到 locale 时的兜底。
  final String uncategorizedLabel;

  /// 空列表占位文案。
  final String emptyLabel;

  final double width;
  final double height;

  const RecentView({
    super.key,
    required this.size,
    required this.items,
    required this.defaultCurrency,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    this.uncategorizedLabel = '未分类',
    this.emptyLabel = '暂无交易',
    required this.width,
    required this.height,
  });

  /// medium 展示最近 3 笔,large 展示最近 6 笔(见类文档)。
  int get _limit => size == HWSize.large ? 6 : 3;

  @override
  Widget build(BuildContext context) {
    final take = items.take(_limit).toList();

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widgetCardBackground(dark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: take.isEmpty
          ? Center(
              child: Text(
                emptyLabel,
                style: TextStyle(fontSize: 12, color: widgetTextTertiary(dark)),
              ),
            )
          : SingleChildScrollView(
              // 行数理论上已被 _limit 控制在 3/6,这里仍防御性禁用滚动 + 裁切
              // 兜底(同 NetWorthView 大号账户列表的技术):即便真实设备字体
              // 度量比预期更高,也只是裁切而不是抛 RenderFlex 溢出异常。
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in take)
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
    );
  }
}

/// 最近交易单行:分类/转账图标 + 名称 + 次行(分类或账户 · 时间) + 右侧金额。
///
/// 公开(非 `RecentView` 私有),供 dashboard 综合仪表盘直接复用同一行组件
/// (见 [RecentView] 类文档)——调用方按需自行控制外层间距/分隔线,本组件
/// 只负责单行内容本身。
class RecentTransactionRow extends StatelessWidget {
  final RecentTransactionItem item;
  final String defaultCurrency;
  final String uncategorizedLabel;
  final Color themeColor;
  final bool redForIncome;
  final bool dark;

  const RecentTransactionRow({
    super.key,
    required this.item,
    required this.defaultCurrency,
    required this.uncategorizedLabel,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
  });

  bool get _isTransfer => item.transaction.type == 'transfer';

  /// 名称:分类名;转账用"转出账户 → 转入账户"(缺一边就只显示存在的那边);
  /// 都没有兜底 [uncategorizedLabel]。
  String get _primaryName {
    if (_isTransfer) {
      final from = item.account?.name;
      final to = item.toAccount?.name;
      if (from != null && to != null) return '$from → $to';
      if (from != null) return from;
      if (to != null) return to;
      return uncategorizedLabel;
    }
    return item.category?.name ?? uncategorizedLabel;
  }

  /// 次行的"分类/账户"部分:主标题已经是分类名的场景(非转账)这里换成
  /// 账户名;主标题已经是账户名的场景(转账)这里换成分类名(转账通常没有
  /// 分类,取到就是 null,次行退化为只显示时间)。
  String? get _secondaryDescriptor =>
      _isTransfer ? item.category?.name : item.account?.name;

  /// 今天显示 `HH:mm`,更早显示 `M/d`(需求原文:"今天显示时:分,更早显示
  /// 月/日"),不引入 intl 依赖——这个固定格式不随 locale 变化。
  String get _timeText {
    final dt = item.transaction.happenedAt;
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return '${dt.month}/${dt.day}';
  }

  String get _secondaryLine {
    final descriptor = _secondaryDescriptor;
    if (descriptor != null && descriptor.isNotEmpty) {
      return '$descriptor · $_timeText';
    }
    return _timeText;
  }

  /// 支出负/红、收入正/绿、转账(及其它类型,如估值调整)中性色 + 不加符号。
  Color get _amountColor {
    switch (item.transaction.type) {
      case 'expense':
        return widgetExpenseColor(redForIncome);
      case 'income':
        return widgetIncomeColor(redForIncome);
      default:
        return widgetTextPrimary(dark);
    }
  }

  /// 币种取交易自身(`currencyCode` 缺失兜底 [defaultCurrency]),金额用
  /// `formatMoneyCompact` + `getCurrencySymbol`——与 dashboard/其它金额展示
  /// 保持同一套纯函数格式化,不依赖 BuildContext。
  String get _amountText {
    final t = item.transaction;
    final code = (t.currencyCode ?? defaultCurrency).toUpperCase();
    final symbol = getCurrencySymbol(code);
    final sign = t.type == 'expense'
        ? '-'
        : t.type == 'income'
            ? '+'
            : '';
    return '$sign$symbol${formatMoneyCompact(t.amount)}';
  }

  Widget _leadingIcon() {
    if (_isTransfer) {
      // 转账没有分类,直接用一个更贴切的图标而不是
      // CategoryService.getCategoryIcon(null) 兜底的通用图标(同主应用
      // transaction_list.dart 对 isAdjustment 特判 Icons.tune 的做法一致)。
      return Icon(Icons.swap_horiz, size: 16, color: themeColor);
    }
    return widgetCategoryIcon(icon: item.category?.icon, color: themeColor, size: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: dark ? 0.22 : 0.12),
              shape: BoxShape.circle,
            ),
            child: _leadingIcon(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _primaryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widgetTextPrimary(dark),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _secondaryLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: widgetTextTertiary(dark)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _amountText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _amountColor,
              fontFeatures: const [kWidgetTabularFeature],
            ),
          ),
        ],
      ),
    );
  }
}
