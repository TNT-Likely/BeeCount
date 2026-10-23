import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Formatted amounts and localized labels are provided by the App binding.
class BeeSearchSummary extends StatelessWidget {
  const BeeSearchSummary(
      {super.key,
      required this.title,
      required this.expenseLabel,
      required this.expense,
      required this.incomeLabel,
      required this.income,
      this.action});
  final String title, expenseLabel, expense, incomeLabel, income;
  final Widget? action;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600))),
          if (action != null) action!
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _Total(label: expenseLabel, amount: expense)),
          const SizedBox(width: 12),
          Expanded(child: _Total(label: incomeLabel, amount: income)),
        ]),
      ]));
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.amount});
  final String label, amount;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        const SizedBox(height: 6),
        Text(amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
      ]);
}

class BeeBatchSelection extends StatelessWidget {
  const BeeBatchSelection(
      {super.key,
      required this.label,
      required this.total,
      required this.actions});
  final String label, total;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 10,
            runSpacing: 5,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(total,
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).hintColor))
            ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: actions),
      ]));
}

class BeeBatchAction {
  const BeeBatchAction(
      {required this.label,
      required this.icon,
      required this.onPressed,
      this.danger = false});
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool danger;
}

/// Fixed at the host's safe bottom; its content does not scroll with results.
class BeeBatchActionBar extends StatelessWidget {
  const BeeBatchActionBar(
      {super.key, required this.actions, this.busy = false});
  final List<BeeBatchAction> actions;
  final bool busy;
  @override
  Widget build(BuildContext context) => Material(
      color: BeeCardTheme.of(context).surface,
      child: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (busy) const LinearProgressIndicator(minHeight: 2),
                Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: actions
                        .map((a) => Expanded(
                            child: TextButton(
                                onPressed: busy ? null : a.onPressed,
                                style: TextButton.styleFrom(
                                    foregroundColor: a.danger
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3, vertical: 8),
                                    minimumSize: const Size(44, 52)),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      a.icon,
                                      const SizedBox(height: 6),
                                      Text(a.label,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11))
                                    ]))))
                        .toList()),
              ]))));
}
