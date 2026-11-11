import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../shared/money.dart';
import '../shared/summary_metric.dart';

/// Category icon and content remain independent hit targets.

class BeeSummaryCard extends StatelessWidget {
  const BeeSummaryCard(
      {super.key,
      required this.title,
      required this.amount,
      required this.incomeLabel,
      required this.income,
      required this.expenseLabel,
      required this.expense,
      this.amountLabel,
      this.currencyLabel,
      this.prefix,
      this.budget,
      this.compact = false,
      this.budgetIndicator,
      this.background,
      this.hidden = false,
      this.onContextTap,
      this.onPrivacyTap,
      this.privacyLabel});
  final String title, amount, incomeLabel, income, expenseLabel, expense;
  final String? amountLabel, currencyLabel, prefix, privacyLabel;
  final Widget? budget, background, budgetIndicator;
  final bool compact;
  final bool hidden;
  final VoidCallback? onContextTap, onPrivacyTap;
  @override
  Widget build(BuildContext context) => compact
      ? _compact(context)
      : BeeSurface(
          background: background,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 27),
                child: Row(children: [
                  Expanded(
                      child: InkWell(
                          onTap: onContextTap,
                          child: Row(children: [
                            Flexible(
                                child: Text(title,
                                    style: const TextStyle(fontSize: 13))),
                            if (onContextTap != null) ...[
                              const SizedBox(width: 5),
                              const BeeLineIcon('ChevronDown', size: 14)
                            ]
                          ]))),
                  if (currencyLabel != null)
                    Text(currencyLabel!,
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).hintColor))
                ])),
            const SizedBox(height: 13),
            if (amountLabel != null)
              Row(children: [
                Text(amountLabel!,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).hintColor)),
                if (onPrivacyTap != null)
                  SizedBox(
                      width: 30,
                      height: 26,
                      child: Semantics(
                          button: true,
                          label: privacyLabel,
                          excludeSemantics: true,
                          onTap: onPrivacyTap,
                          child: IconButton(
                              tooltip: privacyLabel,
                              style: IconButton.styleFrom(
                                  padding: EdgeInsets.zero),
                              onPressed: onPrivacyTap,
                              icon: BeeLineIcon(hidden ? 'EyeOff' : 'Eye',
                                  size: 14,
                                  color: Theme.of(context).hintColor))))
              ]),
            const SizedBox(height: 6),
            Align(
                alignment: Alignment.centerLeft,
                child: BeeMoney(
                    amount: amount,
                    prefix: prefix,
                    hidden: hidden,
                    size: 36,
                    lineHeight: 1.3)),
            const SizedBox(height: 17),
            Row(children: [
              Expanded(
                  child: SummaryMetric(incomeLabel, hidden ? '••••' : income,
                      size: 15, labelSize: 11, gap: 4, lineHeight: 1.5)),
              const SizedBox(width: 10),
              Expanded(
                  child: SummaryMetric(expenseLabel, hidden ? '••••' : expense,
                      size: 15,
                      labelSize: 11,
                      gap: 4,
                      lineHeight: 1.5,
                      alignEnd: true))
            ]),
            if (budget != null) ...[
              const SizedBox(height: 17),
              Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor,
                  thickness: .6),
              const SizedBox(height: 15),
              budget!
            ],
          ]));

  Widget _compact(BuildContext context) => BeeSurface(
      background: background,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 17),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(children: [
              Expanded(
                  child: InkWell(
                      onTap: onContextTap,
                      child: Row(children: [
                        Flexible(
                            child: Text(title,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).hintColor))),
                        if (onContextTap != null) ...[
                          const SizedBox(width: 5),
                          BeeLineIcon('ChevronDown',
                              size: 13, color: Theme.of(context).hintColor)
                        ]
                      ]))),
              if (currencyLabel != null)
                Text(currencyLabel!,
                    style: TextStyle(
                        fontSize: 10, color: Theme.of(context).hintColor)),
              if (onPrivacyTap != null)
                SizedBox(
                    width: 30,
                    height: 30,
                    child: Semantics(
                        button: true,
                        label: privacyLabel,
                        excludeSemantics: true,
                        onTap: onPrivacyTap,
                        child: IconButton(
                            tooltip: privacyLabel,
                            style:
                                IconButton.styleFrom(padding: EdgeInsets.zero),
                            onPressed: onPrivacyTap,
                            icon: BeeLineIcon(hidden ? 'EyeOff' : 'Eye',
                                size: 15, color: Theme.of(context).hintColor))))
            ])),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                if (amountLabel != null)
                  Text(amountLabel!,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: Theme.of(context).hintColor)),
                const SizedBox(height: 5),
                BeeMoney(
                    amount: amount,
                    prefix: prefix,
                    hidden: hidden,
                    size: 34,
                    prefixSize: 16,
                    lineHeight: 1.3,
                    alignment: Alignment.centerLeft)
              ])),
          if (budgetIndicator != null) ...[
            const SizedBox(width: 13),
            budgetIndicator!
          ]
        ]),
        // Keep the approved spacing after removing the visual divider.
        const SizedBox(height: 29),
        Row(children: [
          Expanded(
              child: SummaryMetric(incomeLabel, hidden ? '••••' : income,
                  size: 18,
                  labelSize: 11,
                  gap: 5,
                  lineHeight: 1.35,
                  fitValue: true)),
          const SizedBox(width: 18),
          Expanded(
              child: SummaryMetric(expenseLabel, hidden ? '••••' : expense,
                  size: 18,
                  labelSize: 11,
                  gap: 5,
                  lineHeight: 1.35,
                  fitValue: true,
                  alignEnd: true))
        ])
      ]));
}
