/// Shared 4.x desktop card surfaces and typography. All colors and strings
/// must also work in home_widget’s off-screen tree, without an app Theme.
library;

import 'dart:math' as math;

import 'package:beecount_ui/beecount_ui.dart' show BeeCardTheme;
import 'package:flutter/material.dart';

import '../../services/data/category_service.dart' show CategoryService;
import '../../theme.dart' show BeeTheme;

const Color kWidgetHoney = BeeTheme.honeyGold;
const Color kWidgetExpenseRed = Color(0xFFA44036);
const Color kWidgetIncomeGreen = Color(0xFF1A7351);
const kWidgetTabularFeature = FontFeature.tabularFigures();

Color widgetExpenseColor(bool redForIncome, {bool dark = false}) =>
    widgetIncomeColor(!redForIncome, dark: dark);

Color widgetIncomeColor(bool redForIncome, {bool dark = false}) {
  if (redForIncome) return dark ? const Color(0xFFFFABA4) : kWidgetExpenseRed;
  return dark ? const Color(0xFF80D9B1) : kWidgetIncomeGreen;
}

BeeCardTheme _cardTheme(bool dark) =>
    BeeCardTheme.fromBrightness(dark ? Brightness.dark : Brightness.light);

Color widgetCardBackground(bool dark) => _cardTheme(dark).surface;
Color widgetCardSoft(bool dark) => _cardTheme(dark).soft;
Color widgetDivider(bool dark) => _cardTheme(dark).divider;
Color widgetTextPrimary(bool dark) =>
    dark ? const Color(0xFFF4F5F4) : const Color(0xFF19201E);
Color widgetTextSecondary(bool dark) =>
    dark ? const Color(0xFFB2BABD) : const Color(0xFF626A65);
Color widgetTextTertiary(bool dark) => widgetTextSecondary(dark);
Color widgetOnAccent(Color accent) =>
    accent.computeLuminance() > .179 ? const Color(0xFF151713) : Colors.white;

/// The same logical canvas is painted in the app gallery and the headless
/// engine. Retain the host font family while using the card’s own line metrics.
class WidgetCardSurface extends StatelessWidget {
  const WidgetCardSurface({
    super.key,
    required this.dark,
    required this.width,
    required this.height,
    required this.child,
    this.padding,
  });

  final bool dark;
  final double width, height;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inset = width < 200
        ? const EdgeInsets.all(13)
        : height > 250
            ? const EdgeInsets.all(18)
            : const EdgeInsets.symmetric(horizontal: 17, vertical: 15);
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widgetCardBackground(dark),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: padding ?? inset,
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: DefaultTextStyle.of(context).style.fontFamily,
          color: widgetTextPrimary(dark),
          fontSize: 13,
          height: 1.15,
        ),
        child: child,
      ),
    );
  }
}

class WidgetCardHeading extends StatelessWidget {
  const WidgetCardHeading({
    super.key,
    required this.icon,
    required this.title,
    required this.dark,
    this.meta,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final bool dark, compact;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final foreground = widgetTextPrimary(dark);
    return Row(
      children: [
        Icon(icon, color: foreground, size: compact ? 14 : 17),
        SizedBox(width: compact ? 4 : 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(title,
                maxLines: 1,
                style: TextStyle(
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: foreground)),
          ),
        ),
        if (meta?.isNotEmpty == true) ...[
          const SizedBox(width: 5),
          Text(meta!,
              maxLines: 1,
              style: TextStyle(
                  fontSize: compact ? 9 : 11,
                  color: widgetTextSecondary(dark))),
        ],
      ],
    );
  }
}

class WidgetCardEmpty extends StatelessWidget {
  const WidgetCardEmpty({
    super.key,
    required this.icon,
    required this.label,
    required this.dark,
    this.compact = false,
  });
  final IconData icon;
  final String label;
  final bool dark, compact;

  @override
  Widget build(BuildContext context) {
    final color = widgetTextSecondary(dark);
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: compact ? 17 : 22, color: color),
          const SizedBox(height: 5),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(fontSize: compact ? 10 : 12, color: color)),
        ]),
      ),
    );
  }
}

/// Preserve the formatted amount for semantics and keep international currency
/// prefixes on the same baseline as the tabular digits, including signed flows.
class WidgetCardMoney extends StatelessWidget {
  const WidgetCardMoney({
    super.key,
    required this.amount,
    required this.dark,
    this.fontSize = 18,
    this.color,
    this.alignment = Alignment.centerLeft,
  });

  final String amount;
  final bool dark;
  final double fontSize;
  final Color? color;
  final AlignmentGeometry alignment;
  static final _firstDigit = RegExp(r'[0-9]');

  @override
  Widget build(BuildContext context) {
    final firstDigit = amount.indexOf(_firstDigit);
    final split = firstDigit > 0 ? firstDigit : 0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text.rich(
        TextSpan(children: [
          if (split > 0)
            TextSpan(
                text: amount.substring(0, split),
                style: TextStyle(
                    fontSize: fontSize * .55, fontWeight: FontWeight.w500)),
          TextSpan(text: amount.substring(split)),
        ]),
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.1,
          color: color ?? widgetTextPrimary(dark),
          fontFeatures: const [kWidgetTabularFeature],
        ),
      ),
    );
  }
}

/// 分类图标 key 是否"看起来像 emoji"(而非 `CategoryService` 认识的英文标识
/// 符)。已知 key 都是较长的纯 ASCII 标识符(如 'restaurant'),emoji 通常
/// 1~2 个 grapheme 且码点落在 ASCII 之外很远的区域——启发式,不追求 100%
/// 精确,只需对已有数据集合用。
///
bool widgetLooksLikeEmoji(String s) {
  if (s.length > 4) return false;
  final codePoint = s.runes.isEmpty ? 0 : s.runes.first;
  return codePoint > 0x2100;
}

/// 分类图标兜底解析:`icon` 是 emoji 就直接画文字,否则交给
/// `CategoryService.getCategoryIcon`(内部对不认识的 key / null 已兜底
/// `Icons.category`,不会是空)。供 recent/dashboard 复用,见
/// [widgetLooksLikeEmoji] 文档。
Widget widgetCategoryIcon({
  required String? icon,
  required Color color,
  double size = 18,
}) {
  if (icon != null && icon.isNotEmpty && widgetLooksLikeEmoji(icon)) {
    return Text(icon, style: TextStyle(fontSize: size * 0.9));
  }
  return Icon(CategoryService.getCategoryIcon(icon), size: size, color: color);
}

/// Shared net-worth trend for the asset cards and dashboard.
class WidgetSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final bool filled;
  final double strokeWidth;

  const WidgetSparkline({
    super.key,
    required this.values,
    required this.color,
    this.filled = false,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WidgetSparklinePainter(
        values: values,
        color: color,
        filled: filled,
        strokeWidth: strokeWidth,
      ),
      size: Size.infinite,
    );
  }
}

class _WidgetSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool filled;
  final double strokeWidth;

  _WidgetSparklinePainter({
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

    // 极值点垂直方向留 strokeWidth 的内缩:折线映射满 [0, height] 时最高/
    // 最低点的圆头笔触(向外画半个线宽)会被画布裁掉、视觉上"顶到边",
    // 小画布(netWorth medium 右上角 110×34)尤其明显(2026-07 用户反馈)。
    final vInset = strokeWidth;
    final drawH = math.max(size.height - vInset * 2, 1.0);

    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(dx * i, vInset + drawH - ((values[i] - minV) / range) * drawH),
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
  bool shouldRepaint(covariant _WidgetSparklinePainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.filled != filled ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// 离屏渲染安全的「内容超高裁切」兜底,替代
/// `SingleChildScrollView(physics: NeverScrollableScrollPhysics())`:
/// child 按自然高度布局,超出可用高度时静默裁切,不抛 RenderFlex 溢出。
///
/// **为什么不能用 SingleChildScrollView(2026-07 真机红屏根因)**:
/// `ScrollableState.didChangeDependencies` 会调 `View.of(context)`,而
/// home_widget `renderFlutterWidget` 的离屏树是手工 `attachToRenderTree`
/// 的,树里**没有 View 祖先** → 一 build 就抛
/// "View.of() was called with a context that does not contain a View",
/// debug 构建下整卡被替换成红屏渲进 PNG(recent/dashboard/netWorth-large
/// 真机红屏的根因)。宿主 flutter_test 的树自带 View,复现不出,只在真机
/// 离屏渲染触发。**小组件视图一律禁用任何 Scrollable**——有结构断言测试
/// 守着(见 `test/widget/widget_render_harness_repro_test.dart`)。
class WidgetOverflowClip extends StatelessWidget {
  final Widget child;

  /// 内容小于可用高度时的对齐位置。默认顶对齐(整列列表从上往下排);
  /// "行槽等分"场景(如 RecentView 每行一个 Expanded 槽、槽比行的自然
  /// 高度更高)用 [Alignment.center],让行内容垂直居中于自己的槽。
  final Alignment alignment;

  const WidgetOverflowClip({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        minHeight: 0,
        maxHeight: double.infinity,
        alignment: alignment,
        child: child,
      ),
    );
  }
}
