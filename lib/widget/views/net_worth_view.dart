import 'package:flutter/material.dart';

import '../../utils/account_type_utils.dart' show getIconForAccountType;
import '../../utils/currencies.dart' show getCurrencySymbol;
import '../../utils/format_money.dart' show formatMoneyCompact;
import '../widget_data_service.dart' show NetWorthAccountItem;
import '../widget_spec.dart' show HWSize;
import 'widget_view_style.dart';

/// Net worth, its history and the account balances in the selected ledger.
class NetWorthView extends StatelessWidget {
  const NetWorthView({
    super.key,
    required this.size,
    required this.netWorth,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.baseCurrency,
    required this.trend,
    this.topAccounts = const [],
    required this.themeColor,
    required this.redForIncome,
    required this.dark,
    required this.netWorthLabel,
    required this.totalAssetsLabel,
    required this.totalLiabilitiesLabel,
    this.noAccountsLabel = '暂无账户',
    this.rangeLabel = '',
    this.accountsLabel = '',
    this.hasAccounts,
    required this.width,
    required this.height,
  });

  final HWSize size;
  final double netWorth, totalAssets, totalLiabilities;
  final String baseCurrency;
  final List<({DateTime date, double assets, double liabilities, double net})>
      trend;
  final List<NetWorthAccountItem> topAccounts;
  final Color themeColor;
  final bool redForIncome, dark;

  /// Account details are optional for small and medium cards. A zero balance
  /// alone cannot distinguish an existing account from an empty ledger.
  final bool? hasAccounts;
  final String netWorthLabel, totalAssetsLabel, totalLiabilitiesLabel;
  final String noAccountsLabel, rangeLabel, accountsLabel;
  final double width, height;

  String _money(double value, [String? currency]) =>
      '${getCurrencySymbol(currency ?? baseCurrency)}${formatMoneyCompact(value)}';

  double? get _change {
    if (trend.length < 2 || trend.first.net.abs() < 0.01) return null;
    return (trend.last.net - trend.first.net) / trend.first.net.abs() * 100;
  }

  Widget _caption(String text) => Text(text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: widgetTextSecondary(dark)));

  Widget _hero(bool small) {
    final change = hasAccounts == false ? null : _change;
    final deltaColor = (change ?? 0) >= 0
        ? widgetIncomeColor(redForIncome, dark: dark)
        : widgetExpenseColor(redForIncome, dark: dark);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WidgetCardMoney(
            amount: _money(netWorth), dark: dark, fontSize: small ? 29 : 32),
        if (change != null) ...[
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(change >= 0 ? Icons.trending_up : Icons.trending_down,
                  size: 14, color: deltaColor),
              const SizedBox(width: 3),
              Text('${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [kWidgetTabularFeature],
                      color: deltaColor)),
              if (rangeLabel.isNotEmpty) _caption(' · $rangeLabel'),
            ]),
          ),
        ] else if (rangeLabel.isNotEmpty &&
            hasAccounts != false &&
            trend.length > 1)
          _caption(rangeLabel),
      ],
    );
  }

  Widget _metric(String label, double value) => Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _caption(label),
            const SizedBox(height: 3),
            WidgetCardMoney(amount: _money(value), dark: dark, fontSize: 18),
          ],
        ),
      );

  Widget _metrics() => Row(children: [
        _metric(totalAssetsLabel, totalAssets),
        const SizedBox(width: 10),
        _metric(totalLiabilitiesLabel, totalLiabilities),
      ]);

  Widget _account(NetWorthAccountItem item) {
    final amount = item.convertedBalance == null
        ? _money(item.balance, item.account.currency)
        : _money(item.convertedBalance!);
    return Row(children: [
      Icon(getIconForAccountType(item.account.type),
          size: 16, color: widgetTextSecondary(dark)),
      const SizedBox(width: 7),
      Expanded(
          child: Text(item.account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: widgetTextPrimary(dark)))),
      const SizedBox(width: 8),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * .43),
        child: WidgetCardMoney(
            amount: amount,
            dark: dark,
            fontSize: 15,
            alignment: Alignment.centerRight),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final small = size == HWSize.small;
    final medium = size == HWSize.medium;
    final showTrend = hasAccounts != false && trend.length >= 2;
    final chart = WidgetSparkline(
        values: [for (final p in trend) p.net],
        color: themeColor,
        strokeWidth: small ? 2 : 2.5);
    final separator = Container(height: 1, color: widgetDivider(dark));
    final empty = WidgetCardEmpty(
        icon: Icons.account_balance_wallet_outlined,
        label: noAccountsLabel,
        dark: dark,
        compact: small);

    return WidgetCardSurface(
      dark: dark,
      width: width,
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        WidgetCardHeading(
            icon: Icons.account_balance_wallet_outlined,
            title: netWorthLabel,
            dark: dark,
            meta: baseCurrency,
            compact: small),
        SizedBox(height: small ? 7 : 8),
        if (medium)
          Expanded(
              child: Row(children: [
            Expanded(flex: 3, child: _hero(false)),
            if (showTrend) ...[
              const SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: chart)),
            ],
          ]))
        else ...[
          _hero(small),
          const SizedBox(height: 6),
          if (showTrend || small)
            Expanded(
                child: showTrend
                    ? chart
                    : hasAccounts == false
                        ? empty
                        : const SizedBox.shrink()),
        ],
        if (!small) ...[
          const SizedBox(height: 8),
          separator,
          const SizedBox(height: 8),
          _metrics(),
        ],
        if (size == HWSize.large) ...[
          const SizedBox(height: 9),
          separator,
          const SizedBox(height: 8),
          if (topAccounts.isEmpty)
            if (showTrend)
              SizedBox(height: 48, child: empty)
            else
              Expanded(child: empty)
          else ...[
            if (accountsLabel.isNotEmpty) _caption(accountsLabel),
            for (final item in topAccounts.take(4))
              SizedBox(height: 29, child: _account(item)),
          ],
        ],
      ]),
    );
  }
}
