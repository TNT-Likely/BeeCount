part of '../../category_edit_page.dart';

mixin _CategoryEditActions on ConsumerState<CategoryEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  Timer? _debounce;
  bool _busy = false,
      _picking = false,
      _duplicate = false,
      _isSubCategory = false;
  String _icon = 'category';
  String? _customPath;
  bool _newImage = false;
  Future<String?>? _resolvedIcon;
  BeeCategoryIconSource _iconSource = BeeCategoryIconSource.preset;
  db.Category? _parent;
  bool get isEditing => widget.category != null;
  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _icon = categoryLineIconNames.containsKey(category?.icon)
        ? category!.icon!
        : 'category';
    _iconSource = category?.iconType == 'custom'
        ? BeeCategoryIconSource.custom
        : BeeCategoryIconSource.preset;
    _customPath = category?.customIconPath;
    _resolvePreview();
    _isSubCategory =
        category != null ? category.level == 2 : widget.parentCategory != null;
    _parent = widget.parentCategory;
    if (_isSubCategory && category?.parentId != null) {
      ref
          .read(repositoryProvider)
          .getCategoryById(category!.parentId!)
          .then((v) {
        if (mounted) setState(() => _parent = v);
      });
    }
    _nameController.addListener(() {
      _debounce?.cancel();
      if (_duplicate && mounted) setState(() => _duplicate = false);
      _debounce = Timer(const Duration(milliseconds: 500), _checkDuplicate);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _resolvePreview() {
    final path = _customPath;
    _resolvedIcon = path == null
        ? null
        : path.startsWith('/')
            ? Future.value(path)
            : ref.read(categoryIconServiceProvider).resolveIconPath(path);
  }

  Future<void> _checkDuplicate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _busy) return;
    try {
      final result = await ref.read(repositoryProvider).isCategoryNameDuplicate(
          name: name, kind: widget.kind, excludeId: widget.category?.id);
      if (mounted && name == _nameController.text.trim()) {
        setState(() => _duplicate = result);
      }
    } catch (e, s) {
      logger.error('CategoryEditPage', '分类重名检查失败', e, s);
    }
  }

  Future<void> _message(String title, String message) =>
      showBeeDialog<void>(context,
          title: title,
          child: Text(message),
          actions: [
            BeeButton(
                label: AppLocalizations.of(context).commonOk,
                onPressed: () => Navigator.pop(context))
          ]);
  Future<void> _selectParent() async {
    final repo = ref.read(repositoryProvider), l = AppLocalizations.of(context);
    final future = () async {
      var all = await repo.getTopLevelCategories(widget.kind);
      if (repo is LocalRepository) {
        final scope = await repo.db.loadLedgerPickerContext(null);
        all = await repo.db
            .filterCategoriesForLedger(all, scope, topLevelOnly: true);
      }
      return Future.wait(all.map((c) async {
        final count = await repo.getTransactionCountByCategory(c.id);
        final enabled = await repo.hasSubCategories(c.id) || count == 0;
        return (category: c, count: count, enabled: enabled);
      }));
    }();
    final selected = await showBeeSheet<db.Category>(context,
        title: l.categorySelectParentTitle,
        child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .6,
            child: FutureBuilder(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return BeeStatus(
                        label: l.v4RecordingCategoriesFailed,
                        tone: BeeTone.error,
                        action: BeeButton(
                            label: l.commonClose,
                            onPressed: () => Navigator.pop(context)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return BeeCategoryPicker(
                      immediate: true,
                      selected: _parent == null ? null : '${_parent!.id}',
                      items: [
                        for (final row in snapshot.data!)
                          BeeCategoryChoice(
                              id: '${row.category.id}',
                              label: CategoryUtils.getDisplayName(
                                  row.category.name, context),
                              icon:
                                  RecordingCategoryIcon(category: row.category),
                              enabled: row.enabled,
                              detail: row.count > 0
                                  ? l.tagTransactionCount(row.count)
                                  : null)
                      ],
                      searchLabel: l.searchCategoryHint,
                      emptyLabel: l.categoryEmpty,
                      confirmLabel: l.commonConfirm,
                      cancelLabel: l.commonCancel,
                      onConfirm: (id) => Navigator.pop(
                          context,
                          snapshot.data!
                              .firstWhere((row) => '${row.category.id}' == id)
                              .category),
                      onCancel: () => Navigator.pop(context));
                })));
    if (mounted && selected != null) setState(() => _parent = selected);
  }

  Future<void> _pickIcon() async {
    if (_picking || _busy) return;
    setState(() => _picking = true);
    final l = AppLocalizations.of(context);
    try {
      final file = await ref
          .read(categoryIconPickerProvider)
          .pick(context, ref.read(primaryColorProvider));
      if (file == null || !mounted) return;
      await ref.read(categoryIconServiceProvider).validateImage(file);
      if (!mounted) return;
      setState(() {
        _customPath = file.path;
        _newImage = true;
        _iconSource = BeeCategoryIconSource.custom;
        _resolvePreview();
      });
    } catch (e, s) {
      logger.error('CategoryEditPage', '选择自定义分类图标失败', e, s);
      if (mounted) await _message(l.categoryCustomIconError, '$e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _saveCategory() async {
    if (_busy || _picking || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final l = AppLocalizations.of(context);
    if (_isSubCategory && _parent == null) {
      await _message(l.categoryParentRequiredTitle, l.categoryParentRequired);
      return;
    }
    if (_iconSource == BeeCategoryIconSource.custom && _customPath == null) {
      await _message(l.categorySaveError, l.categoryCustomIconRequired);
      return;
    }
    // Guard before the first await, including the final uniqueness check.
    setState(() => _busy = true);
    final repo = ref.read(repositoryProvider),
        database = ref.read(databaseProvider);
    final service = ref.read(categoryIconServiceProvider);
    final name = _nameController.text.trim();
    try {
      if (await repo.isCategoryNameDuplicate(
          name: name, kind: widget.kind, excludeId: widget.category?.id)) {
        if (mounted) {
          setState(() => _duplicate = true);
          await _message(l.categorySaveError, l.categoryNameDuplicate);
        }
        return;
      }
      if (!mounted) return;
      await database.transaction(() async {
        final id = widget.category?.id ??
            (_isSubCategory
                ? await repo.createSubCategory(
                    parentId: _parent!.id,
                    name: name,
                    kind: widget.kind,
                    icon: _icon)
                : await repo.createCategory(
                    name: name, kind: widget.kind, icon: _icon));
        if (_iconSource == BeeCategoryIconSource.custom && _newImage) {
          // Promotion may remove the temporary crop; retain its saved path for a
          // retry if a later database operation rolls back. Never remove old or
          // shared cached icons here; storage GC handles unreferenced files.
          _customPath = await service.saveCustomIcon(File(_customPath!), id);
          _newImage = false;
          _resolvePreview();
        }
        if (isEditing) {
          await repo.updateCategory(id,
              name: name,
              icon: _icon,
              parentId: _isSubCategory ? _parent?.id : null);
        }
        await repo.updateCategoryIcon(id,
            iconType: _iconSource == BeeCategoryIconSource.custom
                ? 'custom'
                : 'material',
            icon: _icon,
            customIconPath: _iconSource == BeeCategoryIconSource.custom
                ? _customPath
                : null);
      });
      if (!mounted) return;
      _refresh();
      showBeeToast(
          context,
          isEditing
              ? l.categoryUpdated(name)
              : _isSubCategory
                  ? l.categorySubCategoryCreated(name)
                  : l.categoryCreated(name));
      Navigator.pop(context, true);
    } catch (e, s) {
      logger.error('CategoryEditPage', '保存分类失败', e, s);
      if (mounted) await _message(l.categorySaveError, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    ref.invalidate(categoriesProvider);
    if (widget.kind == 'transfer') ref.invalidate(transferCategoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);
    if (ledgerId > 0) unawaited(PostProcessor.sync(ref, ledgerId: ledgerId));
  }

  Future<void> _deleteCategory() async {
    if (!isEditing || _busy || _picking) return;
    setState(() => _busy = true);
    final l = AppLocalizations.of(context), repo = ref.read(repositoryProvider);
    try {
      var count = await repo.getTransactionCountByCategory(widget.category!.id);
      if (widget.category!.level == 1) {
        for (final c in await repo.getSubCategories(widget.category!.id)) {
          count += await repo.getTransactionCountByCategory(c.id);
        }
      }
      if (!mounted) return;
      if (count > 0) {
        await _message(
            l.categoryCannotDelete, l.categoryCannotDeleteMessage(count));
        return;
      }
      final confirmed = await showBeeConfirm(context,
          title: l.categoryDeleteConfirmTitle,
          message: l.categoryDeleteConfirmMessage(widget.category!.name),
          confirmLabel: l.commonDelete,
          cancelLabel: l.commonCancel,
          danger: true);
      if (!confirmed || !mounted) return;
      await repo.deleteCategory(widget.category!.id);
      if (!mounted) return;
      _refresh();
      showBeeToast(context, l.categoryDeleted(widget.category!.name));
      Navigator.pop(context, true);
    } catch (e, s) {
      logger.error('CategoryEditPage', '删除分类失败', e, s);
      if (mounted) await _message(l.categoryDeleteError, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
