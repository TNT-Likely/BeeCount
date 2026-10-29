import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../shared/money.dart';

/// Current-ledger balance strip. Data and actions are supplied by the host.
class BeeLedgerBalance extends StatelessWidget {
  const BeeLedgerBalance(
      {super.key,
      required this.ledger,
      required this.amount,
      required this.stats,
      required this.onLedgerTap,
      required this.onPrivacyTap,
      required this.privacyLabel,
      this.balanceLabel,
      this.currencyLabel,
      this.days,
      this.count,
      this.daysLabel,
      this.countLabel,
      this.onCountTap,
      this.amountColor,
      this.prefix,
      this.hidden = false});
  final String ledger, amount, stats, privacyLabel;
  final String? balanceLabel,
      currencyLabel,
      days,
      count,
      daysLabel,
      countLabel,
      prefix;
  final VoidCallback onLedgerTap, onPrivacyTap;
  final VoidCallback? onCountTap;
  final bool hidden;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 300;
        final hint = Theme.of(context).hintColor;
        return BeeSurface(
            borderRadius: BorderRadius.circular(19),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                    child: InkWell(
                        onTap: onLedgerTap,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 30),
                            child: Row(children: [
                              const BeeLineIcon('BookOpen', size: 15),
                              const SizedBox(width: 6),
                              Flexible(
                                  child: Text(ledger,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                          fontWeight: FontWeight.w500))),
                              const SizedBox(width: 4),
                              BeeLineIcon('ChevronDown', size: 13, color: hint)
                            ])))),
                const SizedBox(width: 6),
                if (currencyLabel != null || balanceLabel != null)
                  Text(currencyLabel ?? balanceLabel!,
                      maxLines: 1,
                      style: TextStyle(fontSize: 10, height: 1.5, color: hint)),
                SizedBox(
                    width: 30,
                    height: 30,
                    child: IconButton(
                        tooltip: privacyLabel,
                        onPressed: onPrivacyTap,
                        padding: EdgeInsets.zero,
                        icon: BeeLineIcon(hidden ? 'EyeOff' : 'Eye', size: 15)))
              ]),
              const SizedBox(height: 1),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: BeeMoney(
                            amount: amount,
                            prefix: prefix,
                            prefixSize: 15,
                            color: amountColor,
                            hidden: hidden,
                            lineHeight: 1.2,
                            size: compact ? 25 : 27))),
                const SizedBox(width: 8),
                ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * .46),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (balanceLabel != null && currencyLabel != null)
                            Text(balanceLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 9, height: 1.5, color: hint)),
                          if (days != null && count != null)
                            FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _stat(context, days!, daysLabel ?? ''),
                                      Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: Text('·',
                                              style: TextStyle(
                                                  fontSize: 9, color: hint))),
                                      if (onCountTap == null)
                                        _stat(context, count!, countLabel ?? '')
                                      else
                                        InkWell(
                                            onTap: onCountTap,
                                            child: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                        minHeight: 24),
                                                child: Center(
                                                    child: _stat(
                                                        context,
                                                        count!,
                                                        countLabel ?? ''))))
                                    ]))
                          else
                            Text(stats,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: hint))
                        ]))
              ])
            ]));
      });

  Widget _stat(BuildContext context, String value, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 11, height: 1.5, fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    height: 1.5,
                    color: Theme.of(context).hintColor))
          ]);
}
