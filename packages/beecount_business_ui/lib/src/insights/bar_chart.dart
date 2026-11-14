import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeChartBar {
  const BeeChartBar(this.label, this.value);
  final String label;
  final double value;
}

class BeeBarChart extends StatelessWidget {
  const BeeBarChart(
      {super.key,
      required this.items,
      required this.valueLabel,
      this.onSelected,
      this.selected});
  final List<BeeChartBar> items;
  final String Function(double) valueLabel;
  final ValueChanged<int>? onSelected;
  final int? selected;
  @override
  Widget build(BuildContext context) {
    final max = items.fold<double>(
        0, (v, i) => i.value.isFinite && i.value > v ? i.value : v);
    return SizedBox(
        height: 130 + MediaQuery.textScalerOf(context).scale(30),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: items.asMap().entries.map((e) {
              final fraction =
                  max <= 0 ? 0.0 : (e.value.value / max).clamp(0.0, 1.0);
              return Expanded(
                  child: Semantics(
                      label: '${e.value.label} ${valueLabel(e.value.value)}',
                      selected: selected == e.key,
                      child: InkWell(
                          onTap: onSelected == null
                              ? null
                              : () => onSelected!(e.key),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(valueLabel(e.value.value),
                                    style: const TextStyle(fontSize: 10)),
                                const SizedBox(height: 4),
                                Container(
                                    height: 100 * fraction + 2,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    decoration: BoxDecoration(
                                        color: selected == null ||
                                                selected == e.key
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : BeeCardTheme.of(context).soft,
                                        borderRadius:
                                            BorderRadius.circular(5))),
                                const SizedBox(height: 5),
                                Text(e.value.label,
                                    style: const TextStyle(fontSize: 10))
                              ]))));
            }).toList()));
  }
}
