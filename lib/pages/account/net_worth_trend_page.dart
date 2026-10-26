import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../presentation/v4/bindings/net_worth_trend.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';

class NetWorthTrendPage extends ConsumerStatefulWidget {
  const NetWorthTrendPage({super.key});
  @override
  ConsumerState<NetWorthTrendPage> createState() => _NetWorthTrendPageState();
}

class _NetWorthTrendPageState extends ConsumerState<NetWorthTrendPage> {
  NetWorthLine _line = NetWorthLine.net;
  NetWorthRange _range = NetWorthRange.m12;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        hidden = ref.watch(hideAmountsProvider);
    final dates =
        _range.dates(ref.watch(earliestTransactionDateProvider).valueOrNull);
    final provider = netWorthTrendSeriesProvider(dates),
        series = ref.watch(provider);
    final currency = ref.watch(baseCurrencyProvider).toUpperCase();
    final multi =
        (ref.watch(usedCurrenciesProvider).valueOrNull?.length ?? 1) > 1;
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.netWorthTrendTitle,
          leading: const BackButton(),
          actions: [
            BeeIconButton(
                label: hidden ? l.v4AmountsShow : l.v4AmountsHide,
                icon: BeeLineIcon(hidden ? 'EyeOff' : 'Eye'),
                onPressed: () =>
                    ref.read(hideAmountsProvider.notifier).state = !hidden),
          ]),
      Expanded(
          child: ListView(padding: const EdgeInsets.all(17), children: [
        BeeFilterBar(
            filters: [for (final v in NetWorthRange.values) v.label(l)],
            selected: _range.label(l),
            onSelected: (label) => setState(() => _range =
                NetWorthRange.values.firstWhere((v) => v.label(l) == label))),
        const SizedBox(height: 12),
        series.when(
          data: (daily) => V4NetWorthTrendContent(
              daily: daily,
              line: _line,
              range: _range,
              currency: currency,
              hidden: hidden,
              multiCurrency: multi,
              onLine: (v) => setState(() => _line = v)),
          loading: () => BeeSurface(
              child: BeeSkeleton(label: l.netWorthTrendTitle, rows: 4)),
          error: (_, __) => BeeSurface(
              child: BeeStatus(
                  label: l.commonError,
                  tone: BeeTone.error,
                  action: BeeButton(
                      label: l.v4RecordingRetry,
                      compact: true,
                      onPressed: () => ref.invalidate(provider)))),
        ),
      ])),
    ]));
  }
}
