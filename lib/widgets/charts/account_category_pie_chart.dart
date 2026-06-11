import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../providers/theme_providers.dart';
import '../../data/db.dart' as db;
import '../biz/section_card.dart';
import 'category_pie_chart.dart';

/// 账户级分类饼图（支出/收入切换）
class AccountCategoryPieChart extends ConsumerStatefulWidget {
  final List<({int? id, String name, String? icon, double total})> expenseData;
  final List<({int? id, String name, String? icon, double total})> incomeData;
  final Color? accentColor;
  /// embedded 模式下不渲染外层 SectionCard、标题和类型切换
  final bool embedded;
  /// embedded 模式下由父级指定展示类型('expense'/'income'),
  /// 否则组件内部 _selectedType 永远是默认的 expense,收入数据显示不出来
  final String? type;

  const AccountCategoryPieChart({
    super.key,
    required this.expenseData,
    required this.incomeData,
    this.accentColor,
    this.embedded = false,
    this.type,
  });

  @override
  ConsumerState<AccountCategoryPieChart> createState() =>
      _AccountCategoryPieChartState();
}

class _AccountCategoryPieChartState
    extends ConsumerState<AccountCategoryPieChart> {
  String _selectedType = 'expense';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Color primaryColor = widget.accentColor ?? ref.watch(primaryColorProvider);

    // embedded 模式由父级 tab 决定类型;独立模式用内部切换状态
    final selectedType =
        widget.embedded ? (widget.type ?? 'expense') : _selectedType;
    final data =
        selectedType == 'expense' ? widget.expenseData : widget.incomeData;
    if (data.isEmpty && widget.expenseData.isEmpty && widget.incomeData.isEmpty) {
      return const SizedBox.shrink();
    }

    // 转换数据格式为 PieCategoryItem
    final pieItems = data.map((item) {
      return (
        id: item.id,
        name: item.name,
        category: null as db.Category?,
        total: item.total,
        subCategories:
            <({int id, db.Category category, String name, double total})>[],
      );
    }).toList();

    final sum = data.fold<double>(0.0, (s, item) => s + item.total);

    // embedded 模式：只输出饼图内容
    if (widget.embedded) {
      if (data.isEmpty) {
        return Padding(
          padding: EdgeInsets.all(24.0.scaled(context, ref)),
          child: Center(
            child: Text(
              l10n.commonEmpty,
              style: TextStyle(
                fontSize: 14,
                color: BeeTokens.textTertiary(context),
              ),
            ),
          ),
        );
      }
      return CategoryPieChart(data: pieItems, sum: sum);
    }

    return SectionCard(
      child: Padding(
        padding: EdgeInsets.all(12.0.scaled(context, ref)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.accountCategoryBreakdown,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                const Spacer(),
                // 支出/收入切换
                _TypeChip(
                  label: l10n.accountCategoryExpense,
                  isSelected: _selectedType == 'expense',
                  primaryColor: primaryColor,
                  onTap: () => setState(() => _selectedType = 'expense'),
                ),
                SizedBox(width: 8.0.scaled(context, ref)),
                _TypeChip(
                  label: l10n.accountCategoryIncome,
                  isSelected: _selectedType == 'income',
                  primaryColor: primaryColor,
                  onTap: () => setState(() => _selectedType = 'income'),
                ),
              ],
            ),
            SizedBox(height: 12.0.scaled(context, ref)),
            if (data.isEmpty)
              Padding(
                padding: EdgeInsets.all(24.0.scaled(context, ref)),
                child: Center(
                  child: Text(
                    l10n.commonEmpty,
                    style: TextStyle(
                      fontSize: 14,
                      color: BeeTokens.textTertiary(context),
                    ),
                  ),
                ),
              )
            else
              CategoryPieChart(
                data: pieItems,
                sum: sum,
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : BeeTokens.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? primaryColor : BeeTokens.textSecondary(context),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
