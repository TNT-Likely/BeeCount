/// 桌面小组件 headless views(`GlanceView`/`NetWorthView`/`QuickAddView` 等,
/// `lib/widget/views/*.dart`)共用的视觉规范常量与小工具函数。
///
/// **headless 约束**:这些 View 渲染在独立的 headless Flutter engine 里
/// (`HomeWidget.renderFlutterWidget`),不依赖调用方 App 的 `BuildContext`/
/// `Theme`/Riverpod `ref`——颜色、主题色、明暗态、文案全部由构造参数显式
/// 传入。这里集中的是「设计规范」里各 View 会反复用到的色值/字重,避免每个
/// View 文件各写一份还互相不一致(色值来自 `.docs/home-widget/plan.md` §二)。
///
/// **图片渲染方案的已知限制**:生成的图片不会随系统明暗切换自动重绘;深浅
/// 色靠 App 前台恢复 / 主题变化时重新触发 `WidgetManager.updateAllWidgets`
/// 重渲一张新图——"更及时地触发重渲"的细节留给 Phase C,这里只保证同一次
/// 渲染内 `dark` 参数对应的颜色是对的。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/data/category_service.dart' show CategoryService;

/// 蜜蜂主题强调色(品牌色)。多数场景下和用户可自定义的 `themeColor` 一致
/// (`primaryColorProvider` 默认值就是它),这里单独留一个常量供不想跟随
/// 用户个性化、需要固定"蜜蜂感"的强调元素使用。
const Color kWidgetHoney = Color(0xFFF5A623);

/// 支出/收入固定色值(未叠加 `redForIncome` 前)。
const Color kWidgetExpenseRed = Color(0xFFE5533C);
const Color kWidgetIncomeGreen = Color(0xFF2FA36B);

/// 数字等宽对齐,金额类文本统一叠加这个 FontFeature。
const kWidgetTabularFeature = FontFeature.tabularFigures();

/// 按 `redForIncome` 解析"支出"语义色(true=红色收入方案下支出用绿,
/// false=红色支出方案下支出用红)。
///
/// 与 `styles/tokens.dart` 的 `BeeTokens.expenseColor` 同一套语义,且已在
/// `accounts_page.dart` 里验证过延伸到"负债"这类非交易类支出语义金额上
/// (总负债用 `expenseColor` 着色)——净资产视图的负债进度条/环比跌幅同样
/// 复用这套映射,不是独立发明的红绿方案。
Color widgetExpenseColor(bool redForIncome) =>
    redForIncome ? kWidgetIncomeGreen : kWidgetExpenseRed;

/// 按 `redForIncome` 解析"收入"语义色,见 [widgetExpenseColor]。净资产视图
/// 的资产进度条/环比涨幅复用这套映射(涨=收入语义=正面)。
Color widgetIncomeColor(bool redForIncome) =>
    redForIncome ? kWidgetExpenseRed : kWidgetIncomeGreen;

/// 卡片背景(明/暗)。暗色不直接照搬 App 内「方案D」的纯黑
/// (`BeeColorTokens` 暗黑背景是 #000000)——小组件是桌面上的独立小卡片,不是
/// 全屏页面,纯黑在各种桌面壁纸上容易糊成一片,取比纯黑略浅的深暖灰。
Color widgetCardBackground(bool dark) =>
    dark ? const Color(0xFF1A1712) : Colors.white;

Color widgetTextPrimary(bool dark) =>
    dark ? Colors.white : const Color(0xFF1A1712);

Color widgetTextSecondary(bool dark) =>
    dark ? Colors.white70 : const Color(0xFF6B6B6B);

Color widgetTextTertiary(bool dark) =>
    dark ? Colors.white38 : const Color(0xFFAFAFAF);

Color widgetDivider(bool dark) =>
    dark ? Colors.white12 : const Color(0xFFEDEDED);

/// 分类图标 key 是否"看起来像 emoji"(而非 `CategoryService` 认识的英文标识
/// 符)。已知 key 都是较长的纯 ASCII 标识符(如 'restaurant'),emoji 通常
/// 1~2 个 grapheme 且码点落在 ASCII 之外很远的区域——启发式,不追求 100%
/// 精确,只需对已有数据集合用。
///
/// `QuickAddView` 独立维护着同一算法的私有实现(未改动,避免触碰已上线/
/// 已测试的 Phase B2a 文件);这里是 Phase B2b 新增的 recent/dashboard 两个
/// View 共用的公开版本,彼此并非互相调用,只是同一套算法。
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

/// 趋势折线图(`CustomPainter`,不依赖任何图表三方库)。画法与
/// `NetWorthView` 内部原有的同名私有实现(`_Sparkline`/`_SparklinePainter`)
/// 完全一致——这里是给 dashboard 综合仪表盘(`DashboardView`,Phase B2b 新增)
/// 开的公开版本;`NetWorthView` 自身继续使用它原有的私有实现,不做改动
/// (避免触碰已上线/已测试的 Phase B2a 文件)。[filled] 为 true 时叠一层由深
/// 到透明的面积渐变。
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
