import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../styles/tokens.dart';
import '../../widgets/category_icon.dart';
import '../biz/biz.dart';
import '../../utils/category_utils.dart';
import '../../pages/transaction/category_detail_page.dart';
import '../../l10n/app_localizations.dart';
import '../../data/db.dart' as db;

class CategoryRankRow extends ConsumerStatefulWidget {
  final int? categoryId; // 分类ID
  final db.Category? category; // 分类对象（用于显示图标）
  final String name;
  final double value;
  final double percent; // 0..1 (相对于总金额的真实占比)
  final Color color;
  final DateTime start; // 统计开始时间
  final DateTime end; // 统计结束时间
  final String scope; // 周期范围
  final DateTime selMonth; // 选中的月份
  final List<({int id, db.Category category, String name, double total})>?
      subCategories; // 预计算的子分类明细

  const CategoryRankRow({
    super.key,
    this.categoryId,
    this.category,
    required this.name,
    required this.value,
    required this.percent,
    required this.color,
    required this.start,
    required this.end,
    required this.scope,
    required this.selMonth,
    this.subCategories,
  });

  @override
  ConsumerState<CategoryRankRow> createState() => _CategoryRankRowState();
}

class _CategoryRankRowState extends ConsumerState<CategoryRankRow> {
  bool _expanded = false;
  List<
      ({
        int id,
        db.Category category,
        String name,
        double total,
        double percent
      })>? _subCategories;
  bool _hasCheckedSubCategories = false;

  @override
  void didUpdateWidget(CategoryRankRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当一级分类的金额或占比发生变化时，重置二级分类缓存
    if (oldWidget.value != widget.value ||
        oldWidget.percent != widget.percent) {
      _hasCheckedSubCategories = false;
      _subCategories = null;
      // 如果当前是展开状态，重新加载数据
      if (_expanded) {
        _loadSubCategories();
      }
    }
  }

  Future<void> _loadSubCategories() async {
    if (widget.categoryId == null) return;

    // 优先使用预计算的子分类数据（已按时间范围正确聚合）
    if (widget.subCategories != null && widget.subCategories!.isNotEmpty) {
      final totalAmount = widget.value;
      final subCatData = widget.subCategories!
          .where((s) => s.total > 0)
          .map((s) => (
                id: s.id,
                category: s.category,
                name: s.name,
                total: s.total,
                percent: totalAmount > 0
                    ? widget.percent * (s.total / totalAmount)
                    : 0.0,
              ))
          .toList();

      setState(() {
        _hasCheckedSubCategories = true;
        _subCategories = subCatData;
      });
      return;
    }

    // 无预计算数据时，标记为空列表
    setState(() {
      _hasCheckedSubCategories = true;
      _subCategories = [];
    });
  }

  void _handleTap(int? categoryId, String categoryName) {
    if (categoryId == null) return;

    // 生成周期标签
    String? periodLabel;
    if (widget.scope != 'all') {
      periodLabel = _currentPeriodLabel(widget.scope, widget.selMonth, context);
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryDetailPage(
          categoryId: categoryId,
          categoryName: categoryName,
          startDate: widget.scope != 'all' ? widget.start : null,
          endDate: widget.scope != 'all' ? widget.end : null,
          periodLabel: periodLabel,
        ),
      ),
    );
  }

  String _currentPeriodLabel(
      String scope, DateTime selMonth, BuildContext context) {
    switch (scope) {
      case 'year':
        return '${selMonth.year}';
      case 'all':
        return AppLocalizations.of(context).analyticsAllYears;
      default:
        return '${selMonth.year}.${selMonth.month.toString().padLeft(2, '0')}';
    }
  }

  void _handleTopLevelTap() async {
    // 首次点击时检查是否有子分类
    if (!_hasCheckedSubCategories) {
      await _loadSubCategories();
    }

    // 有子分类：展开/折叠
    if (_subCategories != null && _subCategories!.isNotEmpty) {
      setState(() {
        _expanded = !_expanded;
      });
    } else {
      // 无子分类：打开详情页
      _handleTap(widget.categoryId, widget.name);
    }
  }

  Widget _buildCategoryRow({
    required int? categoryId,
    required db.Category? category,
    required String name,
    required double value,
    required double percent,
    required bool isTopLevel,
  }) {
    // 使用统一的 CategoryIconWidget
    final iconWidget = CategoryIconWidget(
      category: category,
      categoryName: name,
      size: isTopLevel ? 20 : 18,
      color: widget.color,
    );

    return InkWell(
      onTap:
          isTopLevel ? _handleTopLevelTap : () => _handleTap(categoryId, name),
      splashColor: isTopLevel ? Colors.transparent : null, // 一级分类无水波纹
      highlightColor: isTopLevel ? Colors.transparent : null, // 一级分类无高亮
      child: Padding(
        padding: EdgeInsets.only(
          left: isTopLevel ? 0 : 16.0, // 二级分类缩进
          top: isTopLevel ? 10.0 : 8.0,
          bottom: isTopLevel ? 10.0 : 8.0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: isTopLevel ? 44 : 38,
              height: isTopLevel ? 44 : 38,
              decoration: BoxDecoration(
                color: isTopLevel
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12)
                    : widget.color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: iconWidget,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          CategoryUtils.getDisplayName(name, context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: isTopLevel ? 14 : 13,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AmountText(
                        value: value,
                        signed: false,
                        decimals: 0,
                        style: TextStyle(fontSize: isTopLevel ? 14 : 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${(percent * 100).toStringAsFixed(1)}%',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: BeeTokens.textTertiary(context),
                                  fontSize: isTopLevel ? 12 : 11,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(
                          height: isTopLevel ? 6 : 5,
                          color: widget.color.withValues(alpha: 0.15),
                        ),
                        FractionallySizedBox(
                          widthFactor: percent.clamp(0, 1),
                          child: Container(
                            height: isTopLevel ? 6 : 5,
                            color: widget.color.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 一级分类
        _buildCategoryRow(
          categoryId: widget.categoryId,
          category: widget.category,
          name: widget.name,
          value: widget.value,
          percent: widget.percent,
          isTopLevel: true,
        ),
        // 二级分类展开区域
        if (_expanded && _subCategories != null && _subCategories!.isNotEmpty)
          ...(_subCategories!.map((subCat) {
            return _buildCategoryRow(
              categoryId: subCat.id,
              category: subCat.category,
              name: subCat.name,
              value: subCat.total,
              percent: subCat.percent, // 使用真实占比
              isTopLevel: false,
            );
          }).toList()),
      ],
    );
  }
}
