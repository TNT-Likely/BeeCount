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

enum BeeRecurringPreviewBadgeTone { neutral, highlight, warning }

class BeeRecurringPreviewItem {
  const BeeRecurringPreviewItem({
    required this.index,
    required this.dateText,
    required this.weekdayText,
    required this.badgeText,
    this.badgeTone = BeeRecurringPreviewBadgeTone.neutral,
  });

  final int index;
  final String dateText;
  final String weekdayText;
  final String badgeText;
  final BeeRecurringPreviewBadgeTone badgeTone;
}

class BeeRecurringSchedulePreviewData {
  const BeeRecurringSchedulePreviewData({
    required this.title,
    this.subtitle,
    this.items = const [],
    this.emptyMessage,
    this.footnote,
  });

  final String title;
  final String? subtitle;
  final List<BeeRecurringPreviewItem> items;
  final String? emptyMessage;
  final String? footnote;
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
    this.schedulePreview,
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
  final BeeRecurringSchedulePreviewData? schedulePreview;
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

    Widget group(List<BeeRecurringEditorField> ids, {Widget? footer}) =>
        BeeSurface(
            padding: EdgeInsets.zero,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < ids.length; i++) ...[
                    if (i > 0)
                      const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 1)),
                    field(ids[i]),
                  ],
                  if (footer != null) footer,
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
      group(
        [
          BeeRecurringEditorField.frequency,
          if (showInterval) BeeRecurringEditorField.interval,
          if (showDayOfMonth) BeeRecurringEditorField.dayOfMonth,
          BeeRecurringEditorField.startDate,
          BeeRecurringEditorField.endDate,
        ],
        footer: schedulePreview == null
            ? null
            : _SchedulePreviewPanel(
                key: const ValueKey('recurring-editor-schedule-preview'),
                data: schedulePreview!,
              ),
      ),
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

class _SchedulePreviewPanel extends StatelessWidget {
  const _SchedulePreviewPanel({super.key, required this.data});
  final BeeRecurringSchedulePreviewData data;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    final successColor = beeToneColor(context, BeeTone.success);
    final warnColor = beeToneColor(context, BeeTone.warning);

    Color badgeColor(BeeRecurringPreviewBadgeTone tone) => switch (tone) {
          BeeRecurringPreviewBadgeTone.highlight => successColor,
          BeeRecurringPreviewBadgeTone.warning => warnColor,
          BeeRecurringPreviewBadgeTone.neutral => muted,
        };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: BeeCardTheme.of(context).divider),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                data.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (data.subtitle?.isNotEmpty ?? false)
                Text(
                  data.subtitle!,
                  style: TextStyle(fontSize: 11, color: muted),
                ),
            ],
          ),
          const SizedBox(height: 7),
          if (data.items.isEmpty && (data.emptyMessage?.isNotEmpty ?? false))
            Text(
              data.emptyMessage!,
              style: TextStyle(fontSize: 11.5, height: 1.4, color: muted),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < data.items.length; i++) ...[
                  _PreviewItemRow(
                    item: data.items[i],
                    muted: muted,
                    badgeColor: badgeColor(data.items[i].badgeTone),
                  ),
                ],
              ],
            ),
          if (data.footnote?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              data.footnote!,
              style: TextStyle(fontSize: 11, height: 1.45, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewItemRow extends StatelessWidget {
  const _PreviewItemRow({
    required this.item,
    required this.muted,
    required this.badgeColor,
  });

  final BeeRecurringPreviewItem item;
  final Color muted;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final emphasize = item.badgeTone != BeeRecurringPreviewBadgeTone.neutral;
    final badge = Text(
      item.badgeText,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 11,
        fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
        color: badgeColor,
      ),
    );
    final date = Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(item.dateText,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()])),
        Text(item.weekdayText, style: TextStyle(fontSize: 11, color: muted)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth /
                (MediaQuery.textScalerOf(context).scale(13) / 13) <
            310;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 17,
                child: Text('${item.index}',
                    style: TextStyle(fontSize: 11, height: 1.6, color: muted))),
            const SizedBox(width: 8),
            Expanded(
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [date, const SizedBox(height: 4), badge])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Expanded(flex: 3, child: date),
                            const SizedBox(width: 10),
                            Expanded(flex: 2, child: badge),
                          ])),
          ],
        );
      }),
    );
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
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Theme.of(context).colorScheme.onSurface)),
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
