part of '../../budget_edit_page.dart';

mixin _BudgetEditorActions on ConsumerState<BudgetEditPage> {
  late final TextEditingController _amount;
  late final int _ledgerId;
  late String _type;
  Category? _selected;
  bool _loading = true, _saving = false, _totalUnavailable = false;
  String? _loadError, _amountError;
  List<Category> _categories = [];
  @override
  void initState() {
    super.initState();
    _ledgerId = ref.read(currentLedgerIdProvider);
    _type = widget.budget?.type ?? (widget.isCategory ? 'category' : 'total');
    _amount =
        TextEditingController(text: widget.budget?.amount.toString() ?? '');
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final categories = await repo.getAllCategories();
      final total =
          widget.budget == null ? await repo.getTotalBudget(_ledgerId) : null;
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selected = categories
            .where((c) => c.id == widget.budget?.categoryId)
            .firstOrNull;
        _totalUnavailable = total != null;
        if (_totalUnavailable && _type == 'total') _type = 'category';
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickCategory() async {
    if (_saving || _loading || widget.budget != null) return;
    final l = AppLocalizations.of(context);
    final selected = await showBeeSheet<Category>(context,
        title: l.budgetCategoryLabel,
        child: BeeChoicePicker<Category>(
            items: _categories
                .where((c) => c.kind == 'expense' && c.parentId == null)
                .map((c) => BeeChoice(
                    value: c,
                    title: CategoryUtils.getDisplayName(c.name, context),
                    searchText: c.name,
                    leading: RecordingCategoryIcon(category: c, size: 24)))
                .toList(),
            selected: _selected,
            searchLabel: l.commonSearch,
            emptyLabel: l.budgetCategoryHint,
            onSelected: (value) => Navigator.pop(context, value)));
    if (selected != null && mounted) setState(() => _selected = selected);
  }

  Future<void> _guardWrite() async {
    if (ref.read(currentLedgerIdProvider) != _ledgerId ||
        widget.budget != null && widget.budget!.ledgerId != _ledgerId) {
      throw StateError('Budget ledger changed');
    }
    final ledger = await ref.read(currentLedgerProvider.future);
    if (ledger != null && ledger.isShared && ledger.myRole != 'owner') {
      throw StateError('Budget is owner-only');
    }
    if (ref.read(currentLedgerIdProvider) != _ledgerId) {
      throw StateError('Budget ledger changed');
    }
  }

  void _saved(String message) {
    ref.read(budgetRefreshProvider.notifier).state++;
    unawaited(PostProcessor.sync(ref, ledgerId: _ledgerId));
    showBeeToast(context, message, tone: BeeTone.success);
    Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    final l = AppLocalizations.of(context),
        raw = BeeDecimalInputFormatter.normalize(_amount.text.trim()),
        value = double.tryParse(raw);
    if (value == null || !value.isFinite || value <= 0) {
      setState(() => _amountError = l.budgetAmountHint);
      return;
    }
    if (_type == 'category' && _selected == null) {
      showBeeToast(context, l.budgetCategoryHint, tone: BeeTone.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await _guardWrite();
      if (!mounted) return;
      final repo = ref.read(repositoryProvider), existing = widget.budget;
      if (existing != null) {
        // Original repository updates amount/startDay only; category reassignment
        // remains the original contract and is recorded as Q18 for a decision.
        await repo.updateBudget(existing.id,
            amount: value, startDay: existing.startDay);
      } else {
        await repo.createBudget(
            ledgerId: _ledgerId,
            type: _type,
            categoryId: _selected?.id,
            amount: value,
            startDay: 1);
      }
      if (mounted) _saved(l.budgetSaveSuccess);
    } catch (error) {
      if (mounted) {
        showBeeToast(context, '${l.commonError}: $error', tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving || _loading || widget.budget == null) return;
    final l = AppLocalizations.of(context);
    final confirmed = await showBeeDialog<bool>(context,
        title: l.commonDelete,
        child: Text(l.budgetDeleteConfirm),
        actions: [
          BeeButton(
              label: l.commonCancel,
              kind: BeeButtonKind.secondary,
              onPressed: () => Navigator.pop(context, false)),
          BeeButton(
              label: l.commonDelete,
              kind: BeeButtonKind.danger,
              onPressed: () => Navigator.pop(context, true))
        ]);
    if (confirmed != true || !mounted || _saving) return;
    setState(() => _saving = true);
    try {
      await _guardWrite();
      if (!mounted) return;
      await ref.read(repositoryProvider).deleteBudget(widget.budget!.id);
      if (mounted) _saved(l.budgetDeleteSuccess);
    } catch (error) {
      if (mounted) {
        showBeeToast(context, '${l.commonError}: $error', tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
