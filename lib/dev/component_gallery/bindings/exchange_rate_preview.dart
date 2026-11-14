import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/currency/exchange_rate_page.dart';
import '../../../providers/currency_providers.dart';
import '../../../utils/currencies.dart';
import '../../../pages/currency/exchange_rates/bindings/exchange_rate_actions.dart';

class LiveExchangeRatePreview extends ConsumerWidget {
  const LiveExchangeRatePreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(baseCurrencyProvider),
        used = ref.watch(usedCurrenciesProvider),
        rates = ref.watch(effectiveRatesProvider),
        l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('真实汇率（只读） · $base'),
      const SizedBox(height: 8),
      used.when(
          loading: () => const Text('正在读取使用中币种'),
          error: (_, __) => const Text('币种读取失败'),
          data: (currencies) => rates.when(
              loading: () => const Text('正在读取汇率'),
              error: (_, __) => const Text('汇率读取失败'),
              data: (values) {
                final quotes = currencies
                    .where((c) => c.toUpperCase() != base.toUpperCase())
                    .toList()
                  ..sort();
                if (quotes.isEmpty) return Text(l.ratesEmptyHint);
                return Column(children: [
                  for (final quote in quotes)
                    Builder(builder: (context) {
                      final rate = values[quote];
                      return BeeExchangeRateRow(
                          code: quote,
                          name: getCurrencyName(quote, context),
                          value: rate == null
                              ? '—'
                              : '1 $quote = ${formatExchangeRate(rate.rate)} $base',
                          source: rate == null
                              ? '${l.rateNotFetched} · ${l.rateTapToSet}'
                              : rate.manual
                                  ? l.rateSourceManual
                                  : '${l.rateSourceAuto} · ${l.rateUpdatedAt(rate.rateDate ?? '')}',
                          manual: rate?.manual ?? false,
                          stale: rate != null &&
                              !rate.manual &&
                              exchangeRateIsStale(rate.rateDate));
                    })
                ]);
              })),
      const SizedBox(height: 12),
      BeeButton(
          label: '打开真实汇率管理',
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const ExchangeRatePage())))
    ]);
  }
}
