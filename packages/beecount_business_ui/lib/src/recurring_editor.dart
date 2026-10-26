import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

enum BeeRecurringEditorField {
  ledger,
  currency,
  category,
  account,
  toAccount,
  frequency,
  interval,
  dayOfMonth,
  startDate,
  endDate,
}

/// A displayed field and host-owned selection actions. No repository or date
/// rules are decided by the component.
class BeeRecurringEditorValue {
  const BeeRecurringEditorValue({
    required this.label,
    required this.value,
    required this.icon,
    this.leading,
    this.error,
    this.onSelect,
    this.onClear,
  });
  final String label, value, icon;
  final String? error;
  final Widget? leading;
  final VoidCallback? onSelect, onClear;
}

/// The host owns controllers, validation, frequency visibility and draft writes.
class BeeRecurringEditorForm extends StatelessWidget {
  const BeeRecurringEditorForm({
    super.key,
    required this.amountController,
    required this.noteController,
    required this.type,
    required this.types,
    required this.values,
    required this.amountLabel,
    required this.noteLabel,
    required this.clearLabel,
    this.onType,
    this.amountValidator,
    this.showInterval = true,
    this.showDayOfMonth = true,
    this.enabled = true,
  });
  final TextEditingController amountController, noteController;
  final String type, amountLabel, noteLabel, clearLabel;
  final List<BeeSegment<String>> types;
  final Map<BeeRecurringEditorField, BeeRecurringEditorValue> values;
  final ValueChanged<String>? onType;
  final FormFieldValidator<String>? amountValidator;
  final bool showInterval, showDayOfMonth, enabled;

  @override
  Widget build(BuildContext context) {
    Widget field(BeeRecurringEditorField id) {
      final value = values[id]!;
      return _EditorValueRow(
          key: ValueKey('recurring-editor-${id.name}'),
          value: value,
          enabled: enabled,
          clearLabel: clearLabel);
    }

    Widget group(List<BeeRecurringEditorField> ids) => BeeSurface(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < ids.length; i++) ...[
            if (i > 0)
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1)),
            field(ids[i]),
          ],
        ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSegmented<String>(
          items: types, value: type, onChanged: enabled ? onType : null),
      const SizedBox(height: 12),
      group([BeeRecurringEditorField.ledger, BeeRecurringEditorField.currency]),
      const SizedBox(height: 12),
      BeeSurface(
          child: BeeField(
              key: const ValueKey('recurring-editor-amount'),
              label: amountLabel,
              controller: amountController,
              enabled: enabled,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: amountValidator)),
      const SizedBox(height: 12),
      group([
        if (type != 'transfer') BeeRecurringEditorField.category,
        BeeRecurringEditorField.account,
        if (type == 'transfer') BeeRecurringEditorField.toAccount,
      ]),
      const SizedBox(height: 12),
      group([
        BeeRecurringEditorField.frequency,
        if (showInterval) BeeRecurringEditorField.interval,
        if (showDayOfMonth) BeeRecurringEditorField.dayOfMonth,
        BeeRecurringEditorField.startDate,
        BeeRecurringEditorField.endDate,
      ]),
      const SizedBox(height: 12),
      BeeSurface(
          child: BeeField(
              key: const ValueKey('recurring-editor-note'),
              label: noteLabel,
              controller: noteController,
              enabled: enabled,
              maxLines: 3)),
    ]);
  }
}

class _EditorValueRow extends StatelessWidget {
  const _EditorValueRow(
      {super.key,
      required this.value,
      required this.enabled,
      required this.clearLabel});
  final BeeRecurringEditorValue value;
  final bool enabled;
  final String clearLabel;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: enabled ? value.onSelect : null,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(children: [
                SizedBox(
                    width: 24,
                    child: value.leading ?? BeeLineIcon(value.icon, size: 20)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(value.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor)),
                      const SizedBox(height: 3),
                      Text(value.value,
                          style: const TextStyle(fontSize: 14, height: 1.4)),
                      if (value.error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(value.error!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(context).colorScheme.error))),
                    ])),
                if (value.onClear != null)
                  BeeIconButton(
                      label: '$clearLabel · ${value.label}',
                      icon: const BeeLineIcon('X', size: 16),
                      onPressed: enabled ? value.onClear : null),
                if (value.onSelect != null) ...[
                  const SizedBox(width: 6),
                  BeeLineIcon('ChevronRight',
                      size: 16, color: Theme.of(context).hintColor),
                ],
              ]))));
}
