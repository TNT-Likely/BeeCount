import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';

class LineChart extends StatelessWidget {
  final List<double> values;
  final List<double>? secondaryValues; // 第二条线的数据（可选）
  final Color? secondaryColor; // 第二条线的颜色（可选）
  final List<String> xLabels;
  final int? highlightIndex;
  final VoidCallback onSwipeLeft; // 下一周期
  final VoidCallback onSwipeRight; // 上一周期
  final bool showHint;
  final String? hintText;
  final VoidCallback? onCloseHint;
  final VoidCallback? onPrimaryLineTap; // 主线点击回调
  final VoidCallback? onSecondaryLineTap; // 副线点击回调
  final bool whiteBg;
  final bool showGrid;
  final bool showDots;
  final bool annotate;
  final bool hideAmounts; // 是否隐藏金额
  final Color themeColor;
  // 令牌化参数
  final double lineWidth;
  final double dotRadius;
  final double cornerRadius;
  final double xLabelFontSize;
  final double yLabelFontSize;
  final bool isDark; // 是否暗黑模式
  // minimal 模式:用于 sparkline 等嵌入场景,去掉背景 RRect / Y 轴线 / 平均值虚线,
  // 避免卡中卡(白底套白底 + 轴线)的视觉污染。默认 false,旧调用方零变化。
  final bool minimal;

  /// 是否启用内部手势(点击高亮 / 横滑切周期)。资产卡内嵌图等设 false,把 tap
  /// 让给外层 InkWell(点击进全屏页);否则内部 opaque GestureDetector 会吞掉 tap。
  final bool interactive;

  const LineChart({
    super.key,
    required this.values,
    this.secondaryValues,
    this.secondaryColor,
    required this.xLabels,
    required this.highlightIndex,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.showHint,
    this.hintText,
    this.onCloseHint,
    this.onPrimaryLineTap,
    this.onSecondaryLineTap,
    this.whiteBg = true,
    this.showGrid = true,
    this.showDots = true,
    this.annotate = true,
    this.hideAmounts = false,
    required this.themeColor,
    this.lineWidth = 2.0,
    this.dotRadius = 2.5,
    this.cornerRadius = 12,
    this.xLabelFontSize = 10,
    this.yLabelFontSize = 10,
    this.isDark = false,
    this.minimal = false,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) => BeeLineChart(
        values: values,
        secondaryValues: secondaryValues,
        secondaryColor: secondaryColor,
        xLabels: xLabels,
        highlightIndex: highlightIndex,
        onSwipeLeft: onSwipeLeft,
        onSwipeRight: onSwipeRight,
        onPrimaryLineTap: onPrimaryLineTap,
        onSecondaryLineTap: onSecondaryLineTap,
        whiteBg: whiteBg,
        showGrid: showGrid,
        showDots: showDots,
        annotate: annotate,
        hideAmounts: hideAmounts,
        themeColor: themeColor,
        lineWidth: lineWidth,
        dotRadius: dotRadius,
        cornerRadius: cornerRadius,
        xLabelFontSize: xLabelFontSize,
        yLabelFontSize: yLabelFontSize,
        isDark: isDark,
        minimal: minimal,
        interactive: interactive,
        averageColor: BeeTokens.secondaryTextStatic.withValues(alpha: .55),
        gridColor: BeeTokens.dividerStatic,
        backgroundColor: BeeTokens.dividerStatic,
        textColor: isDark ? Colors.white : BeeTokens.primaryTextStatic,
        mutedColor: isDark ? Colors.white70 : BeeTokens.secondaryTextStatic,
        hint: !showHint
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                    color: BeeTokens.dividerStatic,
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(children: [
                      Icon(Icons.swipe,
                          size: 14, color: BeeTokens.textSecondary(context)),
                      const SizedBox(width: 4),
                      Text(
                          hintText ??
                              AppLocalizations.of(context).analyticsSwipeHint,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: BeeTokens.textSecondary(context))),
                      const SizedBox(width: 4),
                      InkWell(
                          onTap: onCloseHint,
                          child: Icon(Icons.close,
                              size: 14,
                              color: BeeTokens.textTertiary(context))),
                    ])),
              ),
      );
}
