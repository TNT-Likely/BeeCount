import 'package:flutter/material.dart';
import '../../styles/colors.dart';
import 'format_money.dart';

class AmountText extends StatelessWidget {
  final double value;
  final bool hide;
  final bool signed; // 是否显示正负号
  final int decimals;
  final TextStyle? style;
  const AmountText(
      {super.key,
      required this.value,
      this.hide = false,
      this.signed = true,
      this.decimals = 2,
      this.style});

  @override
  Widget build(BuildContext context) {
    if (hide) {
      return Text('****',
          style: style ??
              Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: BeeColors.primaryText));
    }
    final s = formatMoneyCompact(value, maxDecimals: decimals, signed: signed);
    return Text(
      s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: style ??
          Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: BeeColors.primaryText),
    );
  }
}
