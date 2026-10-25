import 'package:flutter/material.dart';
import '../beecount_ui.dart';

/// A small optical track inside a full 40px tap target. Never scrolls sideways.
class BeeCompactTabs<T> extends StatelessWidget {
  const BeeCompactTabs({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.trackHeight = 31,
    this.fontSize = 12,
  });

  final List<BeeSegment<T>> items;
  final T value;
  final ValueChanged<T>? onChanged;
  final double trackHeight, fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = BeeCardTheme.of(context);
    return SizedBox(
      height: 40,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          key: const ValueKey('compact-tab-track'),
          height: trackHeight,
          decoration: BoxDecoration(
              color: colors.soft, borderRadius: BorderRadius.circular(11)),
        ),
        Row(children: [
          for (final item in items)
            Expanded(
              child: Semantics(
                selected: item.value == value,
                inMutuallyExclusiveGroup: true,
                child: Tooltip(
                  message: item.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: item.enabled && onChanged != null
                        ? () => onChanged!(item.value)
                        : null,
                    child: Center(
                      child: Container(
                        height: trackHeight - 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: item.value == value
                              ? colors.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: item.value == value
                              ? const [
                                  BoxShadow(
                                      color: Color(0x0b202a36),
                                      blurRadius: 4,
                                      offset: Offset(0, 1))
                                ]
                              : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Text(item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: fontSize,
                                color: item.value == value
                                    ? theme.colorScheme.onSurface
                                    : theme.hintColor)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}
