import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/currencies.dart' show getCurrencySymbol;
import '../../widgets/biz/format_money.dart' show formatMoneyCompact;
import '../widget_data_service.dart' show NetWorthAccountItem;
import '../widget_spec.dart' show HWSize;
import 'widget_view_style.dart';

/// 净资产(netWorth)小组件视图:小/中/大三档,`WidgetSpec.netWorthSmall` /
/// `netWorthMedium` / `netWorthLarge` 对应渲染。
///
/// headless 组件(见 `widget_view_style.dart` 顶部注释)——金额是原始
/// `double`(已折算到 [baseCurrency],口径与 `WidgetDataService
/// .gatherNetWorthBreakdown` 一致),这里用共享的 `getCurrencySymbol` +
/// `formatMoneyCompact` 纯函数格式化,不依赖 BuildContext/ref。
///
/// 三档共用同一份数据(`size` 只影响排版):
/// - small:净资产大数 + 环比 chip + 底部 sparkline。
/// - medium:净资产大数 + 环比 chip + 右上角小 sparkline + 资产/负债进度条。
/// - large:净资产 hero + 大 sparkline(面积填充) + 资产/负债进度条 + 账户
///   明细(取 [topAccounts] 前 4 条)。
///
/// 为避免固定尺寸(iOS/Android 网格档位)下出现 `RenderFlex` 溢出,可变长度
/// 的区块(sparkline / 账户列表)一律用 `Expanded` 吸收剩余空间,账户列表
/// 额外包一层 [WidgetOverflowClip] 裁切兜底——即便数据行数多于预期空间,
/// 也只是裁切而不是抛异常(**禁用 Scrollable**:离屏树无 View 会炸,见
/// WidgetOverflowClip 文档;桌面小组件图本来就不能真的滚动)。
class NetWorthView extends StatelessWidget {
  final HWSize size;

  final double netWorth;
  final double totalAssets;
  final double totalLiabilities;

  /// 折算目标主币种(ISO code,如 'CNY'),用于金额符号解析。
  final String baseCurrency;

  /// 净值趋势序列,由调用方(`WidgetManager`)决定时间跨度——约定近 30 天
  /// (含今天),首尾两点近似"当前 vs 一个月前",供 [_changePercent] 和
  /// sparkline 共用。少于 2 个点时环比/sparkline 均不渲染(数据不足,不是
  /// bug)。
  final List<({DateTime date, double assets, double liabilities, double net})>
      trend;

  /// 账户明细,仅 large 使用(取前 4 条);其余尺寸传空列表即可。
  final List<NetWorthAccountItem> topAccounts;

  final Color themeColor;
  final bool redForIncome;
  final bool dark;

  final String netWorthLabel;
  final String totalAssetsLabel;
  final String totalLiabilitiesLabel;

  /// large 账户明细列表为空时的占位文案,对应 arb key `widgetNoAccounts`。
  final String noAccountsLabel;

  final double width;
  final double height;

  const NetWorthView({
    super.key,
    required this.size,
    required this.netWorth,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.baseCurrency,
    required this.trend,
    this.topAccounts = const [],
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    required this.netWorthLabel,
    required this.totalAssetsLabel,
    required this.totalLiabilitiesLabel,
    this.noAccountsLabel = '暂无账户',
    required this.width,
    required this.height,
  });

  String _money(double v) =>
      '${getCurrencySymbol(baseCurrency)}${formatMoneyCompact(v)}';

  /// 环比:趋势序列首尾两点(见类文档)。起点接近 0 时百分比无意义,返回
  /// null(调用处不渲染 chip)。
  double? get _changePercent {
    if (trend.length < 2) return null;
    final start = trend.first.net;
    final end = trend.last.net;
    if (start.abs() < 0.01) return null;
    return (end - start) / start.abs() * 100;
  }

  List<double> get _netSeries => trend.map((e) => e.net).toList();

  @override
  Widget build(BuildContext context) {
    switch (size) {
      case HWSize.small:
        return _buildSmall();
      case HWSize.medium:
        return _buildMedium();
      case HWSize.large:
        return _buildLarge();
    }
  }

  Widget _card({required Widget child, required EdgeInsets padding, double radius = 20}) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: widgetCardBackground(dark),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }

  Widget _bigNumber(double fontSize) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        _money(netWorth),
        maxLines: 1,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: widgetTextPrimary(dark),
          height: 1.0,
          fontFeatures: const [kWidgetTabularFeature],
        ),
      ),
    );
  }

  Widget _changeChip() {
    final pct = _changePercent;
    if (pct == null) return const SizedBox.shrink();
    final positive = pct >= 0;
    final color = positive ? widgetIncomeColor(redForIncome) : widgetExpenseColor(redForIncome);
    final arrow = positive ? '▲' : '▼';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.24 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$arrow ${pct.abs().toStringAsFixed(1)}%',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _progressRow({
    required String label,
    required double value,
    required double ratio,
    required Color color,
  }) {
    return SizedBox(
      height: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: widgetTextSecondary(dark))),
              Text(
                _money(value),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widgetTextPrimary(dark),
                  fontFeatures: const [kWidgetTabularFeature],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth * ratio.clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Container(height: 6, width: constraints.maxWidth, color: widgetDivider(dark)),
                    Container(height: 6, width: w, color: color),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 资产/负债进度条的分母(占比参照物):两者中较大的绝对值,避免除零。
  double get _progressMax {
    final m = math.max(totalAssets.abs(), totalLiabilities.abs());
    return m < 0.01 ? 1.0 : m;
  }

  // -------------------------------------------------------------------
  // small(155×155)
  // -------------------------------------------------------------------
  Widget _buildSmall() {
    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            netWorthLabel,
            style: TextStyle(fontSize: 12, color: widgetTextSecondary(dark)),
          ),
          const SizedBox(height: 4),
          SizedBox(height: 32, child: _bigNumber(26)),
          const SizedBox(height: 6),
          _changeChip(),
          const Spacer(),
          Expanded(
            child: WidgetSparkline(values: _netSeries, color: themeColor),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // medium(364×169)
  // -------------------------------------------------------------------
  Widget _buildMedium() {
    return _card(
      // 上下 12 是"不贴边"与"不溢出"之间实测的平衡点(2026-07 用户反馈
      // vertical 8 时文字/折线离卡片边太近):三行内容自然高度 ~92,169 里
      // 富余 ~53 由两个 Spacer 弹性吸收,内容区不套死高 SizedBox,避免不同
      // 字体度量下的 RenderFlex 溢出(教训见本文件早期版本,固定死 56/78
      // 高度在真实字体行高下会溢出几像素)。
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 16,
      // 布局对齐设计稿(2026-07 用户点名与 Artifact 样式稿不一致):
      // 行1 标题 + 右上趋势线;行2 大数 + ▲环比 chip(右对齐);
      // 行3 资产/负债**并排两栏**(各自 label+金额 一行 + 进度条)。
      // Spacer 弹性撑满,medium 卡不留底部空白。
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                netWorthLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widgetTextSecondary(dark),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 110,
                height: 34,
                child: WidgetSparkline(values: _netSeries, color: themeColor),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _bigNumber(24)),
              const SizedBox(width: 8),
              _changeChip(),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _progressRow(
                  label: totalAssetsLabel,
                  value: totalAssets,
                  ratio: totalAssets.abs() / _progressMax,
                  color: widgetIncomeColor(redForIncome),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _progressRow(
                  label: totalLiabilitiesLabel,
                  value: totalLiabilities,
                  ratio: totalLiabilities.abs() / _progressMax,
                  color: widgetExpenseColor(redForIncome),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // large(364×382)
  // -------------------------------------------------------------------
  Widget _buildLarge() {
    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // hero 区不套死高 SizedBox,按自然高度排列(原因见 _buildMedium
          // 顶部注释:固定死高在真实字体行高下会 RenderFlex 溢出)。
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                netWorthLabel,
                style: TextStyle(fontSize: 13, color: widgetTextSecondary(dark)),
              ),
              const SizedBox(height: 4),
              SizedBox(height: 36, child: _bigNumber(30)),
              const SizedBox(height: 6),
              _changeChip(),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            flex: 3,
            child: WidgetSparkline(
              values: _netSeries,
              color: themeColor,
              filled: true,
              strokeWidth: 2.5, // large 卡片更大,线略粗一点视觉上更协调
            ),
          ),
          const SizedBox(height: 10),
          _progressRow(
            label: totalAssetsLabel,
            value: totalAssets,
            ratio: totalAssets.abs() / _progressMax,
            color: widgetIncomeColor(redForIncome),
          ),
          const SizedBox(height: 4),
          _progressRow(
            label: totalLiabilitiesLabel,
            value: totalLiabilities,
            ratio: totalLiabilities.abs() / _progressMax,
            color: widgetExpenseColor(redForIncome),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: widgetDivider(dark)),
          const SizedBox(height: 6),
          Expanded(
            flex: 2,
            child: topAccounts.isEmpty
                ? Center(
                    child: Text(
                      noAccountsLabel,
                      style: TextStyle(fontSize: 11, color: widgetTextTertiary(dark)),
                    ),
                  )
                // 每行一个 Expanded 等分槽(同 RecentView 的做法):账户只有
                // 2 条时按自然高度顶对齐会在区块底部剩一截空白(2026-07 用户
                // 点名),等分后行距摊开撑满;槽过矮(账户 4 条 + 真机字体
                // 度量偏大)由 WidgetOverflowClip 裁切兜底。
                : Column(
                    children: [
                      for (final item in topAccounts.take(4))
                        Expanded(
                          child: WidgetOverflowClip(
                            alignment: Alignment.center,
                            child: _accountRow(item),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _accountRow(NetWorthAccountItem item) {
    final converted = item.convertedBalance;
    // 缺有效汇率的账户按原币余额兜底展示(与 gatherNetWorthTopAccounts 的
    // 文档约定一致),此时符号必须用账户自身币种,不能借用 baseCurrency——
    // 两者数值单位不同,混用会读成错误的金额。
    final amountText = converted != null
        ? _money(converted)
        : '${getCurrencySymbol(item.account.currency)}${formatMoneyCompact(item.balance)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: widgetTextPrimary(dark)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amountText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widgetTextPrimary(dark),
              fontFeatures: const [kWidgetTabularFeature],
            ),
          ),
        ],
      ),
    );
  }
}

// 净值趋势折线图直接使用共享的 [WidgetSparkline](widget_view_style.dart,
// 与 dashboard 同一实现)——本文件早期有一份私有复制版,极值点贴边的内缩
// 修复(2026-07)时合并进共享版,避免两处 painter 漂移。
