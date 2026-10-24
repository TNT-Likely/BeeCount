import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'finance_components.dart';

class BeeDetailItem {
  const BeeDetailItem(
      {required this.label, required this.value, this.icon, this.onTap});
  final String label;
  final Widget value;
  final Widget? icon;
  final VoidCallback? onTap;
}

class BeeDetailList extends StatelessWidget {
  const BeeDetailList({super.key, required this.items});
  final List<BeeDetailItem> items;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
          children: items
              .asMap()
              .entries
              .map((e) => Column(children: [
                    InkWell(
                        onTap: e.value.onTap,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Row(children: [
                                  if (e.value.icon != null) ...[
                                    e.value.icon!,
                                    const SizedBox(width: 8)
                                  ],
                                  SizedBox(
                                      width: 60,
                                      child: Text(e.value.label,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .hintColor))),
                                  Expanded(
                                      child: Align(
                                          alignment: Alignment.centerRight,
                                          child: e.value.value)),
                                  if (e.value.onTap != null) ...[
                                    const SizedBox(width: 6),
                                    const BeeLineIcon('ChevronRight', size: 14)
                                  ]
                                ])))),
                    if (e.key < items.length - 1)
                      Divider(
                          height: 1,
                          color: Theme.of(context).dividerColor,
                          thickness: .6),
                  ]))
              .toList()));
}

class BeeAccountCard extends StatelessWidget {
  const BeeAccountCard(
      {super.key,
      required this.name,
      required this.currency,
      required this.balance,
      required this.kind,
      required this.icon,
      required this.onTap,
      required this.menuLabel,
      required this.actions,
      required this.onAction,
      this.hidden = false,
      this.footer,
      this.excludedLabel,
      this.liabilityLabel});
  final String name, currency, balance, kind, menuLabel;
  final Widget icon;
  final Widget? footer;
  final VoidCallback onTap;
  final bool hidden;
  final String? excludedLabel, liabilityLabel;
  final List<BeeMenuAction<String>> actions;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child: Column(children: [
        Row(children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
              child: InkWell(
                  onTap: onTap,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text('$kind · $currency',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).hintColor))
                      ]))),
          BeeMenuButton<String>(
              label: menuLabel, items: actions, onSelected: onAction)
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: BeeMoney(amount: balance, hidden: hidden, size: 26))),
          if (liabilityLabel != null)
            Text(liabilityLabel!,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).colorScheme.error))
        ]),
        if (footer != null) ...[const SizedBox(height: 12), footer!],
        if (excludedLabel != null) ...[
          const SizedBox(height: 8),
          Align(
              alignment: Alignment.centerLeft,
              child: Text(excludedLabel!,
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).hintColor)))
        ]
      ]));
}

class BeeBudgetCard extends StatelessWidget {
  const BeeBudgetCard(
      {super.key,
      required this.title,
      required this.spentLabel,
      required this.spent,
      required this.remainingLabel,
      required this.remaining,
      required this.progress,
      required this.onTap,
      this.overBudget = false,
      this.warning});
  final String title, spentLabel, spent, remainingLabel, remaining;
  final double progress;
  final VoidCallback onTap;
  final bool overBudget;
  final String? warning;
  @override
  Widget build(BuildContext context) => BeeSurface(
      child: InkWell(
          onTap: onTap,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(spentLabel, style: const TextStyle(fontSize: 11)),
                    BeeMoney(amount: spent, size: 23)
                  ])),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                    Text(remainingLabel, style: const TextStyle(fontSize: 11)),
                    BeeMoney(amount: remaining, size: 23)
                  ]))
            ]),
            const SizedBox(height: 12),
            LinearProgressIndicator(
                value: progress.isFinite ? progress.clamp(0, 1) : 0,
                color: overBudget
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4)),
            if (warning != null) ...[
              const SizedBox(height: 12),
              BeeStatus(
                  label: warning!,
                  tone: overBudget ? BeeTone.error : BeeTone.warning)
            ]
          ])));
}

class BeeChatMessage extends StatelessWidget {
  const BeeChatMessage(
      {super.key,
      required this.author,
      required this.content,
      this.isUser = false,
      this.status,
      this.actions = const []});
  final String author;
  final Widget content;
  final bool isUser;
  final Widget? status;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
          widthFactor: .92,
          child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .13)
                      : BeeCardTheme.of(context).surface,
                  borderRadius: BorderRadius.circular(18)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(author,
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).hintColor)),
                    const SizedBox(height: 8),
                    content,
                    if (status != null) ...[
                      const SizedBox(height: 10),
                      status!
                    ],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: actions)
                    ]
                  ]))));
}

class BeeExecutionStep {
  const BeeExecutionStep(
      {required this.title, required this.tone, this.detail});
  final String title;
  final BeeTone tone;
  final String? detail;
}

class BeeExecutionTimeline extends StatelessWidget {
  const BeeExecutionTimeline({super.key, required this.steps});
  final List<BeeExecutionStep> steps;
  @override
  Widget build(BuildContext context) => BeeSurface(
      child: Column(
          children: steps
              .asMap()
              .entries
              .map((e) => Padding(
                  padding: EdgeInsets.only(
                      bottom: e.key == steps.length - 1 ? 0 : 16),
                  child: BeeStatus(
                      label: e.value.title,
                      detail: e.value.detail,
                      tone: e.value.tone)))
              .toList()));
}

/// Presentation only: authentication, encryption and submission stay in the host.
class BeePinPad extends StatelessWidget {
  const BeePinPad(
      {super.key,
      required this.length,
      required this.filled,
      required this.deleteLabel,
      required this.onDigit,
      required this.onDelete,
      this.error,
      this.invalid = false,
      this.auxiliaryKey,
      this.enabled = true,
      this.cardKeys = false,
      this.compact = false});
  final int length, filled;
  final String deleteLabel;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final String? error;
  final bool enabled, invalid, cardKeys, compact;
  final Widget? auxiliaryKey;
  @override
  Widget build(BuildContext context) => Column(children: [
        Semantics(
            label: '$filled / $length',
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    length,
                    (i) => Container(
                        width: 12,
                        height: 12,
                        margin: EdgeInsets.all(cardKeys ? 7 : 8),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: invalid
                                ? Theme.of(context).colorScheme.error
                                : i < filled
                                    ? cardKeys
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                    : BeeCardTheme.of(context).soft,
                            border: Border.all(
                                color: Theme.of(context).dividerColor)))))),
        if (error != null)
          Padding(
              padding: const EdgeInsets.all(8),
              child: BeeStatus(label: error!, tone: BeeTone.error)),
        const SizedBox(height: 12),
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'delete']
        ])
          Padding(
              padding: EdgeInsets.only(
                  bottom: cardKeys
                      ? row.first.isEmpty
                          ? 0
                          : 9
                      : 6),
              child: Row(
                  children: cardKeys
                      ? [
                          for (var i = 0; i < row.length; i++) ...[
                            if (i > 0) const SizedBox(width: 9),
                            Expanded(
                                child: row[i].isEmpty
                                    ? auxiliaryKey ??
                                        SizedBox(height: compact ? 48 : 57)
                                    : _cardKey(context, row[i]))
                          ]
                        ]
                      : row
                          .map((v) => Expanded(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: v.isEmpty
                                      ? auxiliaryKey ??
                                          SizedBox(
                                              height: cardKeys
                                                  ? compact
                                                      ? 48
                                                      : 57
                                                  : 44)
                                      : cardKeys
                                          ? _cardKey(context, v)
                                          : BeeButton(
                                              label: v == 'delete'
                                                  ? deleteLabel
                                                  : v,
                                              kind: BeeButtonKind.secondary,
                                              onPressed: !enabled
                                                  ? null
                                                  : v == 'delete'
                                                      ? onDelete
                                                      : filled >= length
                                                          ? null
                                                          : () => onDigit(v)))))
                          .toList()))
      ]);

  Widget _cardKey(BuildContext context, String value) {
    final deleting = value == 'delete';
    final callback = !enabled
        ? null
        : deleting
            ? onDelete
            : filled >= length
                ? null
                : () => onDigit(value);
    return SizedBox(
        height: compact ? 48 : 57,
        child: FilledButton(
            onPressed: callback,
            style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: BeeCardTheme.of(context).surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                disabledBackgroundColor: BeeCardTheme.of(context).surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17))),
            child: deleting
                ? Semantics(
                    label: deleteLabel,
                    child: ExcludeSemantics(
                        child: BeeLineIcon('Delete',
                            size: 21,
                            color: Theme.of(context).colorScheme.onSurface)))
                : Text(value,
                    style: TextStyle(
                        fontSize: compact ? 22 : 25,
                        fontWeight: FontWeight.w400))));
  }
}
