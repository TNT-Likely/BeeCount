import 'package:flutter/material.dart';

import '../../utils/currencies.dart' show getCurrencySymbol;
import '../../utils/format_money.dart' show formatMoneyCompact;
import '../widget_data_service.dart' show RecentTransactionItem;
import '../widget_spec.dart' show HWSize;
import 'widget_view_style.dart';

/// 账本最近交易。中号显示三笔，大号显示六笔。
class RecentView extends StatelessWidget {
  final HWSize size;

  final List<RecentTransactionItem> items;

  /// 交易自身 `currencyCode` 为 null 时的兜底币种(账本自身币种,见
  /// `WidgetDataService.gatherLedgerCurrency`)。
  final String defaultCurrency;

  final Color themeColor;
  final bool redForIncome;
  final bool dark;

  /// 分类和转账账户均缺失时显示当前图片语言对应的 commonUncategorized。
  final String uncategorizedLabel;

  /// 空列表占位文案。
  final String emptyLabel;

  /// 当前图片语言的「最近交易」标题。
  final String titleLabel;

  /// 用来区分当日交易和历史日期，选择器样例可以固定这一天。
  final DateTime? referenceDate;
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
    this.referenceDate,
    this.uncategorizedLabel = '未分类',
    this.emptyLabel = '暂无交易',
    this.titleLabel = '最近交易',
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final large = size == HWSize.large;
    return WidgetCardSurface(
      width: width,
      height: height,
      dark: dark,
      padding: EdgeInsets.symmetric(
          horizontal: large ? 18 : 17, vertical: large ? 18 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WidgetCardHeading(
              icon: Icons.receipt_long_outlined, title: titleLabel, dark: dark),
          const SizedBox(height: 7),
          Expanded(
            child: RecentWidgetRows(
              items: items.take(large ? 6 : 3).toList(),
              defaultCurrency: defaultCurrency,
              themeColor: themeColor,
              redForIncome: redForIncome,
              dark: dark,
              compact: !large,
              referenceDate: referenceDate,
              uncategorizedLabel: uncategorizedLabel,
              emptyLabel: emptyLabel,
            ),
          ),
        ],
      ),
    );
  }
}

/// 最近交易卡片和仪表盘按同一顺序展示分类、账户、时间与原币金额。
class RecentWidgetRows extends StatelessWidget {
  const RecentWidgetRows({
    super.key,
    required this.items,
    required this.defaultCurrency,
    required this.uncategorizedLabel,
    required this.emptyLabel,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    this.referenceDate,
    this.compact = false,
  });

  final List<RecentTransactionItem> items;
  final String defaultCurrency, uncategorizedLabel, emptyLabel;
  final Color themeColor;
  final DateTime? referenceDate;
  final bool redForIncome, dark, compact;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return WidgetCardEmpty(
          icon: Icons.inbox_outlined,
          label: emptyLabel,
          dark: dark,
          compact: compact);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) Container(height: 1, color: widgetDivider(dark)),
          Expanded(
              child: RecentTransactionRow(
            item: items[i],
            defaultCurrency: defaultCurrency,
            uncategorizedLabel: uncategorizedLabel,
            themeColor: themeColor,
            redForIncome: redForIncome,
            dark: dark,
            compact: compact,
            referenceDate: referenceDate,
          )),
        ],
      ],
    );
  }
}

class RecentTransactionRow extends StatelessWidget {
  final RecentTransactionItem item;
  final String defaultCurrency;
  final String uncategorizedLabel;
  final Color themeColor;
  final bool redForIncome;
  final bool dark;
  final bool compact;
  final DateTime? referenceDate;

  const RecentTransactionRow({
    super.key,
    required this.item,
    required this.defaultCurrency,
    required this.uncategorizedLabel,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    this.referenceDate,
    this.compact = false,
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
    final now = referenceDate ?? DateTime.now();
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
        return widgetExpenseColor(redForIncome, dark: dark);
      case 'income':
        return widgetIncomeColor(redForIncome, dark: dark);
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
    final ink = Color.lerp(widgetTextPrimary(dark), themeColor, .10)!;
    if (_isTransfer) return Icon(Icons.swap_horiz, size: 16, color: ink);
    return widgetCategoryIcon(icon: item.category?.icon, color: ink, size: 16);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final iconSize = compact ? 28.0 : 31.0;
      return Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widgetCardSoft(dark),
              borderRadius: BorderRadius.circular(9),
            ),
            child: _leadingIcon(),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_primaryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: widgetTextPrimary(dark))),
                const SizedBox(height: 2),
                Text(_secondaryLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: compact ? 9.5 : 10,
                        height: 1.15,
                        color: widgetTextSecondary(dark))),
              ],
            ),
          ),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth * .46),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(_amountText,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: _amountColor,
                    fontFeatures: const [kWidgetTabularFeature],
                  )),
            ),
          ),
        ],
      );
    });
  }
}
