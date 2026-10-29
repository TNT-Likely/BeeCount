import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../shared/money.dart';

class BeeAnnualSummary extends StatelessWidget {
  const BeeAnnualSummary(
      {super.key,
      required this.year,
      required this.title,
      required this.amount,
      required this.metrics,
      required this.chart,
      required this.footer});
  final String year, title, amount, footer;
  final Map<String, String> metrics;
  final Widget chart;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(year,
            style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary)),
        Text(title, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 16),
        Align(
            alignment: Alignment.centerLeft,
            child: BeeMoney(amount: amount, size: 34)),
        const SizedBox(height: 20),
        Wrap(
            spacing: 20,
            runSpacing: 12,
            children: metrics.entries
                .map((e) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600)),
                          Text(e.key, style: const TextStyle(fontSize: 11))
                        ]))
                .toList()),
        const SizedBox(height: 20),
        chart,
        const SizedBox(height: 16),
        Text(footer,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
      ]));
}
