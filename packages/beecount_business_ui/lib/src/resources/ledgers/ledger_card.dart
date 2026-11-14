import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../shared/summary_metric.dart';

class BeeLedgerCard extends StatelessWidget {
  const BeeLedgerCard(
      {super.key,
      required this.name,
      required this.subtitle,
      required this.icon,
      required this.income,
      required this.expense,
      required this.incomeLabel,
      required this.expenseLabel,
      required this.currentLabel,
      required this.onSelect,
      required this.onMenu,
      this.current = false,
      this.status,
      this.footer,
      this.actions = const []});
  final String name,
      subtitle,
      income,
      expense,
      incomeLabel,
      expenseLabel,
      currentLabel;
  final Widget icon;
  final Widget? status, footer;
  final bool current;
  final VoidCallback onSelect, onMenu;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = BeeCardTheme.of(context);
    return Semantics(
        selected: current,
        child: Material(
            color: current
                ? Color.alphaBlend(
                    theme.colorScheme.primary.withValues(alpha: .03),
                    colors.surface)
                : colors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                    color: current
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2)),
            child: InkWell(
                onTap: onSelect,
                onLongPress: onMenu,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(children: [
                      ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 47),
                          child: Row(children: [
                            Container(
                                width: 39,
                                height: 39,
                                decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(14)),
                                child: Center(
                                    child: ExcludeSemantics(child: icon))),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 3),
                                  Text(subtitle,
                                      style: TextStyle(
                                          fontSize: 11, color: theme.hintColor))
                                ])),
                            if (status != null) ...[
                              status!,
                              const SizedBox(width: 8)
                            ],
                            if (current)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const BeeLineIcon('Check', size: 12),
                                        const SizedBox(width: 3),
                                        Text(currentLabel,
                                            style:
                                                const TextStyle(fontSize: 10))
                                      ]))
                          ])),
                      const SizedBox(height: 19),
                      Row(children: [
                        Expanded(
                            child: SummaryMetric(expenseLabel, expense,
                                size: 15, labelSize: 11)),
                        Expanded(
                            child: SummaryMetric(incomeLabel, income,
                                size: 15, labelSize: 11))
                      ]),
                      if (footer != null) ...[
                        const SizedBox(height: 12),
                        footer!
                      ],
                      const SizedBox(height: 14),
                      Row(children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 7),
                          Expanded(child: actions[i])
                        ],
                        const SizedBox(width: 7),
                        SizedBox(
                            width: 44,
                            height: 44,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: colors.soft,
                                    borderRadius: BorderRadius.circular(12)),
                                child: BeeIconButton(
                                    onPressed: onMenu,
                                    label: MaterialLocalizations.of(context)
                                        .showMenuTooltip,
                                    icon: const BeeLineIcon('Ellipsis',
                                        size: 19))))
                      ]),
                    ])))));
  }
}
