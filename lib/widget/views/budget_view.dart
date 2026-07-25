import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/repositories/budget_repository.dart'
    show BudgetOverview, BudgetUsage, CategoryBudgetUsage;
import '../../utils/currencies.dart' show getCurrencySymbol;
import '../../widgets/biz/format_money.dart' show formatMoneyCompact;
import '../widget_spec.dart' show HWSize;
import 'widget_view_style.dart';

/// 预算进度(budget)小组件视图:小/中两档,`WidgetSpec.budgetSmall` /
/// `budgetMedium` 对应渲染。
///
/// headless 组件(见 `widget_view_style.dart` 顶部注释)——消费
/// `WidgetDataService.gatherBudget` 返回的 [BudgetOverview](分类用量已截断到
/// 前 3 个,见其文档),金额格式化用共享的 `getCurrencySymbol` + `formatMoneyCompact`
/// 纯函数,不依赖 BuildContext/ref。
///
/// [overview.totalBudget] 为 null(账本未设总预算)时优雅降级:两档都只展示
/// [noBudgetLabel] 占位文案,不强行画一个 0% 的空环/空进度条(那样反而会让
/// 用户误以为"预算是 0",而不是"根本没设预算")——这是两者语义不同,不能用同一
/// 种视觉表达。
///
/// - small:环形进度(`CustomPainter` 画圆环,track + 按用量比例扫过的彩色弧)
///   + 环内居中大字 `xx%` + [usedLabel] 副标题 + 底部 `剩 ¥x / 总额 ¥y`。
/// - medium:头部 `¥已用金额 / 总额 ¥y · xx%` + 一条粗色进度条 + 下面分类用量
///   top3 小卡(分类名 + 各自百分比,按自身用量状态各自着色)。
///
/// 弧/条颜色随用量状态([BudgetUsage.status])变化:`exceeded`/`danger` 用
/// 支出语义色([widgetExpenseColor]),`warning` 用固定琥珀色,`normal` 用
/// [themeColor](品牌色/用户主题色)——三色阶梯与 `budget_page.dart` 的预算页
/// 提醒语义一致(该页判定阈值在 `BudgetUsage.status` getter 里,这里只是复用
/// 同一份状态字符串挑颜色,不重新计算阈值)。
class BudgetView extends StatelessWidget {
  final HWSize size;

  final BudgetOverview overview;

  /// 账本自身币种(ISO code,如 'CNY'),用于金额符号解析——预算金额本身
  /// 没有独立币种列,固定跟随账本(`WidgetDataService.gatherLedgerCurrency`)。
  final String currencyCode;

  final Color themeColor;
  final bool redForIncome;
  final bool dark;

  /// 顶部小标题(小/中共用),l10n 暂无独立 key。
  final String budgetLabel;

  /// small 环形进度中心的副标题(大字 `xx%` 下面那一行)。
  final String usedLabel;

  /// "总额"文案,medium 头部与 small 底部行共用。
  final String totalLabel;

  /// "剩"文案,small 底部行用。
  final String remainingLabel;

  /// 未设总预算时的占位文案。
  final String noBudgetLabel;

  /// medium 下半排的兜底数据:本月支出 Top3 分类**占比**(分类支出/总支出,
  /// `WidgetDataService.gatherTopSpendingShares`)。[overview.categoryBudgets]
  /// 只包含设置过分类预算的分类,多数用户只设总预算 → 为空 → 下半排消失
  /// (真机反馈);此时用这份占比填充。设了分类预算则优先显示预算用量,
  /// 本列表被忽略。
  final List<({String name, double share})> fallbackShares;

  final double width;
  final double height;

  const BudgetView({
    super.key,
    required this.size,
    required this.overview,
    required this.currencyCode,
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    this.budgetLabel = '本月预算',
    this.usedLabel = '已用',
    this.totalLabel = '总额',
    this.remainingLabel = '剩',
    this.noBudgetLabel = '未设预算',
    this.fallbackShares = const [],
    required this.width,
    required this.height,
  });

  String _money(double v) =>
      '${getCurrencySymbol(currencyCode)}${formatMoneyCompact(v)}';

  /// 按用量状态挑颜色,见类文档"弧/条颜色"一节。
  Color _statusColor(String status) {
    switch (status) {
      case 'exceeded':
      case 'danger':
        return widgetExpenseColor(redForIncome);
      case 'warning':
        return const Color(0xFFFFA726);
      default:
        return themeColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (size) {
      case HWSize.small:
        return _buildSmall();
      case HWSize.medium:
      case HWSize.large:
        // budget 目录里没有 large(见 WidgetSpec.catalog),这里兜底按 medium
        // 排版,不让理论上传错 size 的调用方直接崩溃(同 QuickAddView 的约定)。
        return _buildMedium();
    }
  }

  Widget _card({required Widget child}) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widgetCardBackground(dark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _noBudgetPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.savings_outlined, size: 28, color: widgetTextTertiary(dark)),
          const SizedBox(height: 8),
          Text(
            noBudgetLabel,
            style: TextStyle(fontSize: 12, color: widgetTextTertiary(dark)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // small(155×155)
  // -------------------------------------------------------------------
  Widget _buildSmall() {
    final total = overview.totalBudget;
    if (total == null) {
      return _card(child: _noBudgetPlaceholder());
    }

    final pct = (total.rate * 100).round();
    final color = _statusColor(total.status);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            budgetLabel,
            style: TextStyle(fontSize: 12, color: widgetTextSecondary(dark)),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(78, 78),
                      painter: _BudgetRingPainter(
                        progress: total.rate,
                        trackColor: widgetDivider(dark),
                        progressColor: color,
                        strokeWidth: 8,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widgetTextPrimary(dark),
                            fontFeatures: const [kWidgetTabularFeature],
                          ),
                        ),
                        Text(
                          usedLabel,
                          style: TextStyle(fontSize: 10, color: widgetTextSecondary(dark)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            '$remainingLabel ${_money(total.remaining)} / $totalLabel ${_money(total.budget)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: widgetTextSecondary(dark),
              fontFeatures: const [kWidgetTabularFeature],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // medium(364×169)
  // -------------------------------------------------------------------
  Widget _buildMedium() {
    final total = overview.totalBudget;
    // 分类用量:数据服务已截断到前 3 个(`WidgetDataService.gatherBudget` 的
    // topCategoryCount 默认 3),这里再 take(3) 属于防御性重复(同
    // QuickAddView 即便拿到已限量的数据也再 take 一次的约定)。
    final categories = overview.categoryBudgets.take(3).toList();
    final shares = fallbackShares.take(3).toList();

    if (total == null && categories.isEmpty && shares.isEmpty) {
      return _card(child: _noBudgetPlaceholder());
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            budgetLabel,
            style: TextStyle(fontSize: 12, color: widgetTextSecondary(dark)),
          ),
          const SizedBox(height: 4),
          if (total != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _money(total.used),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: widgetTextPrimary(dark),
                    fontFeatures: const [kWidgetTabularFeature],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '/ $totalLabel ${_money(total.budget)} · ${(total.rate * 100).round()}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: widgetTextSecondary(dark)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _progressBar(total),
            const SizedBox(height: 10),
          ] else
            // 有分类预算但没有总预算:总览行退化为一句提示,分类用量照常展示
            // (见类文档"优雅降级"一节——分类预算是真实数据,不因缺总预算而
            // 一并隐藏)。
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                noBudgetLabel,
                style: TextStyle(fontSize: 12, color: widgetTextTertiary(dark)),
              ),
            ),
          if (categories.isNotEmpty)
            Row(
              children: [for (final c in categories) _categoryChip(c)],
            )
          else if (shares.isNotEmpty)
            // 无分类预算的兜底:本月支出 Top3 分类占比(统一主题色——占比
            // 没有"超支/预警"的预算状态语义,不套三色阶梯)。
            Row(
              children: [
                for (final s in shares)
                  _chip(
                    name: s.name,
                    pct: (s.share * 100).round(),
                    color: themeColor,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _progressBar(BudgetUsage usage) {
    const barHeight = 10.0;
    final color = _statusColor(usage.status);
    return ClipRRect(
      borderRadius: BorderRadius.circular(barHeight / 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth * usage.rate.clamp(0.0, 1.0);
          return Stack(
            children: [
              Container(
                height: barHeight,
                width: constraints.maxWidth,
                color: widgetDivider(dark),
              ),
              Container(height: barHeight, width: w, color: color),
            ],
          );
        },
      ),
    );
  }

  Widget _categoryChip(CategoryBudgetUsage c) => _chip(
        name: c.categoryName,
        pct: (c.usage.rate * 100).round(),
        color: _statusColor(c.usage.status),
      );

  /// 分类小卡通用样式:预算用量([_categoryChip])与支出占比兜底共用。
  Widget _chip({required String name, required int pct, required Color color}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: widgetTextSecondary(dark)),
            ),
            const SizedBox(height: 2),
            Text(
              '$pct%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [kWidgetTabularFeature],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 预算环形进度painter:track 圆环 + 按 [progress] 比例扫过的彩色弧,起点在
/// 12 点钟方向顺时针画。[progress] 可能 >1(超支),画布上按满圈处理(视觉上
/// "已经画满",数字文本仍如实显示真实百分比,如 128%)——这与
/// `BudgetUsage.rate` 只在下限 clamp 到 0、上限不设限的语义一致,颜色由
/// [progressColor] 已经按 exceeded 状态传入警示色,不需要 painter 自己再判断。
class _BudgetRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _BudgetRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _BudgetRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
