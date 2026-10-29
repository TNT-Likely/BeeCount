import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../resources/tags/tag.dart';
import '../shared/money.dart';
import '../transactions/transaction_presentation.dart';

/// Includes account/tag/note only when supplied: the host controls sharing privacy.
class BeeReceipt extends StatelessWidget {
  const BeeReceipt(
      {super.key,
      required this.title,
      required this.amount,
      required this.category,
      required this.date,
      required this.brand,
      this.account,
      this.ledger,
      this.note,
      this.tags = const [],
      this.converted});
  final String title, amount, category, date, brand;
  final String? account, ledger, note, converted;
  final List<BeeTagData> tags;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Center(child: BeeMoney(amount: amount, converted: converted, size: 34)),
        const SizedBox(height: 16),
        const Divider(),
        ...<String>[
          category,
          date,
          if (account != null) account!,
          if (ledger != null) ledger!,
          if (note != null) note!
        ].map((v) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(v, style: const TextStyle(fontSize: 13)))),
        if (tags.isNotEmpty)
          Wrap(spacing: 5, children: tags.map((t) => BeeTag(tag: t)).toList()),
        const SizedBox(height: 16),
        Text(brand,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
      ]));
}
