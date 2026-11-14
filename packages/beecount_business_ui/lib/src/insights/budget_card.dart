import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../shared/money.dart';

class BeeBudgetCard extends StatelessWidget {
  const BeeBudgetCard(
      {super.key,
      required this.title,
      required this.spentLabel,
      required this.spent,
      required this.remainingLabel,
      required this.remaining,
      required this.progress,
      required this.onTap,
      this.overBudget = false,
      this.warning});
  final String title, spentLabel, spent, remainingLabel, remaining;
  final double progress;
  final VoidCallback onTap;
  final bool overBudget;
  final String? warning;
  @override
  Widget build(BuildContext context) => BeeSurface(
      child: InkWell(
          onTap: onTap,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(spentLabel, style: const TextStyle(fontSize: 11)),
                    BeeMoney(amount: spent, size: 23)
                  ])),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                    Text(remainingLabel, style: const TextStyle(fontSize: 11)),
                    BeeMoney(amount: remaining, size: 23)
                  ]))
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(
                value: progress.isFinite ? progress.clamp(0, 1) : 0,
                color: overBudget
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4)),
            if (warning != null) ...[
              const SizedBox(height: 12),
              BeeStatus(
                  label: warning!,
                  tone: overBudget ? BeeTone.error : BeeTone.warning)
            ]
          ])));
}
