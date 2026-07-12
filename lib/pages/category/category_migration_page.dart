import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_providers.dart';
import '../../providers/theme_providers.dart';
import '../../data/db.dart' as db;
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/category_utils.dart';
import '../../widgets/category_icon.dart';
import '../../styles/tokens.dart';

class CategoryMigrationPage extends ConsumerStatefulWidget {
  final db.Category? preselectedFromCategory; // 预填充的来源分类

  const CategoryMigrationPage({
    super.key,
    this.preselectedFromCategory,
  });

  @override
  ConsumerState<CategoryMigrationPage> createState() =>
      _CategoryMigrationPageState();
}

class _CategoryMigrationPageState extends ConsumerState<CategoryMigrationPage> {
  db.Category? _fromCategory;
  db.Category? _toCategory;
  String? _selectedType; // 'income' or 'expense'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 预填充来源分类
    _fromCategory = widget.preselectedFromCategory;
    if (_fromCategory != null) {
      _selectedType = _fromCategory!.kind;
    } else {
      // 默认选中支出
      _selectedType = 'expense';
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesWithCountAsync = ref.watch(categoriesWithCountProvider);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context).categoryMigrationTitle,
            showBack: true,
          ),
          Expanded(
            child: categoriesWithCountAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                  child: Text(AppLocalizations.of(context)
                      .categoryLoadFailed(error.toString()))),
              data: (categoriesWithCount) {
                return _buildMigrationForm(categoriesWithCount);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationForm(
      List<({db.Category category, int transactionCount})>
          categoriesWithCount) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 说明卡片
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: ref.watch(primaryColorProvider),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.categoryMigrationDescription,
                      style: TextStyle(
                        color: ref.watch(primaryColorProvider),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.categoryMigrationDescriptionContent,
                  style: TextStyle(
                    color: BeeTokens.textSecondary(context),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 类型选择
          Text(
            l10n.categoryMigrationTypeLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: BeeTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  label: l10n.categoryExpense,
                  icon: Icons.trending_down,
                  isSelected: _selectedType == 'expense',
                  onTap: () {
                    setState(() {
                      _selectedType = 'expense';
                      _fromCategory = null;
                      _toCategory = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TypeButton(
                  label: l10n.categoryIncome,
                  icon: Icons.trending_up,
                  isSelected: _selectedType == 'income',
                  onTap: () {
                    setState(() {
                      _selectedType = 'income';
                      _fromCategory = null;
                      _toCategory = null;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 迁出分类
          Text(
            l10n.categoryMigrationFromLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: BeeTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          _CategorySelectorButton(
            category: _fromCategory,
            hintText: l10n.categoryMigrationFromHint,
            icon: Icons.upload_outlined,
            enabled: _selectedType != null,
            onTap: _selectedType != null ? () => _selectFromCategory() : null,
          ),
          const SizedBox(height: 24),

          // 迁入分类
          Text(
            l10n.categoryMigrationToLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: BeeTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          _CategorySelectorButton(
            category: _toCategory,
            hintText: _fromCategory == null
                ? l10n.categoryMigrationToHintFirst
                : l10n.categoryMigrationToHint,
            icon: Icons.download_outlined,
            enabled: _fromCategory != null,
            onTap: _fromCategory != null ? () => _selectToCategory() : null,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  _canMigrate() && !_isLoading ? _performMigration : null,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.categoryMigrationStartButton),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 选择迁出分类
  Future<void> _selectFromCategory() async {
    if (_selectedType == null) return;

    final selected = await showCategorySelector(
      context,
      type: _selectedType!,
      includeParentCategories: false, // 不包含有子分类的父分类
      showTransactionCount: true, // 显示交易笔数
      ledgerId: ref.read(currentLedgerIdProvider),
    );

    if (selected != null) {
      setState(() {
        _fromCategory = selected;
        // 如果选择了相同的分类，清除目标分类
        if (_toCategory?.id == _fromCategory?.id) {
          _toCategory = null;
        }
      });
    }
  }

  /// 选择迁入分类
  Future<void> _selectToCategory() async {
    if (_fromCategory == null) return;

    final selected = await showCategorySelector(
      context,
      type: _fromCategory!.kind,
      includeParentCategories: true, // 可以包含有子分类的父分类
      excludeIds: [_fromCategory!.id], // 排除迁出分类本身
      showTransactionCount: true, // 显示交易笔数
      ledgerId: ref.read(currentLedgerIdProvider),
    );

    if (selected != null) {
      setState(() {
        _toCategory = selected;
      });
    }
  }

  bool _canMigrate() {
    return _fromCategory != null &&
        _toCategory != null &&
        _fromCategory!.id != _toCategory!.id;
  }

  Future<void> _performMigration() async {
    if (!_canMigrate()) return;

    final fromCategory = _fromCategory!;
    final toCategory = _toCategory!;

    // 获取迁移信息
    final repo = ref.read(repositoryProvider);
    final migrationInfo = await repo.getCategoryMigrationInfo(
      fromCategoryId: fromCategory.id,
      toCategoryId: toCategory.id,
    );

    if (!migrationInfo.canMigrate) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).categoryMigrationCannotTitle,
        message: AppLocalizations.of(context).categoryMigrationCannotMessage,
      );
      return;
    }

    // 确认迁移
    if (!mounted) return;
    final confirmed = await AppDialog.confirm<bool>(
          context,
          title: AppLocalizations.of(context).categoryMigrationConfirmTitle,
          message: AppLocalizations.of(context).categoryMigrationConfirmMessage(
            migrationInfo.transactionCount.toString(), // count
            CategoryUtils.getDisplayName(
                fromCategory.name, context), // fromName
            CategoryUtils.getDisplayName(toCategory.name, context), // toName
          ),
          okLabel: AppLocalizations.of(context).categoryMigrationConfirmOk,
          cancelLabel: AppLocalizations.of(context).commonCancel,
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 执行迁移
      final migratedCount = await repo.migrateCategory(
        fromCategoryId: fromCategory.id,
        toCategoryId: toCategory.id,
      );

      if (!mounted) return;

      // 显示结果
      await AppDialog.info(
        context,
        title: AppLocalizations.of(context).categoryMigrationCompleteTitle,
        message: AppLocalizations.of(context).categoryMigrationCompleteMessage(
          migratedCount.toString(),
          CategoryUtils.getDisplayName(fromCategory.name, context),
          CategoryUtils.getDisplayName(toCategory.name, context),
        ),
      );

      if (!mounted) return;

      // 刷新数据
      ref.invalidate(categoriesWithCountProvider);

      // 返回上一页
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).categoryMigrationFailedTitle,
        message: AppLocalizations.of(context)
            .categoryMigrationFailedMessage(e.toString()),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

/// 类型选择按钮（收入/支出）
class _TypeButton extends ConsumerWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(primaryColorProvider);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : BeeTokens.surface(context),
          border: Border.all(
            color: isSelected ? primaryColor : BeeTokens.border(context),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  isSelected ? primaryColor : BeeTokens.iconSecondary(context),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color:
                    isSelected ? primaryColor : BeeTokens.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类选择按钮
class _CategorySelectorButton extends ConsumerWidget {
  final db.Category? category;
  final String hintText;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _CategorySelectorButton({
    required this.category,
    required this.hintText,
    required this.icon,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(primaryColorProvider);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BeeTokens.surface(context),
          border: Border.all(
            color: category != null ? primaryColor : BeeTokens.border(context),
            width: category != null ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: category != null
                    ? primaryColor.withValues(alpha: 0.1)
                    : BeeTokens.surface(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                category != null
                    ? getCategoryIconData(category: category!)
                    : icon,
                color: category != null
                    ? primaryColor
                    : BeeTokens.iconTertiary(context),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // 分类信息
            Expanded(
              child: category != null
                  ? Text(
                      CategoryUtils.getDisplayName(category!.name, context),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: BeeTokens.textPrimary(context),
                      ),
                    )
                  : Text(
                      hintText,
                      style: TextStyle(
                        fontSize: 16,
                        color: enabled
                            ? BeeTokens.textTertiary(context)
                            : BeeTokens.textTertiary(context)
                                .withValues(alpha: 0.5),
                      ),
                    ),
            ),
            // 箭头图标
            Icon(
              Icons.chevron_right,
              color: enabled
                  ? BeeTokens.iconSecondary(context)
                  : BeeTokens.iconTertiary(context),
            ),
          ],
        ),
      ),
    );
  }
}
