import 'package:flutter/material.dart';

/// Internal shared financial metric; not part of a public package barrel.
class SummaryMetric extends StatelessWidget {
  const SummaryMetric(this.label, this.value,
      {super.key,
      this.size = 12,
      this.labelSize = 10,
      this.gap = 3,
      this.lineHeight,
      this.fitValue = false,
      this.alignEnd = false});
  final String label, value;
  final double size, labelSize, gap;
  final double? lineHeight;
  final bool alignEnd, fitValue;
  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment:
              alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(label,
                textAlign: alignEnd ? TextAlign.end : TextAlign.start,
                style: TextStyle(
                    fontSize: labelSize,
                    height: lineHeight,
                    color: Theme.of(context).hintColor)),
            SizedBox(height: gap),
            if (fitValue)
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment:
                      alignEnd ? Alignment.centerRight : Alignment.centerLeft,
                  child: _value())
            else
              _value()
          ]);

  Widget _value() => Text(value,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: TextStyle(
          fontSize: size, height: lineHeight, fontWeight: FontWeight.w600));
}
