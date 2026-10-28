import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Controlled account-transaction filter. Queries and apply/cancel remain App-owned.
class BeeAccountFlowFilter extends StatelessWidget {
  const BeeAccountFlowFilter(
      {super.key,
      required this.flow,
      required this.flows,
      required this.sort,
      required this.sortLabel,
      required this.sorts,
      required this.onFlowChanged,
      required this.onSortChanged,
      required this.confirmLabel,
      required this.onConfirm});
  final String flow, sort, sortLabel, confirmLabel;
  final List<BeeSegment<String>> flows, sorts;
  final ValueChanged<String> onFlowChanged, onSortChanged;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BeeCompactTabs<String>(
                value: flow,
                items: flows,
                onChanged: onFlowChanged,
                trackHeight: 32,
                tapHeight: 44),
            const SizedBox(height: 12),
            BeeSelectField<String>(
                label: sortLabel,
                items: sorts,
                value: sort,
                onChanged: (v) {
                  if (v != null) onSortChanged(v);
                }),
            const SizedBox(height: 16),
            BeeButton(label: confirmLabel, onPressed: onConfirm),
          ]);
}
