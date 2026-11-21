import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../shared/money.dart';
import '../shared/summary_metric.dart';

enum BeeHomeSummaryStyle { full, compact, sliding }

class BeeSummaryCard extends StatelessWidget {
  const BeeSummaryCard(
      {super.key,
      required this.title,
      required this.amount,
      required this.incomeLabel,
      required this.income,
      required this.expenseLabel,
      required this.expense,
      this.amountLabel,
      this.currencyLabel,
      this.prefix,
      this.budget,
      this.style = BeeHomeSummaryStyle.full,
      this.budgetIndicator,
      this.background,
      this.hidden = false,
      this.onContextTap,
      this.onPrivacyTap,
      this.privacyLabel});
  final String title, amount, incomeLabel, income, expenseLabel, expense;
  final String? amountLabel, currencyLabel, prefix, privacyLabel;
  final Widget? budget, background, budgetIndicator;
  final BeeHomeSummaryStyle style;
  final bool hidden;
  final VoidCallback? onContextTap, onPrivacyTap;
  @override
  Widget build(BuildContext context) => switch (style) {
        BeeHomeSummaryStyle.full => _full(context),
        BeeHomeSummaryStyle.compact => _compact(context),
        BeeHomeSummaryStyle.sliding => BeeSurface(
            background: background,
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 3),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _compactContext(context, sliding: true),
                  _SlidingSummary(card: this),
                ])),
      };

  Widget _full(BuildContext context) => BeeSurface(
      background: background,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 27),
            child: Row(children: [
              Expanded(
                  child: InkWell(
                      onTap: onContextTap,
                      child: Row(children: [
                        Flexible(
                            child: Text(title,
                                style: const TextStyle(fontSize: 13))),
                        if (onContextTap != null) ...[
                          const SizedBox(width: 5),
                          const BeeLineIcon('ChevronDown', size: 14)
                        ]
                      ]))),
              if (currencyLabel != null)
                Text(currencyLabel!,
                    style: TextStyle(
                        fontSize: 11, color: Theme.of(context).hintColor))
            ])),
        const SizedBox(height: 13),
        if (amountLabel != null)
          Row(children: [
            Text(amountLabel!,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
            if (onPrivacyTap != null)
              SizedBox(
                  width: 30,
                  height: 26,
                  child: Semantics(
                      button: true,
                      label: privacyLabel,
                      excludeSemantics: true,
                      onTap: onPrivacyTap,
                      child: IconButton(
                          tooltip: privacyLabel,
                          style: IconButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: onPrivacyTap,
                          icon: BeeLineIcon(hidden ? 'EyeOff' : 'Eye',
                              size: 14, color: Theme.of(context).hintColor))))
          ]),
        const SizedBox(height: 6),
        Align(
            alignment: Alignment.centerLeft,
            child: BeeMoney(
                amount: amount,
                prefix: prefix,
                hidden: hidden,
                size: 36,
                lineHeight: 1.3)),
        const SizedBox(height: 17),
        Row(children: [
          Expanded(
              child: SummaryMetric(incomeLabel, hidden ? '••••' : income,
                  size: 15, labelSize: 11, gap: 4, lineHeight: 1.5)),
          const SizedBox(width: 10),
          Expanded(
              child: SummaryMetric(expenseLabel, hidden ? '••••' : expense,
                  size: 15,
                  labelSize: 11,
                  gap: 4,
                  lineHeight: 1.5,
                  alignEnd: true))
        ]),
        if (budget != null) ...[
          const SizedBox(height: 17),
          Divider(
              height: 1, color: Theme.of(context).dividerColor, thickness: .6),
          const SizedBox(height: 15),
          budget!
        ],
      ]));

  Widget _compactContext(BuildContext context, {bool sliding = false}) =>
      ConstrainedBox(
          constraints: BoxConstraints(minHeight: sliding ? 44 : 32),
          child: Row(children: [
            Expanded(
                child: InkWell(
                    onTap: onContextTap,
                    child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: sliding ? 44 : 0),
                        child: Row(children: [
                          Flexible(
                              child: Text(title,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor))),
                          if (onContextTap != null) ...[
                            const SizedBox(width: 5),
                            BeeLineIcon('ChevronDown',
                                size: 13, color: Theme.of(context).hintColor)
                          ]
                        ])))),
            if (currencyLabel != null)
              Text(currencyLabel!,
                  style: TextStyle(
                      fontSize: 10, color: Theme.of(context).hintColor)),
            if (onPrivacyTap != null)
              SizedBox(
                  width: sliding ? 44 : 30,
                  height: sliding ? 44 : 30,
                  child: Semantics(
                      button: true,
                      label: privacyLabel,
                      excludeSemantics: true,
                      onTap: onPrivacyTap,
                      child: IconButton(
                          tooltip: privacyLabel,
                          style: IconButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: onPrivacyTap,
                          icon: BeeLineIcon(hidden ? 'EyeOff' : 'Eye',
                              size: 15, color: Theme.of(context).hintColor))))
          ]));

  Widget _compact(BuildContext context) => BeeSurface(
      background: background,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 17),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _compactContext(context),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                if (amountLabel != null)
                  Text(amountLabel!,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: Theme.of(context).hintColor)),
                const SizedBox(height: 5),
                BeeMoney(
                    amount: amount,
                    prefix: prefix,
                    hidden: hidden,
                    size: 34,
                    prefixSize: 16,
                    lineHeight: 1.3,
                    alignment: Alignment.centerLeft)
              ])),
          if (budgetIndicator != null) ...[
            const SizedBox(width: 13),
            budgetIndicator!
          ]
        ]),
        // Keep the approved spacing after removing the visual divider.
        const SizedBox(height: 29),
        Row(children: [
          Expanded(
              child: SummaryMetric(incomeLabel, hidden ? '••••' : income,
                  size: 18,
                  labelSize: 11,
                  gap: 5,
                  lineHeight: 1.35,
                  fitValue: true)),
          const SizedBox(width: 18),
          Expanded(
              child: SummaryMetric(expenseLabel, hidden ? '••••' : expense,
                  size: 18,
                  labelSize: 11,
                  gap: 5,
                  lineHeight: 1.35,
                  fitValue: true,
                  alignEnd: true))
        ])
      ]));
}

class _SlidingSummary extends StatefulWidget {
  const _SlidingSummary({required this.card});

  final BeeSummaryCard card;

  @override
  State<_SlidingSummary> createState() => _SlidingSummaryState();
}

class _SlidingSummaryState extends State<_SlidingSummary> {
  final _controller = PageController(keepPage: false);
  int _selected = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(index,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final metrics = [
      (label: card.amountLabel ?? '', amount: card.amount),
      (label: card.incomeLabel, amount: card.income),
      (label: card.expenseLabel, amount: card.expense),
    ];
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context);
    final size = MediaQuery.sizeOf(context).width < 350 ? 26.0 : 30.0;
    final height = scale.scale(12) * 1.4 + scale.scale(size) * 1.2 + 4;
    final accent = theme.colorScheme.primary;
    return Row(children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            height: height,
            child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _selected = index),
                children: [
                  for (final metric in metrics)
                    Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(metric.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: theme.hintColor)),
                          const SizedBox(height: 2),
                          BeeMoney(
                              amount: metric.amount,
                              prefix: card.prefix,
                              hidden: card.hidden,
                              size: size,
                              lineHeight: 1.2,
                              alignment: Alignment.centerLeft),
                        ]),
                ])),
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Row(children: [
              for (var index = 0; index < metrics.length; index++)
                Expanded(
                    child: Semantics(
                        button: true,
                        selected: index == _selected,
                        label: metrics[index].label,
                        child: InkWell(
                            onTap: () => _select(index),
                            borderRadius: BorderRadius.circular(9),
                            child: SizedBox(
                                height: 44,
                                child: Center(
                                    child: Container(
                                        width: index == _selected ? 16 : 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                            color: index == _selected
                                                ? accent
                                                : accent.withValues(alpha: .5),
                                            borderRadius:
                                                BorderRadius.circular(9)))))))),
            ])),
      ])),
      if (card.budgetIndicator != null) ...[
        const SizedBox(width: 12),
        card.budgetIndicator!,
      ],
    ]);
  }
}
