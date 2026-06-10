import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/currency/rate_math.dart';
import '../../styles/tokens.dart';
import '../../utils/currencies.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../widgets/biz/section_card.dart';
import '../../widgets/ui/ui.dart';

/// 汇率管理页(多币种 MVP Task 8)。
/// - 自动拉取(24h 节流,单币种内部 no-op)+ 手动编辑覆盖
/// - 主币种切换:set provider → 已有手动汇率提示 → force 重拉
/// 方向约定全链统一:rate 字符串 = 「1 quote = rate base」。
class ExchangeRatePage extends ConsumerStatefulWidget {
  const ExchangeRatePage({super.key});

  @override
  ConsumerState<ExchangeRatePage> createState() => _ExchangeRatePageState();
}

class _ExchangeRatePageState extends ConsumerState<ExchangeRatePage> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // 进页静默拉取:24h 节流 + 单币种 no-op,内部自判,不阻塞 UI。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshExchangeRatesFromUi(ref);
    });
  }

  /// 6 位有效数字展示(方向已是「1 quote = rate base」)。
  String _fmt6(String rate) {
    final v = double.tryParse(rate);
    if (v == null) return rate;
    return v.toStringAsPrecision(6);
  }

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final l10n = AppLocalizations.of(context);
    final ok = await refreshExchangeRatesFromUi(ref, force: true);
    if (!mounted) return;
    setState(() => _refreshing = false);
    showToast(context, ok ? l10n.rateRefreshSuccess : l10n.rateRefreshFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    final base = ref.watch(baseCurrencyProvider).toUpperCase();
    final usedAsync = ref.watch(usedCurrenciesProvider);
    final ratesAsync = ref.watch(effectiveRatesProvider);

    // 外币 = 使用中币种 − 主币种,排序
    final quotes = (usedAsync.valueOrNull ?? <String>{})
        .where((c) => c.toUpperCase() != base)
        .map((c) => c.toUpperCase())
        .toList()
      ..sort();
    final rates = ratesAsync.valueOrNull ?? const <String, EffectiveRate>{};

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.exchangeRatePageTitle,
            showBack: true,
            compact: true,
            actions: [
              if (_refreshing)
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12.0.scaled(context, ref)),
                  child: SizedBox(
                    width: 18.0.scaled(context, ref),
                    height: 18.0.scaled(context, ref),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              else
                IconButton(
                  onPressed: _onRefresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: l10n.exchangeRatePageTitle,
                ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 12.0.scaled(context, ref),
                vertical: 8.0.scaled(context, ref),
              ),
              children: [
                // 1. 主币种
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: () => _pickBaseCurrency(context),
                    borderRadius: BorderRadius.circular(8.0.scaled(context, ref)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.0.scaled(context, ref),
                      ),
                      child: Row(
                        children: [
                          Text(
                            l10n.baseCurrencyLabel,
                            style: TextStyle(
                              fontSize: 15,
                              color: BeeTokens.textPrimary(context),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            displayCurrency(base, context),
                            style: TextStyle(
                              fontSize: 14,
                              color: BeeTokens.textSecondary(context),
                            ),
                          ),
                          SizedBox(width: 4.0.scaled(context, ref)),
                          Icon(
                            Icons.chevron_right,
                            size: 18.0.scaled(context, ref),
                            color: BeeTokens.iconTertiary(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.0.scaled(context, ref)),

                // 2. 汇率列表 / 空态
                if (quotes.isEmpty)
                  SectionCard(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 32.0.scaled(context, ref),
                        horizontal: 16.0.scaled(context, ref),
                      ),
                      child: Center(
                        child: Text(
                          l10n.ratesEmptyHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: BeeTokens.textTertiary(context),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SectionCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (int i = 0; i < quotes.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 12.0.scaled(context, ref),
                              endIndent: 12.0.scaled(context, ref),
                              color: BeeTokens.divider(context),
                            ),
                          _RateRow(
                            quote: quotes[i],
                            base: base,
                            eff: rates[quotes[i]],
                            primary: primary,
                            fmt6: _fmt6,
                            onTap: () =>
                                _editRate(context, quotes[i], base, rates[quotes[i]]),
                          ),
                        ],
                      ],
                    ),
                  ),

                SizedBox(height: 16.0.scaled(context, ref)),
                // 3. 免责声明
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.0.scaled(context, ref),
                  ),
                  child: Text(
                    l10n.rateDisclaimer,
                    style: TextStyle(
                      fontSize: 11,
                      color: BeeTokens.textTertiary(context),
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 主币种选择底部弹窗(全币种列表 + 搜索)。
  Future<void> _pickBaseCurrency(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(baseCurrencyProvider).toUpperCase();
    final primary = ref.read(primaryColorProvider);

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeeTokens.surfaceSheet(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bctx) {
        String query = '';
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
                    l10n.baseCurrencyLabel,
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
                              color: sel
                                  ? primary
                                  : BeeTokens.textPrimary(bctx),
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          trailing:
                              sel ? Icon(Icons.check, color: primary) : null,
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

    if (picked == null || !mounted) return;
    final next = picked.toUpperCase();
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

  /// 编辑某币种的手动汇率。
  Future<void> _editRate(
    BuildContext context,
    String quote,
    String base,
    EffectiveRate? eff,
  ) async {
    final l10n = AppLocalizations.of(context);
    final primary = ref.read(primaryColorProvider);
    final repo = ref.read(repositoryProvider);
    final hadManual = eff?.manual ?? false;
    // 预填:已有有效汇率取其值,否则空。
    final controller = TextEditingController(
      text: eff != null ? _fmt6(eff.rate) : '',
    );

    await showDialog<void>(
      context: context,
      builder: (dctx) {
        String? errorText;
        return StatefulBuilder(builder: (sctx, setDlgState) {
          // 实时反向参考:1 base ≈ (1/rate) quote
          final parsed = double.tryParse(controller.text.trim());
          final inverseText = (parsed != null && parsed > 0)
              ? (1 / parsed).toStringAsPrecision(6)
              : '—';

          return AlertDialog(
            backgroundColor: BeeTokens.surfaceElevated(dctx),
            title: Text(
              l10n.rateEditTitle,
              style: TextStyle(color: BeeTokens.textPrimary(dctx)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    prefixText: '1 $quote = ',
                    suffixText: base,
                    errorText: errorText,
                  ),
                  onChanged: (_) => setDlgState(() => errorText = null),
                ),
                SizedBox(height: 10.0.scaled(context, ref)),
                Text(
                  l10n.rateInverseHint(base, inverseText, quote),
                  style: TextStyle(
                    fontSize: 12,
                    color: BeeTokens.textTertiary(dctx),
                  ),
                ),
              ],
            ),
            actions: [
              if (hadManual)
                TextButton(
                  onPressed: () async {
                    await repo.removeOverride(base: base, quote: quote);
                    ref.read(rateRefreshTickProvider.notifier).state++;
                    if (dctx.mounted) Navigator.pop(dctx);
                  },
                  child: Text(
                    l10n.rateResetToAuto,
                    style: TextStyle(color: BeeTokens.textSecondary(dctx)),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: Text(
                  l10n.commonCancel,
                  style: TextStyle(color: BeeTokens.textSecondary(dctx)),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final raw = controller.text.trim();
                  final v = double.tryParse(raw);
                  if (v == null || v <= 1e-6 || v >= 1e9) {
                    setDlgState(() => errorText = l10n.commonError);
                    return;
                  }
                  // rate 字符串原样存用户输入(trim),不二次格式化。
                  await repo.setOverride(base: base, quote: quote, rate: raw);
                  ref.read(rateRefreshTickProvider.notifier).state++;
                  if (dctx.mounted) Navigator.pop(dctx);
                },
                child: Text(
                  l10n.commonSave,
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
    controller.dispose();
  }
}

/// 单条汇率行。
class _RateRow extends ConsumerWidget {
  final String quote;
  final String base;
  final EffectiveRate? eff;
  final Color primary;
  final String Function(String) fmt6;
  final VoidCallback onTap;

  const _RateRow({
    required this.quote,
    required this.base,
    required this.eff,
    required this.primary,
    required this.fmt6,
    required this.onTap,
  });

  /// rateDate 距今 > 7 天?(rateDate 形如 "2026-06-10")
  bool _isStale(String? rateDate) {
    if (rateDate == null) return false;
    final d = DateTime.tryParse(rateDate);
    if (d == null) return false;
    return DateTime.now().difference(d) > const Duration(days: 7);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mainName = getCurrencyName(quote, context);

    // subtitle 状态
    Widget subtitle;
    if (eff == null) {
      subtitle = Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 12, color: BeeTokens.textTertiary(context)),
          children: [
            TextSpan(text: l10n.rateNotFetched),
            const TextSpan(text: ' · '),
            TextSpan(text: l10n.rateTapToSet),
          ],
        ),
      );
    } else if (eff!.manual) {
      subtitle = Text(
        l10n.rateSourceManual,
        style: TextStyle(
          fontSize: 12,
          color: primary,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      final stale = _isStale(eff!.rateDate);
      subtitle = Text(
        '${l10n.rateSourceAuto} · ${l10n.rateUpdatedAt(eff!.rateDate ?? '')}',
        style: TextStyle(
          fontSize: 12,
          color: stale ? Colors.orange : BeeTokens.textTertiary(context),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12.0.scaled(context, ref),
          vertical: 12.0.scaled(context, ref),
        ),
        child: Row(
          children: [
            // 左:币种名 + 码 / 状态
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          mainName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: BeeTokens.textPrimary(context),
                          ),
                        ),
                      ),
                      SizedBox(width: 6.0.scaled(context, ref)),
                      Text(
                        quote,
                        style: TextStyle(
                          fontSize: 12,
                          color: BeeTokens.textTertiary(context),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.0.scaled(context, ref)),
                  subtitle,
                ],
              ),
            ),
            SizedBox(width: 8.0.scaled(context, ref)),
            // 右:汇率值
            Text(
              eff == null
                  ? '—'
                  : '1 $quote = ${fmt6(eff!.rate)} $base',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: eff == null
                    ? BeeTokens.textTertiary(context)
                    : BeeTokens.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
