import '../../../utils/format_utils.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../../providers.dart';
import '../../../services/currency/rate_math.dart';
import '../../../services/marketing/product_promos.dart';
import '../../../widgets/biz/amount_text.dart';
import '../../../widgets/biz/format_money.dart';
import '../../../widgets/biz/product_promo_card.dart';
import '../../../data/db.dart' as db;
import '../../../l10n/app_localizations.dart';
import '../../../styles/tokens.dart';
import '../../../utils/ui_scale_extensions.dart';
import '../../../utils/account_type_utils.dart';
import '../../../utils/credit_card_amounts.dart';
import '../../../utils/currencies.dart';

/// Account-specific data formatting, credit/valuation sections and list groups.
/// 折算详情弹窗的一行数据：原币 + 折算后/缺失标示。
/// 净资产明细弹窗与分组小计明细弹窗共用同一渲染(redline:两处一份代码)。
class AccountConversionEntry {
  final String code; // 大写币种码
  final double originalValue; // 原币金额(符号保持调用方口径)
  final double? convertedValue; // 折算后(base 自身/可折算才有);缺失为 null
  final bool isBase;
  final bool isMissing;
  const AccountConversionEntry({
    required this.code,
    required this.originalValue,
    required this.convertedValue,
    required this.isBase,
    required this.isMissing,
  });
}

/// 折算详情弹窗的单行:左 币种码+本地化名 / 中 原币值 / 右 base 空·缺失 badge·≈折算灰字。
class ConversionDetailRowBinding extends ConsumerWidget {
  final AccountConversionEntry entry;
  final String baseSymbol;
  final bool useCompact;

  const ConversionDetailRowBinding({
    super.key,
    required this.entry,
    required this.baseSymbol,
    required this.useCompact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selectedLocale = ref.watch(languageProvider);
    final chinese = selectedLocale?.languageCode == 'zh' ||
        (selectedLocale == null &&
            Localizations.localeOf(context).languageCode == 'zh');
    return BeeAccountConversionRow(
        code: entry.code,
        currencyName: getCurrencyName(entry.code, context),
        original: formatDisplayAmount(entry.originalValue,
            currencyCode: entry.code,
            showCurrency: true,
            useCompactFormat: useCompact,
            isChineseLocale: chinese,
            signed: false),
        hidden: ref.watch(hideAmountsProvider),
        missingLabel: entry.isMissing ? l.unconvertedBadge : null,
        converted:
            entry.isBase || entry.isMissing || entry.convertedValue == null
                ? null
                : '≈ $baseSymbol${entry.convertedValue!.toStringAsFixed(2)}');
  }
}

/// 折算详情沿用底部弹层，外观由基础 BeeSheet 提供。
/// 净资产明细 / 分组小计明细共用;[entries] 已是 UI 所需的每币种行数据。
void showAccountConversionDetailSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required List<AccountConversionEntry> entries,
  required String baseSymbol,
  required bool useCompact,
  Widget? footer,
}) {
  showBeeSheet<void>(context,
      title: title,
      child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in entries)
          ConversionDetailRowBinding(
              entry: e, baseSymbol: baseSymbol, useCompact: useCompact),
        if (footer != null) footer,
      ])));
}

/// Subscribe in the owning page build before lazily laid-out child rows can
/// flush a derived provider and synchronously notify their ancestor consumer.
class AccountCardDisplayData {
  const AccountCardDisplayData({
    required this.hidden,
    required this.compactMoney,
    required this.multiCurrencyActive,
    required this.base,
    required this.rates,
    required this.defaultExpense,
    required this.defaultIncome,
  });

  factory AccountCardDisplayData.watch(WidgetRef ref) => AccountCardDisplayData(
      hidden: ref.watch(hideAmountsProvider),
      compactMoney: ref.watch(compactAmountProvider),
      multiCurrencyActive: ref.watch(multiCurrencyActiveProvider),
      base: ref.watch(baseCurrencyProvider).toUpperCase(),
      rates: ref.watch(effectiveRatesProvider).valueOrNull,
      defaultExpense: ref.watch(defaultExpenseAccountIdProvider).valueOrNull,
      defaultIncome: ref.watch(defaultIncomeAccountIdProvider).valueOrNull);

  final bool hidden, compactMoney, multiCurrencyActive;
  final String base;
  final Map<String, EffectiveRate>? rates;
  final int? defaultExpense, defaultIncome;
}

class AccountTypeGroupBinding extends ConsumerStatefulWidget {
  final String type;
  final List<db.Account> accounts;
  final bool compact;
  final Color primaryColor;
  final Map<int, ({double balance, double expense, double income})>? allStats;
  final AccountCardDisplayData? display;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(db.Account account) onTap;
  final void Function(db.Account account) onEdit;

  const AccountTypeGroupBinding({
    super.key,
    this.compact = false,
    required this.type,
    required this.accounts,
    required this.primaryColor,
    this.allStats,
    this.display,
    required this.onReorder,
    required this.onTap,
    required this.onEdit,
  });

  @override
  ConsumerState<AccountTypeGroupBinding> createState() =>
      _AccountTypeGroupState();
}

class _AccountTypeGroupState extends ConsumerState<AccountTypeGroupBinding> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final typeColor = getColorForAccountType(widget.type, widget.primaryColor);

    if (widget.compact) {
      return BeeAssetTypeGroup(
          title: getAccountTypeLabel(context, widget.type),
          count: widget.accounts.length,
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
          children: [
            for (final account in widget.accounts)
              AccountCardBinding(
                  key: ValueKey(account.id),
                  account: account,
                  compact: true,
                  primaryColor: widget.primaryColor,
                  typeColor: typeColor,
                  stats: widget.allStats?[account.id],
                  display: widget.display,
                  onTap: () => widget.onTap(account),
                  onEdit: () => widget.onEdit(account))
          ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BeeMenuRow(
            title: getAccountTypeLabel(context, widget.type),
            leading: AccountTypeIcon(type: widget.type, size: 23),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${widget.accounts.length}',
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).hintColor)),
              const SizedBox(width: 8),
              BeeLineIcon(_expanded ? 'ChevronUp' : 'ChevronDown', size: 17),
            ]),
            onTap: () => setState(() => _expanded = !_expanded)),
        // 账户卡片列表
        if (_expanded)
          ...widget.accounts.map((account) {
            return AccountCardBinding(
              key: ValueKey(account.id),
              account: account,
              primaryColor: widget.primaryColor,
              typeColor: typeColor,
              stats: widget.allStats?[account.id],
              display: widget.display,
              onTap: () => widget.onTap(account),
              onEdit: () => widget.onEdit(account),
            );
          }),
      ],
    );
  }
}

/// 「已隐藏」账户分区(账户隐藏 #240,产品设计 01 §4.1)。置于所有在用分组
/// 之后,默认折叠;分区头显示「已隐藏(N)· 合计 ¥x」(小计口径同净资产卡:
/// 多币种折算跳过缺汇率币种,复用 [convertAmountsToBase],与资产/负债分组
/// 小计同一函数,保证与净资产汇总卡的差额天然对上账)。隐藏卡复用
/// [AccountCardBinding],传入中性灰 typeColor 弱化视觉权重 + onRestore 回调。
class HiddenAccountsSectionBinding extends ConsumerStatefulWidget {
  final List<db.Account> accounts;
  final Map<int, ({double balance, double expense, double income})>? allStats;
  final AccountCardDisplayData? display;
  final bool compact;
  final Color primaryColor;
  final void Function(db.Account account) onTap;
  final void Function(db.Account account) onEdit;
  final void Function(db.Account account) onRestore;

  const HiddenAccountsSectionBinding({
    super.key,
    this.compact = false,
    required this.accounts,
    required this.allStats,
    this.display,
    required this.primaryColor,
    required this.onTap,
    required this.onEdit,
    required this.onRestore,
  });

  @override
  ConsumerState<HiddenAccountsSectionBinding> createState() =>
      _HiddenAccountsSectionState();
}

class _HiddenAccountsSectionState
    extends ConsumerState<HiddenAccountsSectionBinding> {
  // 默认折叠(产品设计 01 §4.1)。
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.accounts.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final isDark = BeeTokens.isDark(context);
    // 中性灰(暗黑/明亮各一档),弱化隐藏卡视觉权重,不用账户类型主题色
    // (0xFF48484A 沿用 tokens.dart 里同款暗黑中性灰,见 surfaceCategoryIcon)。
    final mutedColor = isDark ? const Color(0xFF48484A) : Colors.grey.shade400;

    // 按币种分组计算小计,口径同 _buildClassificationSection(仅隐藏账户)。
    final Map<String, double> subtotalByCurrency = {};
    for (final account in widget.accounts) {
      final balance = widget.allStats?[account.id]?.balance ?? 0;
      subtotalByCurrency.update(
        account.currency,
        (v) => v + balance,
        ifAbsent: () => balance,
      );
    }
    final display = widget.display ?? AccountCardDisplayData.watch(ref);
    final multiCurrencyActive = display.multiCurrencyActive;
    final rates = display.rates;
    final base = display.base;
    final hide = display.hidden;

    final totalText = hide
        ? '****'
        : _subtotalText(subtotalByCurrency, multiCurrencyActive, rates, base);
    final summary =
        l10n.accountHiddenSectionSummary(widget.accounts.length, totalText);

    if (widget.compact) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BeeMenuRow(
            title: summary,
            subtitle: l10n.v4AssetsHiddenIncluded,
            leading: const BeeLineIcon('EyeOff', size: 15),
            trailing:
                BeeLineIcon(_expanded ? 'ChevronUp' : 'ChevronDown', size: 13),
            onTap: () => setState(() => _expanded = !_expanded)),
        if (_expanded)
          BeeSurface(
              padding: EdgeInsets.zero,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final account in widget.accounts)
                  AccountCardBinding(
                      key: ValueKey('hidden_${account.id}'),
                      compact: true,
                      account: account,
                      primaryColor: widget.primaryColor,
                      typeColor: mutedColor,
                      stats: widget.allStats?[account.id],
                      display: display,
                      onTap: () => widget.onTap(account),
                      onEdit: () => widget.onEdit(account),
                      onRestore: () => widget.onRestore(account))
              ]))
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BeeMenuRow(
            title: summary,
            leading: const BeeLineIcon('EyeOff', size: 20),
            trailing:
                BeeLineIcon(_expanded ? 'ChevronUp' : 'ChevronDown', size: 17),
            onTap: () => setState(() => _expanded = !_expanded)),
        if (_expanded)
          ...widget.accounts.map((account) => AccountCardBinding(
                key: ValueKey('hidden_${account.id}'),
                account: account,
                primaryColor: widget.primaryColor,
                typeColor: mutedColor,
                stats: widget.allStats?[account.id],
                display: display,
                onTap: () => widget.onTap(account),
                onEdit: () => widget.onEdit(account),
                onRestore: () => widget.onRestore(account),
              )),
      ],
    );
  }

  /// 小计文本:与净资产卡同口径。单币种直接格式化;跨币种且折算态就绪时,
  /// 折到主币种(与 _buildGroupConvertedSubtotal 同一个 convertAmountsToBase)。
  String _subtotalText(
    Map<String, double> subtotalByCurrency,
    bool multiCurrencyActive,
    Map<String, EffectiveRate>? rates,
    String base,
  ) {
    final isSingleCurrency = subtotalByCurrency.length <= 1;
    if (multiCurrencyActive && rates != null && !isSingleCurrency) {
      final result = convertAmountsToBase(
        amounts: subtotalByCurrency,
        rates: rates,
        base: base,
      );
      return '${getCurrencySymbol(base)}${result.total.abs().toStringAsFixed(2)}';
    }
    final currency = subtotalByCurrency.keys.firstOrNull ?? base;
    final value = subtotalByCurrency.values.firstOrNull ?? 0;
    return '${getCurrencySymbol(currency)}${formatMoneyCompact(value, maxDecimals: 2, signed: false)}';
  }
}

/// 账户卡片
class AccountCardBinding extends ConsumerWidget {
  final db.Account account;
  final bool compact;
  final Color primaryColor;
  final Color typeColor;
  final ({double balance, double expense, double income})? stats;
  final AccountCardDisplayData? display;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  /// 「已隐藏」分区卡片的恢复回调(账户隐藏 #240)。非空时才渲染「已隐藏」
  /// 灰标 + 恢复按钮;在用卡片(account.hidden==false)不受影响。
  final VoidCallback? onRestore;

  const AccountCardBinding({
    super.key,
    this.compact = false,
    required this.account,
    required this.primaryColor,
    required this.typeColor,
    this.stats,
    this.display,
    required this.onTap,
    required this.onEdit,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = BeeTokens.isDark(context);

    if (compact) {
      return _compactRow(
          context, display ?? AccountCardDisplayData.watch(ref), l10n);
    }
    final hidden = ref.watch(hideAmountsProvider);
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
            onLongPress: onEdit,
            child: BeeAccountCard(
              name: account.name,
              currency: account.currency,
              balance: stats == null
                  ? '—'
                  : formatBalanceFull(stats!.balance, account.currency),
              kind: getAccountTypeLabel(context, account.type),
              icon: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(13)),
                  child: Center(
                      child: AccountTypeIcon(type: account.type, size: 23))),
              onTap: onTap,
              menuLabel: l10n.commonMore,
              hidden: hidden,
              actions: [
                BeeMenuAction(value: 'edit', label: l10n.commonEdit),
                if (onRestore != null)
                  BeeMenuAction(value: 'restore', label: l10n.accountRestore)
              ],
              onAction: (v) {
                if (v == 'restore') {
                  onRestore?.call();
                } else {
                  onEdit();
                }
              },
              excludedLabel: account.hidden ? l10n.accountHiddenTag : null,
              footer: stats == null
                  ? const SizedBox(
                      height: 18,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : account.type == 'credit_card'
                      ? _buildCreditCardStats(context, ref, l10n, isDark)
                      : isValuationOnlyType(account.type)
                          ? _buildValuationStats(context, ref, l10n, isDark)
                          : Row(children: [
                              Expanded(
                                  child: CardStatBinding(
                                      label: l10n.homeIncome,
                                      value: stats!.income,
                                      textColor: BeeTokens.textPrimary(context),
                                      labelColor:
                                          BeeTokens.textSecondary(context),
                                      ref: ref,
                                      currencyCode: account.currency)),
                              Expanded(
                                  child: CardStatBinding(
                                      label: l10n.homeExpense,
                                      value: stats!.expense,
                                      textColor: BeeTokens.textPrimary(context),
                                      labelColor:
                                          BeeTokens.textSecondary(context),
                                      ref: ref,
                                      currencyCode: account.currency)),
                            ]),
            )));
  }

  Widget _compactRow(BuildContext context, AccountCardDisplayData display,
      AppLocalizations l) {
    final hidden = display.hidden;
    final compactMoney = display.compactMoney;
    final base = display.base;
    final rates = display.rates;
    final balance = stats?.balance;
    String amount(double value) => formatDisplayAmount(value,
        currencyCode: account.currency,
        showCurrency: true,
        signed: false,
        useCompactFormat: compactMoney,
        isChineseLocale: Localizations.localeOf(context).languageCode == 'zh');
    final foreign =
        display.multiCurrencyActive && account.currency.toUpperCase() != base;
    final converted = balance == null || rates == null
        ? null
        : computeNativeAmount(
            amount: balance,
            accountCurrency: account.currency,
            ledgerBase: base,
            rates: rates);
    final expense = display.defaultExpense;
    final income = display.defaultIncome;
    final badge = account.id == expense
        ? l.v4AssetsDefaultExpense
        : account.id == income
            ? l.v4AssetsDefaultIncome
            : null;
    final credit = account.type == 'credit_card' && balance != null
        ? CreditCardAmounts(balance, limit: account.creditLimit)
        : null;
    final dates = account.billingDay != null && account.paymentDueDay != null
        ? l.creditCardBillingInfo(account.billingDay!, account.paymentDueDay!)
        : null;
    final metadata = [
      if (account.cardLastFour?.isNotEmpty == true)
        '•• ${account.cardLastFour}',
      if (isValuationOnlyType(account.type) && account.updatedAt != null)
        '${account.updatedAt!.month.toString().padLeft(2, '0')}-${account.updatedAt!.day.toString().padLeft(2, '0')}',
      if (account.cardLastFour?.isNotEmpty != true &&
          account.note?.isNotEmpty == true)
        account.note!
    ].join(' · ');
    return BeeCompactAccountRow(
        name: account.name,
        subtitle: metadata,
        amount: balance == null ? '—' : amount(balance),
        hidden: hidden,
        icon: AccountTypeIcon(
            type: account.type,
            size: 19,
            monochrome: true,
            color: Theme.of(context).hintColor),
        onTap: onTap,
        onEdit: onEdit,
        badge: badge,
        converted: foreign
            ? (converted == null
                ? l.unconvertedBadge
                : '≈ ${formatDisplayAmount(converted, currencyCode: base, showCurrency: true, signed: false, useCompactFormat: compactMoney)}')
            : null,
        status: isValuationOnlyType(account.type)
            ? (isLiabilityType(account.type)
                ? l.valuationCurrentDebt
                : l.valuationCurrentValue)
            : credit != null
                ? (credit.overpayment > 0
                    ? l.creditCardOverpayment
                    : l.creditCardOwed)
                : null,
        progress: credit != null && (account.creditLimit ?? 0) > 0
            ? (credit.debt / account.creditLimit!).clamp(0.0, 1.0)
            : null,
        creditLeft: credit?.estimatedAvailable != null
            ? '${l.creditAvailable} ${amount(credit!.estimatedAvailable!)}'
            : null,
        creditRight: credit != null ? dates : null,
        onRestore: onRestore,
        restoreLabel: l.accountRestore,
        includedLabel: l.v4AssetsHiddenIncluded);
  }

  Widget _buildValuationStats(
      BuildContext context, WidgetRef ref, AppLocalizations l10n, bool isDark) {
    final textColor = BeeTokens.textPrimary(context);
    final labelColor = BeeTokens.textSecondary(context);
    final isLiability = isLiabilityType(account.type);
    final displayValue = isLiability ? stats!.balance.abs() : stats!.balance;
    final label =
        isLiability ? l10n.valuationCurrentDebt : l10n.valuationCurrentValue;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: labelColor,
                ),
              ),
              SizedBox(height: 2.0.scaled(context, ref)),
              AmountText(
                value: displayValue,
                signed: false,
                showCurrency: false,
                useCompactFormat: ref.watch(compactAmountProvider),
                currencyCode: account.currency,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        if (account.updatedAt != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                Icons.update,
                size: 14.0.scaled(context, ref),
                color: labelColor,
              ),
              SizedBox(height: 2.0.scaled(context, ref)),
              Text(
                '${account.updatedAt!.month.toString().padLeft(2, '0')}-${account.updatedAt!.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 11,
                  color: labelColor,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCreditCardStats(
      BuildContext context, WidgetRef ref, AppLocalizations l10n, bool isDark) {
    final amounts =
        CreditCardAmounts(stats!.balance, limit: account.creditLimit);
    final used = amounts.debt;
    final textColor = BeeTokens.textPrimary(context);
    final labelColor = BeeTokens.textSecondary(context);

    // 信用卡按 type 判定;无额度时仅显示当前欠款,不再 fallthrough 到收入/支出卡
    final creditLimit = account.creditLimit;
    if (creditLimit == null || creditLimit <= 0) {
      return Align(
        alignment: Alignment.centerLeft,
        child: CardStatBinding(
          label: amounts.overpayment > 0
              ? l10n.creditCardOverpayment
              : l10n.creditCardOwed,
          value: amounts.overpayment > 0 ? amounts.overpayment : used,
          textColor: textColor,
          labelColor: labelColor,
          ref: ref,
          currencyCode: account.currency,
        ),
      );
    }

    final usageRate =
        creditLimit > 0 ? (used / creditLimit).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        // 进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(3.0.scaled(context, ref)),
          child: LinearProgressIndicator(
            value: usageRate,
            backgroundColor: BeeTokens.divider(context),
            valueColor: AlwaysStoppedAnimation<Color>(
              primaryColor,
            ),
            minHeight: 4.0.scaled(context, ref),
          ),
        ),
        SizedBox(height: 8.0.scaled(context, ref)),
        Row(
          children: [
            Expanded(
              child: CardStatBinding(
                label: l10n.creditLimit,
                value: creditLimit,
                textColor: textColor,
                labelColor: labelColor,
                ref: ref,
                currencyCode: account.currency,
              ),
            ),
            Container(
              width: 1,
              height: 24.0.scaled(context, ref),
              color: BeeTokens.divider(context),
            ),
            Expanded(
              child: CardStatBinding(
                label: amounts.overpayment > 0
                    ? l10n.creditCardOverpayment
                    : l10n.creditCardOwed,
                value: amounts.overpayment > 0 ? amounts.overpayment : used,
                textColor: textColor,
                labelColor: labelColor,
                ref: ref,
                currencyCode: account.currency,
              ),
            ),
            Container(
              width: 1,
              height: 24.0.scaled(context, ref),
              color: BeeTokens.divider(context),
            ),
            Expanded(
              child: CardStatBinding(
                label: l10n.creditAvailable,
                value: amounts.estimatedAvailable ?? 0,
                textColor: textColor,
                labelColor: labelColor,
                ref: ref,
                currencyCode: account.currency,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 卡片内统计项
class CardStatBinding extends StatelessWidget {
  final String label;
  final double value;
  final Color textColor;
  final Color labelColor;
  final WidgetRef ref;

  /// 账户的货币代码 — 用来锁住 formatBalance 的格式;不传则 fallback 到账本货币。
  final String? currencyCode;

  const CardStatBinding({
    super.key,
    required this.label,
    required this.value,
    required this.textColor,
    required this.labelColor,
    required this.ref,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AmountText(
          value: value,
          signed: false,
          showCurrency: false,
          useCompactFormat: ref.watch(compactAmountProvider),
          currencyCode: currencyCode,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

/// 紧凑默认账户选择行
/// 资产管理页 header 右上角的「蜜蜂家当」入口。
///
/// 用 Material 标准的 Premium / 进阶版图标(`workspace_premium_outlined`),
/// 跟 setting / add 等 outlined 图标视觉重量完全一致;语义上暗示「升级 /
/// 进阶版本」,鼓励点击。颜色自适应 header 背景。点击进入介绍弹窗。
class BeeAssetsHeaderEntryBinding extends StatelessWidget {
  const BeeAssetsHeaderEntryBinding({super.key, this.asMenuRow = false});
  final bool asMenuRow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final info = beeAssetsPromo(context);
    final texts = buildPromoTexts(context, l10n.aboutBeeAssets);

    if (asMenuRow) {
      return BeeMenuRow(
          title: info.title,
          leading: const BeeLineIcon('Sparkles'),
          onTap: () => ProductPromoLauncher.open(context, info, texts));
    }
    return BeeIconButton(
      onPressed: () => ProductPromoLauncher.open(context, info, texts),
      label: info.title,
      icon: const BeeLineIcon('Sparkles'),
    );
  }
}
