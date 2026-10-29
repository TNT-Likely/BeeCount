import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../shared/money.dart';

class BeeBatchBar extends StatelessWidget {
  const BeeBatchBar(
      {super.key,
      required this.selectionLabel,
      required this.total,
      required this.actions});
  final String selectionLabel, total;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child: Column(children: [
        Row(children: [
          Expanded(
              child:
                  Text(selectionLabel, style: const TextStyle(fontSize: 13))),
          BeeMoney(amount: total, size: 16)
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: actions)
      ]));
}
