import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeAccountChoice {
  const BeeAccountChoice(
      {required this.id,
      required this.name,
      required this.currency,
      this.balance = '',
      this.detail,
      this.icon});
  final String id, name, currency, balance;
  final String? detail;
  final Widget? icon;
}

/// The host supplies permission-filtered resources and balances. No requests here.
class BeeAccountPicker extends StatelessWidget {
  const BeeAccountPicker(
      {super.key,
      required this.accounts,
      required this.currency,
      required this.selected,
      required this.searchLabel,
      required this.emptyLabel,
      required this.unsetLabel,
      required this.onSelected,
      this.filterByCurrency = true,
      this.allowUnset = true});
  final List<BeeAccountChoice> accounts;
  final bool filterByCurrency, allowUnset;
  final String currency, searchLabel, emptyLabel, unsetLabel;
  final String? selected;
  final ValueChanged<String?> onSelected;
  @override
  Widget build(BuildContext context) => BeeChoicePicker<String?>(
          items: [
            if (allowUnset) BeeChoice<String?>(value: null, title: unsetLabel),
            ...accounts
                .where((a) => !filterByCurrency || a.currency == currency)
                .map((a) => BeeChoice<String?>(
                    value: a.id,
                    title: a.name,
                    subtitle: [
                      a.currency,
                      if (a.balance.isNotEmpty) a.balance,
                      if (a.detail != null) a.detail!
                    ].join(' · '),
                    leading: a.icon ?? const BeeLineIcon('Wallet'),
                    searchText: a.currency))
          ],
          selected: selected,
          searchLabel: searchLabel,
          emptyLabel: emptyLabel,
          onSelected: onSelected);
}
