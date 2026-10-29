import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

class BeeBalanceAdjustmentOption {
  const BeeBalanceAdjustmentOption(
      {required this.createTransaction,
      required this.title,
      required this.description,
      required this.confirmLabel});
  final bool createTransaction;
  final String title, description, confirmLabel;
}

/// Amounts and allowed modes come from the app; this widget never changes money.
class BeeAccountBalanceAdjustment extends StatelessWidget {
  const BeeAccountBalanceAdjustment(
      {super.key,
      required this.currentLabel,
      required this.currentAmount,
      required this.targetLabel,
      required this.targetAmount,
      required this.differenceLabel,
      required this.differenceAmount,
      required this.differenceColor,
      required this.options,
      required this.createTransaction,
      required this.onModeChanged,
      required this.onConfirm});
  final String currentLabel, currentAmount, targetLabel, targetAmount;
  final String differenceLabel, differenceAmount;
  final Color differenceColor;
  final List<BeeBalanceAdjustmentOption> options;
  final bool createTransaction;
  final ValueChanged<bool> onModeChanged, onConfirm;

  @override
  Widget build(BuildContext context) {
    final option = options
        .singleWhere((item) => item.createTransaction == createTransaction);
    Widget amount(String label, String value, {bool target = false}) => Column(
            crossAxisAlignment:
                target ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).hintColor)),
              const SizedBox(height: 6),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: target
                              ? Theme.of(context).colorScheme.primary
                              : null)))
            ]);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      DecoratedBox(
          decoration: BoxDecoration(
              color: BeeCardTheme.of(context).soft,
              borderRadius: BorderRadius.circular(18)),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Expanded(child: amount(currentLabel, currentAmount)),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: BeeLineIcon('ArrowRight', size: 18)),
                  Expanded(
                      child: amount(targetLabel, targetAmount, target: true))
                ]),
                const Divider(height: 28),
                Row(children: [
                  Expanded(
                      child: Text(differenceLabel,
                          style: const TextStyle(fontSize: 12))),
                  Flexible(
                      child: Text(differenceAmount,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: differenceColor)))
                ])
              ]))),
      const SizedBox(height: 16),
      BeeSegmented<bool>(
          items: options
              .map((item) =>
                  BeeSegment<bool>(item.createTransaction, item.title))
              .toList(),
          value: createTransaction,
          onChanged: onModeChanged),
      const SizedBox(height: 12),
      Align(
          alignment: Alignment.centerLeft,
          child: Text(option.description,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Theme.of(context).hintColor))),
      const SizedBox(height: 20),
      BeeButton(
          label: option.confirmLabel,
          icon: const BeeLineIcon('Check', size: 18),
          onPressed: () => onConfirm(createTransaction))
    ]);
  }
}
