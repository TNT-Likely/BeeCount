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
class StatCellBinding extends ConsumerWidget {
  final String label;
  final double value;
  final Color? valueColor;

  const StatCellBinding({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: BeeTokens.textTertiary(context),
          ),
        ),
        SizedBox(height: 2.0.scaled(context, ref)),
        AmountText(
          value: value,
          signed: false,
          showCurrency: false,
          useCompactFormat: ref.watch(compactAmountProvider),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor ?? BeeTokens.textPrimary(context),
          ),
        ),
      ],
    );
  }
}

/// 折算视图里「≈ 符号+数值」的灰色小字（每币种折算行尾随）。
/// 这是派生金额文本，需跟 AmountText 一样响应隐藏金额开关。
class ApproxConvertedTextBinding extends ConsumerWidget {
  final String text;

  const ApproxConvertedTextBinding({super.key, required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(hideAmountsProvider);
    return Text(
      hide ? '≈ ****' : text,
      style: TextStyle(
        fontSize: 12,
        color: BeeTokens.textTertiary(context),
      ),
    );
  }
}

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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16.0.scaled(context, ref),
        vertical: 10.0.scaled(context, ref),
      ),
      child: Row(
        children: [
          // 左:币种码 + 本地化名
          Expanded(
            child: Row(
              children: [
                Text(
                  entry.code,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                SizedBox(width: 6.0.scaled(context, ref)),
                Flexible(
                  child: Text(
                    getCurrencyName(entry.code, context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textTertiary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.0.scaled(context, ref)),
          // 中:原币净值
          AmountText(
            value: entry.originalValue,
            signed: false,
            showCurrency: true,
            currencyCode: entry.code,
            useCompactFormat: useCompact,
            style: TextStyle(
              fontSize: 14,
              color: BeeTokens.textSecondary(context),
            ),
          ),
          SizedBox(width: 8.0.scaled(context, ref)),
          // 右:base 自身空 / 缺失橙 badge / ≈ 折算 灰字
          if (entry.isBase)
            const SizedBox.shrink()
          else if (entry.isMissing)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 6.0.scaled(context, ref),
                vertical: 1.0.scaled(context, ref),
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange, width: 1),
                borderRadius: BorderRadius.circular(4.0.scaled(context, ref)),
              ),
              child: Text(
                l10n.unconvertedBadge,
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            )
          else if (entry.convertedValue != null)
            // abs:与同行原币 AmountText(signed:false) 的绝对值口径一致(负债不带负号)。
            ApproxConvertedTextBinding(
              text:
                  '≈ $baseSymbol${entry.convertedValue!.abs().toStringAsFixed(2)}',
            ),
        ],
      ),
    );
  }
}

/// 折算详情弹窗(骨架照 _showSettingsSheet:拖拽条 + 标题 + SafeArea)。
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
  showModalBottomSheet(
    context: context,
    backgroundColor: BeeTokens.surfaceSheet(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽条
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color:
                    BeeTokens.textTertiary(sheetContext).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: BeeTokens.textPrimary(sheetContext),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final e in entries)
                      ConversionDetailRowBinding(
                        entry: e,
                        baseSymbol: baseSymbol,
                        useCompact: useCompact,
                      ),
                    if (footer != null) footer,
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.0.scaled(sheetContext, ref)),
          ],
        ),
      );
    },
  );
}

/// 折算视图的总资产/总负债单元格：≈(灰) 前缀 + 折算后金额(主币种)。
class ConvertedStatCellBinding extends ConsumerWidget {
  final String label;
  final double value;
  final String currencyCode;
  final Color valueColor;
  final bool useCompact;

  const ConvertedStatCellBinding({
    super.key,
    required this.label,
    required this.value,
    required this.currencyCode,
    required this.valueColor,
    required this.useCompact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: BeeTokens.textTertiary(context),
          ),
        ),
        SizedBox(height: 2.0.scaled(context, ref)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '≈ ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: BeeTokens.textTertiary(context),
              ),
            ),
            Flexible(
              child: AmountText(
                value: value,
                signed: false,
                showCurrency: true,
                currencyCode: currencyCode,
                useCompactFormat: useCompact,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 账户类型分组（可折叠，默认展开）
class AccountTypeGroupBinding extends ConsumerStatefulWidget {
  final String type;
  final List<db.Account> accounts;
  final Color primaryColor;
  final Map<int, ({double balance, double expense, double income})>? allStats;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(db.Account account) onTap;
  final void Function(db.Account account) onEdit;

  const AccountTypeGroupBinding({
    super.key,
    required this.type,
    required this.accounts,
    required this.primaryColor,
    this.allStats,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 类型标题栏（点击展开/折叠）
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(
              top: 12.0.scaled(context, ref),
              bottom: 6.0.scaled(context, ref),
              left: 4.0.scaled(context, ref),
              right: 4.0.scaled(context, ref),
            ),
            child: Row(
              children: [
                Container(
                  width: 28.0.scaled(context, ref),
                  height: 28.0.scaled(context, ref),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(7.0.scaled(context, ref)),
                  ),
                  child: Center(
                    child: AccountTypeIcon(
                      type: widget.type,
                      size: 16.0.scaled(context, ref),
                      color: typeColor,
                    ),
                  ),
                ),
                SizedBox(width: 8.0.scaled(context, ref)),
                Text(
                  getAccountTypeLabel(context, widget.type),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                SizedBox(width: 6.0.scaled(context, ref)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 5.0.scaled(context, ref),
                    vertical: 1.0.scaled(context, ref),
                  ),
                  decoration: BoxDecoration(
                    color:
                        BeeTokens.textTertiary(context).withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(8.0.scaled(context, ref)),
                  ),
                  child: Text(
                    '${widget.accounts.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: BeeTokens.textTertiary(context),
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18.0.scaled(context, ref),
                    color: BeeTokens.iconTertiary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 账户卡片列表
        if (_expanded)
          ...widget.accounts.map((account) {
            return AccountCardBinding(
              key: ValueKey(account.id),
              account: account,
              primaryColor: widget.primaryColor,
              typeColor: typeColor,
              stats: widget.allStats?[account.id],
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
  final Color primaryColor;
  final void Function(db.Account account) onTap;
  final void Function(db.Account account) onEdit;
  final void Function(db.Account account) onRestore;

  const HiddenAccountsSectionBinding({
    super.key,
    required this.accounts,
    required this.allStats,
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
    final multiCurrencyActive = ref.watch(multiCurrencyActiveProvider);
    final rates = ref.watch(effectiveRatesProvider).valueOrNull;
    final base = ref.watch(baseCurrencyProvider).toUpperCase();
    final hide = ref.watch(hideAmountsProvider);

    final totalText = hide
        ? '****'
        : _subtotalText(subtotalByCurrency, multiCurrencyActive, rates, base);
    final summary =
        l10n.accountHiddenSectionSummary(widget.accounts.length, totalText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(
              top: 16.0.scaled(context, ref),
              bottom: 4.0.scaled(context, ref),
              left: 4.0.scaled(context, ref),
              right: 4.0.scaled(context, ref),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility_off_outlined,
                    size: 18.0.scaled(context, ref),
                    color: BeeTokens.textTertiary(context)),
                SizedBox(width: 6.0.scaled(context, ref)),
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textSecondary(context),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.chevron_right,
                      size: 18.0.scaled(context, ref),
                      color: BeeTokens.iconTertiary(context)),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.accounts.map((account) => AccountCardBinding(
                key: ValueKey('hidden_${account.id}'),
                account: account,
                primaryColor: widget.primaryColor,
                typeColor: mutedColor,
                stats: widget.allStats?[account.id],
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
  final Color primaryColor;
  final Color typeColor;
  final ({double balance, double expense, double income})? stats;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  /// 「已隐藏」分区卡片的恢复回调(账户隐藏 #240)。非空时才渲染「已隐藏」
  /// 灰标 + 恢复按钮;在用卡片(account.hidden==false)不受影响。
  final VoidCallback? onRestore;

  const AccountCardBinding({
    super.key,
    required this.account,
    required this.primaryColor,
    required this.typeColor,
    this.stats,
    required this.onTap,
    required this.onEdit,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = BeeTokens.isDark(context);

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
class CompactDefaultAccountBinding extends ConsumerWidget {
  final List<db.Account> accounts;
  final Color primaryColor;
  final String type;

  const CompactDefaultAccountBinding({
    super.key,
    required this.accounts,
    required this.primaryColor,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isIncome = type == 'income';
    final defaultAccountIdAsync = isIncome
        ? ref.watch(defaultIncomeAccountIdProvider)
        : ref.watch(defaultExpenseAccountIdProvider);

    return defaultAccountIdAsync.when(
      data: (defaultAccountId) {
        db.Account? defaultAccount;
        if (defaultAccountId != null) {
          defaultAccount =
              accounts.where((a) => a.id == defaultAccountId).firstOrNull;
        }

        final title = isIncome
            ? l10n.accountDefaultIncomeTitle
            : l10n.accountDefaultExpenseTitle;

        return InkWell(
          onTap: () => _showPicker(context, ref, accounts, defaultAccountId),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0.scaled(context, ref),
              vertical: 10.0.scaled(context, ref),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                const Spacer(),
                Text(
                  defaultAccount?.name ?? l10n.accountDefaultNone,
                  style: TextStyle(
                    fontSize: 13,
                    color: BeeTokens.textTertiary(context),
                  ),
                ),
                SizedBox(width: 2.0.scaled(context, ref)),
                Icon(
                  Icons.chevron_right,
                  size: 16.0.scaled(context, ref),
                  color: BeeTokens.iconTertiary(context),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref,
      List<db.Account> accounts, int? currentDefaultId) {
    final l10n = AppLocalizations.of(context);
    final isIncome = type == 'income';
    final title = isIncome
        ? l10n.accountDefaultIncomeTitle
        : l10n.accountDefaultExpenseTitle;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BeeTokens.surfaceElevated(context),
        title: Text(title,
            style: TextStyle(color: BeeTokens.textPrimary(context))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                leading:
                    Icon(Icons.block, color: BeeTokens.iconSecondary(context)),
                title: Text(
                  l10n.accountDefaultNone,
                  style: TextStyle(
                    color: currentDefaultId == null
                        ? primaryColor
                        : BeeTokens.textPrimary(context),
                    fontWeight: currentDefaultId == null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                trailing: currentDefaultId == null
                    ? Icon(Icons.check, color: primaryColor)
                    : null,
                onTap: () async {
                  if (isIncome) {
                    await ref
                        .read(defaultAccountSetterProvider)
                        .setDefaultIncomeAccountId(null);
                    ref.invalidate(defaultIncomeAccountIdProvider);
                  } else {
                    await ref
                        .read(defaultAccountSetterProvider)
                        .setDefaultExpenseAccountId(null);
                    ref.invalidate(defaultExpenseAccountIdProvider);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ...accounts.map((account) {
                final isSelected = account.id == currentDefaultId;
                return ListTile(
                  dense: true,
                  leading: AccountTypeIcon(
                    type: account.type,
                    size: 24,
                  ),
                  title: Text(
                    account.name,
                    style: TextStyle(
                      color: isSelected
                          ? primaryColor
                          : BeeTokens.textPrimary(context),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: primaryColor)
                      : null,
                  onTap: () async {
                    if (isIncome) {
                      await ref
                          .read(defaultAccountSetterProvider)
                          .setDefaultIncomeAccountId(account.id);
                      ref.invalidate(defaultIncomeAccountIdProvider);
                    } else {
                      await ref
                          .read(defaultAccountSetterProvider)
                          .setDefaultExpenseAccountId(account.id);
                      ref.invalidate(defaultExpenseAccountIdProvider);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// 资产管理页 header 右上角的「蜜蜂家当」入口。
///
/// 用 Material 标准的 Premium / 进阶版图标(`workspace_premium_outlined`),
/// 跟 setting / add 等 outlined 图标视觉重量完全一致;语义上暗示「升级 /
/// 进阶版本」,鼓励点击。颜色自适应 header 背景。点击进入介绍弹窗。
class BeeAssetsHeaderEntryBinding extends StatelessWidget {
  const BeeAssetsHeaderEntryBinding({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final info = beeAssetsPromo(context);
    final texts = buildPromoTexts(context, l10n.aboutBeeAssets);

    return IconButton(
      onPressed: () => ProductPromoLauncher.open(context, info, texts),
      tooltip: info.title,
      icon: const Icon(Icons.auto_awesome_outlined),
    );
  }
}
