part of '../../category_manage_page.dart';

class _CategoryGridView extends ConsumerStatefulWidget {
  final Widget tools, transferSetting;
  final List<({db.Category category, int transactionCount})>
      categoriesWithCount;
  final String kind;
  final VoidCallback onAddCategory;

  const _CategoryGridView({
    required this.categoriesWithCount,
    required this.kind,
    required this.tools,
    required this.transferSetting,
    required this.onAddCategory,
  });

  @override
  ConsumerState<_CategoryGridView> createState() => _CategoryGridViewState();
}

class _CategoryGridViewState extends ConsumerState<_CategoryGridView> {
  List<_CategoryItem> _flatList = [];
  bool _isLoading = true;
  Future<void> _sortWrites = Future<void>.value();
  int _pendingSortWrites = 0;

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
            item.category.kind == widget.kind && item.category.level == 1)
        .toList();

    // 按 sortOrder 排序
    topLevelCategories
        .sort((a, b) => a.category.sortOrder.compareTo(b.category.sortOrder));

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

    // A database snapshot from an earlier drop must not undo a later drop
    // that is still waiting to be persisted. Keep current IDs in their local
    // order, while accepting updated names, icons, counts and newly added rows.
    if (_pendingSortWrites > 0) {
      final incoming = {for (final item in flatList) item.category.id: item};
      final ordered = <_CategoryItem>[];
      for (final item in _flatList) {
        final updated = incoming.remove(item.category.id);
        if (updated != null) ordered.add(updated);
      }
      ordered.addAll(incoming.values);
      flatList
        ..clear()
        ..addAll(ordered);
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
    final topLevelCategories =
        _flatList.where((item) => !item.isSubCategory).toList();

    final l10n = AppLocalizations.of(context);
    final byId = {
      for (final row in widget.categoriesWithCount)
        row.category.id: row.category
    };
    BeeManagedCategory data(db.Category cat, int count,
            {List<BeeManagedCategory> children = const [],
            bool isDefault = false}) =>
        BeeManagedCategory(
            id: '${cat.id}',
            name: CategoryUtils.getDisplayName(cat.name, context),
            icon: RecordingCategoryIcon(
                category: cat,
                size: 19,
                color: Theme.of(context).colorScheme.onSurface),
            detail:
                '${children.isEmpty ? '' : '${children.length} ${l10n.categorySubCategoryTitle} · '}${l10n.ledgersRecords('$count')}',
            children: children,
            isDefault: isDefault);
    return BeeCategoryManagementList(
      reorderLabel: l10n.categoryDetailSortTitle,
      manageLabel: l10n.categoryManageChildren,
      empty: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: BeeStatus(
              label: l10n.categoryEmpty,
              action: BeeButton(
                  label: l10n.categoryNew, onPressed: widget.onAddCategory))),
      items: topLevelCategories
          .map((item) => data(item.category, item.transactionCount,
              isDefault: item.isDefault,
              children: (widget.categoriesWithCount
                      .where((r) => r.category.parentId == item.category.id)
                      .toList()
                    ..sort((a, b) =>
                        a.category.sortOrder.compareTo(b.category.sortOrder)))
                  .map((r) => data(r.category, r.transactionCount))
                  .toList()))
          .toList(),
      onEdit: (id) => _onEditCategory(byId[int.parse(id)]!),
      onManageChildren: (id) => _showSubcategoryDialog(byId[int.parse(id)]!),
      onReorder: (oldIndex, newIndex) =>
          _onReorderTopLevel(oldIndex, newIndex, topLevelCategories),
      footer: Column(children: [widget.transferSetting, widget.tools]),
    );
  }

  Future<void> _onReorderTopLevel(
      int oldIndex, int newIndex, List<_CategoryItem> topLevelCategories) {
    if (oldIndex < 0 ||
        oldIndex >= topLevelCategories.length ||
        newIndex < 0 ||
        newIndex > topLevelCategories.length) {
      return Future<void>.value();
    }
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return Future<void>.value();

    final reorderedItems = List<_CategoryItem>.from(topLevelCategories);
    final movedItem = reorderedItems.removeAt(oldIndex);
    reorderedItems.insert(newIndex, movedItem);
    setState(() => _flatList = reorderedItems);

    final repo = ref.read(repositoryProvider);
    final activeLedgerId = ref.read(currentLedgerIdProvider);
    final updates = reorderedItems.asMap().entries.map((entry) {
      return (id: entry.value.category.id, sortOrder: entry.key);
    }).toList();
    _pendingSortWrites++;
    var failed = false;

    // Keep accepted drops in order even if a first database write is slow.
    // The repository stays valid after this page is closed; WidgetRef does not.
    _sortWrites = _sortWrites.then((_) async {
      await repo.updateCategorySortOrders(updates);
      if (!mounted) return;
      ref.invalidate(categoriesProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }
      // categoriesWithCountProvider already watches the database. Invalidating
      // its subscription here needlessly rebuilds the reorderable subtree.
    }).catchError((Object error, StackTrace stack) {
      failed = true;
      logger.error('CategoryManage', '保存分类排序失败', error, stack);
      if (mounted) {
        showBeeToast(context, AppLocalizations.of(context).commonFailed);
      }
    }).whenComplete(() {
      _pendingSortWrites--;
      if (mounted && failed && _pendingSortWrites == 0) _loadData();
    });
    return _sortWrites;
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
    if (mounted) _loadData();
  }
}

class _CategoryItem {
  final db.Category category;
  final int transactionCount;
  final bool isDefault;
  final bool isSubCategory;
  final bool hasSubCategories;

  _CategoryItem({
    required this.category,
    required this.transactionCount,
    required this.isDefault,
    required this.isSubCategory,
    this.hasSubCategories = false,
  });
}

class _SubcategoryDialog extends ConsumerStatefulWidget {
  final db.Category parentCategory;
  final List<({db.Category category, int transactionCount})>
      categoriesWithCount;
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

  bool _loadFailed = false;
  Future<void> _loadSubCategories() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final subCategories =
          await repo.getSubCategories(widget.parentCategory.id);

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
    } catch (error) {
      logger.error('CategoryManage', '加载二级分类失败: $error');
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeDialog(
        title: Row(children: [
          SizedBox(
              width: 32,
              height: 32,
              child: RecordingCategoryIcon(
                  category: widget.parentCategory,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(CategoryUtils.getDisplayName(
                  widget.parentCategory.name, context))),
        ]),
        content: _isLoading
            ? const SizedBox(
                height: 80, child: Center(child: CircularProgressIndicator()))
            : _loadFailed
                ? BeeStatus(
                    label: l.commonError,
                    tone: BeeTone.error,
                    action: BeeButton(
                        label: l.helpCenterRetry,
                        onPressed: _loadSubCategories))
                : BeeCategoryChildrenGrid(
                    items: [
                        for (final row in _subCategories ??
                            <({db.Category category, int transactionCount})>[])
                          BeeManagedCategory(
                              id: '${row.category.id}',
                              name: CategoryUtils.getDisplayName(
                                  row.category.name, context),
                              icon: RecordingCategoryIcon(
                                  category: row.category,
                                  size: 20,
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
                              detail:
                                  l.ledgersRecords('${row.transactionCount}'))
                      ],
                    emptyLabel: l.categoryEmpty,
                    onEdit: (id) => widget.onSubCategoryTap(_subCategories!
                        .firstWhere((row) => row.category.id == int.parse(id))
                        .category)),
        actions: [
          BeeButton(
              label: l.commonAdd,
              kind: BeeButtonKind.secondary,
              icon: const BeeLineIcon('Plus', size: 16),
              onPressed: widget.onAddSubCategory),
          BeeButton(
              label: l.commonEdit,
              kind: BeeButtonKind.secondary,
              icon: const BeeLineIcon('PencilLine', size: 16),
              onPressed: widget.onEditParentCategory),
        ]);
  }
}
