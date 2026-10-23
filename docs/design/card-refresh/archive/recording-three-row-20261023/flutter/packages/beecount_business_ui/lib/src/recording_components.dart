import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => BeeSurface(
      padding: EdgeInsets.fromLTRB(15, compact ? 7 : 12, 15, compact ? 7 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            currency,
            const SizedBox(width: 12),
            Expanded(child: ledger)
          ]),
          SizedBox(height: compact ? 2 : 6),
          SizedBox(
              height: compact ? 34 : 48,
              child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(symbol,
                            style: TextStyle(
                                fontSize: compact ? 17 : 22,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 7),
                        Text(amount,
                            key: const ValueKey('recording-amount'),
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                    fontSize: compact ? 27 : 34,
                                    fontWeight: FontWeight.w600)),
                      ]))),
          if (!compact) const SizedBox(height: 2),
          if (!compact)
            Text(hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11, color: Theme.of(context).hintColor)),
          if (conversion != null) conversion!,
        ],
      ));
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
      this.hasChildren = false});
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
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
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
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400)),
                ],
              )),
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
      required this.deleteLabel});
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
                                height: 44,
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
                                                fontSize: op ? 25 : 23,
                                                fontWeight: FontWeight.w500)))),
                          ),
                        ),
                      ),
                    ));
                  })),
                )));
  }
}
