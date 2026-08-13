import 'package:flutter/material.dart';

import '../../services/data/category_service.dart' show CategoryService;
import '../widget_data_service.dart' show QuickAddCategoryItem;
import '../widget_spec.dart' show HWSize;
import 'widget_view_style.dart';

/// 快速记账(quickAdd)小组件视图:小/中两档,`WidgetSpec.quickAddSmall` /
/// `quickAddMedium` 对应渲染。
///
/// headless 组件(见 `widget_view_style.dart` 顶部注释)。消费
/// `List<QuickAddCategoryItem>`(本周期支出常用分类,已按用量降序、且已剔除
/// "未分类"桶——见 `WidgetDataService.gatherQuickAddCategories` 文档),
/// 只做展示,不含深链跳转(点击态属原生壳 P3/P4 range,这里只画图)。
///
/// - small(155×155):2×2 格 = 前 3 个分类(不足 3 个用占位格补齐,保持网格
///   形状不塌)+ 第 4 格固定是「记一笔」按钮。
/// - medium(364×169):2×4 格 = 前 7 个分类(同样用占位格补齐)+ 末格固定是
///   「记一笔」。**不是**小号那样只画一行——364×169 里单行格子只占得满
///   上半截,下面一大片空白(2026-08 用户点名"空白很多不好看");两行网格
///   同时把入口数从 4 个提到 7 个,更符合"快速"记账的定位。
class QuickAddView extends StatelessWidget {
  final HWSize size;

  final List<QuickAddCategoryItem> categories;

  final Color themeColor;
  final bool dark;

  /// 「记一笔」按钮文案。l10n 暂无独立 key。
  final String addLabel;

  /// 左上内容标签(「快速记账」,对应 arb `widgetGalleryQuickAddTitle`)——
  /// 六款组件统一的内容标签制(2026-07 用户拍板 A 方案)。
  final String titleLabel;

  final double width;
  final double height;

  const QuickAddView({
    super.key,
    required this.size,
    required this.categories,
    required this.themeColor,
    required this.dark,
    required this.addLabel,
    required this.width,
    required this.height,
    this.titleLabel = '快速记账',
  });

  @override
  Widget build(BuildContext context) {
    switch (size) {
      case HWSize.small:
        return _buildSmall();
      case HWSize.medium:
      case HWSize.large:
        // quickAdd 目录里没有 large(见 WidgetSpec.catalog),这里兜底按
        // medium 排版,不让理论上传错 size 的调用方直接崩溃。
        return _buildMedium();
    }
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widgetCardBackground(dark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  // -------------------------------------------------------------------
  // small(155×155):2×2 网格
  // -------------------------------------------------------------------
  Widget _buildSmall() {
    final cells = <Widget>[
      for (final c in categories.take(3)) _categoryCell(c),
    ];
    while (cells.length < 3) {
      // 分类不足 3 个(如全新账本还没有支出记录)时用占位格补齐,保持
      // 2×2 网格形状不塌——不是 bug,是数据本就还没攒够。
      cells.add(_placeholderCell());
    }
    cells.add(_addButtonCell());

    Widget gridCell(Widget child) => Expanded(
          child: Padding(padding: const EdgeInsets.all(4), child: child),
        );

    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(),
          Expanded(
            child: Row(children: [gridCell(cells[0]), gridCell(cells[1])]),
          ),
          Expanded(
            child: Row(children: [gridCell(cells[2]), gridCell(cells[3])]),
          ),
        ],
      ),
    );
  }

  /// 统一内容标签行(样式与 budget/netWorth 的小标题一致)。bottom 只留 2:
  /// small 155×155 里标题 + 2×2 网格垂直空间紧张,多 2px 就会把格子内容挤溢出。
  Widget _title() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
      child: Text(
        titleLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: widgetTextSecondary(dark),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // medium(364×169):2×4 网格,7 分类 + 「记一笔」
  // -------------------------------------------------------------------
  /// medium 网格列数与总格数(末格恒为「记一笔」,故分类最多 [_mediumColumns]
  /// × 2 - 1 = 7 个)。
  static const _mediumColumns = 4;
  static const _mediumCells = _mediumColumns * 2;

  Widget _buildMedium() {
    final cells = <Widget>[
      for (final c in categories.take(_mediumCells - 1)) _categoryCell(c),
    ];
    // 与 small 同一套策略:分类不够就补占位格,保持网格形状不塌。取数侧
    // (`WidgetDataService.gatherQuickAddCategories`)会用账本里其余支出分类
    // 补足,所以正常账本几乎不会走到这里。
    while (cells.length < _mediumCells - 1) {
      cells.add(_placeholderCell());
    }
    cells.add(_addButtonCell());

    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(),
          for (var row = 0; row < 2; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < _mediumColumns; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: cells[row * _mediumColumns + col],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 格子内容尺寸按档分级:两档都是被 Expanded 严格约束的网格格子(small
  /// 2×2 / medium 2×4),必须保证「内容自然高度 < 行高」,否则 RenderFlex
  /// 溢出。medium 行高约 59(149 可用 - 标题 ~19,再二等分、去掉格间距),比
  /// small 的约 55 略宽裕,故图标/文字各放大一档,但仍留足余量。
  bool get _isSmall => size == HWSize.small;
  double get _cellGlyph => _isSmall ? 20 : 24;
  double get _cellGap => _isSmall ? 2 : 3;
  double get _cellVPad => _isSmall ? 5 : 4;

  /// 分类名/按钮文案字号:medium 格子宽约 80(小号仅约 65),多给 1px 更清楚,
  /// 也让较长的英文分类名少些省略号。
  double get _cellLabel => _isSmall ? 10 : 11;

  Widget _categoryCell(QuickAddCategoryItem item) {
    return Container(
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: dark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: _cellVPad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _categoryGlyph(item.icon),
          SizedBox(height: _cellGap),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _cellLabel,
              fontWeight: FontWeight.w500,
              color: widgetTextPrimary(dark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderCell() {
    return Container(
      decoration: BoxDecoration(
        color: widgetDivider(dark),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Icon(Icons.more_horiz, size: 18, color: widgetTextTertiary(dark)),
      ),
    );
  }

  Widget _addButtonCell() {
    return Container(
      decoration: BoxDecoration(
        color: themeColor,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: _cellVPad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 与 _categoryGlyph 同尺寸(small 紧凑档曾因 22 溢出 3.5px)。
          Icon(Icons.add, color: Colors.white, size: _cellGlyph),
          SizedBox(height: _cellGap),
          Text(
            addLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _cellLabel,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// 分类图标:`icon` 字段绝大多数情况下是 `CategoryService` 认识的图标
  /// key(英文标识符,如 'restaurant'),但字段本身就是"自由字符串",不排除
  /// 未来/异常数据是 emoji——这里做个粗略但足够用的启发式区分:已知 key
  /// 都是较长的纯 ASCII 标识符,emoji 通常 1~2 个 grapheme 且码点落在
  /// ASCII 之外很远的区域。命中 emoji 就直接当文字画,否则一律交给
  /// `CategoryService.getCategoryIcon`(内部对不认识的 key 已兜底
  /// `Icons.category`,不会是空)。
  Widget _categoryGlyph(String? icon) {
    if (icon != null && icon.isNotEmpty && _looksLikeEmoji(icon)) {
      // 高度必须锁死成和 `Icon(size: _cellGlyph)` 一样:裸 Text 的占位高度是
      // 「字号 × 字体行高倍数」,真机/预览用的中文字体下约 1.4 倍,比同字号的
      // Icon 高出近 10px,直接把受 Expanded 约束的网格格子撑爆(RenderFlex
      // overflowed;flutter_test 默认的 Ahem 字体行高恰好是 1.0,所以单元测试
      // 里复现不出来,只有加载真实字体渲染时才暴露)。
      return SizedBox(
        height: _cellGlyph,
        child: Center(
          child: Text(
            icon,
            style: TextStyle(fontSize: _cellGlyph * 0.85, height: 1.0),
          ),
        ),
      );
    }
    return Icon(CategoryService.getCategoryIcon(icon),
        size: _cellGlyph, color: themeColor);
  }

  static bool _looksLikeEmoji(String s) {
    if (s.length > 4) return false;
    final codePoint = s.runes.isEmpty ? 0 : s.runes.first;
    return codePoint > 0x2100;
  }
}
