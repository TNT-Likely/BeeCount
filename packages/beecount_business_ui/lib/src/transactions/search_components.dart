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
      this.actionLabel,
      this.onAction});
  final String title, expenseLabel, expense, incomeLabel, income;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: const EdgeInsets.all(17),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600))),
              if (actionLabel != null)
                SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(26),
                    child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).hintColor,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 26),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: Text(actionLabel!,
                            style: const TextStyle(fontSize: 11, height: 1.5))))
            ]),
            const SizedBox(height: 13),
            const Divider(height: 1, thickness: 1),
            const SizedBox(height: 14),
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
        SizedBox(
            height: MediaQuery.textScalerOf(context).scale(21),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: Theme.of(context).hintColor)))),
        const SizedBox(height: 5),
        Text(amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 19,
                height: 1.5,
                letterSpacing: -.4,
                fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.all(17),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 10,
                runSpacing: 5,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
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
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 0, 17, 12),
          child: Material(
              color: BeeCardTheme.of(context).surface,
              borderRadius: BorderRadius.circular(17),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
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
                                            ? Theme.of(context)
                                                .colorScheme
                                                .error
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
                                              style:
                                                  const TextStyle(fontSize: 11))
                                        ]))))
                            .toList()),
                  ])))));
}
