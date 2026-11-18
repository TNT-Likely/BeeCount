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
  bool _accountHidden = false, _toAccountHidden = false;
  String? _currencyCode,
      _ledgerCurrency,
      _ledgerName,
      _accountName,
      _toAccountName;
  String? _loadError, _writeError;
  bool get _isEditing => widget.recurring != null;

  DateTime? _effectiveDraftLastGenerated() {
    final prev = widget.recurring?.lastGeneratedDate;
    if (prev == null) return null;
    final prevDay = RecurringTransactionService.dateOnly(prev);
    final startDay = RecurringTransactionService.dateOnly(_startDate);
    // 若用户显式把开始日期调到了上次生成日之后，从新开始日期重新起算
    if (startDay.isAfter(prevDay)) return null;
    return prevDay;
  }

  @override
  void initState() {
    super.initState();
    final rule = widget.recurring;
    final today = RecurringTransactionService.dateOnly(DateTime.now());
    _type = rule?.type ?? 'expense';
    _frequency = RecurringFrequency.fromString(rule?.frequency ?? 'monthly');
    _interval = rule?.interval ?? 1;
    _startDate = rule == null
        ? today
        : RecurringTransactionService.dateOnly(rule.startDate);
    _endDate = rule?.endDate == null
        ? null
        : RecurringTransactionService.dateOnly(rule!.endDate!);
    _dayOfMonth = _frequency == RecurringFrequency.monthly
        ? (rule == null ? today.day : (rule.dayOfMonth ?? _startDate.day))
        : null;
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
          _accountHidden = from?.hidden ?? false;
          _toAccountName = to?.name;
          _toAccountHidden = to?.hidden ?? false;
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
          _toAccountHidden = false;
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
        if (_frequency == RecurringFrequency.monthly) {
          _dayOfMonth ??= _startDate.day;
        } else {
          // 清理非月频残留的 dayOfMonth，防止切为 yearly 时篡改开始日期锚点
          _dayOfMonth = null;
        }
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
        initial: _dayOfMonth ?? _startDate.day,
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
    if (_amountController.text.isEmpty ||
        double.tryParse(_amountController.text) == null) {
      return false;
    }
    if (_selectedLedgerId == null) {
      return false;
    }
    if (_type != 'transfer' && _selectedCategory == null) {
      return false;
    }
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
    final todayStart = RecurringTransactionService.dateOnly(DateTime.now());
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
      final clean = RecurringTransactionService.dateOnly(date);
      setState(() {
        if (isStartDate) {
          _startDate = clean;
          if (_endDate != null && _endDate!.isBefore(clean)) {
            _endDate = clean;
          }
        } else {
          _endDate = clean;
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
      rateBase: base,
    );
    if (picked == null || !mounted) return;
    final upper = picked.toUpperCase();
    if (upper == _effectiveCurrency()) return;
    setState(() {
      _currencyCode = upper == base.toUpperCase() ? null : upper;
      _selectedAccountId = null;
      _selectedToAccountId = null;
      _accountName = null;
      _toAccountName = null;
      _accountHidden = false;
      _toAccountHidden = false;
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
    final currency = _effectiveCurrency().toUpperCase();
    final allAccounts = await repo.getAllAccounts();
    var accounts = allAccounts
        .where((a) => a.currency.toUpperCase() == currency && !a.hidden)
        .toList();

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

    if (!mounted) return;
    setState(() {
      if (isFromAccount) {
        _selectedAccountId = selected;
        _accountName =
            accounts.where((a) => a.id == selected).firstOrNull?.name;
        _accountHidden = false;
        if (_type == 'transfer' && selected == _selectedToAccountId) {
          _selectedToAccountId = null;
          _toAccountName = null;
          _toAccountHidden = false;
        }
      } else {
        _selectedToAccountId = selected;
        _toAccountName =
            accounts.where((a) => a.id == selected).firstOrNull?.name;
        _toAccountHidden = false;
      }
    });
  }

  Future<void> _saveRecurringTransaction() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);

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
    final normalizedStart = RecurringTransactionService.dateOnly(_startDate);
    final normalizedEnd = _endDate == null
        ? null
        : RecurringTransactionService.dateOnly(_endDate!);
    final effectiveDayOfMonth = _frequency == RecurringFrequency.monthly
        ? (_dayOfMonth ?? normalizedStart.day)
        : null;
    final effectiveInterval =
        _frequency == RecurringFrequency.daily ? 1 : _interval;

    setState(() {
      _saving = true;
      _writeError = null;
    });
    try {
      if (_isEditing) {
        final prevLast = widget.recurring!.lastGeneratedDate;
        final shouldResetCursor = prevLast != null &&
            normalizedStart
                .isAfter(RecurringTransactionService.dateOnly(prevLast));

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
          interval: effectiveInterval,
          dayOfMonth: effectiveDayOfMonth,
          dayOfWeek: null,
          monthOfYear: null,
          startDate: normalizedStart,
          endDate: normalizedEnd,
          enabled: _enabled,
          lastGeneratedDate: null,
          updateLastGeneratedDate: shouldResetCursor,
          currencyCode: _currencyCode,
        );
      } else {
        await repo.addRecurringTransaction(
          ledgerId: _selectedLedgerId!,
          type: _type,
          amount: double.parse(_amountController.text),
          categoryId: _type == 'transfer' ? null : _selectedCategory!.id,
          accountId: _selectedAccountId,
          toAccountId: _selectedToAccountId,
          note: _noteController.text.isEmpty ? null : _noteController.text,
          frequency: _frequency.value,
          interval: effectiveInterval,
          dayOfMonth: effectiveDayOfMonth,
          dayOfWeek: null,
          monthOfYear: null,
          startDate: normalizedStart,
          endDate: normalizedEnd,
          currencyCode: _currencyCode,
        );
      }

      if (_enabled) {
        final generatedLedgers = await RecurringTransactionService
            .generatePendingTransactionsStatic(
          repository: repo,
          rescanIfBusy: true,
        );
        if (mounted) {
          for (final ledgerId in generatedLedgers) {
            await PostProcessor.run(ref, ledgerId: ledgerId);
          }
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
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
