import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'asset_cards.dart';
import '../shared/money.dart';
export 'asset_cards.dart';

/// The host formats every amount using the original currency, compact and
/// historical-rate rules. No calculation or request belongs in these models.
class BeeAssetAmount {
  const BeeAssetAmount(this.text, {this.approximate = false});
  final String text;
  final bool approximate;
}

class BeeAssetSummary extends StatelessWidget {
  const BeeAssetSummary({
    super.key,
    required this.title,
    required this.balances,
    required this.assetsLabel,
    required this.assets,
    required this.liabilitiesLabel,
    required this.liabilities,
    required this.hidden,
    required this.privacyLabel,
    required this.onPrivacy,
    this.detailLabel,
    this.onDetails,
    this.compact = false,
    this.unitLabel,
    this.onUnit,
    this.currencies = const [],
    this.currency,
    this.onCurrency,
    this.footnote,
    this.onFootnote,
    this.warning = false,
  });
  final String title, assetsLabel, liabilitiesLabel, privacyLabel;
  final List<BeeAssetAmount> balances;
  final List<String> assets, liabilities;
  final bool hidden;
  final VoidCallback onPrivacy;
  final String? detailLabel;
  final VoidCallback? onDetails;
  final bool compact, warning;
  final String? unitLabel, currency, footnote;
  final VoidCallback? onUnit, onFootnote;
  final List<BeeSegment<String>> currencies;
  final ValueChanged<String>? onCurrency;

  @override
  Widget build(BuildContext context) => compact
      ? BeeAssetOverviewCard(
          title: title,
          balance: balances.first.text,
          approximate: balances.first.approximate,
          assetsLabel: assetsLabel,
          assets: assets.firstOrNull ?? '0',
          liabilitiesLabel: liabilitiesLabel,
          liabilities: liabilities.firstOrNull ?? '0',
          hidden: hidden,
          privacyLabel: privacyLabel,
          onPrivacy: onPrivacy,
          unitLabel: unitLabel,
          onUnit: onUnit,
          currencies: currencies,
          currency: currency,
          onCurrency: onCurrency,
          footnote: footnote,
          onFootnote: onFootnote,
          detailLabel: detailLabel,
          onDetails: onDetails,
          warning: warning)
      : BeeSurface(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(title,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).hintColor))),
                  BeeIconButton(
                      label: privacyLabel,
                      icon: BeeLineIcon(hidden ? 'EyeOff' : 'Eye', size: 17),
                      onPressed: onPrivacy),
                  if (onDetails != null && detailLabel != null)
                    BeeIconButton(
                        label: detailLabel!,
                        icon: const BeeLineIcon('ChevronRight', size: 17),
                        onPressed: onDetails),
                ]),
                for (var i = 0; i < balances.length; i++)
                  Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 2 : 6),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: BeeMoney(
                              amount: balances[i].text,
                              hidden: hidden,
                              prefix: balances[i].approximate ? '≈' : null,
                              prefixSize: 19,
                              size: i == 0 ? 34 : 24,
                              lineHeight: 1.4))),
                const SizedBox(height: 20),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _metric(context, assetsLabel, assets)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _metric(context, liabilitiesLabel, liabilities)),
                ]),
              ]));

  Widget _metric(BuildContext context, String label, List<String> amounts) =>
      Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor)),
            const SizedBox(height: 5),
            for (final value in amounts)
              Align(
                  alignment: Alignment.centerLeft,
                  child: BeeMoney(
                      amount: value,
                      hidden: hidden,
                      size: 16,
                      lineHeight: 1.5)),
          ]);
}

/// Chart data, loading/error state and the detail route are supplied by the App.
class BeeAssetChartSection<T> extends StatelessWidget {
  const BeeAssetChartSection({
    super.key,
    required this.title,
    required this.child,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.detailLabel,
    this.onDetails,
    this.compact = false,
  });
  final String title;
  final bool compact;
  final Widget child;
  final List<BeeSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;
  final String? detailLabel;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) => compact
      ? BeeSurface(
          padding: const EdgeInsets.fromLTRB(17, 12, 17, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600))),
              if (segments.length > 1)
                SizedBox(
                    width: 128,
                    child: BeeCompactTabs<T>(
                        items: segments,
                        value: selected,
                        onChanged: onSelected,
                        trackHeight: 28,
                        fontSize: 10))
            ]),
            child,
          ]))
      : BeeSurface(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600))),
            if (onDetails != null && detailLabel != null)
              BeeButton(
                  label: detailLabel!,
                  kind: BeeButtonKind.quiet,
                  compact: true,
                  onPressed: onDetails),
          ]),
          if (segments.length > 1) ...[
            const SizedBox(height: 12),
            BeeSegmented<T>(
                items: segments, value: selected, onChanged: onSelected),
          ],
          const SizedBox(height: 12),
          child,
        ]));
}

/// A controlled settings body. Default-account selection and persistence remain
/// in the host; the rate entry follows the host's actual multi-currency gate.
class BeeAccountPreferences extends StatelessWidget {
  const BeeAccountPreferences({
    super.key,
    required this.enabled,
    required this.enableLabel,
    required this.onEnabled,
    required this.expenseLabel,
    required this.expenseAccount,
    required this.onExpenseAccount,
    required this.incomeLabel,
    required this.incomeAccount,
    required this.onIncomeAccount,
    this.rateLabel,
    this.onRates,
    this.showDefaults = true,
  });
  final bool enabled, showDefaults;
  final String enableLabel,
      expenseLabel,
      expenseAccount,
      incomeLabel,
      incomeAccount;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onExpenseAccount, onIncomeAccount;
  final String? rateLabel;
  final VoidCallback? onRates;

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        BeeToggleRow(title: enableLabel, value: enabled, onChanged: onEnabled),
        if (onRates != null && rateLabel != null)
          BeeMenuRow(title: rateLabel!, onTap: onRates),
        if (enabled && showDefaults) ...[
          const Divider(height: 1),
          BeeMenuRow(
              title: expenseLabel,
              subtitle: expenseAccount,
              onTap: onExpenseAccount),
          const Divider(height: 1),
          BeeMenuRow(
              title: incomeLabel,
              subtitle: incomeAccount,
              onTap: onIncomeAccount),
        ],
      ]);
}

/// Original/converted amounts and missing-rate status are supplied separately;
/// the row must never invent a rate or change the sign of an amount.
class BeeAccountConversionRow extends StatelessWidget {
  const BeeAccountConversionRow({
    super.key,
    required this.code,
    required this.currencyName,
    required this.original,
    required this.hidden,
    this.converted,
    this.missingLabel,
  });
  final String code, currencyName, original;
  final String? converted, missingLabel;
  final bool hidden;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 2,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(code,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(currencyName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).hintColor)),
                ])),
        const SizedBox(width: 12),
        Expanded(
            flex: 3,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeeMoney(amount: original, hidden: hidden, size: 14),
                  if (missingLabel != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(missingLabel!,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xffaa8b29))))
                  else if (converted != null)
                    Text(hidden ? '••••' : converted!,
                        maxLines: 2,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).hintColor)),
                ])),
      ]));
}
