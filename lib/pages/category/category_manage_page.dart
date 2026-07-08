import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../data/db.dart' as db;
import '../../services/billing/post_processor.dart';
import '../../services/category_package_service.dart';
import '../../services/system/logger_service.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/category_utils.dart';
import '../../styles/tokens.dart';
import '../../widgets/category_icon.dart';
import 'category_edit_page.dart';

class CategoryManagePage extends ConsumerStatefulWidget {
  final int initialTabIndex; // 0: 支出, 1: 收入

  const CategoryManagePage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
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
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.categoryTitle,
            showBack: true,
            actions: [
              IconButton(
                onPressed: _shareCategories,
                icon: const Icon(Icons.share_outlined),
                tooltip: l10n.categoryShare,
              ),
              _buildMoreMenu(context, l10n, primaryColor),
            ],
          ),
          TabBar(
            controller: _tabController,
            labelColor: BeeTokens.textPrimary(context),
            unselectedLabelColor: BeeTokens.textSecondary(context),
            tabs: [
              Tab(text: l10n.categoryExpense),
              Tab(text: l10n.categoryIncome),
            ],
          ),
          _buildTransferIconSetting(context, l10n, primaryColor),
          Expanded(
            child: categoriesWithCountAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text(l10n.categoryLoadFailed(error.toString()))),
              data: (categoriesWithCount) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _CategoryGridView(
                      categoriesWithCount: categoriesWithCount,
                      kind: 'expense',
                    ),
                    _CategoryGridView(
                      categoriesWithCount: categoriesWithCount,
                      kind: 'income',
                    ),
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryEditPage(kind: kind),
      ),
    );
    // 无需手动刷新，Repository 层会自动处理
  }

  /// 构建美化的更多菜单
  Widget _buildMoreMenu(BuildContext context, AppLocalizations l10n, Color primaryColor) {
    return BeePopupMenu(
      tooltip: l10n.commonMore,
      primaryColor: primaryColor,
      items: [
        BeeMenuItem.tip(label: l10n.categoryReorderTip),
        const BeeMenuItem.divider(),
        BeeMenuItem.action(
          value: 'add',
          icon: Icons.add_circle_outline,
          label: l10n.categoryNew,
        ),
        BeeMenuItem.action(
          value: 'import',
          icon: Icons.download_outlined,
          label: l10n.categoryImport,
        ),
        const BeeMenuItem.divider(),
        BeeMenuItem.action(
          value: 'clear_unused',
          icon: Icons.delete_sweep_outlined,
          label: l10n.categoryClearUnused,
          isDanger: true,
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'add':
            _addCategory();
            break;
          case 'import':
            _importCategories();
            break;
          case 'clear_unused':
            _clearUnusedCategories();
            break;
        }
      },
    );
  }

  /// 分享分类
  Future<void> _shareCategories() async {
    final l10n = AppLocalizations.of(context);

    // 选择分享范围
    final scope = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.categoryShareScopeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.filter_list),
              title: Text(_tabController.index == 0
                  ? l10n.categoryShareScopeExpense
                  : l10n.categoryShareScopeIncome),
              onTap: () => Navigator.pop(context, 'current'),
            ),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: Text(l10n.categoryShareScopeAll),
              onTap: () => Navigator.pop(context, 'all'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );

    if (scope == null || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);

      // 确定过滤类型
      String? filterKind;
      if (scope == 'current') {
        filterKind = _tabController.index == 0 ? 'expense' : 'income';
      }

      // 生成文件名
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'beecount_categories_$timestamp.zip';

      String outputPath;
      if (Platform.isAndroid) {
        final downloadPath = '/storage/emulated/0/Download/BeeCount';
        final dir = Directory(downloadPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        outputPath = '$downloadPath/$fileName';
      } else {
        final tempDir = await getTemporaryDirectory();
        outputPath = '${tempDir.path}/$fileName';
      }

      // 导出分类包
      await CategoryPackageService.exportPackage(
        repository: repo,
        outputPath: outputPath,
        filterKind: filterKind,
      );

      if (!mounted) return;

      if (Platform.isAndroid) {
        showToast(context, l10n.categoryShareSuccess(outputPath.replaceAll('/storage/emulated/0/', '')));
      } else {
        await Share.shareXFiles(
          [XFile(outputPath)],
          subject: l10n.categoryShareSubject,
        );
      }
    } catch (e) {
      logger.error('CategoryManage', '分享分类失败: $e');
      if (!mounted) return;
      showToast(context, l10n.categoryShareFailed);
    }
  }

  /// 导入分类
  Future<void> _importCategories() async {
    final l10n = AppLocalizations.of(context);

    try {
      // 选择文件
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );
      } catch (e) {
        result = await FilePicker.platform.pickFiles(type: FileType.any);
      }

      if (result == null || result.files.isEmpty || !mounted) return;

      final filePath = result.files.first.path;
      if (filePath == null) {
        showToast(context, l10n.configImportNoFilePath);
        return;
      }

      // 验证文件扩展名
      final fileName = filePath.toLowerCase();
      if (!fileName.endsWith('.zip')) {
        showToast(context, l10n.categoryImportInvalidFile);
        return;
      }

      if (!mounted) return;

      // 选择导入模式
      final mode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.categoryImportModeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.merge_type),
                title: Text(l10n.categoryImportModeMerge),
                subtitle: Text(l10n.categoryImportModeMergeDesc),
                onTap: () => Navigator.pop(context, 'merge'),
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: Text(l10n.categoryImportModeOverwrite),
                subtitle: Text(l10n.categoryImportModeOverwriteDesc),
                onTap: () => Navigator.pop(context, 'overwrite'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      );

      if (mode == null || !mounted) return;

      // 执行导入
      final repo = ref.read(repositoryProvider);

      if (mode == 'overwrite') {
        // 覆盖模式：先清空未使用的分类
        // 注意：有交易记录的分类不会被删除
        await _clearUnusedCategoriesSilent();
      }

      final importResult = await CategoryPackageService.importPackage(
        filePath: filePath,
        repository: repo,
        mode: mode,
      );

      if (!mounted) return;
      showToast(
        context,
        l10n.categoryImportSuccessDetail(
          importResult.imported,
          importResult.skipped,
          importResult.iconsImported,
        ),
      );
      ref.invalidate(categoriesWithCountProvider);
    } catch (e) {
      logger.error('CategoryManage', '导入分类失败: $e');
      if (!mounted) return;
      showToast(context, l10n.categoryImportFailed);
    }
  }

  /// 清空未使用的分类
  Future<void> _clearUnusedCategories() async {
    final l10n = AppLocalizations.of(context);
    final categoriesWithCount = ref.read(categoriesWithCountProvider).valueOrNull ?? [];

    // 找出交易数为0的分类（统计已包含子分类交易数）
    final unusedCategories = categoriesWithCount
        .where((item) => item.transactionCount == 0)
        .toList();

    if (unusedCategories.isEmpty) {
      showToast(context, l10n.categoryClearUnusedEmpty);
      return;
    }

    // 收集将被删除的分类信息（包括子分类）
    final toDeleteList = <String>[];
    for (final item in unusedCategories) {
      final categoryName = CategoryUtils.getDisplayName(item.category.name, context);
      toDeleteList.add(categoryName);

      // 如果是父分类，添加其所有将被删除的子分类
      if (item.category.level == 1) {
        final children = unusedCategories
            .where((c) => c.category.parentId == item.category.id)
            .toList();
        for (final child in children) {
          final childName = CategoryUtils.getDisplayName(child.category.name, context);
          toDeleteList.add('  ├─ $childName');
        }
      }
    }

    // 确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.categoryClearUnusedTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.categoryClearUnusedMessage(unusedCategories.length)),
            const SizedBox(height: 16),
            Text(
              l10n.categoryClearUnusedListTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              toDeleteList.join('\n'),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);
      final ids = unusedCategories.map((item) => item.category.id).toList();
      await repo.deleteCategoriesByIds(ids);

      // 把批量删除推到服务端（分类是 user-scoped ledgerId=0 变更）。
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }

      if (!mounted) return;
      showToast(context, l10n.categoryClearUnusedSuccess(ids.length));
      ref.invalidate(categoriesWithCountProvider);
    } catch (e) {
      logger.error('CategoryManage', '清空未使用分类失败: $e');
      if (!mounted) return;
      showToast(context, l10n.categoryClearUnusedFailed);
    }
  }

  /// 静默清空未使用的分类（用于覆盖导入）
  Future<void> _clearUnusedCategoriesSilent() async {
    final categoriesWithCount = ref.read(categoriesWithCountProvider).valueOrNull ?? [];
    final unusedCategories = categoriesWithCount
        .where((item) => item.transactionCount == 0)
        .toList();

    if (unusedCategories.isEmpty) return;

    final repo = ref.read(repositoryProvider);
    final ids = unusedCategories.map((item) => item.category.id).toList();
    await repo.deleteCategoriesByIds(ids);

    // 跟非 silent 版本对齐:显式 sync 触发,user-global category:delete change
    // 才能跨设备 push 到 server。覆盖导入流程后续也会再触发一次 sync,这里
    // 重复 trigger 也无害(SyncEngine 单飞 + 2s debounce 自动合并)。
    final activeLedgerId = ref.read(currentLedgerIdProvider);
    if (activeLedgerId > 0) {
      unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
    }
  }

  /// 构建转账图标设置区域
  Widget _buildTransferIconSetting(BuildContext context, AppLocalizations l10n, Color primaryColor) {
    return FutureBuilder<db.Category>(
      future: ref.read(repositoryProvider).getTransferCategory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final transferCategory = snapshot.data!;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: BeeTokens.surface(context),
            border: Border.all(
              color: BeeTokens.isDark(context)
                ? primaryColor.withValues(alpha: 0.3)
                : BeeTokens.border(context),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CategoryEditPage(
                      category: transferCategory,
                      kind: 'transfer',
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CategoryIconWidget(
                      category: transferCategory,
                      size: 28,
                      showBackground: true,
                      circular: true,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.transferIconSettings,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: BeeTokens.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.transferIconSettingsDesc,
                            style: TextStyle(
                              fontSize: 13,
                              color: BeeTokens.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: BeeTokens.iconSecondary(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryGridView extends ConsumerStatefulWidget {
  final List<({db.Category category, int transactionCount})> categoriesWithCount;
  final String kind;

  const _CategoryGridView({
    required this.categoriesWithCount,
    required this.kind,
  });

  @override
  ConsumerState<_CategoryGridView> createState() => _CategoryGridViewState();
}

class _CategoryGridViewState extends ConsumerState<_CategoryGridView> {
  List<_CategoryItem> _flatList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_CategoryGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categoriesWithCount != oldWidget.categoriesWithCount ||
        widget.kind != oldWidget.kind) {
      _loadData();
    }
  }

  /// 加载数据：只构建一级分类列表，从已有数据判断是否有子分类
  void _loadData() {
    // 获取当前类型的一级分类
    final topLevelCategories = widget.categoriesWithCount
        .where((item) =>
            item.category.kind == widget.kind &&
            item.category.level == 1)
        .toList();

    // 按 sortOrder 排序
    topLevelCategories.sort((a, b) => a.category.sortOrder.compareTo(b.category.sortOrder));

    // 构建父分类ID集合，用于快速判断是否有子分类
    final parentIds = widget.categoriesWithCount
        .where((item) => item.category.parentId != null)
        .map((item) => item.category.parentId!)
        .toSet();

    final flatList = <_CategoryItem>[];

    for (final topItem in topLevelCategories) {
      // 直接从内存数据判断是否有子分类
      final hasSubCategories = parentIds.contains(topItem.category.id);

      // transactionCount 已经包含了所有子分类的交易数，不需要再累加
      flatList.add(_CategoryItem(
        category: topItem.category,
        transactionCount: topItem.transactionCount,
        isDefault: false,
        isSubCategory: false,
        hasSubCategories: hasSubCategories,
      ));
    }

    setState(() {
      _flatList = flatList;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 数据还未加载完成
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 过滤出一级分类
    final topLevelCategories = _flatList
        .where((item) => !item.isSubCategory && !item.isActionButtons)
        .toList();

    if (topLevelCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: BeeTokens.textTertiary(context),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).categoryEmpty,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: BeeTokens.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableGridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: topLevelCategories.length,
      onReorder: (oldIndex, newIndex) {
        _onReorderTopLevel(oldIndex, newIndex, topLevelCategories);
      },
      itemBuilder: (context, index) {
        final item = topLevelCategories[index];
        return _CategoryCard(
          key: ValueKey(item.category.id),
          item: item,
          onTap: () => _onCategoryTap(item),
        );
      },
    );
  }

  Future<void> _onReorderTopLevel(int oldIndex, int newIndex, List<_CategoryItem> topLevelCategories) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // 1. 立即更新本地状态（乐观更新），避免UI闪回
    final reorderedItems = List<_CategoryItem>.from(topLevelCategories);
    final movedItem = reorderedItems.removeAt(oldIndex);
    reorderedItems.insert(newIndex, movedItem);

    // 重建 _flatList，保持一级分类的新顺序
    setState(() {
      _flatList = reorderedItems;
    });

    // 2. 批量保存到数据库
    final repo = ref.read(repositoryProvider);
    final updates = reorderedItems.asMap().entries.map((entry) {
      return (id: entry.value.category.id, sortOrder: entry.key);
    }).toList();
    await repo.updateCategorySortOrders(updates);

    // 拖拽排序也记了 ChangeTracker 变更，推到云端让 web 的 sortOrder 一致。
    final activeLedgerId = ref.read(currentLedgerIdProvider);
    if (activeLedgerId > 0) {
      unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
    }

    // 3. 刷新 provider 以同步其他地方的数据
    ref.invalidate(categoriesWithCountProvider);
  }


  void _onCategoryTap(_CategoryItem item) async {
    if (item.isSubCategory) {
      await _onEditCategory(item.category);
    } else {
      if (item.hasSubCategories) {
        // 有子分类：弹出对话框
        await _showSubcategoryDialog(item.category);
      } else {
        // 无子分类：直接编辑
        await _onEditCategory(item.category);
      }
    }
  }

  /// 显示子分类对话框
  Future<void> _showSubcategoryDialog(db.Category parentCategory) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => _SubcategoryDialog(
        parentCategory: parentCategory,
        categoriesWithCount: widget.categoriesWithCount,
        onSubCategoryTap: (cat) {
          Navigator.pop(dialogContext);
          _onEditCategory(cat);
        },
        onAddSubCategory: () {
          Navigator.pop(dialogContext);
          _onAddSubCategory(parentCategory);
        },
        onEditParentCategory: () {
          Navigator.pop(dialogContext);
          _onEditCategory(parentCategory);
        },
      ),
    );
  }

  Future<void> _onEditCategory(db.Category category) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryEditPage(
          category: category,
          kind: category.kind,
        ),
      ),
    );
  }

  Future<void> _onAddSubCategory(db.Category parent) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryEditPage(
          kind: parent.kind,
          parentCategory: parent,
        ),
      ),
    );
    _loadData();
  }
}

class _CategoryItem {
  final db.Category category;
  final int transactionCount;
  final bool isDefault;
  final bool isSubCategory;
  final db.Category? parent;
  final bool hasSubCategories;
  final bool isActionButtons; // 是否为操作按钮项

  _CategoryItem({
    required this.category,
    required this.transactionCount,
    required this.isDefault,
    required this.isSubCategory,
    this.parent,
    this.hasSubCategories = false,
    this.isActionButtons = false,
  });
}

class _CategoryCard extends ConsumerWidget {
  final _CategoryItem item;
  final VoidCallback onTap;

  const _CategoryCard({
    super.key,
    required this.item,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 二级分类：使用浅色背景
    final backgroundColor = item.isSubCategory
        ? Colors.orange[50]
        : Theme.of(context).colorScheme.surface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isSubCategory
                ? Colors.orange.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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
                  Container(
                    width: item.isSubCategory ? 28 : 32,
                    height: item.isSubCategory ? 28 : 32,
                    decoration: BoxDecoration(
                      color: item.isSubCategory
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: CategoryIconWidget(
                      category: item.category,
                      size: item.isSubCategory ? 16.0 : 18.0,
                      color: item.isSubCategory
                          ? Colors.orange[700]!
                          : Theme.of(context).colorScheme.primary,
                      circular: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      CategoryUtils.getDisplayName(item.category.name, context),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: item.isSubCategory ? 10 : 12,
                            color: item.isSubCategory ? Colors.orange[900] : null,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).categoryMigrationTransactionLabel(item.transactionCount),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: item.isSubCategory
                              ? Colors.orange[700]
                              : Theme.of(context).colorScheme.outline,
                          fontSize: item.isSubCategory ? 9 : 10,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // 有子分类的一级分类：右下角显示指示器
            if (!item.isSubCategory && item.hasSubCategories)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 子分类对话框
class _SubcategoryDialog extends ConsumerStatefulWidget {
  final db.Category parentCategory;
  final List<({db.Category category, int transactionCount})> categoriesWithCount;
  final Function(db.Category) onSubCategoryTap;
  final VoidCallback onAddSubCategory;
  final VoidCallback onEditParentCategory;

  const _SubcategoryDialog({
    required this.parentCategory,
    required this.categoriesWithCount,
    required this.onSubCategoryTap,
    required this.onAddSubCategory,
    required this.onEditParentCategory,
  });

  @override
  ConsumerState<_SubcategoryDialog> createState() => _SubcategoryDialogState();
}

class _SubcategoryDialogState extends ConsumerState<_SubcategoryDialog> {
  List<({db.Category category, int transactionCount})>? _subCategories;
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadSubCategories();
  }

  Future<void> _loadSubCategories() async {
    final repo = ref.read(repositoryProvider);
    final subCategories = await repo.getSubCategories(widget.parentCategory.id);

    final result = <({db.Category category, int transactionCount})>[];
    for (final subCat in subCategories) {
      final subCount = widget.categoriesWithCount
          .firstWhere(
            (item) => item.category.id == subCat.id,
            orElse: () => (category: subCat, transactionCount: 0),
          )
          .transactionCount;
      result.add((category: subCat, transactionCount: subCount));
    }

    if (mounted) {
      setState(() {
        _subCategories = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: CategoryIconWidget(
                    category: widget.parentCategory,
                    size: 18,
                    color: primaryColor,
                    circular: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    CategoryUtils.getDisplayName(widget.parentCategory.name, context),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 内容区域
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: (_subCategories?.length ?? 0) + 2, // 子分类 + 添加 + 编辑
                itemBuilder: (context, index) {
                  final subCategories = _subCategories ?? [];
                  // 添加按钮
                  if (index == subCategories.length) {
                    return _DialogActionButton(
                      onTap: widget.onAddSubCategory,
                      icon: Icons.add,
                      label: l10n.commonAdd,
                    );
                  }
                  // 编辑按钮
                  if (index == subCategories.length + 1) {
                    return _DialogActionButton(
                      onTap: widget.onEditParentCategory,
                      icon: Icons.edit_outlined,
                      label: l10n.commonEdit,
                    );
                  }
                  // 子分类
                  final item = subCategories[index];
                  return _DialogSubCategoryCard(
                    category: item.category,
                    transactionCount: item.transactionCount,
                    onTap: () => widget.onSubCategoryTap(item.category),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 对话框中的操作按钮
class _DialogActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;

  const _DialogActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = BeeTokens.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: BeeTokens.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? BeeTokens.border(context) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primaryColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
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

/// 对话框中的子分类卡片
class _DialogSubCategoryCard extends StatelessWidget {
  final db.Category category;
  final int transactionCount;
  final VoidCallback onTap;

  const _DialogSubCategoryCard({
    required this.category,
    required this.transactionCount,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = BeeTokens.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: BeeTokens.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? BeeTokens.border(context) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: CategoryIconWidget(
                category: category,
                size: 14,
                color: primaryColor,
                circular: true,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                CategoryUtils.getDisplayName(category.name, context),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              AppLocalizations.of(context).categoryMigrationTransactionLabel(transactionCount),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

