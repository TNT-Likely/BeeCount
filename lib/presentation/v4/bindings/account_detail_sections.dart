import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart' as db;
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../utils/account_type_utils.dart';
import '../../../utils/credit_card_amounts.dart';
import '../../../utils/currencies.dart';
import '../../../widgets/biz/format_money.dart';
import '../../../utils/category_utils.dart';
import 'account_detail.dart';
import '../../../services/currency/rate_math.dart';

class AccountDetailSummary extends ConsumerWidget {
  const AccountDetailSummary(
      {super.key,
      required this.account,
      required this.stats,
      required this.onRetry,
      required this.onRepay,
      required this.onValue,
      this.ledgerCount = 0,
      this.onLedgers,
      this.onInfo,
      this.actions});
  final db.Account account;
  final AsyncValue<({double balance, double income, double expense})> stats;
  final VoidCallback onRetry, onRepay, onValue;
  final int ledgerCount;
  final VoidCallback? onLedgers, onInfo;
  final Widget? actions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        hidden = ref.watch(hideAmountsProvider);
    final compact = ref.watch(compactAmountProvider);
    final base = ref.watch(baseCurrencyProvider);
    final rates = ref.watch(effectiveRatesProvider).valueOrNull;
    final valuation = isValuationOnlyType(account.type),
        credit = account.type == 'credit_card';
    final liability = isLiabilityType(account.type),
        symbol = getDistinctCurrencySymbol(account.currency);
    final metadata = [
      if (account.bankName?.isNotEmpty == true) account.bankName!,
      if (account.cardLastFour?.isNotEmpty == true)
        '**** ${account.cardLastFour}',
      if (account.note?.isNotEmpty == true) account.note!
    ];
    String number(double value) => hidden
        ? '••••'
        : compact
            ? formatDisplayAmount(value,
                currencyCode: account.currency,
                useCompactFormat: true,
                isChineseLocale:
                    Localizations.localeOf(context).languageCode == 'zh',
                signed: false)
            : formatMoneyCompact(value, trimZeros: false);
    String money(double value) => hidden ? '••••' : '$symbol${number(value)}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      stats.when(
          data: (s) {
            final amounts =
                CreditCardAmounts(s.balance, limit: account.creditLimit);
            final debt = amounts.debt, available = amounts.estimatedAvailable;
            final value = credit
                ? (amounts.overpayment > 0 ? amounts.overpayment : debt)
                : valuation && liability
                    ? s.balance.abs()
                    : s.balance;
            final label = credit
                ? (amounts.overpayment > 0
                    ? l.creditCardOverpayment
                    : l.creditCardOwed)
                : valuation
                    ? (liability
                        ? l.valuationCurrentDebt
                        : l.valuationCurrentValue)
                    : l.accountBalance;
            final due =
                daysUntilAccountPayment(account.paymentDueDay, DateTime.now());
            final scheme = Theme.of(context).colorScheme;
            final usage = available != null
                ? (debt / account.creditLimit!).clamp(0.0, 1.0)
                : null;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BeeAccountSummaryCard(
                      title: account.name,
                      caption:
                          '${getAccountTypeLabel(context, account.type)} · ${account.currency}',
                      icon: AccountTypeIcon(type: account.type, size: 32),
                      balanceLabel: label,
                      currency: account.currency,
                      prefix: hidden ? '' : symbol,
                      amount: number(value),
                      privacyLabel: hidden ? l.v4AmountsShow : l.v4AmountsHide,
                      onPrivacy: () => ref
                          .read(hideAmountsProvider.notifier)
                          .state = !hidden,
                      properties: [
                        BeeAccountProperty(
                            label: l.v4AccountNetWorthLabel,
                            value: l.v4AccountIncluded,
                            icon: const BeeLineIcon('Check', size: 11),
                            onPressed: onInfo),
                        BeeAccountProperty(
                            label: l.v4AccountLinkedBooks,
                            value: l.v4AccountLedgerCount(ledgerCount),
                            onPressed: onLedgers),
                      ],
                      conversion: account.currency.toUpperCase() ==
                              base.toUpperCase()
                          ? null
                          : TextButton(
                              onPressed: () => showBeeSheet<void>(context,
                                  title: l.v4AccountNetWorthLabel,
                                  child:
                                      Text(l.netWorthTrendMultiCurrencyNote)),
                              child: Row(children: [
                                Expanded(
                                    child: Text(l.v4DetailConvertedScope(base),
                                        style: const TextStyle(fontSize: 10))),
                                Text(
                                    hidden
                                        ? '••••'
                                        : rates == null ||
                                                computeNativeAmount(
                                                        amount: s.balance,
                                                        accountCurrency:
                                                            account.currency,
                                                        ledgerBase: base,
                                                        rates: rates) ==
                                                    null
                                            ? l.unconvertedBadge
                                            : '≈ ${getDistinctCurrencySymbol(base)}${number(computeNativeAmount(amount: s.balance, accountCurrency: account.currency, ledgerBase: base, rates: rates)!)}',
                                    style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 4),
                                const BeeLineIcon('ChevronRight', size: 12)
                              ]))),
                  if (actions != null) ...[
                    const SizedBox(height: 12),
                    actions!
                  ],
                  if (metadata.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    BeeSurface(
                        child: Text(metadata.join(' · '),
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.6,
                                color: Theme.of(context).hintColor))),
                  ],
                  if (credit) ...[
                    const SizedBox(height: 12),
                    if (account.creditLimit != null)
                      BeeSurface(
                          child: Row(children: [
                        Expanded(
                            child: Text(
                                '${l.creditLimit}\n${money(account.creditLimit ?? 0)}')),
                        if (available != null)
                          Expanded(
                              child: Text(
                                  '${l.creditAvailable}\n${money(available)}')),
                      ])),
                    const SizedBox(height: 8),
                    BeeCreditCardTerms(
                        usage: hidden ? null : usage,
                        usageColor: usage == null
                            ? null
                            : usage < .5
                                ? const Color(0xff25856d)
                                : usage < .8
                                    ? const Color(0xffaa8b29)
                                    : scheme.error,
                        estimateHint:
                            available == null ? null : l.creditCardEstimateHint,
                        billingLabel: account.billingDay != null &&
                                account.paymentDueDay != null
                            ? l.creditCardBillingInfo(
                                account.billingDay!, account.paymentDueDay!)
                            : null,
                        paymentLabel: due == null
                            ? null
                            : due == 0
                                ? l.creditCardPaymentDueToday
                                : l.creditCardDaysUntilPayment(due),
                        paymentColor: due == null
                            ? null
                            : due <= 3
                                ? scheme.error
                                : due <= 7
                                    ? const Color(0xffaa8b29)
                                    : scheme.primary,
                        showRepayButton: actions == null,
                        repayLabel: l.creditCardQuickRepay,
                        onRepay: onRepay),
                  ],
                ]);
          },
          loading: () => const BeeSurface(
              child: SizedBox(
                  height: 170,
                  child: Center(child: CircularProgressIndicator()))),
          error: (_, __) => BeeStatus(
              label: l.commonError,
              tone: BeeTone.error,
              action:
                  BeeButton(label: l.v4RecordingRetry, onPressed: onRetry))),
      if (valuation) ...[
        const SizedBox(height: 12),
        BeeButton(
            label: liability ? l.valuationUpdateDebt : l.valuationUpdateValue,
            icon: const BeeLineIcon('PencilLine'),
            onPressed: onValue),
      ],
    ]);
  }
}

class AccountDetailDistribution extends ConsumerStatefulWidget {
  const AccountDetailDistribution(
      {super.key,
      required this.accountId,
      required this.credit,
      required this.value,
      required this.onChanged,
      this.startDate,
      this.endExclusive});
  final int accountId;
  final bool credit;
  final String value;
  final ValueChanged<String> onChanged;
  final DateTime? startDate, endExclusive;
  @override
  ConsumerState<AccountDetailDistribution> createState() =>
      _AccountDistributionState();
}

class _AccountDistributionState
    extends ConsumerState<AccountDetailDistribution> {
  int _selected = -1;
  String _signature = '';
  static const colors = [
    Color(0xff5b8ff9),
    Color(0xff5ad8a6),
    Color(0xfff6bd16),
    Color(0xffe86452),
    Color(0xff6dc8ec),
    Color(0xff945fb9),
    Color(0xffff9845),
    Color(0xff1e9493),
    Color(0xffff99c3)
  ];
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hidden = ref.watch(hideAmountsProvider);
    final kind = widget.credit ? 'expense' : widget.value;
    final params = (accountId: widget.accountId, type: kind);
    final data = widget.startDate == null && widget.endExclusive == null
        ? ref.watch(accountCategoryStatsProvider(params))
        : ref.watch(accountPeriodCategoryStatsProvider((
            accountId: widget.accountId,
            type: kind,
            start: widget.startDate,
            end: widget.endExclusive
          )));
    return BeeSurface(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.credit)
        Text(l.accountCategoryExpense,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))
      else
        BeeSegmented<String>(
            value: widget.value,
            items: [
              BeeSegment('expense', l.accountCategoryExpense),
              BeeSegment('income', l.accountCategoryIncome)
            ],
            onChanged: widget.onChanged),
      const SizedBox(height: 12),
      data.when(
          data: (rows) {
            final positive = rows
                .where((r) => r.total > 0 && r.total.isFinite)
                .toList()
              ..sort((a, b) => b.total.compareTo(a.total));
            if (positive.isEmpty) return BeeEmptyState(title: l.commonEmpty);
            final total = positive.fold(0.0, (sum, r) => sum + r.total);
            final parts = positive
                .take(8)
                .map((r) => (
                      label: CategoryUtils.getDisplayName(r.name, context,
                          kind: kind),
                      value: r.total
                    ))
                .toList();
            final other = positive.skip(8).fold(0.0, (sum, r) => sum + r.total);
            if (other > 0) parts.add((label: l.commonOther, value: other));
            final signature =
                '$kind:${parts.map((p) => '${p.label}:${p.value}').join('|')}';
            if (signature != _signature) {
              _signature = signature;
              _selected = -1;
            }
            final chosen = _selected >= 0 && _selected < parts.length
                ? parts[_selected]
                : null;
            String number(double value) =>
                hidden ? '••••' : formatMoneyCompact(value, trimZeros: false);
            return BeeDonutChart(
                items: [
                  for (var i = 0; i < parts.length; i++)
                    BeeChartSlice(
                        label: parts[i].label,
                        value: parts[i].value,
                        color: colors[i % colors.length],
                        valueLabel:
                            '${number(parts[i].value)} · ${(parts[i].value / total * 100).toStringAsFixed(1)}%')
                ],
                centerLabel:
                    '${chosen?.label ?? l.analyticsTotalAmount}\n${number(chosen?.value ?? total)}',
                selected: _selected,
                onSelected: (i) => setState(() => _selected = i));
          },
          loading: () => const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => BeeStatus(
              label: l.commonError,
              tone: BeeTone.error,
              action: BeeButton(
                  label: l.v4RecordingRetry,
                  onPressed: () =>
                      ref.invalidate(accountCategoryStatsProvider(params))))),
    ]));
  }
}

Future<double?> showAccountValuationDialog(
        BuildContext context, db.Account account) =>
    showDialog<double>(
        context: context,
        builder: (_) => _AccountValuationDialog(account: account));

class _AccountValuationDialog extends StatefulWidget {
  const _AccountValuationDialog({required this.account});
  final db.Account account;
  @override
  State<_AccountValuationDialog> createState() => _AccountValuationState();
}

class _AccountValuationState extends State<_AccountValuationDialog> {
  late final _text = TextEditingController(
      text: widget.account.initialBalance.abs().toStringAsFixed(2));
  bool _invalid = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        liability = isLiabilityType(widget.account.type);
    return BeeDialog(
        title: Text(liability ? l.valuationUpdateDebt : l.valuationUpdateValue),
        content: TextField(
            controller: _text,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration: InputDecoration(
                prefixText:
                    '${getDistinctCurrencySymbol(widget.account.currency)} ',
                hintText:
                    liability ? l.valuationDebtHint : l.valuationAccountHint,
                errorText: _invalid ? l.v4AmountInvalid : null)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.commonCancel)),
          FilledButton(
              onPressed: () {
                final value = double.tryParse(_text.text.trim());
                if (value == null || !value.isFinite) {
                  setState(() => _invalid = true);
                  return;
                }
                Navigator.pop(context, value);
              },
              child: Text(l.commonOk))
        ]);
  }
}
