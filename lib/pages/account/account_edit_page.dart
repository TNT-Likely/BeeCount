import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../data/db.dart' as db;
import '../../data/repositories/local/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/currencies.dart';
import '../../styles/tokens.dart';
import '../../utils/account_type_utils.dart';
import '../../widgets/currency/currency_picker_sheet.dart';
import '../../providers/credit_card_reminder_providers.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';

part '../../presentation/v4/bindings/account_edit_actions.dart';

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

class _AccountEditPageState extends ConsumerState<AccountEditPage>
    with _AccountEditActions {
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final credit = _selectedType == 'credit_card';
    final bank = _selectedType == 'bank_card';
    final editableBalance =
        !isEditing || !isValuationOnlyType(widget.account!.type);
    Widget section(String id, List<Widget> children) => BeeSurface(
        key: ValueKey('account-section-$id'),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children));
    return PopScope(
        canPop: !_saving,
        child: V4PageScaffold(
            body: AbsorbPointer(
                absorbing: _saving,
                child: Column(children: [
                  BeePageHeader(
                      title: isEditing ? l.accountEditTitle : l.accountNewTitle,
                      leading: const BackButton()),
                  Expanded(
                      child: Form(
                          key: _formKey,
                          child: BeePageBody(eager: true, children: [
                            section('type', [
                              BeeAccountTypePicker(
                                  key: const ValueKey('account-type-group'),
                                  groups: [
                                    for (final group in [0, 1])
                                      BeeAccountTypeGroup(
                                          id: group == 0
                                              ? 'daily'
                                              : 'valuation',
                                          label: group == 0
                                              ? l.accountGroupTradable
                                              : l.accountTabValuation,
                                          choices: (group == 0
                                                  ? tradableAccountTypes
                                                  : valuationAccountTypes)
                                              .map((type) => BeeIconChoice(
                                                  value: type,
                                                  label: getAccountTypeLabel(
                                                      context, type),
                                                  icon: AccountTypeIcon(
                                                      type: type, size: 24),
                                                  enabled: !isEditing ||
                                                      isValuationOnlyType(
                                                              type) ==
                                                          isValuationOnlyType(
                                                              widget.account!
                                                                  .type)))
                                              .toList())
                                  ],
                                  group: _typeTab == 0 ? 'daily' : 'valuation',
                                  value: _selectedType,
                                  onGroupChanged: (value) => setState(() =>
                                      _typeTab = value == 'daily' ? 0 : 1),
                                  onChanged: _selectType)
                            ]),
                            section('basic', [
                              BeeField(
                                  key: const ValueKey('account-name'),
                                  label: l.accountNameLabel,
                                  hint: l.accountNameHint,
                                  controller: _nameController,
                                  error: _nameErrorText,
                                  onChanged: _checkNameDuplicate,
                                  validator: (v) => v?.trim().isNotEmpty == true
                                      ? null
                                      : l.accountNameRequired),
                              const SizedBox(height: 10),
                              BeeMenuRow(
                                  key: const ValueKey('account-currency'),
                                  title: l.ledgersCurrency,
                                  subtitle: displayCurrency(
                                      _selectedCurrency, context),
                                  leading: const BeeLineIcon('Globe', size: 20),
                                  onTap: _pickCurrency),
                              if (editableBalance) ...[
                                const SizedBox(height: 10),
                                BeeField(
                                    key: const ValueKey(
                                        'account-balance-amount'),
                                    label: isEditing && !credit
                                        ? l.accountBalance
                                        : _getInitialBalanceLabel(l),
                                    hint: _getInitialBalanceHint(l),
                                    controller: _initialBalanceController,
                                    prefixIcon: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(getCurrencySymbol(
                                            _selectedCurrency))),
                                    readOnly:
                                        !_balanceLoaded || _balanceLoadFailed,
                                    suffixIcon: _balanceLoadFailed
                                        ? IconButton(
                                            tooltip: l.helpCenterRetry,
                                            onPressed:
                                                _retryEditableCurrentBalance,
                                            icon: const BeeLineIcon('RefreshCw',
                                                size: 18))
                                        : !_balanceLoaded
                                            ? const Padding(
                                                padding: EdgeInsets.all(14),
                                                child: SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2)))
                                            : null,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true, signed: true),
                                    validator: _validateBalance),
                              ],
                              if (credit) ...[
                                const SizedBox(height: 12),
                                BeeSegmented<bool>(
                                    key: const ValueKey(
                                        'account-credit-balance-kind'),
                                    items: [
                                      BeeSegment(false, l.creditCardOwed),
                                      BeeSegment(true, l.creditCardOverpayment)
                                    ],
                                    value: _creditOverpayment,
                                    onChanged: (v) =>
                                        setState(() => _creditOverpayment = v)),
                              ],
                            ]),
                            if (credit)
                              section('credit', [
                                Text(l.creditCardSettings,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                BeeField(
                                    key: const ValueKey('account-credit-limit'),
                                    label: l.creditLimit,
                                    hint: l.creditLimitHint,
                                    controller: _creditLimitController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    validator: (v) {
                                      final text = v?.trim() ?? '',
                                          number =
                                              double.tryParse(v?.trim() ?? '');
                                      return text.isEmpty ||
                                              (number != null &&
                                                  number.isFinite &&
                                                  number > 0)
                                          ? null
                                          : l.creditLimitHint;
                                    }),
                                const SizedBox(height: 10),
                                _creditDays(l),
                                const Divider(height: 20),
                                _bankFields(l),
                                const SizedBox(height: 8),
                                BeeToggleRow(
                                    title: l.creditCardReminderTitle,
                                    subtitle: l.creditCardReminderDesc,
                                    value: _reminderEnabled,
                                    onChanged: (v) =>
                                        setState(() => _reminderEnabled = v)),
                                if (_reminderEnabled)
                                  BeeSegmented<int>(
                                      key: const ValueKey(
                                          'account-credit-reminder-days'),
                                      items: [
                                        for (final day in [1, 3, 5, 7])
                                          BeeSegment(
                                              day,
                                              l.creditCardReminderDaysBefore(
                                                  day))
                                      ],
                                      value: _reminderDaysBefore,
                                      onChanged: (v) => setState(
                                          () => _reminderDaysBefore = v)),
                              ]),
                            if (bank)
                              section('bank', [
                                Text(l.accountMetaInfo,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 12),
                                _bankFields(l),
                              ]),
                            section('note', [
                              BeeField(
                                  key: const ValueKey('account-note'),
                                  label: l.accountNote,
                                  hint: l.accountNoteHint,
                                  controller: _noteController,
                                  maxLines: 3)
                            ]),
                            if (isEditing)
                              BeeSurface(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(children: [
                                    BeeMenuRow(
                                        title: widget.account!.hidden
                                            ? l.accountUnhide
                                            : l.accountHide,
                                        leading: BeeLineIcon(
                                            widget.account!.hidden
                                                ? 'Eye'
                                                : 'EyeOff',
                                            size: 20),
                                        onTap: _toggleHidden),
                                    const Divider(
                                        height: 1, indent: 12, endIndent: 12),
                                    BeeMenuRow(
                                        title: l.commonDelete,
                                        danger: true,
                                        leading: const BeeLineIcon('Trash2',
                                            size: 20),
                                        onTap: _delete),
                                  ])),
                          ]))),
                  SafeArea(
                      top: false,
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
                          child: SizedBox(
                              width: double.infinity,
                              child: BeeButton(
                                  label: l.commonSave,
                                  loading: _saving,
                                  onPressed: _saving ||
                                          _pickingCurrency ||
                                          _isNameDuplicate ||
                                          !_balanceLoaded ||
                                          _balanceLoadFailed
                                      ? null
                                      : _save)))),
                ]))));
  }

  Widget _creditDays(AppLocalizations l) =>
      LayoutBuilder(builder: (context, bounds) {
        final billing = _AccountCreditDayField(
            label: l.billingDay,
            value: _billingDay,
            onChanged: (v) => setState(() => _billingDay = v));
        final due = _AccountCreditDayField(
            label: l.paymentDueDay,
            value: _paymentDueDay,
            onChanged: (v) => setState(() => _paymentDueDay = v));
        return bounds.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(12) > 14
            ? Column(children: [billing, due])
            : Row(children: [
                Expanded(child: billing),
                const SizedBox(width: 8),
                Expanded(child: due)
              ]);
      });

  Widget _bankFields(AppLocalizations l) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: BeeField(
                key: const ValueKey('account-bank-name'),
                label: l.accountBankName,
                hint: l.accountBankNameHint,
                controller: _bankNameController)),
        const SizedBox(width: 10),
        Expanded(
            child: BeeField(
                key: const ValueKey('account-card-last-four'),
                label: l.accountCardLastFour,
                hint: l.accountCardLastFourHint,
                controller: _cardLastFourController,
                maxLength: 4,
                keyboardType: TextInputType.number)),
      ]);
}

class _AccountCreditDayField extends StatelessWidget {
  const _AccountCreditDayField(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeMenuRow(
        title: label,
        subtitle: value == null ? l.selectDay : l.dayOfMonth(value!),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (value != null)
            IconButton(
                tooltip: l.commonRemove,
                onPressed: () => onChanged(null),
                icon: const BeeLineIcon('X', size: 16)),
          const BeeLineIcon('ChevronDown', size: 16)
        ]),
        onTap: () => showBeeSheet<void>(context,
            title: label,
            child: SingleChildScrollView(
                child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (var day = 1; day <= 28; day++)
                SizedBox(
                    width: 58,
                    height: 44,
                    child: BeeButton(
                        compact: true,
                        label: '$day',
                        kind: value == day
                            ? BeeButtonKind.primary
                            : BeeButtonKind.secondary,
                        onPressed: () {
                          onChanged(day);
                          Navigator.pop(context);
                        })),
            ]))));
  }
}
