import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_providers.dart';
import '../data/db.dart' as db;
import '../widgets/ui/ui.dart';
import '../widgets/biz/biz.dart';

class CategoryMigrationPage extends ConsumerStatefulWidget {
  final db.Category? preselectedFromCategory; // 预填充的来源分类
  
  const CategoryMigrationPage({
    super.key,
    this.preselectedFromCategory,
  });
  
  @override
  ConsumerState<CategoryMigrationPage> createState() => _CategoryMigrationPageState();
}

class _CategoryMigrationPageState extends ConsumerState<CategoryMigrationPage> {
  db.Category? _fromCategory;
  db.Category? _toCategory;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    // 预填充来源分类
    _fromCategory = widget.preselectedFromCategory;
  }
  
  @override
  Widget build(BuildContext context) {
    final categoriesWithCountAsync = ref.watch(categoriesWithCountProvider);
    
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: '分类迁移',
            showBack: true,
          ),
          Expanded(
            child: categoriesWithCountAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('加载失败: $error')),
              data: (categoriesWithCount) {
                return _buildMigrationForm(categoriesWithCount);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMigrationForm(List<({db.Category category, int transactionCount})> categoriesWithCount) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '分类迁移说明',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• 将指定分类的所有交易记录迁移到另一个分类\n'
                    '• 迁移后，原分类的交易数据将全部转移到目标分类\n'
                    '• 此操作不可撤销，请谨慎选择',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '迁出分类',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SearchableDropdown<({db.Category category, int transactionCount})>(
            items: categoriesWithCount.where((item) => item.transactionCount > 0).toList(),
            value: categoriesWithCount.where((item) => item.category.id == _fromCategory?.id).firstOrNull,
            hintText: '选择要迁出的分类',
            prefixIcon: const Icon(Icons.upload_outlined),
            onChanged: (item) {
              setState(() {
                _fromCategory = item?.category;
                // 如果选择了相同的分类，清除目标分类
                if (_toCategory?.id == _fromCategory?.id) {
                  _toCategory = null;
                }
              });
            },
            itemBuilder: (item) => _CategoryDropdownItem(
              category: item.category,
              transactionCount: item.transactionCount,
            ),
            filter: (item, query) {
              return item.category.name.toLowerCase().contains(query) ||
                     item.category.kind.toLowerCase().contains(query);
            },
            labelExtractor: (item) => '${item.category.name} (${item.transactionCount}笔)',
          ),
          const SizedBox(height: 24),
          Text(
            '迁入分类',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SearchableDropdown<({db.Category category, int transactionCount})>(
            items: _fromCategory != null 
              ? categoriesWithCount.where((item) => 
                  item.category.kind == _fromCategory!.kind && 
                  item.category.id != _fromCategory!.id
                ).toList()
              : [],
            value: categoriesWithCount.where((item) => item.category.id == _toCategory?.id).firstOrNull,
            hintText: _fromCategory == null ? '请先选择迁出分类' : '选择迁入的分类',
            prefixIcon: const Icon(Icons.download_outlined),
            enabled: _fromCategory != null,
            onChanged: (item) {
              setState(() {
                _toCategory = item?.category;
              });
            },
            itemBuilder: (item) => _CategoryDropdownItem(
              category: item.category,
              transactionCount: item.transactionCount,
            ),
            filter: (item, query) {
              return item.category.name.toLowerCase().contains(query) ||
                     item.category.kind.toLowerCase().contains(query);
            },
            labelExtractor: (item) => '${item.category.name} (${item.transactionCount}笔)',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canMigrate() && !_isLoading ? _performMigration : null,
              child: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('开始迁移'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
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
        title: '无法迁移',
        message: '选择的分类无法进行迁移，请检查分类状态。',
      );
      return;
    }
    
    // 确认迁移
    if (!mounted) return;
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: '确认迁移',
      message: '确定要将「${fromCategory.name}」的 ${migrationInfo.transactionCount} 笔交易迁移到「${toCategory.name}」吗？\n\n此操作不可撤销！',
      okLabel: '确认迁移',
      cancelLabel: '取消',
    ) ?? false;
    
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
        title: '迁移完成',
        message: '成功将 $migratedCount 笔交易从「${fromCategory.name}」迁移到「${toCategory.name}」。',
      );
      
      // 刷新数据
      ref.invalidate(categoriesWithCountProvider);
      
      // 返回上一页
      Navigator.of(context).pop(true);
      
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: '迁移失败',
        message: '迁移过程中发生错误：$e',
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

class _CategoryDropdownItem extends StatelessWidget {
  final db.Category category;
  final int transactionCount;
  
  const _CategoryDropdownItem({
    required this.category,
    required this.transactionCount,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getCategoryIcon(category.icon),
            color: Theme.of(context).colorScheme.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (transactionCount > 0)
                Text(
                  '$transactionCount笔 · ${category.kind == 'expense' ? '支出' : '收入'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
  
  IconData _getCategoryIcon(String? iconName) {
    if (iconName == null || iconName.isEmpty) {
      return Icons.category;
    }
    
    // 这里可以复用分类管理页面的图标映射逻辑
    // 为了简化，暂时使用默认图标
    switch (iconName) {
      case 'restaurant': return Icons.restaurant;
      case 'directions_car': return Icons.directions_car;
      case 'shopping_cart': return Icons.shopping_cart;
      case 'home': return Icons.home;
      case 'work': return Icons.work;
      case 'savings': return Icons.savings;
      case 'card_giftcard': return Icons.card_giftcard;
      default: return Icons.category;
    }
  }
}