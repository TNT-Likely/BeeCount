import 'package:beecount_business_ui/detail_currency.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'detail_currency_totals.dart';

Widget detailCurrencyNotice(
    BuildContext context, DetailCurrencyProjection projection) {
  final l = AppLocalizations.of(context), date = projection.oldestRateDate;
  final stale = projection.isStaleAt(DateTime.now());
  final missing = projection.missingCurrencies
      .map((code) => code == '?' ? l.billCardUnknownLedger : code)
      .join(' / ');
  return BeeDetailCurrencyNotice(
    scopeLabel: l.v4DetailConvertedScope(projection.targetCurrency ?? '—'),
    missingLabel: projection.missingCount == 0
        ? null
        : l.v4DetailMissingConversion(projection.missingCount, missing),
    rateDateLabel: date == null
        ? null
        : stale
            ? l.v4DetailRatesStale(date)
            : l.v4DetailRateDate(date),
    stale: stale,
  );
}
