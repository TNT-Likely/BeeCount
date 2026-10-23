import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Keep both columns tight so a short value cannot leave trailing empty space.
class RecordingConversionSummary extends StatelessWidget {
  const RecordingConversionSummary(
      {super.key,
      required this.label,
      required this.value,
      required this.onTap,
      this.isError = false});
  final String label, value;
  final VoidCallback onTap;
  final bool isError;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 18),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        color: Theme.of(context).hintColor))),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Flexible(
                      child: Text(value,
                          key: const ValueKey('recording-conversion-value'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.2,
                              color: isError
                                  ? Theme.of(context).colorScheme.error
                                  : null))),
                  const SizedBox(width: 4),
                  BeeLineIcon('ChevronRight',
                      key: const ValueKey('recording-conversion-chevron'),
                      size: 13,
                      color: Theme.of(context).hintColor),
                ])),
          ])));
}

class RecordingAmountCard extends StatelessWidget {
  const RecordingAmountCard(
      {super.key,
      required this.currency,
      required this.ledger,
      required this.amount,
      required this.hint,
      required this.symbol,
      this.conversion,
      this.compact = false});
  final Widget currency;
  final Widget ledger;
  final String amount;
  final String hint;
  final String symbol;
  final Widget? conversion;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final amountLine = FittedBox(
        alignment: Alignment.centerLeft,
        fit: BoxFit.scaleDown,
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (!compact) ...[
                Text(symbol, style: const TextStyle(fontSize: 21)),
                const SizedBox(width: 6),
              ],
              Text(amount,
                  key: const ValueKey('recording-amount'),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: compact ? 28 : 33,
                      fontWeight: FontWeight.w600)),
            ]));
    return BeeSurface(
        padding: EdgeInsets.fromLTRB(compact ? 12 : 16, compact ? 0 : 9,
            compact ? 12 : 16, compact ? 0 : 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact)
              SizedBox(
                  height: 44,
                  child: Row(children: [
                    currency,
                    const SizedBox(width: 8),
                    Expanded(child: amountLine),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 92),
                        child: ledger),
                  ]))
            else ...[
              SizedBox(
                  height: 32,
                  child: Row(children: [
                    currency,
                    const SizedBox(width: 12),
                    Expanded(child: ledger)
                  ])),
              SizedBox(height: 44, child: amountLine),
            ],
            if (!compact || conversion != null)
              SizedBox(
                height: compact ? 18 : 30,
                child: conversion ??
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text(hint,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    fontSize: 11,
                                    color: Theme.of(context).hintColor))),
              ),
          ],
        ));
  }
}

/// Fixed form above the keypad. Slots keep data and editing in the host app.
class RecordingDetailsCard extends StatelessWidget {
  const RecordingDetailsCard(
      {super.key,
      required this.note,
      required this.date,
      required this.tags,
      required this.attachment,
      this.account,
      this.noteToggle,
      this.noteExpanded = true});
  final Widget note, date, tags, attachment;
  final Widget? account, noteToggle;
  final bool noteExpanded;

  @override
  Widget build(BuildContext context) => BeeSurface(
      key: const ValueKey('recording-details'),
      borderRadius: BorderRadius.circular(noteExpanded ? 18 : 15),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (noteExpanded) ...[
          SizedBox(
              height: 44,
              child: Row(children: [
                Expanded(child: note),
                if (noteToggle != null) noteToggle!,
                attachment,
              ])),
          Divider(
              height: 1,
              thickness: .6,
              color: Theme.of(context).dividerColor.withValues(alpha: .2)),
        ],
        SizedBox(
            height: 44,
            child: Row(children: [
              if (!noteExpanded && noteToggle != null) noteToggle!,
              if (account != null) Expanded(child: account!),
              const SizedBox(width: 4),
              date,
              const SizedBox(width: 4),
              if (noteExpanded) Expanded(child: tags) else tags,
              if (!noteExpanded) attachment,
            ])),
      ]));
}

/// The app resolves built-in/custom images; this tile only handles presentation.
class RecordingCategoryTile extends StatelessWidget {
  const RecordingCategoryTile(
      {super.key,
      required this.label,
      required this.icon,
      required this.onTap,
      this.selected = false,
      this.expanded = false,
      this.hasChildren = false,
      this.compact = false});
  final bool compact;
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool selected;
  final bool expanded;
  final bool hasChildren;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 61 : 64),
              child: Padding(
                  padding: EdgeInsets.symmetric(vertical: compact ? 3 : 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : BeeCardTheme.of(context).soft,
                              borderRadius: BorderRadius.circular(12)),
                          child: Stack(children: [
                            Center(child: icon),
                            if (hasChildren)
                              Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Icon(
                                      expanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      size: 13)),
                          ])),
                      const SizedBox(height: 4),
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: compact ? 10 : 11,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                    ],
                  ))),
        ));
  }
}

class RecordingSubcategoryChip extends StatelessWidget {
  const RecordingSubcategoryChip(
      {super.key,
      required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String label;
  final Widget icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color:
              selected ? BeeCardTheme.of(context).surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  icon,
                  const SizedBox(width: 5),
                  Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  fontSize: 11,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400))),
                ])),
          ),
        ),
      );
}

/// All four operators are directly available; calculation stays in the app.
class RecordingKeypad extends StatelessWidget {
  const RecordingKeypad(
      {super.key,
      required this.onDigit,
      required this.onOperator,
      required this.onBackspace,
      required this.onClear,
      required this.deleteLabel,
      this.compact = false});
  final bool compact;
  final ValueChanged<String> onDigit;
  final ValueChanged<String> onOperator;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = BeeCardTheme.of(context);
    const keys = [
      '7',
      '8',
      '9',
      '÷',
      '4',
      '5',
      '6',
      '×',
      '1',
      '2',
      '3',
      '-',
      '.',
      '0',
      '⌫',
      '+'
    ];
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
            4,
            (row) => Padding(
                  padding: EdgeInsets.only(bottom: row == 3 ? 0 : 5),
                  child: Row(
                      children: List.generate(4, (column) {
                    final value = keys[row * 4 + column];
                    final op = column == 3;
                    return Expanded(
                        child: Padding(
                      padding: EdgeInsets.only(right: column == 3 ? 0 : 5),
                      child: Semantics(
                        label: value == '⌫' ? deleteLabel : value,
                        excludeSemantics: true,
                        onTap: () => value == '⌫'
                            ? onBackspace()
                            : op
                                ? onOperator(value)
                                : onDigit(value),
                        onLongPress: value == '⌫' ? onClear : null,
                        button: true,
                        child: Material(
                          color: op
                              ? Color.alphaBlend(
                                  theme.colorScheme.primary
                                      .withValues(alpha: .12),
                                  colors.surface)
                              : colors.surface,
                          elevation: .3,
                          shadowColor: Colors.black.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            key: ValueKey('recording-key-$value'),
                            borderRadius: BorderRadius.circular(12),
                            onLongPress: value == '⌫' ? onClear : null,
                            onTap: () => value == '⌫'
                                ? onBackspace()
                                : op
                                    ? onOperator(value)
                                    : onDigit(value),
                            child: SizedBox(
                                height: compact ? 44 : 46,
                                child: Center(
                                    child: value == '⌫'
                                        ? const BeeLineIcon('Delete', size: 20)
                                        : Text(value == '-' ? '−' : value,
                                            style: TextStyle(
                                                color: op
                                                    ? Color.lerp(
                                                        theme.colorScheme
                                                            .primary,
                                                        theme.colorScheme
                                                            .onSurface,
                                                        .42)
                                                    : theme
                                                        .colorScheme.onSurface,
                                                fontSize: op
                                                    ? 25
                                                    : compact
                                                        ? 23
                                                        : 24,
                                                fontWeight: FontWeight.w500)))),
                          ),
                        ),
                      ),
                    ));
                  })),
                )));
  }
}
