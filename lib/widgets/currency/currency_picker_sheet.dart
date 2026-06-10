import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../utils/currencies.dart';
import '../ui/ui.dart';

/// 币种选择 bottom sheet(搜索 + 列表 + 选中勾)。返回选中的 code,取消返回 null。
///
/// 从 exchange_rate_page._pickBaseCurrency 抽出,汇率页 / 个性化页共用。
Future<String?> showCurrencyPickerSheet(
  BuildContext context, {
  required String selected,
  required Color primaryColor,
  String? title,
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
        final filtered = getCurrencies(bctx).where((c) {
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
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final sel = c.code == current;
                      return ListTile(
                        title: Text(
                          '${c.name} (${c.code})',
                          style: TextStyle(
                            color:
                                sel ? primaryColor : BeeTokens.textPrimary(bctx),
                            fontWeight:
                                sel ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: sel
                            ? Icon(Icons.check, color: primaryColor)
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
