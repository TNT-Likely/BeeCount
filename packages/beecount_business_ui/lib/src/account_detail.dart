import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Credit and repayment presentation. The App supplies balances, dates and actions.
class BeeCreditCardTerms extends StatelessWidget {
  const BeeCreditCardTerms({
    super.key,
    this.usage,
    this.usageColor,
    this.estimateHint,
    this.billingLabel,
    this.paymentLabel,
    this.paymentColor,
    required this.repayLabel,
    required this.onRepay,
  });
  final double? usage;
  final Color? usageColor, paymentColor;
  final String? estimateHint, billingLabel, paymentLabel;
  final String repayLabel;
  final VoidCallback? onRepay;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    return BeeSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (usage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: usage!.clamp(0.0, 1.0),
                minHeight: 5,
                color: usageColor,
                backgroundColor: BeeCardTheme.of(context).soft,
              ),
            ),
            const SizedBox(height: 9),
          ],
          if (estimateHint != null) ...[
            Text(estimateHint!, style: TextStyle(fontSize: 11, color: muted)),
            const SizedBox(height: 12),
          ],
          if (billingLabel != null || paymentLabel != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BeeLineIcon('CalendarDays', size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (billingLabel != null)
                        Text(billingLabel!,
                            style: TextStyle(fontSize: 12, color: muted)),
                      if (paymentLabel != null) ...[
                        if (billingLabel != null) const SizedBox(height: 4),
                        Text(paymentLabel!,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: paymentColor)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
          ],
          BeeButton(
              label: repayLabel,
              icon: const BeeLineIcon('ArrowLeftRight', size: 18),
              kind: BeeButtonKind.secondary,
              onPressed: onRepay),
        ],
      ),
    );
  }
}
