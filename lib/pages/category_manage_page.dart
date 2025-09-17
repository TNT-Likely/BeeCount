import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../providers/database_providers.dart';
import '../data/repository.dart';
import '../widgets/ui/ui.dart';
import '../widgets/ui/toast.dart';
import '../data/db.dart' as db;
import '../services/category_service.dart';
import 'category_edit_page.dart';

class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({super.key});
  
  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> with TickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // 重新构建以更新按钮状态
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final categoriesWithCountAsync = ref.watch(categoriesWithCountProvider);
    
    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: '分类管理',
            showBack: true,
            actions: [
              IconButton(
                onPressed: () => _addCategory(),
                icon: const Icon(Icons.add),
                tooltip: '新建分类',
              ),
            ],
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '支出分类'),
              Tab(text: '收入分类'),
            ],
          ),
          Expanded(
            child: categoriesWithCountAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('加载失败: $error')),
              data: (categoriesWithCount) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _CategoryGridView(categoriesWithCount: categoriesWithCount, kind: 'expense'),
                    _CategoryGridView(categoriesWithCount: categoriesWithCount, kind: 'income'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  void _addCategory() async {
    final kind = _tabController.index == 0 ? 'expense' : 'income';
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryEditPage(kind: kind),
      ),
    );
    
    // 如果有更新，刷新分类列表
    if (result == true) {
      ref.invalidate(categoriesProvider);
      ref.invalidate(categoriesWithCountProvider);
    }
  }
}

class _CategoryGridView extends ConsumerWidget {
  final List<({db.Category category, int transactionCount})> categoriesWithCount;
  final String kind;
  
  const _CategoryGridView({
    required this.categoriesWithCount,
    required this.kind,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取默认分类名单
    final defaultNames = CategoryService.getDefaultCategoryNames(kind);

    // 分离自定义分类和默认分类
    final customCategories = categoriesWithCount
        .where((item) => item.category.kind == kind && !defaultNames.contains(item.category.name))
        .toList();

    // 创建默认分类的虚拟CategoryWithCount对象用于显示
    final defaultCategoryNames = kind == 'expense'
        ? CategoryService.defaultExpenseCategories
        : CategoryService.defaultIncomeCategories;

    final defaultCategoryItems = defaultCategoryNames.map((name) {
      // 查找是否有对应的数据库记录（用于获取交易数量）
      final dbCategory = categoriesWithCount
          .where((item) => item.category.name == name && item.category.kind == kind)
          .firstOrNull;

      // 如果数据库中有记录，使用实际数据；否则创建虚拟记录
      if (dbCategory != null) {
        return dbCategory;
      } else {
        // 创建虚拟的Category对象用于显示
        final iconName = CategoryService.getDefaultCategoryIcon(name, kind);
        final virtualCategory = db.Category(
          id: -1, // 使用负数ID标识虚拟分类
          name: name,
          kind: kind,
          icon: iconName,
        );
        return (category: virtualCategory, transactionCount: 0);
      }
    }).toList();

    // 合并自定义分类和默认分类，默认分类在后
    final allCategories = [...customCategories, ...defaultCategoryItems];

    if (allCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无分类',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 自定义分类网格
        if (customCategories.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: customCategories.length,
            itemBuilder: (context, index) {
              final categoryWithCount = customCategories[index];
              return _CategoryCard(
                category: categoryWithCount.category,
                transactionCount: categoryWithCount.transactionCount,
                isDefault: false,
              );
            },
          ),
          const SizedBox(height: 32),
        ],

        // 分割线和默认分类标题
        if (defaultCategoryItems.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '默认分类',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),

          // 默认分类网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: defaultCategoryItems.length,
            itemBuilder: (context, index) {
              final categoryWithCount = defaultCategoryItems[index];
              return _CategoryCard(
                category: categoryWithCount.category,
                transactionCount: categoryWithCount.transactionCount,
                isDefault: true,
              );
            },
          ),
        ],
      ],
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  final db.Category category;
  final int transactionCount;
  final bool isDefault;

  const _CategoryCard({
    required this.category,
    required this.transactionCount,
    this.isDefault = false,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CategoryEditPage(
              category: category,
              kind: category.kind,
            ),
          ),
        );

        // 如果有更新，刷新分类列表
        if (result == true) {
          ref.invalidate(categoriesProvider);
          ref.invalidate(categoriesWithCountProvider);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CategoryService.getCategoryIcon(category.icon),
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$transactionCount笔',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}