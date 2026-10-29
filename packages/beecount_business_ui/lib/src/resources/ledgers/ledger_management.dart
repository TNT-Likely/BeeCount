import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../shared/action_menu.dart';

/// Controlled ledger metadata. Values remain drafts until the App confirms.
class BeeLedgerEditorForm extends StatelessWidget {
  const BeeLedgerEditorForm({
    super.key,
    required this.nameController,
    required this.nameLabel,
    required this.currencyLabel,
    required this.currency,
    required this.periodLabel,
    required this.period,
    required this.onCurrency,
    required this.onPeriod,
    this.nameError,
    this.onNameChanged,
  });
  final TextEditingController nameController;
  final String nameLabel, currencyLabel, currency, periodLabel, period;
  final String? nameError;
  final VoidCallback onCurrency, onPeriod;
  final ValueChanged<String>? onNameChanged;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BeeField(
                controller: nameController,
                label: nameLabel,
                error: nameError,
                onChanged: onNameChanged,
                textInputAction: TextInputAction.done),
            const SizedBox(height: 12),
            BeeMenuRow(
                title: currencyLabel,
                subtitle: currency,
                leading: const BeeLineIcon('Coins', size: 20),
                onTap: onCurrency),
            const Divider(height: 1),
            BeeMenuRow(
                title: periodLabel,
                subtitle: period,
                leading: const BeeLineIcon('CalendarDays', size: 20),
                onTap: onPeriod),
          ]);
}

/// The existing ledger cycle permits days 1–28. It is deliberately distinct
/// from a transaction date wheel; the App supplies localized hints and labels.
class BeeMonthStartDayGrid extends StatelessWidget {
  const BeeMonthStartDayGrid({
    super.key,
    required this.value,
    required this.hint,
    required this.onSelected,
  }) : assert(value >= 1 && value <= 28);
  final int value;
  final String hint;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(hint,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, constraints) {
              final columns =
                  ((constraints.maxWidth + 8) / 52).floor().clamp(1, 7);
              return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 28,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8),
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final selected = day == value;
                    final colors = BeeCardTheme.of(context);
                    return Semantics(
                        selected: selected,
                        inMutuallyExclusiveGroup: true,
                        child: Material(
                            color: selected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: .12)
                                : colors.soft,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : colors.divider)),
                            child: InkWell(
                                onTap: () => onSelected(day),
                                borderRadius: BorderRadius.circular(12),
                                child: Center(child: Text('$day')))));
                  });
            }),
          ]);
}

/// Complete context accompanies both the discoverable menu and long press.
/// Permissions and action availability are supplied by the host.
class BeeLedgerActions extends StatelessWidget {
  const BeeLedgerActions({
    super.key,
    required this.name,
    required this.subtitle,
    required this.actions,
    required this.onSelected,
    this.shared = false,
    this.details,
  });
  final String name, subtitle;
  final bool shared;
  final Widget? details;
  final List<BeeAction> actions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(
                      child: BeeLineIcon(shared ? 'Users' : 'BookOpen',
                          size: 21))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).hintColor)),
                  ])),
            ]),
            if (details != null) ...[const SizedBox(height: 12), details!],
            const SizedBox(height: 12),
            const Divider(height: 1),
            BeeActionMenu(actions: actions, onSelected: onSelected),
          ]);
}
