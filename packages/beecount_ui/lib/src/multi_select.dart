import 'package:flutter/material.dart';
import '../beecount_ui.dart';

class BeeMultiSelectOption<T> {
  const BeeMultiSelectOption(
      {required this.value, required this.label, this.key});
  final T value;
  final String label;
  final Key? key;
}

/// Controlled set selection composed from the shared choice-chip visual.
class BeeMultiSelect<T> extends StatelessWidget {
  const BeeMultiSelect(
      {super.key,
      required this.selectedValues,
      required this.options,
      required this.onChanged});
  final Set<T> selectedValues;
  final List<BeeMultiSelectOption<T>> options;
  final ValueChanged<Set<T>>? onChanged;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 6, children: [
        for (final option in options)
          BeeChoiceChip(
              key: option.key,
              label: option.label,
              selected: selectedValues.contains(option.value),
              onSelected: onChanged == null
                  ? null
                  : (selected) {
                      final next = Set<T>.of(selectedValues);
                      selected
                          ? next.add(option.value)
                          : next.remove(option.value);
                      onChanged!(Set<T>.unmodifiable(next));
                    }),
      ]);
}
