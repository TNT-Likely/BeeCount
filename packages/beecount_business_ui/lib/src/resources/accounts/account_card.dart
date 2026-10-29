import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../shared/money.dart';

class BeeAccountCard extends StatelessWidget {
  const BeeAccountCard(
      {super.key,
      required this.name,
      required this.currency,
      required this.balance,
      required this.kind,
      required this.icon,
      required this.onTap,
      required this.menuLabel,
      required this.actions,
      required this.onAction,
      this.hidden = false,
      this.footer,
      this.excludedLabel,
      this.liabilityLabel});
  final String name, currency, balance, kind, menuLabel;
  final Widget icon;
  final Widget? footer;
  final VoidCallback onTap;
  final bool hidden;
  final String? excludedLabel, liabilityLabel;
  final List<BeeMenuAction<String>> actions;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: BeeSurface(
          child: Column(children: [
        Row(children: [
          ExcludeSemantics(child: icon),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                Text('$kind · $currency',
                    style: TextStyle(
                        fontSize: 11, color: Theme.of(context).hintColor))
              ])),
          Semantics(
              container: true,
              child: BeeMenuButton<String>(
                  label: menuLabel, items: actions, onSelected: onAction))
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: BeeMoney(amount: balance, hidden: hidden, size: 26))),
          if (liabilityLabel != null)
            Text(liabilityLabel!,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).colorScheme.error))
        ]),
        if (footer != null) ...[const SizedBox(height: 12), footer!],
        if (excludedLabel != null) ...[
          const SizedBox(height: 8),
          Align(
              alignment: Alignment.centerLeft,
              child: Text(excludedLabel!,
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).hintColor)))
        ]
      ])));
}
