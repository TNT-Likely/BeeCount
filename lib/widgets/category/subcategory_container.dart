import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart' as db;
import '../../services/data/category_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/category_utils.dart';
import '../../styles/tokens.dart';

/// 二级分类容器组件
/// 用于展示一个一级分类下的所有二级分类，以及操作按钮
class SubcategoryContainer extends ConsumerWidget {
  /// 父分类
  final db.Category parentCategory;

  /// 子分类列表
  final List<({db.Category category, int transactionCount})> subCategories;

  /// 点击子分类回调
  final Function(db.Category) onSubCategoryTap;

  /// 添加子分类回调
  final VoidCallback onAddSubCategory;

  /// 编辑父分类回调
  final VoidCallback onEditParentCategory;

  const SubcategoryContainer({
    super.key,
    required this.parentCategory,
    required this.subCategories,
    required this.onSubCategoryTap,
    required this.onAddSubCategory,
    required this.onEditParentCategory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 计算总项目数：子分类 + 添加按钮 + 编辑按钮
    final totalItems = subCategories.length + 2;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: totalItems,
          itemBuilder: (context, index) {
            // 倒数第二个是添加按钮
            if (index == subCategories.length) {
              return _ActionButton(
                onTap: onAddSubCategory,
                icon: Icons.add,
                label: '添加',
              );
            }

            // 最后一个是编辑按钮
            if (index == subCategories.length + 1) {
              return _ActionButton(
                onTap: onEditParentCategory,
                icon: Icons.edit_outlined,
                label: '编辑',
              );
            }

            final item = subCategories[index];
            return _SubCategoryCard(
              category: item.category,
              transactionCount: item.transactionCount,
              onTap: () => onSubCategoryTap(item.category),
            );
          },
        ),
      ),
    );
  }
}

/// 操作按钮（添加/编辑）
class _ActionButton extends ConsumerWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  const _ActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: BeeTokens.surfacePopoverCard(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: BeeTokens.border(context),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: primaryColor,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 二级分类卡片
class _SubCategoryCard extends ConsumerWidget {
  final db.Category category;
  final int transactionCount;
  final VoidCallback onTap;

  const _SubCategoryCard({
    required this.category,
    required this.transactionCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: BeeTokens.surfacePopoverCard(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: BeeTokens.border(context),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 图标略小 (28 vs 32)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CategoryService.getCategoryIcon(category.icon),
                      color: primaryColor,
                      size: 16, // 略小 (16 vs 18)
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      CategoryUtils.getDisplayName(category.name, context),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10, // 略小 (10 vs 12)
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context)
                        .categoryMigrationTransactionLabel(transactionCount),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 9, // 略小 (9 vs 10)
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
