import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../providers/currency_providers.dart';
import '../../styles/tokens.dart';
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
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BeeTokens.surfaceSheet(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (bctx) {
      String query = '';
      final sheetTitle = title ?? AppLocalizations.of(bctx).baseCurrencyLabel;
      return StatefulBuilder(builder: (sctx, setSheetState) {
        // 常用币种置顶(kCommonCurrencyCodes 顺序),其余按地区原顺序。
        final allCur = getCurrencies(bctx);
        final ordered = <CurrencyInfo>[];
        for (final code in kCommonCurrencyCodes) {
          final hit = allCur.where((c) => c.code == code);
          if (hit.isNotEmpty) ordered.add(hit.first);
        }
        ordered.addAll(
            allCur.where((c) => !kCommonCurrencyCodes.contains(c.code)));
        final filtered = ordered.where((c) {
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
            height: 440,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: BeeTokens.textTertiary(bctx).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  sheetTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimary(bctx),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: AppLocalizations.of(bctx).ledgersSearchCurrency,
                  ),
                  onChanged: (v) => setSheetState(() => query = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  // 汇率展示:rateBase 传入时用 Consumer 拿全量汇率;否则空 map。
                  child: Consumer(builder: (cctx, ref, _) {
                    final rates = rateBase == null
                        ? const <String, double>{}
                        : (ref
                                .watch(currencyPickerRatesProvider(
                                    rateBase.toUpperCase()))
                                .valueOrNull ??
                            const <String, double>{});
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final sel = c.code == current;
                        // 汇率行:1 该币种 ≈ x rateBase(base 自身/缺失不显示)
                        String? rateText;
                        if (rateBase != null &&
                            c.code != rateBase!.toUpperCase()) {
                          final r = rates[c.code];
                          if (r != null) {
                            rateText =
                                '1 ${c.code} ≈ ${r.toStringAsPrecision(4)} ${rateBase!.toUpperCase()}';
                          }
                        }
                        return ListTile(
                          leading: currencyFlag(cctx, c.code),
                          title: Text(
                            '${c.name} (${c.code})',
                            style: TextStyle(
                              color: sel
                                  ? primaryColor
                                  : BeeTokens.textPrimary(bctx),
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: rateText == null
                              ? null
                              : Text(
                                  rateText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: BeeTokens.textTertiary(cctx),
                                  ),
                                ),
                          trailing: sel
                              ? Icon(Icons.check, color: primaryColor)
                              : null,
                          onTap: () => Navigator.pop(bctx, c.code),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      });
    },
  );
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
