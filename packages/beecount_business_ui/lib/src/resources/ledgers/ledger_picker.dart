import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeLedgerChoice {
  const BeeLedgerChoice(
      {required this.id,
      required this.name,
      required this.currency,
      this.detail});
  final String id, name, currency;
  final String? detail;
}

class BeeLedgerPicker extends StatelessWidget {
  const BeeLedgerPicker(
      {super.key,
      required this.ledgers,
      required this.currentId,
      required this.searchLabel,
      required this.emptyLabel,
      required this.currentLabel,
      required this.onSelected,
      this.createLabel,
      this.onCreate,
      this.joinLabel,
      this.onJoin});
  final List<BeeLedgerChoice> ledgers;
  final String? currentId;
  final String searchLabel, emptyLabel, currentLabel;
  final ValueChanged<String> onSelected;
  final String? createLabel, joinLabel;
  final VoidCallback? onCreate, onJoin;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
            child: BeeChoicePicker<String>(
                items: ledgers
                    .map((l) => BeeChoice(
                        value: l.id,
                        title: l.name,
                        subtitle: [
                          l.currency,
                          if (l.detail != null) l.detail!,
                          if (l.id == currentId) currentLabel
                        ].join(' · '),
                        leading: const BeeLineIcon('BookOpen')))
                    .toList(),
                selected: currentId,
                searchLabel: searchLabel,
                emptyLabel: emptyLabel,
                onSelected: onSelected)),
        if (onCreate != null && createLabel != null) ...[
          const SizedBox(height: 12),
          BeeButton(label: createLabel!, onPressed: onCreate)
        ],
        if (onJoin != null && joinLabel != null) ...[
          const SizedBox(height: 8),
          BeeButton(
              label: joinLabel!,
              kind: BeeButtonKind.secondary,
              onPressed: onJoin)
        ],
      ]);
}
