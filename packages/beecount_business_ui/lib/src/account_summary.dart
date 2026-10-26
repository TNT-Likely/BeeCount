import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'resource_components.dart';
import 'finance_components.dart';

class BeeAccountProperty {
  const BeeAccountProperty(
      {required this.label, required this.value, this.icon, this.onPressed});
  final String label, value;
  final Widget? icon;
  final VoidCallback? onPressed;
}

class BeeAccountSummaryCard extends StatelessWidget {
  const BeeAccountSummaryCard(
      {super.key,
      required this.title,
      required this.caption,
      required this.icon,
      required this.balanceLabel,
      required this.amount,
      required this.prefix,
      required this.currency,
      required this.properties,
      this.onPrivacy,
      this.privacyLabel,
      this.conversion,
      this.note});
  final String title, caption, balanceLabel, amount, prefix, currency;
  final Widget icon;
  final List<BeeAccountProperty> properties;
  final VoidCallback? onPrivacy;
  final String? privacyLabel, note;
  final Widget? conversion;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    return BeeSurface(
        padding: const EdgeInsets.fromLTRB(18, 19, 18, 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: BeeCardTheme.of(context).soft,
                    borderRadius: BorderRadius.circular(13)),
                alignment: Alignment.center,
                child: icon),
            const SizedBox(width: 11),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: muted))
                ]))
          ]),
          const SizedBox(height: 15),
          Row(children: [
            Text(balanceLabel, style: TextStyle(fontSize: 10, color: muted)),
            if (onPrivacy != null)
              SizedBox(
                  width: 30,
                  height: 30,
                  child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: privacyLabel,
                      onPressed: onPrivacy,
                      icon: BeeLineIcon('Eye', size: 14, color: muted))),
            const Spacer(),
            Text(currency, style: TextStyle(fontSize: 10, color: muted))
          ]),
          BeeMoney(
              amount: amount,
              prefix: prefix.isEmpty ? null : prefix,
              size: MediaQuery.sizeOf(context).width <= 380 ? 29 : 33,
              prefixSize: 18,
              lineHeight: 1.35),
          if (conversion != null) conversion!,
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < properties.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                    child: InkWell(
                        onTap: properties[i].onPressed,
                        splashFactory: NoSplash.splashFactory,
                        highlightColor: Colors.transparent,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(properties[i].label,
                                      style:
                                          TextStyle(fontSize: 9, color: muted)),
                                  const SizedBox(height: 5),
                                  Row(children: [
                                    if (properties[i].icon != null) ...[
                                      properties[i].icon!,
                                      const SizedBox(width: 3)
                                    ],
                                    Flexible(
                                        child: Text(properties[i].value,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500))),
                                    if (properties[i].onPressed != null)
                                      BeeLineIcon('ChevronRight',
                                          size: 10, color: muted)
                                  ])
                                ]))))
              ]
            ],
          ),
          if (note?.isNotEmpty == true)
            Text(note!,
                style: TextStyle(fontSize: 10, color: muted, height: 1.6)),
        ]));
  }
}

class BeeAccountCashflowCard extends StatelessWidget {
  const BeeAccountCashflowCard(
      {super.key,
      required this.title,
      required this.currency,
      required this.incomeLabel,
      required this.income,
      required this.expenseLabel,
      required this.expense,
      required this.netLabel,
      required this.net,
      required this.detailLabel,
      required this.onDetail,
      this.note,
      this.onNote});
  final String title,
      currency,
      incomeLabel,
      income,
      expenseLabel,
      expense,
      netLabel,
      net,
      detailLabel;
  final VoidCallback onDetail;
  final String? note;
  final VoidCallback? onNote;
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    Widget metric(String label, String value, Color? color) => Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 9, color: muted)),
          const SizedBox(height: 5),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: color)))
        ]));
    return BeeSurface(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text('$title  $currency',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600))),
            TextButton(
                onPressed: onDetail,
                child: Text(detailLabel,
                    style: TextStyle(fontSize: 10, color: muted)))
          ]),
          Row(children: [
            metric(incomeLabel, income, const Color(0xffbd5d50)),
            const SizedBox(width: 7),
            metric(expenseLabel, expense, const Color(0xff25856d)),
            const SizedBox(width: 7),
            metric(netLabel, net, null)
          ]),
          if (note != null)
            Padding(
                padding: const EdgeInsets.only(top: 9),
                child: InkWell(
                    onTap: onNote,
                    child: Text(note!,
                        style:
                            TextStyle(fontSize: 9, color: muted, height: 1.5))))
        ]));
  }
}

class BeeBalanceHistoryCard extends StatelessWidget {
  const BeeBalanceHistoryCard(
      {super.key,
      required this.title,
      required this.currency,
      required this.values,
      required this.axisLabels,
      required this.selectedLabel,
      required this.emptyLabel,
      this.onSelected,
      this.selectedIndex});
  final String title, currency, selectedLabel, emptyLabel;
  final List<double> values;
  final List<String> axisLabels;
  final ValueChanged<int>? onSelected;
  final int? selectedIndex;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600))),
          Text(currency,
              style:
                  TextStyle(fontSize: 10, color: Theme.of(context).hintColor))
        ]),
        Align(
            alignment: Alignment.centerRight,
            child: Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 8),
                child: Text(selectedLabel,
                    style: TextStyle(
                        fontSize: 10, color: Theme.of(context).hintColor)))),
        if (values.isEmpty)
          SizedBox(height: 115, child: Center(child: Text(emptyLabel)))
        else
          BeeResourceTrend(
              values: values,
              label: title,
              axisLabels: axisLabels,
              includeZero: false,
              selectedIndex: selectedIndex,
              onSelected: onSelected)
      ]));
}
