part of 'recurring_editor_controls.dart';

mixin _RecurringEditorActions on ConsumerState<RecurringEditorControls> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late String _type;
  late RecurringFrequency _frequency;
  late int _interval;
  late DateTime _startDate;
  DateTime? _endDate;
  int? _dayOfMonth;
  Category? _selectedCategory;
  int? _selectedAccountId, _selectedToAccountId, _selectedLedgerId;
  late bool _enabled;
  bool _hasAttemptedSave = false, _saving = false, _initializing = true;
  String? _currencyCode,
      _ledgerCurrency,
      _ledgerName,
      _accountName,
      _toAccountName;
  String? _loadError, _writeError;
  bool get _isEditing => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.recurring;
    _type = rule?.type ?? 'expense';
    _frequency = RecurringFrequency.fromString(rule?.frequency ?? 'monthly');
    _interval = rule?.interval ?? 1;
    _startDate = rule?.startDate ?? DateTime.now();
    _endDate = rule?.endDate;
    _dayOfMonth = rule == null ? DateTime.now().day : rule.dayOfMonth;
    _selectedAccountId = rule?.accountId;
    _selectedToAccountId = rule?.toAccountId;
    _enabled = rule?.enabled ?? true;
    _selectedLedgerId = rule?.ledgerId ?? ref.read(currentLedgerIdProvider);
    _currencyCode = rule?.currencyCode?.toUpperCase();
    if (rule != null) {
      _amountController.text = rule.amount.toStringAsFixed(2);
      _noteController.text = rule.note ?? '';
    }
    _amountController.addListener(_amountChanged);
    _initialize();
  }

  void _amountChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    setState(() {
      _initializing = true;
      _loadError = null;
    });
    try {
      await _loadLedgerCurrency();
      if (!mounted) return;
      final rule = widget.recurring;
      if (rule != null) {
        final repo = ref.read(repositoryProvider);
        final category = rule.categoryId == null
            ? null
            : await repo.getCategoryById(rule.categoryId!);
        final from = rule.accountId == null
            ? null
            : await repo.getAccount(rule.accountId!);
        final to = rule.toAccountId == null
            ? null
            : await repo.getAccount(rule.toAccountId!);
        if (!mounted) return;
        setState(() {
          _selectedCategory = category;
          _accountName = from?.name;
          _toAccountName = to?.name;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _loadLedgerCurrency() async {
    final ledgerId = _selectedLedgerId;
    if (ledgerId == null) return;
    final ledger = await ref.read(repositoryProvider).getLedgerById(ledgerId);
    if (!mounted || ledgerId != _selectedLedgerId) return;
    setState(() {
      _ledgerName = ledger?.name;
      _ledgerCurrency = (ledger?.currency.isNotEmpty ?? false)
          ? ledger!.currency.toUpperCase()
          : 'CNY';
      if (_currencyCode?.toUpperCase() == _ledgerCurrency) _currencyCode = null;
    });
  }

  String _effectiveCurrency() =>
      _currencyCode ??
      _ledgerCurrency ??
      ref.read(currentLedgerCurrencyProvider);

  void _selectType(String value) => setState(() {
        _type = value;
        _selectedCategory = null;
        if (value != 'transfer') {
          _selectedToAccountId = null;
          _toAccountName = null;
        }
      });

  Future<void> _pickFrequency() async {
    final l = AppLocalizations.of(context);
    final result = await showRecurringEditorWheel<RecurringFrequency>(context,
        initial: _frequency,
        items: RecurringFrequency.values,
        labelBuilder: (value) => recurringEditorFrequencyLabel(l, value),
        title: l.recurringTransactionFrequency);
    if (result != null && mounted) {
      setState(() {
        _frequency = result;
        if (_frequency == RecurringFrequency.daily) _interval = 1;
      });
    }
  }

  Future<void> _pickInterval() async {
    final l = AppLocalizations.of(context);
    final result = await showRecurringEditorWheel<int>(context,
        initial: _interval,
        items: List.generate(12, (i) => i + 1),
        labelBuilder: (value) =>
            recurringEditorIntervalLabel(l, _frequency, value),
        title: l.recurringTransactionInterval);
    if (result != null && mounted) setState(() => _interval = result);
  }

  Future<void> _pickDayOfMonth() async {
    final l = AppLocalizations.of(context);
    final result = await showRecurringEditorWheel<int>(context,
        initial: _dayOfMonth ?? 1,
        items: List.generate(31, (i) => i + 1),
        labelBuilder: (value) => '$value',
        title: l.recurringTransactionDayOfMonth);
    if (result != null && mounted) setState(() => _dayOfMonth = result);
  }

  @override
  void dispose() {
    _amountController.removeListener(_amountChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _getAccountErrorText(bool isFromAccount) {
    if (!_hasAttemptedSave) return null;

    if (isFromAccount) {
      if (_type == 'transfer' && _selectedAccountId == null) {
        return '请选择转出账户';
      }
    } else {
      if (_type == 'transfer' && _selectedToAccountId == null) {
        return '请选择转入账户';
      }
      if (_type == 'transfer' &&
          _selectedAccountId != null &&
          _selectedToAccountId != null &&
          _selectedAccountId == _selectedToAccountId) {
        return '转出账户和转入账户不能相同';
      }
    }

    return null;
  }

  String? _getLedgerErrorText() {
    if (!_hasAttemptedSave) return null;
    if (_selectedLedgerId == null) {
      return '请选择账本';
    }
    return null;
  }

  String? _getCategoryErrorText() {
    if (!_hasAttemptedSave) return null;
    if (_type != 'transfer' && _selectedCategory == null) {
      return '请选择分类';
    }
    return null;
  }

  bool _isFormValid() {
    // 检查金额
    if (_amountController.text.isEmpty ||
        double.tryParse(_amountController.text) == null) {
      return false;
    }

    // 检查账本
    if (_selectedLedgerId == null) {
      return false;
    }

    // 检查分类（非转账）
    if (_type != 'transfer' && _selectedCategory == null) {
      return false;
    }

    // 检查转账账户
    if (_type == 'transfer') {
      if (_selectedAccountId == null || _selectedToAccountId == null) {
        return false;
      }
      if (_selectedAccountId == _selectedToAccountId) {
        return false;
      }
    }

    return true;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    // 开始日期最早只能是今天:禁止历史开始日期,避免回溯生成脏数据(issue #135);
    // 结束日期不早于开始日期。
    final minDate = isStartDate ? todayStart : _startDate;
    var initial = isStartDate ? _startDate : (_endDate ?? _startDate);
    if (initial.isBefore(minDate)) initial = minDate;

    final date = await showRecurringEditorDatePicker(
      context,
      initial: initial,
      minDate: minDate,
      maxDate: DateTime(2100),
    );

    if (date != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  Future<void> _selectLedger() async {
    if (!mounted) return;

    final selected = await showLedgerSelector(
      context,
      currentLedgerId: _selectedLedgerId,
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedLedgerId = selected;
      });
      // 新账本本位币可能不同 → 重载并归一币种(_loadLedgerCurrency 内部处理)
      await _loadLedgerCurrency();
    }
  }

  Future<void> _selectCurrency() async {
    final l10n = AppLocalizations.of(context);
    final String base =
        _ledgerCurrency ?? ref.read(currentLedgerCurrencyProvider);
    final picked = await showCurrencyPickerSheet(
      context,
      selected: _effectiveCurrency(),
      primaryColor: ref.read(primaryColorProvider),
      title: l10n.txCurrencyPickerTitle,
      rateBase: base, // 展示各币种对账本本位币的汇率
    );
    if (picked == null || !mounted) return;
    final upper = picked.toUpperCase();
    if (upper == _effectiveCurrency()) return;
    setState(() {
      _currencyCode = upper == base.toUpperCase() ? null : upper;
      // 币种优先联动:账户列表按币种过滤,旧账户可能已不符 → 清空重选
      _selectedAccountId = null;
      _selectedToAccountId = null;
      _accountName = null;
      _toAccountName = null;
    });
  }

  Future<void> _selectCategory() async {
    if (!mounted) return;

    final selected = await showCategorySelector(
      context,
      type: _type,
      currentCategoryId: _selectedCategory?.id,
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedCategory = selected;
      });
    }
  }

  Future<void> _selectAccount({required bool isFromAccount}) async {
    final repo = ref.read(repositoryProvider);

    // 按**本模板的有效币种**过滤(v32 / issue #444:此前硬按账本本位币过滤,
    // 外币账户根本选不到);排除已隐藏账户
    // (账户隐藏 #240 E2:该处历史上也缺 isTradableType,本期只补 hidden,不扩范围)
    final currency = _effectiveCurrency().toUpperCase();
    final allAccounts = await repo.getAllAccounts();
    var accounts = allAccounts
        .where((a) => a.currency.toUpperCase() == currency && !a.hidden)
        .toList();

    // 如果是选择转入账户，排除已选择的转出账户
    if (!isFromAccount && _selectedAccountId != null) {
      accounts = accounts.where((a) => a.id != _selectedAccountId).toList();
    }

    if (!mounted) return;

    final title = isFromAccount
        ? (_type == 'transfer'
            ? AppLocalizations.of(context).transferFromAccount
            : AppLocalizations.of(context).accountSelectTitle)
        : AppLocalizations.of(context).transferToAccount;

    final selected = await showBeeDialog<int?>(
      context,
      title: title,
      child: SizedBox(
        width: double.maxFinite,
        child: accounts.isEmpty && _type == 'transfer' && !isFromAccount
            ? Text(AppLocalizations.of(context).commonEmpty)
            : Column(mainAxisSize: MainAxisSize.min, children: [
                if (_type != 'transfer' || isFromAccount)
                  BeeMenuRow(
                      title: AppLocalizations.of(context).accountNone,
                      onTap: () => Navigator.of(context).pop(null)),
                for (final account in accounts)
                  BeeMenuRow(
                      title: account.name,
                      selected: account.id ==
                          (isFromAccount
                              ? _selectedAccountId
                              : _selectedToAccountId),
                      onTap: () => Navigator.of(context).pop(account.id)),
              ]),
      ),
    );

    // 用户点击了选项或取消（原契约：取消也清空当前一端）
    if (!mounted) return;
    setState(() {
      if (isFromAccount) {
        _selectedAccountId = selected;
        _accountName =
            accounts.where((a) => a.id == selected).firstOrNull?.name;
        // 如果转出账户与转入账户相同，清空转入账户
        if (_type == 'transfer' && selected == _selectedToAccountId) {
          _selectedToAccountId = null;
          _toAccountName = null;
        }
      } else {
        _selectedToAccountId = selected;
        _toAccountName =
            accounts.where((a) => a.id == selected).firstOrNull?.name;
      }
    });
  }

  Future<void> _saveRecurringTransaction() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);

    // 标记为已尝试保存，触发错误提示显示
    setState(() {
      _hasAttemptedSave = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isFormValid()) {
      return;
    }

    final repo = ref.read(repositoryProvider);

    setState(() {
      _saving = true;
      _writeError = null;
    });
    try {
      if (_isEditing) {
        // 编辑模式：检查是否需要重置 lastGeneratedDate
        bool shouldResetLastGenerated = false;
        if (widget.recurring!.lastGeneratedDate != null &&
            _startDate.isBefore(widget.recurring!.lastGeneratedDate!)) {
          shouldResetLastGenerated = true;
          logger.info('周期账单', '开始日期早于最后生成日期，重置 lastGeneratedDate');
        }

        await repo.updateRecurringTransaction(
          id: widget.recurring!.id,
          ledgerId: _selectedLedgerId!,
          type: _type,
          amount: double.parse(_amountController.text),
          categoryId: _type == 'transfer' ? null : _selectedCategory!.id,
          accountId: _selectedAccountId,
          toAccountId: _selectedToAccountId,
          note: _noteController.text.isEmpty ? null : _noteController.text,
          frequency: _frequency.value,
          interval: _interval,
          dayOfMonth: _dayOfMonth,
          dayOfWeek: null,
          monthOfYear: null,
          startDate: _startDate,
          endDate: _endDate,
          enabled: _enabled,
          currencyCode: _currencyCode, // null = 账本本位币
        );

        // 如果需要重置最后生成日期，单独更新
        if (shouldResetLastGenerated) {
          // 注意：这里需要先清空 lastGeneratedDate
          // 由于 updateLastGeneratedDate 不支持 null，我们需要直接在 updateRecurringTransaction 中处理
          // 暂时跳过这个步骤，后续如果需要可以扩展 Repository 接口
        }
      } else {
        // 新建模式
        await repo.addRecurringTransaction(
          ledgerId: _selectedLedgerId!,
          type: _type,
          amount: double.parse(_amountController.text),
          categoryId: _type == 'transfer' ? null : _selectedCategory!.id,
          accountId: _selectedAccountId,
          toAccountId: _selectedToAccountId,
          note: _noteController.text.isEmpty ? null : _noteController.text,
          frequency: _frequency.value,
          interval: _interval,
          dayOfMonth: _dayOfMonth,
          dayOfWeek: null,
          monthOfYear: null,
          startDate: _startDate,
          endDate: _endDate,
          currencyCode: _currencyCode, // null = 账本本位币
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // 返回 true 表示数据已更改
      }
    } catch (e, stackTrace) {
      // 使用 logger 记录详细错误信息
      logger.error('周期账单保存', '保存失败', e, stackTrace);
      if (mounted) {
        setState(() => _writeError = e.toString());
        showBeeToast(context, '${l10n.commonError}: $e', tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRecurringTransaction() async {
    if (_saving || widget.recurring == null) return;
    final l = AppLocalizations.of(context);
    final confirmed = await showBeeDialog<bool>(context,
        title: l.commonDelete,
        child: Text(l.recurringTransactionDeleteConfirm),
        actions: [
          BeeButton(
              label: l.commonCancel,
              kind: BeeButtonKind.secondary,
              onPressed: () => Navigator.pop(context, false)),
          BeeButton(
              label: l.commonDelete,
              kind: BeeButtonKind.danger,
              onPressed: () => Navigator.pop(context, true)),
        ]);
    if (confirmed != true || !mounted || _saving) return;
    setState(() {
      _saving = true;
      _writeError = null;
    });
    try {
      await ref
          .read(repositoryProvider)
          .deleteRecurringTransaction(widget.recurring!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error, stack) {
      logger.error('周期账单删除', '删除失败', error, stack);
      if (mounted) {
        setState(() => _writeError = error.toString());
        showBeeToast(context, '${l.commonError}: $error', tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
