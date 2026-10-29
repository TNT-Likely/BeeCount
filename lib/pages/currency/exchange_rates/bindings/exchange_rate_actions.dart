import 'dart:async';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers.dart';
import '../../../../services/billing/post_processor.dart';
import '../../../../services/currency/rate_math.dart';
import '../../../shared/selectors/currency_picker_sheet.dart';
import 'exchange_rate_editor.dart';

String formatExchangeRate(String rate) =>
    double.tryParse(rate)?.toStringAsPrecision(6) ?? rate;
bool exchangeRateIsStale(String? date, {DateTime? now}) {
  final parsed = date == null ? null : DateTime.tryParse(date);
  return parsed != null &&
      (now ?? DateTime.now()).difference(parsed) > const Duration(days: 7);
}

mixin ExchangeRateActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool ratesRefreshing = false;
  Future<void> refreshRates() async {
    if (ratesRefreshing) return;
    setState(() => ratesRefreshing = true);
    final ok = await refreshExchangeRatesFromUi(ref, force: true);
    if (!mounted) return;
    setState(() => ratesRefreshing = false);
    final l = AppLocalizations.of(context);
    showBeeToast(context, ok ? l.rateRefreshSuccess : l.rateRefreshFailed,
        tone: ok ? BeeTone.success : BeeTone.error);
  }

  Future<void> pickRateBase() async {
    final selected = await showCurrencyPickerSheet(context,
        selected: ref.read(baseCurrencyProvider).toUpperCase(),
        primaryColor: ref.read(primaryColorProvider));
    if (selected == null || !mounted) return;
    await applyBaseCurrencySelection(context, ref, selected);
  }

  Future<void> editRate(String quote, String base, EffectiveRate? rate) async {
    final result = await showDialog<ExchangeRateDraft>(
        context: context,
        builder: (_) => ExchangeRateEditor(
            quote: quote,
            base: base,
            hadManual: rate?.manual ?? false,
            initialText: rate == null
                ? ''
                : rate.manual
                    ? rate.rate
                    : formatExchangeRate(rate.rate)));
    if (result == null || !mounted) return;
    try {
      final repo = ref.read(repositoryProvider);
      if (result.reset) {
        await repo.removeOverride(base: base, quote: quote);
      } else {
        await repo.setOverride(base: base, quote: quote, rate: result.rate);
      }
      if (!mounted) return;
      ref.read(rateRefreshTickProvider.notifier).state++;
      final ledger = ref.read(currentLedgerIdProvider);
      if (ledger > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: ledger));
      }
    } catch (_) {
      if (mounted) {
        showBeeToast(context, AppLocalizations.of(context).commonError,
            tone: BeeTone.error);
      }
    }
  }
}
