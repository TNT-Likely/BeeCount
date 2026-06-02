import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/section_card.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/currencies.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../utils/account_type_utils.dart';
import '../../providers/credit_card_reminder_providers.dart';

class AccountEditPage extends ConsumerStatefulWidget {
  final db.Account? account; // null表示新建
  final int ledgerId;

  const AccountEditPage({
    super.key,
    this.account,
    required this.ledgerId,
  });

  @override
  ConsumerState<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends ConsumerState<AccountEditPage> {
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
  bool _isNameDuplicate = false;
  String? _nameErrorText;
  // 账户类型 Tab：0 = 日常账户，1 = 估值账户
  int _typeTab = 0;

  // 日常账户类型（走流水）
  static const List<String> tradableAccountTypes = [
    'cash',
    'bank_card',
    'credit_card',
    'alipay',
    'wechat',
    'other',
  ];

  // 估值账户类型（只记当前价值 / 欠款，不走流水）
  static const List<String> valuationAccountTypes = [
    'real_estate',
    'vehicle',
    'investment',
    'insurance',
    'social_fund',
    'loan',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    _initialBalanceController = TextEditingController(
      text: widget.account?.initialBalance != null &&
              widget.account!.initialBalance != 0.0
          ? widget.account!.initialBalance.abs().toStringAsFixed(2)
          : '',
    );
    _creditLimitController = TextEditingController(
      text: widget.account?.creditLimit != null
          ? widget.account!.creditLimit!.toStringAsFixed(2)
          : '',
    );
    _bankNameController = TextEditingController(text: widget.account?.bankName ?? '');
    _cardLastFourController = TextEditingController(text: widget.account?.cardLastFour ?? '');
    _noteController = TextEditingController(text: widget.account?.note ?? '');
    _selectedType = widget.account?.type ?? 'cash';
    _selectedCurrency = widget.account?.currency ?? 'CNY';
    _billingDay = widget.account?.billingDay;
    _paymentDueDay = widget.account?.paymentDueDay;
    _typeTab = isValuationOnlyType(_selectedType) ? 1 : 0;
    _loadReminderSettings();
  }

  Future<void> _loadReminderSettings() async {
    if (widget.account != null) {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('cc_reminder_enabled_${widget.account!.id}') ?? false;
      final daysBefore = prefs.getInt('cc_reminder_days_${widget.account!.id}') ?? 3;
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

  String _getInitialBalanceLabel(AppLocalizations l10n) {
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
        return l10n.creditCardInitialBalanceHint;
      default:
        return l10n.accountInitialBalanceHint;
    }
  }

  /// v1.15.0: 检查账户名称是否重复
  Future<void> _checkNameDuplicate(String name) async {
    if (name.trim().isEmpty) {
      setState(() {
        _isNameDuplicate = false;
        _nameErrorText = null;
      });
      return;
    }

    final repo = ref.read(repositoryProvider);
    final allAccounts = await repo.getAllAccounts();
    final isDuplicate = allAccounts.any((account) {
      // 如果是编辑模式，排除当前账户本身
      if (isEditing && account.id == widget.account!.id) {
        return false;
      }
      return account.name == name.trim();
    });

    if (mounted) {
      setState(() {
        _isNameDuplicate = isDuplicate;
        _nameErrorText = isDuplicate
            ? AppLocalizations.of(context).accountNameDuplicate
            : null;
      });
    }
  }

  /// 切换账户类型：复用旧逻辑——离开信用卡/银行卡时清空对应字段。
  void _selectType(String type) {
    setState(() {
      final oldType = _selectedType;
      _selectedType = type;
      if (oldType == 'credit_card' && type != 'credit_card') {
        _creditLimitController.clear();
        _billingDay = null;
        _paymentDueDay = null;
        _reminderEnabled = false;
      }
      final wasBankOrCredit = oldType == 'bank_card' || oldType == 'credit_card';
      final isBankOrCredit = type == 'bank_card' || type == 'credit_card';
      if (wasBankOrCredit && !isBankOrCredit) {
        _bankNameController.clear();
        _cardLastFourController.clear();
      }
    });
  }

  TextStyle _sectionTitle(BuildContext context) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: BeeTokens.textPrimary(context),
      );

  /// 资产/负债 分段标签
  Widget _segTab(BuildContext context,
      {required String label,
      required bool selected,
      required Color primaryColor,
      required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 8.0.scaled(context, ref)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? BeeTokens.surfaceElevated(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? primaryColor : BeeTokens.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);

    // 统一的 filled 圆角输入框装饰（委托顶层实现，便于点击式字段框复用）
    InputDecoration filledDec(
            {String? label, String? hint, String? prefix, String? errorText}) =>
        _filledDecoration(context, primaryColor,
            label: label, hint: hint, prefix: prefix, errorText: errorText);

    final typesForTab = _typeTab == 0 ? tradableAccountTypes : valuationAccountTypes;
    final isCreditCard = _selectedType == 'credit_card';
    final isBankCard = _selectedType == 'bank_card';

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: isEditing ? l10n.accountEditTitle : l10n.accountNewTitle,
            showBack: true,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.only(
                  left: 12.0.scaled(context, ref),
                  right: 12.0.scaled(context, ref),
                  top: 8.0.scaled(context, ref),
                  bottom: 8.0.scaled(context, ref) +
                      MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  // ===== 账户类型（资产/负债 Tab + 缩小网格）=====
                  SectionCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(16.0.scaled(context, ref)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: BeeTokens.surfaceInput(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                _segTab(context,
                                    label: l10n.accountGroupTradable,
                                    selected: _typeTab == 0,
                                    primaryColor: primaryColor,
                                    onTap: () => setState(() => _typeTab = 0)),
                                _segTab(context,
                                    label: l10n.accountTabValuation,
                                    selected: _typeTab == 1,
                                    primaryColor: primaryColor,
                                    onTap: () => setState(() => _typeTab = 1)),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.0.scaled(context, ref)),
                          GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10.0.scaled(context, ref),
                            crossAxisSpacing: 10.0.scaled(context, ref),
                            childAspectRatio: 1.0,
                            children: typesForTab.map((type) {
                              final isSelected = _selectedType == type;
                              // 编辑模式禁止跨“可交易 / 估值”大类切换（语义不同）
                              final disabled = isEditing &&
                                  isValuationOnlyType(type) !=
                                      isValuationOnlyType(widget.account!.type);
                              return _AccountTypeCard(
                                type: type,
                                label: getAccountTypeLabel(context, type),
                                isSelected: isSelected,
                                primaryColor: primaryColor,
                                disabled: disabled,
                                onTap: disabled ? () {} : () => _selectType(type),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 8.0.scaled(context, ref)),

                  // ===== 基本（名称 + 币种/余额）=====
                  SectionCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(16.0.scaled(context, ref)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: filledDec(
                              label: l10n.accountNameLabel,
                              hint: l10n.accountNameHint,
                              errorText: _nameErrorText,
                            ),
                            style: const TextStyle(fontSize: 16),
                            onChanged: (value) => _checkNameDuplicate(value),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return l10n.accountNameRequired;
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 12.0.scaled(context, ref)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 120.0.scaled(context, ref),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    // 同账单日：开选择器前先收键盘
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    if (isEditing) {
                                      final repo = ref.read(repositoryProvider);
                                      final hasTransactions = await repo
                                          .hasTransactions(widget.account!.id);
                                      if (hasTransactions) {
                                        if (!context.mounted) return;
                                        await AppDialog.info(
                                          context,
                                          title: l10n.commonNotice,
                                          message: l10n.accountCurrencyLocked,
                                        );
                                        return;
                                      }
                                    }
                                    if (!context.mounted) return;
                                    final picked = await _showCurrencyPicker(
                                        context,
                                        initial: _selectedCurrency);
                                    if (picked != null) {
                                      setState(() => _selectedCurrency = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration:
                                        filledDec(label: l10n.ledgersCurrency),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayCurrency(
                                                _selectedCurrency, context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                        ),
                                        Icon(Icons.expand_more,
                                            size: 18.0.scaled(context, ref),
                                            color:
                                                BeeTokens.iconTertiary(context)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.0.scaled(context, ref)),
                              Expanded(
                                child: TextFormField(
                                  controller: _initialBalanceController,
                                  decoration: filledDec(
                                    label: _getInitialBalanceLabel(l10n),
                                    hint: _getInitialBalanceHint(l10n),
                                    prefix:
                                        '${getCurrencySymbol(_selectedCurrency)} ',
                                  ),
                                  style: const TextStyle(fontSize: 16),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true, signed: true),
                                  validator: (value) {
                                    if (value != null && value.trim().isNotEmpty) {
                                      if (double.tryParse(value.trim()) == null) {
                                        return '请输入有效的金额';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ===== 信用卡信息（仅 credit_card）=====
                  if (isCreditCard) ...[
                    SizedBox(height: 8.0.scaled(context, ref)),
                    SectionCard(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(16.0.scaled(context, ref)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.creditCardSettings, style: _sectionTitle(context)),
                            SizedBox(height: 12.0.scaled(context, ref)),
                            // 信用额度（必填）
                            TextFormField(
                              controller: _creditLimitController,
                              decoration: filledDec(
                                label: '${l10n.creditLimit} *',
                                hint: l10n.creditLimitHint,
                                prefix: '${getCurrencySymbol(_selectedCurrency)} ',
                              ),
                              style: const TextStyle(fontSize: 16),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              validator: (value) {
                                final t = value?.trim() ?? '';
                                final parsed = double.tryParse(t);
                                if (t.isEmpty || parsed == null || parsed <= 0) {
                                  return l10n.creditLimitHint;
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 12.0.scaled(context, ref)),
                            // 账单日 / 还款日（双列，必填）
                            Row(
                              children: [
                                Expanded(
                                  child: _DayPickerTile(
                                    label: '${l10n.billingDay} *',
                                    value: _billingDay,
                                    primaryColor: primaryColor,
                                    onChanged: (day) =>
                                        setState(() => _billingDay = day),
                                  ),
                                ),
                                SizedBox(width: 12.0.scaled(context, ref)),
                                Expanded(
                                  child: _DayPickerTile(
                                    label: '${l10n.paymentDueDay} *',
                                    value: _paymentDueDay,
                                    primaryColor: primaryColor,
                                    onChanged: (day) =>
                                        setState(() => _paymentDueDay = day),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.0.scaled(context, ref)),
                            // 开户行 / 卡号后四（双列）
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _bankNameController,
                                    decoration: filledDec(
                                      label: l10n.accountBankName,
                                      hint: l10n.accountBankNameHint,
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                SizedBox(width: 12.0.scaled(context, ref)),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cardLastFourController,
                                    decoration: filledDec(
                                      label: l10n.accountCardLastFour,
                                      hint: l10n.accountCardLastFourHint,
                                    ).copyWith(counterText: ''),
                                    style: const TextStyle(fontSize: 16),
                                    maxLength: 4,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.0.scaled(context, ref)),
                            Divider(color: BeeTokens.divider(context)),
                            // 还款提醒
                            SwitchListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                l10n.creditCardReminderTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: BeeTokens.textPrimary(context),
                                ),
                              ),
                              subtitle: Text(
                                l10n.creditCardReminderDesc,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BeeTokens.textTertiary(context),
                                ),
                              ),
                              value: _reminderEnabled,
                              activeColor: primaryColor,
                              onChanged: (value) =>
                                  setState(() => _reminderEnabled = value),
                            ),
                            if (_reminderEnabled) ...[
                              SizedBox(height: 4.0.scaled(context, ref)),
                              Wrap(
                                spacing: 8.0.scaled(context, ref),
                                children: [1, 3, 5, 7].map((days) {
                                  final isSelected = _reminderDaysBefore == days;
                                  return ChoiceChip(
                                    label: Text(
                                        l10n.creditCardReminderDaysBefore(days)),
                                    selected: isSelected,
                                    selectedColor:
                                        primaryColor.withValues(alpha: 0.15),
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      color: isSelected
                                          ? primaryColor
                                          : BeeTokens.textSecondary(context),
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    onSelected: (_) => setState(
                                        () => _reminderDaysBefore = days),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ===== 卡信息（仅 bank_card）=====
                  if (isBankCard) ...[
                    SizedBox(height: 8.0.scaled(context, ref)),
                    SectionCard(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(16.0.scaled(context, ref)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.accountMetaInfo, style: _sectionTitle(context)),
                            SizedBox(height: 12.0.scaled(context, ref)),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _bankNameController,
                                    decoration: filledDec(
                                      label: l10n.accountBankName,
                                      hint: l10n.accountBankNameHint,
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                SizedBox(width: 12.0.scaled(context, ref)),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cardLastFourController,
                                    decoration: filledDec(
                                      label: l10n.accountCardLastFour,
                                      hint: l10n.accountCardLastFourHint,
                                    ).copyWith(counterText: ''),
                                    style: const TextStyle(fontSize: 16),
                                    maxLength: 4,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ===== 备注（所有类型）=====
                  SizedBox(height: 8.0.scaled(context, ref)),
                  SectionCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(16.0.scaled(context, ref)),
                      child: TextFormField(
                        controller: _noteController,
                        decoration: filledDec(
                          label: l10n.accountNote,
                          hint: l10n.accountNoteHint,
                        ),
                        style: const TextStyle(fontSize: 16),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                  ),

                  SizedBox(height: 24.0.scaled(context, ref)),

                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    height: 48.0.scaled(context, ref),
                    child: ElevatedButton(
                      onPressed: (_saving || _isNameDuplicate) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[400],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8.0.scaled(context, ref)),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              l10n.commonSave,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  // 删除按钮（仅编辑时显示）
                  if (isEditing) ...[
                    SizedBox(height: 12.0.scaled(context, ref)),
                    SizedBox(
                      width: double.infinity,
                      height: 48.0.scaled(context, ref),
                      child: OutlinedButton(
                        onPressed: _saving ? null : _delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                8.0.scaled(context, ref)),
                          ),
                        ),
                        child: Text(
                          l10n.commonDelete,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // 信用卡：账单日 / 还款日必填（额度由表单 validator 拦截）
    if (_selectedType == 'credit_card' &&
        (_billingDay == null || _paymentDueDay == null)) {
      showToast(context, AppLocalizations.of(context).creditCardDaysRequired);
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(repositoryProvider);
      final name = _nameController.text.trim();
      final initialBalanceText = _initialBalanceController.text.trim();
      var initialBalance =
          initialBalanceText.isEmpty ? 0.0 : double.parse(initialBalanceText);

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
          final hasTransactions = await repo.hasTransactions(widget.account!.id);
          if (hasTransactions) {
            if (mounted) {
              setState(() => _saving = false);
              final l10n = AppLocalizations.of(context);
              await AppDialog.info(
                context,
                title: l10n.commonNotice,
                message: l10n.accountCurrencyLocked,
              );
            }
            return;
          }
          currencyToUpdate = _selectedCurrency;
        }

        // 如果从信用卡切换到其他类型，清空信用卡字段
        final wasCreditCard = widget.account!.type == 'credit_card';
        final clearCreditCardFields = wasCreditCard && !isCreditCard;

        // 元信息字段
        final isBankOrCredit = _selectedType == 'bank_card' || _selectedType == 'credit_card';
        final wasBankOrCredit = widget.account!.type == 'bank_card' || widget.account!.type == 'credit_card';
        final clearMetadataFields = wasBankOrCredit && !isBankOrCredit;
        final bankName = isBankOrCredit ? _bankNameController.text.trim() : null;
        final cardLastFour = isBankOrCredit ? _cardLastFourController.text.trim() : null;
        final noteText = _noteController.text.trim();

        await repo.updateAccount(
          widget.account!.id,
          name: name,
          type: _selectedType,
          currency: currencyToUpdate,
          initialBalance: initialBalance,
          creditLimit: isCreditCard ? creditLimit : null,
          billingDay: isCreditCard ? _billingDay : null,
          paymentDueDay: isCreditCard ? _paymentDueDay : null,
          clearCreditCardFields: clearCreditCardFields,
          bankName: bankName != null && bankName.isNotEmpty ? bankName : null,
          cardLastFour: cardLastFour != null && cardLastFour.isNotEmpty ? cardLastFour : null,
          note: noteText.isNotEmpty ? noteText : null,
          clearMetadataFields: clearMetadataFields,
        );

        // 保存还款提醒设置
        if (isCreditCard) {
          await _saveReminderSettings(widget.account!.id);
        }
      } else {
        final isBankOrCredit = _selectedType == 'bank_card' || _selectedType == 'credit_card';
        final bankNameText = isBankOrCredit ? _bankNameController.text.trim() : null;
        final cardLastFourText = isBankOrCredit ? _cardLastFourController.text.trim() : null;
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
          bankName: bankNameText != null && bankNameText.isNotEmpty ? bankNameText : null,
          cardLastFour: cardLastFourText != null && cardLastFourText.isNotEmpty ? cardLastFourText : null,
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
        showToast(context, '${AppLocalizations.of(context).commonError}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);

    // 检查是否有关联交易
    final repo = ref.read(repositoryProvider);
    final txCount = await repo.getTransactionCountByAccount(widget.account!.id);

    if (txCount > 0) {
      // 有关联交易，提示用户
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.accountDeleteWarningTitle),
          content: Text(l10n.accountDeleteWarningMessage(txCount)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.commonDelete),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    } else {
      // 没有关联交易，简单确认
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.commonConfirm),
          content: Text(l10n.accountDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.commonDelete),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _saving = true);

    try {
      await repo.deleteAccount(widget.account!.id);

      // 触发账本同步(后台异步,不阻塞页面关闭)
      if (mounted) {
        PostProcessor.sync(ref, ledgerId: widget.ledgerId);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, '${l10n.commonError}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
  Future<String?> _showCurrencyPicker(BuildContext context, {String? initial}) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeeTokens.surfaceElevated(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bctx) {
        String query = '';
        String? selected = initial;
        return StatefulBuilder(builder: (sctx, setState) {
          final filtered = getCurrencies(context).where((c) {
            final q = query.trim();
            if (q.isEmpty) return true;
            final uq = q.toUpperCase();
            return c.code.contains(uq) || c.name.contains(q);
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(bctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: 420,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(bctx).ledgersSelectCurrency,
                    style: Theme.of(bctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: AppLocalizations.of(bctx).ledgersSearchCurrency,
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final sel = c.code == selected;
                        return ListTile(
                          title: Text('${c.name} (${c.code})'),
                          trailing: sel
                              ? const Icon(Icons.check, color: Colors.black)
                              : null,
                          onTap: () => Navigator.pop(bctx, c.code),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

/// 统一的 filled 圆角输入框装饰（TextField 与点击式字段框共用，保证等高同款）
InputDecoration _filledDecoration(
  BuildContext context,
  Color primary, {
  String? label,
  String? hint,
  String? prefix,
  String? errorText,
}) {
  OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(color: BeeTokens.textTertiary(context)),
    prefixText: prefix,
    errorText: errorText,
    filled: true,
    fillColor: BeeTokens.surfaceInput(context),
    isDense: true,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: b(Colors.transparent, 0),
    enabledBorder: b(Colors.transparent, 0),
    focusedBorder: b(primary, 1.5),
    errorBorder: b(Colors.red, 1),
    focusedErrorBorder: b(Colors.red, 1.5),
  );
}

/// 日期选择行（1-28）— filled 输入框样式，可双列并排
class _DayPickerTile extends ConsumerWidget {
  final String label;
  final int? value;
  final Color primaryColor;
  final ValueChanged<int?> onChanged;

  const _DayPickerTile({
    required this.label,
    required this.value,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasValue = value != null;
    return InkWell(
      onTap: () => _showDayPicker(context, l10n),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _filledDecoration(context, primaryColor, label: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? l10n.dayOfMonth(value!) : l10n.selectDay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: hasValue
                      ? BeeTokens.textPrimary(context)
                      : BeeTokens.textTertiary(context),
                ),
              ),
            ),
            Icon(Icons.expand_more,
                size: 18.0.scaled(context, ref),
                color: BeeTokens.iconTertiary(context)),
          ],
        ),
      ),
    );
  }

  void _showDayPicker(BuildContext context, AppLocalizations l10n) async {
    // 先收起键盘并等其收完，避免输入框焦点残留导致选完日期后键盘又弹回来
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: BeeTokens.surfaceElevated(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  label,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: 28,
                  itemBuilder: (_, index) {
                    final day = index + 1;
                    final isSelected = day == value;
                    return GestureDetector(
                      onTap: () {
                        onChanged(day);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor
                                : BeeTokens.border(ctx),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : BeeTokens.textPrimary(ctx),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 账户类型选择卡片
class _AccountTypeCard extends ConsumerWidget {
  final String type;
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;
  final bool disabled;

  const _AccountTypeCard({
    required this.type,
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 禁用态：灰底 + 浅边 + 灰字 + 图标淡化，明确区别于可选/选中
    final Color bg = disabled
        ? BeeTokens.surfaceInput(context)
        : (isSelected
            ? primaryColor.withValues(alpha: 0.12)
            : BeeTokens.surfaceElevated(context));
    final Color borderColor = disabled
        ? BeeTokens.divider(context)
        : (isSelected ? primaryColor : BeeTokens.border(context));
    final Color fg = disabled
        ? BeeTokens.textTertiary(context)
        : (isSelected ? primaryColor : BeeTokens.textSecondary(context));
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(8.0.scaled(context, ref)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 2.0.scaled(context, ref)),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8.0.scaled(context, ref)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: disabled ? 0.35 : 1.0,
              child: AccountTypeIcon(
                type: type,
                size: 24.0.scaled(context, ref),
              ),
            ),
            SizedBox(height: 6.0.scaled(context, ref)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: fg,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
