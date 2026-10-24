import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/v4/bindings/exchange_rate_actions.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../providers.dart';
import '../../services/currency/rate_math.dart';
import '../../utils/currencies.dart';

class ExchangeRatePage extends ConsumerStatefulWidget {
  const ExchangeRatePage({super.key});
  @override
  ConsumerState<ExchangeRatePage> createState() => _ExchangeRatePageState();
}

class _ExchangeRatePageState extends ConsumerState<ExchangeRatePage>
    with ExchangeRateActions<ExchangeRatePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshExchangeRatesFromUi(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        base = ref.watch(baseCurrencyProvider).toUpperCase(),
        used = ref.watch(usedCurrenciesProvider),
        rates = ref.watch(effectiveRatesProvider);
    Widget error(VoidCallback retry) => BeeEmptyState(
        title: l.commonError,
        icon: const BeeLineIcon('CircleAlert', size: 36),
        action: BeeButton(label: l.v4RecordingRetry, onPressed: retry));
    Widget rows(Set<String> currencies, Map<String, EffectiveRate> values) {
      final quotes = currencies
          .map((c) => c.toUpperCase())
          .where((c) => c != base)
          .toList()
        ..sort();
      if (quotes.isEmpty) {
        return BeeSurface(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l.ratesEmptyHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Theme.of(context).hintColor))));
      }
      return BeeSurface(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < quotes.length; i++) ...[
              if (i > 0)
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Divider(height: 1)),
              Builder(builder: (context) {
                final quote = quotes[i], rate = values[quote];
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
                        exchangeRateIsStale(rate.rateDate),
                    onTap: () => editRate(quote, base, rate));
              })
            ]
          ]));
    }

    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.exchangeRatePageTitle,
          leading: const BackButton(),
          actions: [
            if (ratesRefreshing)
              const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)))
            else
              BeeIconButton(
                  label: l.exchangeRatePageTitle,
                  icon: const BeeLineIcon('RefreshCw'),
                  onPressed: refreshRates)
          ]),
      Expanded(
          child: BeePageBody(eager: true, children: [
        BeeSurface(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: BeeMenuRow(
                title: l.baseCurrencyLabel,
                trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Flexible(
                          child: Text(displayCurrency(base, context),
                              style: const TextStyle(fontSize: 13))),
                      const SizedBox(width: 6),
                      const BeeLineIcon('ChevronRight', size: 16)
                    ])),
                onTap: pickRateBase)),
        used.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                error(() => ref.invalidate(usedCurrenciesProvider)),
            data: (currencies) => rates.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    error(() => ref.invalidate(effectiveRatesProvider)),
                data: (values) => rows(currencies, values))),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(l.rateDisclaimer,
                style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: Theme.of(context).hintColor))),
      ]))
    ]));
  }
}
