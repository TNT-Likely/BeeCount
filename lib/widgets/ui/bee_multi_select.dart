import 'package:flutter/material.dart';

import '../../styles/tokens.dart';

class BeeMultiSelectOption<T> {
  final T value;
  final String label;
  final Key? key;
  const BeeMultiSelectOption(
      {required this.value, required this.label, this.key});
}

/// Independent, wrapping capsules for selecting any number of options.
/// Matches CapsuleSwitcher: black selection by day, theme color by night.
class BeeMultiSelect<T> extends StatelessWidget {
  final Set<T> selectedValues;
  final List<BeeMultiSelectOption<T>> options;
  final ValueChanged<Set<T>>? onChanged;

  const BeeMultiSelect(
      {super.key,
      required this.selectedValues,
      required this.options,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final selectedBg =
        BeeTokens.isDark(context) ? BeeTokens.primary(context) : Colors.black;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return Wrap(spacing: 8, runSpacing: 6, children: [
      for (final option in options)
        Builder(builder: (_) {
          final selected = selectedValues.contains(option.value);
          final fg = selected
              ? BeeTokens.textOnColor(selectedBg)
              : BeeTokens.textSecondary(context);
          return Semantics(
            key: option.key,
            button: true,
            checked: selected,
            enabled: onChanged != null,
            child: Opacity(
              opacity: onChanged == null ? .5 : 1,
              child: AnimatedContainer(
                duration: duration,
                decoration: BoxDecoration(
                    color: selected
                        ? selectedBg
                        : BeeTokens.surfaceCapsule(context),
                    borderRadius: BorderRadius.circular(24)),
                child: Material(
                  type: MaterialType.transparency,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onChanged == null
                        ? null
                        : () {
                            final next = Set<T>.of(selectedValues);
                            selected
                                ? next.remove(option.value)
                                : next.add(option.value);
                            onChanged!(Set<T>.unmodifiable(next));
                          },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 9),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                                selected
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                size: 15,
                                color: fg),
                            const SizedBox(width: 5),
                            Text(option.label,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: fg)),
                          ])),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
    ]);
  }
}
