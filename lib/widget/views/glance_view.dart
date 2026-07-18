import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../widget_spec.dart' show HWSize;
import 'widget_view_style.dart';

/// 收支速览(glance)小组件视图:小/中两档,`WidgetSpec.glanceSmall` /
/// `WidgetSpec.glanceMedium` 对应渲染。
///
/// headless 组件(见 `widget_view_style.dart` 顶部注释)——金额已由调用方
/// (`WidgetManager`)格式化成显示字符串再传入,这里只负责排版/配色,不做
/// 数值计算。
///
/// **medium 是从旧 `HomeWidgetView` 原样迁移的**(渐变主题色卡 + header +
/// 2×2 白色 stat 卡),视觉上不应比迁移前难看;唯一的有意"微调"是把支出/
/// 收入色值换成 `widget_view_style.dart` 里跟净资产/快速记账共用的新色值
/// (`#E5533C`/`#2FA36B`,来自 `.docs/home-widget/plan.md` §二统一视觉规范,
/// 比旧的 `#FF6B6B`/`#51CF66` 更柔和),以及让 `dark` 参数对渐变叠黑程度有
/// 一点点影响(桌面纯黑背景下对比度更好)。iOS/Android 2:1 网格的宽高分叉
/// 逻辑（外层透明 padding 撑到 `width`×`height`、内容始终按 364×169 画）
/// 同样照旧搬过来,不是本次改动的范围。
class GlanceView extends StatelessWidget {
  final HWSize size;

  final String todayExpense;
  final String todayIncome;
  final String monthExpense;
  final String monthIncome;

  final Color themeColor;
  final bool redForIncome;

  /// 系统明暗态,由 `WidgetManager` 用 `PlatformDispatcher` 在渲染时取一次
  /// 传入(见 widget_view_style.dart 顶部注释:图片不会自动跟随系统切换,
  /// 靠 App 重渲染触发,这部分留 Phase C)。
  final bool dark;

  /// medium 用:App 名 + header 右侧月份徽章文案。
  final String appName;
  final String monthSuffix;

  /// small 用:顶部"今日"徽章文案。
  final String todayLabel;

  final String todayExpenseLabel;
  final String todayIncomeLabel;
  final String monthExpenseLabel;
  final String monthIncomeLabel;

  final double width;
  final double height;

  const GlanceView.medium({
    super.key,
    required this.todayExpense,
    required this.todayIncome,
    required this.monthExpense,
    required this.monthIncome,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    required this.appName,
    required this.monthSuffix,
    required this.todayExpenseLabel,
    required this.todayIncomeLabel,
    required this.monthExpenseLabel,
    required this.monthIncomeLabel,
    required this.width,
    required this.height,
    this.todayLabel = '今日',
  }) : size = HWSize.medium;

  const GlanceView.small({
    super.key,
    required this.todayExpense,
    required this.monthExpense,
    required this.monthIncome,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    required this.todayLabel,
    required this.todayExpenseLabel,
    required this.monthExpenseLabel,
    required this.monthIncomeLabel,
    required this.width,
    required this.height,
    this.todayIncome = '',
    this.appName = '',
    this.monthSuffix = '',
    this.todayIncomeLabel = '',
  }) : size = HWSize.small;

  Color get _expenseColor => widgetExpenseColor(redForIncome);
  Color get _incomeColor => widgetIncomeColor(redForIncome);

  @override
  Widget build(BuildContext context) {
    return size == HWSize.small ? _buildSmall() : _buildMedium();
  }

  // -------------------------------------------------------------------
  // small(155×155):紧凑卡,今日支出大数 + 本月收支底栏
  // -------------------------------------------------------------------
  Widget _buildSmall() {
    final expenseColor = _expenseColor;
    final incomeColor = _incomeColor;
    final bg = widgetCardBackground(dark);
    final textSecondary = widgetTextSecondary(dark);

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: themeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                todayLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            todayExpenseLabel,
            style: TextStyle(fontSize: 11, color: textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              todayExpense,
              maxLines: 1,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: expenseColor,
                height: 1.0,
                fontFeatures: const [kWidgetTabularFeature],
              ),
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _miniStat(monthExpenseLabel, monthExpense, expenseColor, textSecondary),
              ),
              Container(width: 1, height: 24, color: widgetDivider(dark)),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(monthIncomeLabel, monthIncome, incomeColor, textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color valueColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, color: labelColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor,
              fontFeatures: const [kWidgetTabularFeature],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // medium(364×169 / 2:1):从旧 HomeWidgetView 迁移,视觉基本不变
  // -------------------------------------------------------------------
  Widget _buildMedium() {
    // iOS systemMedium 与 Android 2:1 网格宽高比不同,外层透明容器撑到
    // width×height,内容始终按 364×169 画并垂直居中——与迁移前的
    // HomeWidgetView 完全一致(D2 back-compat 的一部分,不是本次改动)。
    final isAndroid = Platform.isAndroid;
    final verticalPadding = isAndroid ? (182 - 169) / 2 : 0.0;
    final darkenAmount = dark ? 0.28 : 0.15;

    return Container(
      width: width,
      height: height,
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Container(
        width: 364,
        height: 169,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeColor,
              Color.lerp(themeColor, Colors.black, darkenAmount)!,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  appName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${DateTime.now().month}$monthSuffix',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                      todayExpenseLabel,
                      todayExpense,
                      _expenseColor,
                      Icons.arrow_upward,
                      true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      todayIncomeLabel,
                      todayIncome,
                      _incomeColor,
                      Icons.arrow_downward,
                      true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                      monthExpenseLabel,
                      monthExpense,
                      _expenseColor,
                      Icons.trending_up,
                      false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      monthIncomeLabel,
                      monthIncome,
                      _incomeColor,
                      Icons.trending_down,
                      false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    Color color,
    IconData icon,
    bool isToday,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, size: 10, color: color),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isToday ? 16 : 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.0,
                    fontFeatures: const [kWidgetTabularFeature],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.add_circle_outline, size: 12, color: Colors.grey[400]),
            ],
          ),
        ],
      ),
    );
  }
}
