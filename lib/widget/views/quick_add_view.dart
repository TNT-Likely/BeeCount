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
/// - medium(364×169):一整行(最多 4 个分类 + 「记一笔」,共 5 格),分类
///   数不足时该行自然更宽,不额外补占位格。
class QuickAddView extends StatelessWidget {
  final HWSize size;

  final List<QuickAddCategoryItem> categories;

  final Color themeColor;
  final bool dark;

  /// 「记一笔」按钮文案。l10n 暂无独立 key。
  final String addLabel;

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
        children: [
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

  // -------------------------------------------------------------------
  // medium(364×169):一整行,最多 4 分类 + 「记一笔」
  // -------------------------------------------------------------------
  Widget _buildMedium() {
    final cells = <Widget>[
      for (final c in categories.take(4)) _categoryCell(c),
      _addButtonCell(),
    ];

    return _cardContainer(
      child: Row(
        children: [
          for (final cell in cells)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: cell,
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryCell(QuickAddCategoryItem item) {
    return Container(
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: dark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _categoryGlyph(item.icon),
          const SizedBox(height: 4),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, color: Colors.white, size: 22),
          const SizedBox(height: 2),
          Text(
            addLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
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
      return Text(icon, style: const TextStyle(fontSize: 20));
    }
    return Icon(CategoryService.getCategoryIcon(icon), size: 20, color: themeColor);
  }

  static bool _looksLikeEmoji(String s) {
    if (s.length > 4) return false;
    final codePoint = s.runes.isEmpty ? 0 : s.runes.first;
    return codePoint > 0x2100;
  }
}
