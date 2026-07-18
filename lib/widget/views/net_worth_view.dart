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
/// 额外包一层不可滚动的 `SingleChildScrollView` 兜底——即便数据行数多于
/// 预期空间,也只是裁切而不是抛异常(桌面小组件图本来就不能真的滚动)。
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
            child: _Sparkline(values: _netSeries, color: themeColor),
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
      // 上下 padding 比左右小一点:169 高度本就紧凑,给内容多留一点可用高度
      // (下方两条进度条 + hero 区不套死高 SizedBox,按自然高度排列,避免
      // 不同字体度量下的 RenderFlex 溢出——教训见本文件早期版本,固定死
      // 56/78 高度在真实字体行高下会溢出几像素)。
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      netWorthLabel,
                      style: TextStyle(fontSize: 12, color: widgetTextSecondary(dark)),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(height: 26, child: _bigNumber(22)),
                    const SizedBox(height: 4),
                    _changeChip(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                height: 40,
                child: _Sparkline(values: _netSeries, color: themeColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _progressRow(
            label: totalAssetsLabel,
            value: totalAssets,
            ratio: totalAssets.abs() / _progressMax,
            color: widgetIncomeColor(redForIncome),
          ),
          const SizedBox(height: 2),
          _progressRow(
            label: totalLiabilitiesLabel,
            value: totalLiabilities,
            ratio: totalLiabilities.abs() / _progressMax,
            color: widgetExpenseColor(redForIncome),
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
            child: _Sparkline(
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
                      // l10n 暂无独立"暂无账户"key,先用中文默认值占位。
                      // TODO(i18n): Phase C 补三语 arb key。
                      '暂无账户',
                      style: TextStyle(fontSize: 11, color: widgetTextTertiary(dark)),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: topAccounts.take(4).map(_accountRow).toList(),
                    ),
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

/// 净值趋势折线图(CustomPainter,不依赖任何图表三方库)。[filled] 为 true
/// 时叠一层由深到透明的面积渐变(large 用),否则只画线(small/medium 用)。
class _Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final bool filled;
  final double strokeWidth;

  const _Sparkline({
    required this.values,
    required this.color,
    this.filled = false,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklinePainter(values: values, color: color, filled: filled, strokeWidth: strokeWidth),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool filled;
  final double strokeWidth;

  _SparklinePainter({
    required this.values,
    required this.color,
    required this.filled,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 数据不足 2 个点画不出折线,或画布尺寸为 0(布局挤压到极限)时直接跳过
    // ——不是异常,静默留白即可。
    if (values.length < 2 || size.width <= 0 || size.height <= 0) return;

    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(dx * i, size.height - ((values[i] - minV) / range) * size.height),
    ];

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }

    if (filled) {
      final fillPath = Path()..moveTo(points.first.dx, size.height);
      for (final p in points) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath
        ..lineTo(points.last.dx, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size);
      canvas.drawPath(fillPath, fillPaint);
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.filled != filled ||
      oldDelegate.strokeWidth != strokeWidth;
}
