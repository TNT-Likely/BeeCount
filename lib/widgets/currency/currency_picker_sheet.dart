import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../utils/currencies.dart';
import 'currency_flag.dart';
import '../ui/ui.dart';

/// 币种选择 bottom sheet(搜索 + 国旗 + 汇率 + 选中勾)。返回选中的 code,取消返回 null。
///
/// 从 exchange_rate_page._pickBaseCurrency 抽出,汇率页 / 个性化页 / 记账弹窗共用。
/// [rateBase] 传入(大写 ISO)时,每行右侧展示「1 该币种 ≈ x rateBase」的汇率
/// (弹窗内拉一次全量,缺失显示占位)。
Future<String?> showCurrencyPickerSheet(
  BuildContext context, {
  required String selected,
  required Color primaryColor,
  String? title,
  String? rateBase,
}) {
  final current = selected.toUpperCase();
  return showBeeSheet<String>(context,
      title: title ?? AppLocalizations.of(context).baseCurrencyLabel,
      child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .6,
          child: Consumer(builder: (bctx, ref, _) {
            final l10n = AppLocalizations.of(bctx);
            final currencies = getCurrencies(bctx);
            final ordered = [
              for (final code in kCommonCurrencyCodes)
                ...currencies.where((item) => item.code == code),
              ...currencies
                  .where((item) => !kCommonCurrencyCodes.contains(item.code)),
            ];
            final rates = rateBase == null
                ? const <String, double>{}
                : ref
                        .watch(
                            currencyPickerRatesProvider(rateBase.toUpperCase()))
                        .valueOrNull ??
                    const <String, double>{};
            return Theme(
                data: Theme.of(bctx).copyWith(
                    colorScheme: Theme.of(bctx)
                        .colorScheme
                        .copyWith(primary: primaryColor)),
                child: BeeCurrencyPicker(
                    currencies: ordered.map((currency) {
                      final rate = rates[currency.code];
                      return BeeCurrencyChoice(
                          code: currency.code,
                          name: currency.name,
                          symbol: getCurrencySymbol(currency.code),
                          common: kCommonCurrencyCodes.contains(currency.code),
                          icon: currencyFlag(bctx, currency.code),
                          rateHint: rateBase != null &&
                                  currency.code != rateBase.toUpperCase() &&
                                  rate != null
                              ? '1 ${currency.code} ≈ ${rate.toStringAsPrecision(4)} ${rateBase.toUpperCase()}'
                              : null);
                    }).toList(),
                    selected: current,
                    searchLabel: l10n.ledgersSearchCurrency,
                    emptyLabel: l10n.commonEmpty,
                    onSelected: (code) => Navigator.pop(bctx, code)));
          })));
}

/// 应用主币种选择:同值跳过 / set provider / 已有手动汇率提示 / force 重拉自动汇率。
///
/// 汇率页与个性化页共用 —— 选完后统一走这条收尾逻辑。mounted 守卫照旧。
Future<void> applyBaseCurrencySelection(
  BuildContext context,
  WidgetRef ref,
  String code,
) async {
  final l10n = AppLocalizations.of(context);
  final current = ref.read(baseCurrencyProvider).toUpperCase();
  final next = code.toUpperCase();
  if (next == current) return;

  ref.read(baseCurrencyProvider.notifier).state = next;
  // 新主币种若已有手动汇率,提示并立即生效;随后 force 重拉自动汇率。
  final repo = ref.read(repositoryProvider);
  final overrides = await repo.getOverrides(next);
  if (!context.mounted) return;
  if (overrides.isNotEmpty) {
    showToast(context, l10n.rateManualApplied(overrides.length));
  }
  await refreshExchangeRatesFromUi(ref, force: true);
}
