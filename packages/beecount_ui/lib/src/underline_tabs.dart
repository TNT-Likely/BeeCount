import 'package:flutter/material.dart';
import '../beecount_ui.dart' show BeeSegment;

/// Explicit compact choices with a small underline and full-height tap targets.
/// Wraps at large font sizes; it never introduces horizontal swipe navigation.
class BeeUnderlineTabs<T> extends StatelessWidget {
  const BeeUnderlineTabs(
      {super.key,
      required this.items,
      required this.value,
      required this.onChanged,
      this.fontSize = 13});
  final List<BeeSegment<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  final double fontSize;
  @override
  Widget build(BuildContext context) => Wrap(
      spacing: 17,
      runSpacing: 2,
      children: items
          .map((item) => Semantics(
              selected: item.value == value,
              inMutuallyExclusiveGroup: true,
              child: Tooltip(
                  message: item.label,
                  child: InkWell(
                      splashFactory: NoSplash.splashFactory,
                      highlightColor: Colors.transparent,
                      onTap: item.enabled ? () => onChanged(item.value) : null,
                      borderRadius: BorderRadius.circular(7),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 40),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Padding(
                                padding:
                                    const EdgeInsets.only(top: 9, bottom: 7),
                                child: Text(item.label,
                                    style: TextStyle(
                                        fontSize: fontSize,
                                        color: item.value == value
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                            : Theme.of(context).hintColor,
                                        fontWeight: item.value == value
                                            ? FontWeight.w600
                                            : FontWeight.w400))),
                            Container(
                                width: 13,
                                height: 3,
                                decoration: BoxDecoration(
                                    color: item.value == value
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(2)))
                          ]))))))
          .toList());
}
