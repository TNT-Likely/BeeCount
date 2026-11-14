import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeHomeIdentity extends StatelessWidget {
  const BeeHomeIdentity(
      {super.key,
      required this.name,
      required this.ledger,
      required this.logo,
      required this.onLedgerTap,
      required this.actions,
      this.showBrand = true,
      this.pageTitle});
  final String name, ledger;
  final String? pageTitle;
  final Widget logo;
  final VoidCallback onLedgerTap;
  final List<Widget> actions;
  final bool showBrand;
  Widget _ledger(BuildContext context) => InkWell(
      onTap: onLedgerTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
            child: Text(ledger,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: showBrand ? 11 : 13,
                    color: Theme.of(context).hintColor))),
        const SizedBox(width: 5),
        BeeLineIcon('ChevronDown',
            size: 15, color: Theme.of(context).hintColor),
      ]));
  @override
  Widget build(BuildContext context) => Row(children: [
        if (showBrand) ...[
          SizedBox(width: 26, height: 32, child: logo),
          const SizedBox(width: 8)
        ],
        Expanded(
            child: showBrand
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        _ledger(context),
                      ])
                : Row(children: [
                    Flexible(
                        child: Text(pageTitle ?? name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Flexible(child: _ledger(context)),
                  ])),
        ...actions,
      ]);
}
