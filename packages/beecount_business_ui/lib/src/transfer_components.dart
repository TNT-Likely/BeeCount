import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeTransferAccountPair extends StatelessWidget {
  const BeeTransferAccountPair(
      {super.key,
      required this.fromLabel,
      required this.toLabel,
      required this.fromName,
      required this.toName,
      this.onFrom,
      this.onTo,
      this.fromDetail,
      this.toDetail,
      this.fromIcon,
      this.toIcon});
  final String fromLabel, toLabel, fromName, toName;
  final VoidCallback? onFrom, onTo;
  final String? fromDetail, toDetail;
  final Widget? fromIcon, toIcon;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(children: [
        BeeMenuRow(
            title: fromName,
            subtitle:
                [fromLabel, if (fromDetail != null) fromDetail!].join(' · '),
            leading: fromIcon ?? const BeeLineIcon('Wallet', size: 21),
            onTap: onFrom),
        Row(children: [
          const SizedBox(width: 14),
          const BeeLineIcon('ArrowDown', size: 16),
          const SizedBox(width: 18),
          Expanded(
              child: Divider(color: Theme.of(context).dividerColor, height: 1))
        ]),
        BeeMenuRow(
            title: toName,
            subtitle: [toLabel, if (toDetail != null) toDetail!].join(' · '),
            leading: toIcon ?? const BeeLineIcon('Wallet', size: 21),
            onTap: onTo),
      ]));
}
