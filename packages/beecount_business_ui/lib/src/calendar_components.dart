import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// The host supplies localized dates and prepared amounts; this layer has no
/// repository, currency conversion, locale or calendar engine dependency.
class BeeCalendarMonthHeading extends StatelessWidget {
  const BeeCalendarMonthHeading(
      {super.key,
      required this.title,
      required this.previousLabel,
      required this.nextLabel,
      required this.onMonth,
      this.onPrevious,
      this.onNext});
  final String title, previousLabel, nextLabel;
  final VoidCallback onMonth;
  final VoidCallback? onPrevious, onNext;
  @override
  Widget build(BuildContext context) => Row(children: [
        BeeIconButton(
            label: previousLabel,
            icon: const BeeLineIcon('ChevronLeft'),
            onPressed: onPrevious),
        Expanded(
            child: TextButton(
                onPressed: onMonth,
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600))),
                  const SizedBox(width: 4),
                  const BeeLineIcon('ChevronDown', size: 16)
                ]))),
        BeeIconButton(
            label: nextLabel,
            icon: const BeeLineIcon('ChevronRight'),
            onPressed: onNext)
      ]);
}

class BeeCalendarDayCell extends StatelessWidget {
  const BeeCalendarDayCell(
      {super.key,
      required this.day,
      required this.semanticLabel,
      required this.expenseColor,
      required this.incomeColor,
      this.expense,
      this.income,
      this.selected = false,
      this.today = false,
      this.outside = false});
  final String day, semanticLabel;
  final String? expense, income;
  final Color expenseColor, incomeColor;
  final bool selected, today, outside;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), cs = theme.colorScheme;
    final fg = selected ? cs.onPrimary : cs.onSurface;
    return Semantics(
        label: semanticLabel,
        selected: selected,
        child: ExcludeSemantics(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: selected
                            ? cs.primary
                            : today
                                ? cs.primary.withValues(alpha: .09)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: today && !selected
                            ? Border.all(
                                color: cs.primary.withValues(alpha: .5))
                            : null),
                    child: Opacity(
                        opacity: outside ? .35 : 1,
                        child: SizedBox.expand(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              Text(day,
                                  style: TextStyle(
                                      fontSize: 14,
                                      height: 1.2,
                                      color: fg,
                                      fontWeight: selected || today
                                          ? FontWeight.w600
                                          : FontWeight.w400)),
                              const SizedBox(height: 3),
                              Opacity(
                                  opacity: !outside && expense != null ? 1 : 0,
                                  child: _amount(expense ?? ' ',
                                      selected ? fg : expenseColor)),
                              Opacity(
                                  opacity: !outside && income != null ? 1 : 0,
                                  child: _amount(income ?? ' ',
                                      selected ? fg : incomeColor))
                            ])))))));
  }

  Widget _amount(String value, Color color) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 10,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: color)));
}

class BeeCalendarDayHeading extends StatelessWidget {
  const BeeCalendarDayHeading(
      {super.key,
      required this.title,
      required this.weekday,
      required this.addLabel,
      required this.onAdd});
  final String title, weekday, addLabel;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text.rich(TextSpan(children: [
      TextSpan(
          text: title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      TextSpan(
          text: '  $weekday',
          style: TextStyle(fontSize: 12, color: theme.hintColor))
    ]));
    final add = BeeButton(
        label: addLabel,
        kind: BeeButtonKind.secondary,
        icon: const BeeLineIcon('Plus', size: 16),
        onPressed: onAdd);
    return LayoutBuilder(
        builder: (context, c) =>
            c.maxWidth < 310 || MediaQuery.textScalerOf(context).scale(1) > 1.2
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [label, const SizedBox(height: 8), add])
                : Row(children: [
                    Expanded(child: label),
                    const SizedBox(width: 8),
                    add
                  ]));
  }
}
