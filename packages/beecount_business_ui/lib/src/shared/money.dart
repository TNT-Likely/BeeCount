import 'package:flutter/material.dart';

class BeeMoney extends StatelessWidget {
  const BeeMoney(
      {super.key,
      required this.amount,
      this.prefix,
      this.prefixSize,
      this.converted,
      this.hidden = false,
      this.size = 28,
      this.color,
      this.lineHeight,
      this.alignment = Alignment.centerRight});
  final Alignment alignment;
  final String amount;
  final String? prefix, converted;
  final bool hidden;
  final double size;
  final double? prefixSize;
  final double? lineHeight;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: alignment.x < 0
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: alignment,
                child: Text.rich(
                    TextSpan(children: [
                      if (!hidden && prefix != null)
                        TextSpan(
                            text: '$prefix ',
                            style: TextStyle(
                                fontSize: prefixSize ?? size * .6,
                                fontWeight: FontWeight.w400)),
                      TextSpan(text: hidden ? '••••' : amount)
                    ]),
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: size,
                        height: lineHeight,
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()]))),
            if (converted != null)
              Text(hidden ? '••••' : converted!,
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.55,
                      color: Theme.of(context).hintColor)),
          ]);
}
