part of '../../../pages/category/category_manage_page.dart';

mixin _CategoryManagementActions on ConsumerState<CategoryManagePage> {
  TabController get _tabController;

  void _addCategory({String? kind}) async {
    final categoryKind =
        kind ?? (_tabController.index == 0 ? 'expense' : 'income');
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryEditPage(kind: categoryKind),
      ),
    );
    // 无需手动刷新，Repository 层会自动处理
  }

  /// 构建美化的更多菜单
  Widget _buildMoreMenu(
          BuildContext context, AppLocalizations l10n, Color primaryColor,
          {bool guide = false}) =>
      guide
          ? BeeMenuRow(
              title: l10n.v4CategoryToolsTitle,
              subtitle: l10n.v4CategoryToolsHint,
              leading: const BeeLineIcon('Settings2', size: 21),
              onTap: _showCategoryTools)
          : BeeIconButton(
              label: l10n.commonMore,
              icon: const BeeLineIcon('Settings2', size: 21),
              onPressed: _showCategoryTools);

  Future<void> _showCategoryTools() async {
    final l = AppLocalizations.of(context);
    final choice = await showBeeDialog<String>(context,
        title: l.v4CategoryToolsTitle,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.categoryReorderTip,
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          const SizedBox(height: 12),
          BeeActionMenu(actions: [
            BeeAction(
                id: 'share',
                label: l.categoryShare,
                icon: const BeeLineIcon('Share2')),
            BeeAction(
                id: 'add',
                label: l.categoryNew,
                icon: const BeeLineIcon('Plus')),
            BeeAction(
                id: 'import',
                label: l.categoryImport,
                icon: const BeeLineIcon('Download')),
            BeeAction(
                id: 'generate_default',
                label: l.categoryGenerateDefault,
                icon: const BeeLineIcon('Sparkles')),
            BeeAction(
                id: 'clear_unused',
                label: l.categoryClearUnused,
                icon: const BeeLineIcon('Trash2'),
                danger: true),
          ], onSelected: (id) => Navigator.pop(context, id)),
        ]));
    if (!mounted) return;
    switch (choice) {
      case 'share':
        await _shareCategories();
        break;
      case 'add':
        _addCategory();
        break;
      case 'import':
        await _importCategories();
        break;
      case 'generate_default':
        await _generateDefaultCategories();
        break;
      case 'clear_unused':
        await _clearUnusedCategories();
        break;
    }
  }

  Future<void> _generateDefaultCategories() async {
    final l10n = AppLocalizations.of(context);
    final kind = _tabController.index == 0 ? 'expense' : 'income';
    final kindName =
        kind == 'expense' ? l10n.categoryExpense : l10n.categoryIncome;
    final useHierarchical = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var selectedMode = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => BeeDialog(
            title: Text('${l10n.categoryGenerateDefault} · $kindName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BeeRadioTile<bool>(
                  value: false,
                  groupValue: selectedMode,
                  label: l10n.categoryGenerateDefaultFlat,
                  onChanged: (value) =>
                      setDialogState(() => selectedMode = value),
                ),
                BeeRadioTile<bool>(
                  value: true,
                  groupValue: selectedMode,
                  label: l10n.categoryGenerateDefaultHierarchical,
                  onChanged: (value) =>
                      setDialogState(() => selectedMode = value),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.categoryGenerateDefaultHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            actions: [
              BeeButton(
                  label: l10n.commonCancel,
                  kind: BeeButtonKind.secondary,
                  onPressed: () => Navigator.pop(dialogContext)),
              BeeButton(
                  label: l10n.commonConfirm,
                  onPressed: () => Navigator.pop(dialogContext, selectedMode)),
            ],
          ),
        );
      },
    );
    if (useHierarchical == null || !mounted) return;

    try {
      final createdCount = await SeedService.addDefaultCategories(
        repository: ref.read(repositoryProvider),
        l10n: l10n,
        kind: kind,
        hierarchical: useHierarchical,
      );
      if (!mounted) return;
      if (createdCount == 0) {
        showToast(context, l10n.categoryGenerateDefaultNoChanges);
        return;
      }

      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }
      ref.invalidate(categoriesWithCountProvider);
      showToast(context, l10n.categoryGenerateDefaultSuccess(createdCount));
    } catch (e) {
      logger.error('CategoryManage', '生成默认分类失败: $e');
      if (!mounted) return;
      showToast(context, l10n.categoryGenerateDefaultFailed);
    }
  }

  /// 分享分类
  Future<void> _shareCategories() async {
    final l10n = AppLocalizations.of(context);

    // 选择分享范围
    final scope = await showDialog<String>(
      context: context,
      builder: (context) => BeeDialog(
        title: Text(l10n.categoryShareScopeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeeMenuRow(
              leading: const BeeLineIcon('ListFilter'),
              title: _tabController.index == 0
                  ? l10n.categoryShareScopeExpense
                  : l10n.categoryShareScopeIncome,
              onTap: () => Navigator.pop(context, 'current'),
            ),
            BeeMenuRow(
              leading: const BeeLineIcon('Layers'),
              title: l10n.categoryShareScopeAll,
              onTap: () => Navigator.pop(context, 'all'),
            ),
          ],
        ),
        actions: [
          BeeButton(
              label: l10n.commonCancel,
              kind: BeeButtonKind.secondary,
              onPressed: () => Navigator.pop(context)),
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
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
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
        showToast(
            context,
            l10n.categoryShareSuccess(
                outputPath.replaceAll('/storage/emulated/0/', '')));
      } else {
        await SharePlus.instance.share(ShareParams(
          files: [XFile(outputPath)],
          subject: l10n.categoryShareSubject,
        ));
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
        builder: (context) => BeeDialog(
          title: Text(l10n.categoryImportModeTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeeMenuRow(
                leading: const BeeLineIcon('GitMerge'),
                title: l10n.categoryImportModeMerge,
                subtitle: l10n.categoryImportModeMergeDesc,
                onTap: () => Navigator.pop(context, 'merge'),
              ),
              BeeMenuRow(
                leading: const BeeLineIcon('RefreshCw'),
                title: l10n.categoryImportModeOverwrite,
                subtitle: l10n.categoryImportModeOverwriteDesc,
                onTap: () => Navigator.pop(context, 'overwrite'),
              ),
            ],
          ),
          actions: [
            BeeButton(
                label: l10n.commonCancel,
                kind: BeeButtonKind.secondary,
                onPressed: () => Navigator.pop(context)),
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
    final categoriesWithCount =
        ref.read(categoriesWithCountProvider).valueOrNull ?? [];

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
      final categoryName =
          CategoryUtils.getDisplayName(item.category.name, context);
      toDeleteList.add(categoryName);

      // 如果是父分类，添加其所有将被删除的子分类
      if (item.category.level == 1) {
        final children = unusedCategories
            .where((c) => c.category.parentId == item.category.id)
            .toList();
        for (final child in children) {
          final childName =
              CategoryUtils.getDisplayName(child.category.name, context);
          toDeleteList.add('  ├─ $childName');
        }
      }
    }

    // 确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => BeeDialog(
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
          BeeButton(
              label: l10n.commonCancel,
              kind: BeeButtonKind.secondary,
              onPressed: () => Navigator.pop(context, false)),
          BeeButton(
              label: l10n.commonDelete,
              kind: BeeButtonKind.danger,
              onPressed: () => Navigator.pop(context, true)),
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
    final categoriesWithCount =
        ref.read(categoriesWithCountProvider).valueOrNull ?? [];
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
  Future<db.Category>? _transferCategoryFuture;

  Widget _buildTransferIconSetting(
          BuildContext context, AppLocalizations l10n, Color primaryColor) =>
      FutureBuilder<db.Category>(
          future: _transferCategoryFuture ??=
              ref.read(repositoryProvider).getTransferCategory(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final category = snapshot.requireData;
            return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: BeeSurface(
                    padding: EdgeInsets.zero,
                    child: BeeMenuRow(
                        title: l10n.transferIconSettings,
                        subtitle: l10n.transferIconSettingsDesc,
                        leading: RecordingCategoryIcon(
                            category: category,
                            size: 22,
                            color: Theme.of(context).colorScheme.onSurface),
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => CategoryEditPage(
                                  category: category, kind: 'transfer')));
                          if (mounted) {
                            setState(() => _transferCategoryFuture = ref
                                .read(repositoryProvider)
                                .getTransferCategory());
                          }
                        })));
          });
}
