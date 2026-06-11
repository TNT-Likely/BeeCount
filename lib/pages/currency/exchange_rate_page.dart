import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/currency/rate_math.dart';
import '../../styles/tokens.dart';
import '../../utils/currencies.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../widgets/biz/section_card.dart';
import '../../widgets/currency/currency_picker_sheet.dart';
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

  /// 主币种选择底部弹窗(全币种列表 + 搜索)。复用公用 sheet + 应用逻辑。
  Future<void> _pickBaseCurrency(BuildContext context) async {
    final current = ref.read(baseCurrencyProvider).toUpperCase();
    final primary = ref.read(primaryColorProvider);
    final picked = await showCurrencyPickerSheet(
      context,
      selected: current,
      primaryColor: primary,
    );
    if (picked == null || !context.mounted) return;
    await applyBaseCurrencySelection(context, ref, picked);
  }

  /// 编辑某币种的手动汇率。
  Future<void> _editRate(
    BuildContext context,
    String quote,
    String base,
    EffectiveRate? eff,
  ) async {
    // 弹窗自持 TextEditingController(State.dispose 在路由完全移除后才被调用)。
    // 不要在 await showDialog 返回后立刻 dispose —— 退场动画期间 TextField
    // 仍引用 controller,会 use-after-dispose 红屏。
    final result = await showDialog<({bool reset, String rate})>(
      context: context,
      builder: (_) => _RateEditDialog(
        quote: quote,
        base: base,
        hadManual: eff?.manual ?? false,
        // 预填:手动值回填原始字符串(保留用户精度);自动值用 _fmt6 展示(6 位有效,
        // 编辑后会被新输入覆盖,截断无妨);无汇率则留空。
        initialText: eff == null
            ? ''
            : (eff.manual ? eff.rate : _fmt6(eff.rate)),
      ),
    );
    if (result == null || !mounted) return; // 取消/遮罩关闭

    final repo = ref.read(repositoryProvider);
    if (result.reset) {
      await repo.removeOverride(base: base, quote: quote);
    } else {
      // rate 字符串原样存用户输入(trim),不二次格式化。
      await repo.setOverride(base: base, quote: quote, rate: result.rate);
    }
    ref.read(rateRefreshTickProvider.notifier).state++;
    final activeLedgerId = ref.read(currentLedgerIdProvider);
    if (activeLedgerId > 0) {
      unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
    }
  }
}

/// 汇率编辑弹窗:自持 controller,关闭时通过返回值告知动作
/// (reset=true 恢复自动;reset=false 保存 rate;null=取消)。
class _RateEditDialog extends ConsumerStatefulWidget {
  final String quote;
  final String base;
  final bool hadManual;
  final String initialText;

  const _RateEditDialog({
    required this.quote,
    required this.base,
    required this.hadManual,
    required this.initialText,
  });

  @override
  ConsumerState<_RateEditDialog> createState() => _RateEditDialogState();
}

class _RateEditDialogState extends ConsumerState<_RateEditDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    // 实时反向参考:1 base ≈ (1/rate) quote
    final parsed = double.tryParse(_controller.text.trim());
    final inverseText = (parsed != null && parsed > 0)
        ? (1 / parsed).toStringAsPrecision(6)
        : '—';

    return AlertDialog(
      backgroundColor: BeeTokens.surfaceElevated(context),
      title: Text(
        l10n.rateEditTitle,
        style: TextStyle(color: BeeTokens.textPrimary(context)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              prefixText: '1 ${widget.quote} = ',
              suffixText: widget.base,
              errorText: _errorText,
            ),
            onChanged: (_) => setState(() => _errorText = null),
          ),
          SizedBox(height: 10.0.scaled(context, ref)),
          Text(
            l10n.rateInverseHint(widget.base, inverseText, widget.quote),
            style: TextStyle(
              fontSize: 12,
              color: BeeTokens.textTertiary(context),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.hadManual)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, (reset: true, rate: '')),
            child: Text(
              l10n.rateResetToAuto,
              style: TextStyle(color: BeeTokens.textSecondary(context)),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.commonCancel,
            style: TextStyle(color: BeeTokens.textSecondary(context)),
          ),
        ),
        TextButton(
          onPressed: () {
            final raw = _controller.text.trim();
            final v = double.tryParse(raw);
            if (v == null || v <= 1e-6 || v >= 1e9) {
              setState(() => _errorText = l10n.commonError);
              return;
            }
            Navigator.pop(context, (reset: false, rate: raw));
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
