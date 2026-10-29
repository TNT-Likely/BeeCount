part of '../../account_edit_page.dart';

mixin _AccountEditActions on ConsumerState<AccountEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _initialBalanceController;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _cardLastFourController;
  late final TextEditingController _noteController;
  late String _selectedType;
  late String _selectedCurrency;
  int? _billingDay;
  int? _paymentDueDay;
  bool _reminderEnabled = false;
  int _reminderDaysBefore = 3;
  bool _saving = false;
  bool _pickingCurrency = false;
  bool _balanceLoaded = true;
  bool _balanceLoadFailed = false;
  bool _creditOverpayment = false;
  double? _loadedCurrentBalance;
  bool _isNameDuplicate = false;
  String? _nameErrorText;
  // 账户类型 Tab：0 = 日常账户，1 = 估值账户
  int _typeTab = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    final hasEditableCurrentBalance =
        widget.account != null && !isValuationOnlyType(widget.account!.type);
    _balanceLoaded = !hasEditableCurrentBalance;
    _initialBalanceController = TextEditingController(
      text: !hasEditableCurrentBalance &&
              widget.account?.initialBalance != null &&
              widget.account!.initialBalance != 0.0
          ? widget.account!.initialBalance.abs().toStringAsFixed(2)
          : '',
    );
    _creditLimitController = TextEditingController(
      text: widget.account?.creditLimit != null
          ? widget.account!.creditLimit!.toStringAsFixed(2)
          : '',
    );
    _bankNameController =
        TextEditingController(text: widget.account?.bankName ?? '');
    _cardLastFourController =
        TextEditingController(text: widget.account?.cardLastFour ?? '');
    _noteController = TextEditingController(text: widget.account?.note ?? '');
    _selectedType = widget.account?.type ?? 'cash';
    _selectedCurrency = widget.account?.currency ?? 'CNY';
    _billingDay = widget.account?.billingDay;
    _paymentDueDay = widget.account?.paymentDueDay;
    _typeTab = isValuationOnlyType(_selectedType) ? 1 : 0;
    if (hasEditableCurrentBalance) _loadEditableCurrentBalance();
    _loadReminderSettings();
  }

  Future<void> _loadEditableCurrentBalance() async {
    try {
      final balance = await ref
          .read(repositoryProvider)
          .getAccountBalance(widget.account!.id);
      if (!mounted) return;
      setState(() {
        _loadedCurrentBalance = balance;
        _creditOverpayment = balance > 0;
        _initialBalanceController.text =
            (_selectedType == 'credit_card' ? balance.abs() : balance)
                .toStringAsFixed(2);
        _balanceLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _balanceLoadFailed = true);
      showBeeToast(context, '${AppLocalizations.of(context).commonError}: $error');
    }
  }

  Future<void> _loadReminderSettings() async {
    if (widget.account != null) {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool('cc_reminder_enabled_${widget.account!.id}') ?? false;
      final daysBefore =
          prefs.getInt('cc_reminder_days_${widget.account!.id}') ?? 3;
      if (mounted) {
        setState(() {
          _reminderEnabled = enabled;
          _reminderDaysBefore = daysBefore;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialBalanceController.dispose();
    _creditLimitController.dispose();
    _bankNameController.dispose();
    _cardLastFourController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get isEditing => widget.account != null;

  String? _validateBalance(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty && !isEditing) return null;
    final parsed = double.tryParse(text);
    if (parsed == null ||
        !parsed.isFinite ||
        (_selectedType == 'credit_card' && parsed < 0)) {
      return AppLocalizations.of(context).creditCardAmountInvalid;
    }
    return null;
  }

  String _getInitialBalanceLabel(AppLocalizations l10n) {
    if (_selectedType == 'credit_card') {
      return _creditOverpayment
          ? l10n.creditCardOverpayment
          : l10n.creditCardOwed;
    }
    if (isValuationOnlyType(_selectedType)) {
      return isLiabilityType(_selectedType)
          ? l10n.valuationCurrentDebt
          : l10n.valuationCurrentValue;
    }
    return l10n.accountInitialBalance;
  }

  String _getInitialBalanceHint(AppLocalizations l10n) {
    if (isValuationOnlyType(_selectedType)) {
      return isLiabilityType(_selectedType)
          ? l10n.valuationDebtHint
          : l10n.valuationAccountHint;
    }
    switch (_selectedType) {
      case 'credit_card':
        return _creditOverpayment
            ? l10n.creditCardOverpaymentHint
            : l10n.creditCardDebtHint;
      default:
        return l10n.accountInitialBalanceHint;
    }
  }

  Future<bool?> _promptBalanceAdjustmentChoice({
    required double currentBalance,
    required double targetBalance,
    required AppLocalizations l10n,
  }) async {
    final difference = targetBalance - currentBalance;
    final symbol = getCurrencySymbol(_selectedCurrency);
    String amount(double value) =>
        '${value < 0 ? '−' : ''}$symbol${value.abs().toStringAsFixed(2)}';
    final signedDifference =
        '${difference > 0 ? '+' : difference < 0 ? '−' : ''}'
        '$symbol${difference.abs().toStringAsFixed(2)}';
    var createTransaction = false;
    return showBeeSheet<bool>(context,
        title: l10n.accountBalanceAdjustmentTitle,
        child: StatefulBuilder(builder: (sheetContext, setChoice) {
      return SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l10n.accountBalanceAdjustmentChooseAction,
            style: TextStyle(
                fontSize: 12, color: Theme.of(sheetContext).hintColor)),
        const SizedBox(height: 16),
        BeeAccountBalanceAdjustment(
            currentLabel: l10n.accountBalanceCurrent,
            currentAmount: amount(currentBalance),
            targetLabel: l10n.accountBalanceAfterAdjustment,
            targetAmount: amount(targetBalance),
            differenceLabel: l10n.accountBalanceDifference,
            differenceAmount: signedDifference,
            differenceColor: difference > 0
                ? BeeTokens.success(sheetContext)
                : difference < 0
                    ? BeeTokens.error(sheetContext)
                    : BeeTokens.textSecondary(sheetContext),
            options: [
              BeeBalanceAdjustmentOption(
                  createTransaction: false,
                  title: l10n.accountBalanceAdjustmentOnly,
                  description: l10n.accountBalanceAdjustmentOnlyMessage,
                  confirmLabel: l10n.accountBalanceAdjustmentConfirmOnly),
              BeeBalanceAdjustmentOption(
                  createTransaction: true,
                  title: l10n.accountBalanceAdjustmentCreate,
                  description: l10n.accountBalanceAdjustmentCreateMessage,
                  confirmLabel: l10n.accountBalanceAdjustmentConfirmCreate),
            ],
            createTransaction: createTransaction,
            onModeChanged: (value) =>
                setChoice(() => createTransaction = value),
            onConfirm: (value) => Navigator.pop(sheetContext, value)),
      ]));
    }));
  }

  void _retryEditableCurrentBalance() {
    setState(() => _balanceLoadFailed = false);
    _loadEditableCurrentBalance();
  }

  /// v1.15.0: 检查账户名称是否重复
  Future<void> _checkNameDuplicate(String name) async {
    final draftName = name.trim();
    if (draftName.isEmpty) {
      setState(() {
        _isNameDuplicate = false;
        _nameErrorText = null;
      });
      return;
    }
    try {
      final accounts = await ref.read(repositoryProvider).getAllAccounts();
      if (!mounted || _nameController.text.trim() != draftName) return;
      final duplicate = accounts.any((account) =>
          account.id != widget.account?.id && account.name == draftName);
      setState(() {
        _isNameDuplicate = duplicate;
        _nameErrorText = duplicate
            ? AppLocalizations.of(context).accountNameDuplicate
            : null;
      });
    } catch (_) {
      // Saving independently rechecks the same repository before any write.
      if (!mounted || _nameController.text.trim() != draftName) return;
      setState(() => _nameErrorText = AppLocalizations.of(context).commonError);
    }
  }

  /// 切换账户类型：复用旧逻辑——离开信用卡/银行卡时清空对应字段。
  void _selectType(String type) {
    setState(() {
      final oldType = _selectedType;
      if (oldType != type &&
          (oldType == 'credit_card' || type == 'credit_card')) {
        final parsed = double.tryParse(_initialBalanceController.text);
        if (parsed != null) {
          final signed = oldType == 'credit_card'
              ? (_creditOverpayment ? parsed : -parsed)
              : parsed;
          _creditOverpayment = signed > 0;
          _initialBalanceController.text =
              (type == 'credit_card' ? signed.abs() : signed)
                  .toStringAsFixed(2);
        }
      }
      _selectedType = type;
      if (oldType == 'credit_card' && type != 'credit_card') {
        _creditLimitController.clear();
        _billingDay = null;
        _paymentDueDay = null;
        _reminderEnabled = false;
      }
      final wasBankOrCredit =
          oldType == 'bank_card' || oldType == 'credit_card';
      final isBankOrCredit = type == 'bank_card' || type == 'credit_card';
      if (wasBankOrCredit && !isBankOrCredit) {
        _bankNameController.clear();
        _cardLastFourController.clear();
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _pickingCurrency) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_balanceLoaded || _balanceLoadFailed) return;
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      await Scrollable.ensureVisible(invalid.first.context,
          duration: const Duration(milliseconds: 200), alignment: .2);
      return;
    }

    if (_selectedType == 'credit_card' &&
        _reminderEnabled &&
        _paymentDueDay == null) {
      showBeeToast(
          context, AppLocalizations.of(context).creditCardReminderDueRequired);
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(repositoryProvider);
      final name = _nameController.text.trim();
      final accounts = await repo.getAllAccounts();
      if (!mounted) return;
      if (accounts.any((account) =>
          account.name == name && account.id != widget.account?.id)) {
        setState(() {
          _isNameDuplicate = true;
          _nameErrorText = AppLocalizations.of(context).accountNameDuplicate;
        });
        return;
      }
      final initialBalanceText = _initialBalanceController.text.trim();
      final enteredBalance =
          initialBalanceText.isEmpty ? 0.0 : double.parse(initialBalanceText);
      var initialBalance = enteredBalance;
      if (_selectedType == 'credit_card') {
        initialBalance = enteredBalance == 0
            ? 0
            : (_creditOverpayment ? enteredBalance : -enteredBalance);
      }

      // 贷款类型：用户输入正数，存储为负数
      if (_selectedType == 'loan' && initialBalance > 0) {
        initialBalance = -initialBalance;
      }

      // 信用卡字段
      final isCreditCard = _selectedType == 'credit_card';
      final creditLimitText = _creditLimitController.text.trim();
      final creditLimit = isCreditCard && creditLimitText.isNotEmpty
          ? double.parse(creditLimitText)
          : null;

      if (isEditing) {
        // 检查币种是否变化
        String? currencyToUpdate;
        if (_selectedCurrency != widget.account!.currency) {
          // 币种变化了，需要再次检查是否有交易
          final hasTransactions =
              await repo.hasTransactions(widget.account!.id);
          if (hasTransactions) {
            if (mounted) {
              await _accountInfo(
                  AppLocalizations.of(context).accountCurrencyLocked);
            }
            return;
          }
          currencyToUpdate = _selectedCurrency;
        }

        var balanceNeedsUpdate = false;
        var createBalanceAdjustment = false;
        final targetBalance = initialBalance;
        if (!isValuationOnlyType(widget.account!.type) &&
            !isValuationOnlyType(_selectedType)) {
          final currentBalance =
              await repo.getAccountBalance(widget.account!.id);
          if (!mounted) return;
          // Metadata saves must not overwrite transactions added meanwhile.
          if ((targetBalance - (_loadedCurrentBalance ?? currentBalance))
                  .abs() >=
              0.0000001) {
            final choice = await _promptBalanceAdjustmentChoice(
              currentBalance: currentBalance,
              targetBalance: targetBalance,
              l10n: AppLocalizations.of(context),
            );
            if (!mounted || choice == null) return;
            balanceNeedsUpdate = true;
            createBalanceAdjustment = choice;
          }
        }

        // 如果从信用卡切换到其他类型，清空信用卡字段
        final wasCreditCard = widget.account!.type == 'credit_card';
        final clearCreditCardFields = wasCreditCard;

        // 元信息字段
        final isBankOrCredit =
            _selectedType == 'bank_card' || _selectedType == 'credit_card';
        final bankName =
            isBankOrCredit ? _bankNameController.text.trim() : null;
        final cardLastFour =
            isBankOrCredit ? _cardLastFourController.text.trim() : null;
        final noteText = _noteController.text.trim();

        Future<void> persist() async {
          await repo.updateAccount(
            widget.account!.id,
            name: name,
            type: _selectedType,
            currency: currencyToUpdate,
            creditLimit: isCreditCard ? creditLimit : null,
            billingDay: isCreditCard ? _billingDay : null,
            paymentDueDay: isCreditCard ? _paymentDueDay : null,
            clearCreditCardFields: clearCreditCardFields,
            // Empty strings clear individual text fields; null means preserve in the repository.
            bankName: bankName ?? '',
            cardLastFour: cardLastFour ?? '',
            note: noteText,
          );

          if (balanceNeedsUpdate) {
            await repo.setAccountBalance(
              ledgerId: widget.ledgerId,
              accountId: widget.account!.id,
              targetBalance: targetBalance,
              createBalanceAdjustment: createBalanceAdjustment,
            );
          }
        }

        if (repo is LocalRepository) {
          await repo.db.transaction(persist);
        } else {
          await persist();
        }
        if (balanceNeedsUpdate) {
          ref.invalidate(accountStatsProvider(widget.account!.id));
          ref.read(statsRefreshProvider.notifier).state++;
          ref.read(tagListRefreshProvider.notifier).state++;
        }

        // 保存还款提醒设置
        if (isCreditCard || wasCreditCard) {
          await _saveReminderSettings(widget.account!.id);
        }
      } else {
        final isBankOrCredit =
            _selectedType == 'bank_card' || _selectedType == 'credit_card';
        final bankNameText =
            isBankOrCredit ? _bankNameController.text.trim() : null;
        final cardLastFourText =
            isBankOrCredit ? _cardLastFourController.text.trim() : null;
        final noteText = _noteController.text.trim();

        final id = await repo.createAccount(
          ledgerId: widget.ledgerId,
          name: name,
          type: _selectedType,
          currency: _selectedCurrency,
          initialBalance: initialBalance,
          creditLimit: creditLimit,
          billingDay: isCreditCard ? _billingDay : null,
          paymentDueDay: isCreditCard ? _paymentDueDay : null,
          bankName: bankNameText != null && bankNameText.isNotEmpty
              ? bankNameText
              : null,
          cardLastFour: cardLastFourText != null && cardLastFourText.isNotEmpty
              ? cardLastFourText
              : null,
          note: noteText.isNotEmpty ? noteText : null,
        );

        // 保存还款提醒设置
        if (isCreditCard) {
          await _saveReminderSettings(id);
        }
      }

      // 触发账本同步(后台异步,不阻塞页面关闭)
      if (mounted) {
        PostProcessor.sync(ref, ledgerId: widget.ledgerId);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${AppLocalizations.of(context).commonError}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (_saving || _pickingCurrency || !isEditing) return;
    setState(() => _saving = true);
    try {
      final l = AppLocalizations.of(context),
          repo = ref.read(repositoryProvider);
      final count = await repo.getTransactionCountByAccount(widget.account!.id);
      if (!mounted) return;
      final confirmed = await showBeeConfirm(context,
          title: count > 0 ? l.accountDeleteWarningTitle : l.commonConfirm,
          message: count > 0
              ? l.accountDeleteWarningMessage(count)
              : l.accountDeleteConfirm,
          confirmLabel: l.commonDelete,
          cancelLabel: l.commonCancel,
          danger: true);
      if (!confirmed || !mounted) return;
      await repo.deleteAccount(widget.account!.id);
      if (mounted) {
        PostProcessor.sync(ref, ledgerId: widget.ledgerId);
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        showBeeToast(
            context, '${AppLocalizations.of(context).commonError}: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 隐藏 / 恢复账户（账户隐藏 #240,产品设计 01 §3.2/§五）。
  /// - 恢复:低风险、可逆,不弹确认,即时生效(同管理页「已隐藏」分区的恢复按钮)。
  /// - 隐藏:弹确认框,若该账户被活跃周期模板引用(E2)追加提示;隐藏后若它是
  ///   默认收/支账户则清空该设置(E3)。
  Future<void> _toggleHidden() async {
    if (_saving || _pickingCurrency || !isEditing) return;
    final l = AppLocalizations.of(context), account = widget.account!;
    final repo = ref.read(repositoryProvider);
    setState(() => _saving = true);
    try {
      if (account.hidden) {
        await repo.setAccountHidden(account.id, false);
        if (mounted) {
          PostProcessor.sync(ref, ledgerId: widget.ledgerId);
          showBeeToast(context, l.accountRestoredToast);
          Navigator.pop(context, true);
        }
        return;
      }
      final recurring = await repo.getActiveRecurringCountByAccount(account.id);
      if (!mounted) return;
      final confirmed = await showBeeConfirm(context,
          title: l.accountHideConfirmTitle,
          message: recurring > 0
              ? '${l.accountHideConfirmBody}\n${l.accountHideRecurringWarn(recurring)}'
              : l.accountHideConfirmBody,
          confirmLabel: l.accountHide,
          cancelLabel: l.commonCancel);
      if (!confirmed || !mounted) return;
      await repo.setAccountHidden(account.id, true);
      final income = await ref.read(defaultIncomeAccountIdProvider.future);
      final expense = await ref.read(defaultExpenseAccountIdProvider.future);
      var cleared = false;
      if (income == account.id) {
        await ref
            .read(defaultAccountSetterProvider)
            .setDefaultIncomeAccountId(null);
        ref.invalidate(defaultIncomeAccountIdProvider);
        cleared = true;
      }
      if (expense == account.id) {
        await ref
            .read(defaultAccountSetterProvider)
            .setDefaultExpenseAccountId(null);
        ref.invalidate(defaultExpenseAccountIdProvider);
        cleared = true;
      }
      if (mounted) {
        PostProcessor.sync(ref, ledgerId: widget.ledgerId);
        showBeeToast(
            context,
            cleared
                ? '${l.accountHiddenToast} · ${l.accountHideClearedDefault}'
                : l.accountHiddenToast);
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) showBeeToast(context, '${l.commonError}: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveReminderSettings(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cc_reminder_enabled_$accountId', _reminderEnabled);
    await prefs.setInt('cc_reminder_days_$accountId', _reminderDaysBefore);

    // 调度或取消提醒
    if (_reminderEnabled && _paymentDueDay != null) {
      await CreditCardReminderService.scheduleReminder(
        accountId: accountId,
        accountName: _nameController.text.trim(),
        paymentDueDay: _paymentDueDay!,
        daysBefore: _reminderDaysBefore,
      );
    } else {
      await CreditCardReminderService.cancelReminder(accountId);
    }
  }

  /// 显示币种选择器（复用账本页面的实现）
  Future<void> _pickCurrency() async {
    if (_saving || _pickingCurrency) return;
    setState(() => _pickingCurrency = true);
    try {
      if (isEditing &&
          await ref
              .read(repositoryProvider)
              .hasTransactions(widget.account!.id)) {
        if (mounted) {
          await _accountInfo(
              AppLocalizations.of(context).accountCurrencyLocked);
        }
        return;
      }
      if (!mounted) return;
      final picked = await showCurrencyPickerSheet(context,
          selected: _selectedCurrency,
          primaryColor: ref.read(primaryColorProvider),
          title: AppLocalizations.of(context).ledgersSelectCurrency);
      if (mounted && picked != null) setState(() => _selectedCurrency = picked);
    } catch (error) {
      if (mounted) {
        showBeeToast(
            context, '${AppLocalizations.of(context).commonError}: $error');
      }
    } finally {
      if (mounted) setState(() => _pickingCurrency = false);
    }
  }

  Future<void> _accountInfo(String message) {
    final l = AppLocalizations.of(context);
    return showBeeDialog<void>(context,
        title: l.commonNotice,
        child: Text(message),
        actions: [
          BeeButton(
              label: l.commonConfirm, onPressed: () => Navigator.pop(context))
        ]);
  }
}
