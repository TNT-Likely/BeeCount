import 'package:beecount_ui/card_frame.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// A report chapter. The host supplies already calculated and localized content.
class BeeAnnualReportSection extends StatelessWidget {
  const BeeAnnualReportSection(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.children});
  final String title, subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(17, 8, 17, 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(3, 6, 3, 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 25, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Theme.of(context).hintColor)),
                  ])),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i]
          ],
        ]),
      );
}

class BeeAnnualMetric extends StatelessWidget {
  const BeeAnnualMetric(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      this.description,
      this.color,
      this.compact = false});
  final String label, value;
  final String? description;
  final Widget icon;
  final Color? color;
  final bool compact;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: BeeCardTheme.of(context).soft,
                  borderRadius: BorderRadius.circular(11)),
              child: Center(
                  child: IconTheme(
                      data: IconThemeData(
                          size: 18,
                          color:
                              color ?? Theme.of(context).colorScheme.primary),
                      child: icon))),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Theme.of(context).hintColor))),
        ]),
        const SizedBox(height: 12),
        Text(value,
            style: TextStyle(
                fontSize: compact ? 23 : 27,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()])),
        if (description != null) ...[
          const SizedBox(height: 5),
          Text(description!,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).hintColor))
        ],
      ]));
}

class BeeAnnualComparisonRow extends StatelessWidget {
  const BeeAnnualComparisonRow(
      {super.key,
      required this.month,
      required this.income,
      required this.expense,
      required this.incomeRatio,
      required this.expenseRatio,
      required this.incomeLabel,
      required this.expenseLabel,
      this.highlights = const [],
      this.incomeColor = const Color(0xff23896d),
      this.expenseColor = const Color(0xffd45c5c)});
  final String month, income, expense, incomeLabel, expenseLabel;
  final double incomeRatio, expenseRatio;
  final List<String> highlights;
  final Color incomeColor, expenseColor;
  @override
  Widget build(BuildContext context) {
    Widget bar(String label, String amount, double ratio, Color color) =>
        Semantics(
            label: '$label $amount',
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).hintColor))),
                    Text(amount,
                        style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600))
                  ]),
                  const SizedBox(height: 5),
                  ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: ratio.clamp(0, 1),
                          minHeight: 7,
                          color: color,
                          backgroundColor: BeeCardTheme.of(context).soft)),
                ]));
    return BeeSurface(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          spacing: 8,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(month,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            for (final label in highlights)
              Text(label,
                  style: TextStyle(
                      fontSize: 10, color: Theme.of(context).hintColor))
          ]),
      const SizedBox(height: 12),
      bar(incomeLabel, income, incomeRatio, incomeColor),
      const SizedBox(height: 10),
      bar(expenseLabel, expense, expenseRatio, expenseColor),
    ]));
  }
}

class BeeAnnualRank extends StatelessWidget {
  const BeeAnnualRank(
      {super.key,
      required this.rank,
      required this.title,
      required this.amount,
      required this.percentage,
      required this.fraction,
      this.icon});
  final int rank;
  final String title, amount, percentage;
  final double fraction;
  final Widget? icon;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$rank'.padLeft(2, '0'),
              style:
                  TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
          const SizedBox(width: 10),
          if (icon != null) ...[
            IconTheme(
                data: IconThemeData(
                    size: 20, color: Theme.of(context).colorScheme.primary),
                child: icon!),
            const SizedBox(width: 10)
          ],
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Flexible(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(amount,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(percentage,
                style:
                    TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
          ]))
        ]),
        const SizedBox(height: 12),
        ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
                value: fraction.clamp(0, 1),
                minHeight: 5,
                backgroundColor: BeeCardTheme.of(context).soft)),
      ]));
}

@immutable
class BeeAnnualTrendPoint {
  const BeeAnnualTrendPoint(
      {required this.label,
      required this.amount,
      required this.fraction,
      this.color});
  final String label, amount;
  final double fraction;
  final Color? color;
}

class BeeAnnualTrend extends StatelessWidget {
  const BeeAnnualTrend({super.key, required this.points});
  final List<BeeAnnualTrendPoint> points;
  @override
  Widget build(BuildContext context) => BeeSurface(child: LayoutBuilder(
        builder: (context, constraints) {
          final labelStyle =
              TextStyle(fontSize: 11, color: Theme.of(context).hintColor);
          double labelWidth = 0, labelHeight = 0;
          for (final point in points) {
            final painter = TextPainter(
                text: TextSpan(text: point.label, style: labelStyle),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1)
              ..layout();
            if (painter.width > labelWidth) labelWidth = painter.width;
            if (painter.height > labelHeight) labelHeight = painter.height;
            painter.dispose();
          }
          // Keep month labels in one readable line at the user's text scale.
          // Narrow charts scroll horizontally instead of wrapping a month number.
          final minimumWidth = (labelWidth + 6) * points.length;
          final width = minimumWidth > constraints.maxWidth
              ? minimumWidth
              : constraints.maxWidth;
          final contentHeight = 160 + 8 + labelHeight;
          final chart = SizedBox(
              width: width,
              height: contentHeight > 200 ? contentHeight : 200,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final p in points)
                  Expanded(
                      child: Semantics(
                          label: '${p.label} ${p.amount}',
                          child: Tooltip(
                              message: '${p.label} · ${p.amount}',
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                            height:
                                                160 * p.fraction.clamp(0, 1),
                                            decoration: BoxDecoration(
                                                color: p.color ??
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withValues(alpha: .4),
                                                borderRadius: const BorderRadius
                                                    .vertical(
                                                    top: Radius.circular(4)))),
                                        const SizedBox(height: 8),
                                        Text(p.label,
                                            maxLines: 1,
                                            softWrap: false,
                                            style: labelStyle),
                                      ]))))),
              ]));
          return minimumWidth > constraints.maxWidth
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal, child: chart)
              : chart;
        },
      ));
}

class BeeAnnualMoment extends StatelessWidget {
  const BeeAnnualMoment(
      {super.key,
      required this.label,
      required this.amount,
      required this.date,
      required this.note,
      required this.icon,
      this.color});
  final String label, amount, date, note;
  final Widget icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconTheme(data: IconThemeData(size: 18, color: color), child: icon),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).hintColor))),
          Text(date,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
        ]),
        const SizedBox(height: 14),
        Text(amount,
            style: TextStyle(
                fontSize: 27, fontWeight: FontWeight.w700, color: color)),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(note,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Theme.of(context).hintColor))
        ]
      ]));
}

class BeeAnnualAchievement extends StatelessWidget {
  const BeeAnnualAchievement(
      {super.key,
      required this.title,
      required this.description,
      required this.icon,
      required this.unlocked});
  final String title, description;
  final Widget icon;
  final bool unlocked;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: BeeCardTheme.of(context).soft,
                borderRadius: BorderRadius.circular(14)),
            child: Center(
                child: IconTheme(
                    data: IconThemeData(
                        size: 23,
                        color: unlocked
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).hintColor),
                    child: icon))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(description,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).hintColor))
        ])),
        const SizedBox(width: 5),
        BeeLineIcon(unlocked ? 'CircleCheck' : 'Lock',
            size: 18, color: Theme.of(context).hintColor)
      ]));
}

/// The unskinned year-in-review hero. Formatting and ledger selection are host
/// responsibilities; this surface never starts a data request.
class BeeAnnualOverview extends StatelessWidget {
  const BeeAnnualOverview(
      {super.key,
      required this.year,
      required this.title,
      required this.subtitle,
      required this.expenseLabel,
      required this.expense,
      required this.incomeLabel,
      required this.income,
      required this.savingsLabel,
      required this.savings,
      this.brand,
      this.facts = const []});
  final String year,
      title,
      subtitle,
      expenseLabel,
      expense,
      incomeLabel,
      income,
      savingsLabel,
      savings;
  final Widget? brand;
  final List<({String label, String value})> facts;
  @override
  Widget build(BuildContext context) => BeeCardFrame(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(year,
                  style: const TextStyle(
                      fontSize: 40,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.5))),
          if (brand != null) SizedBox(width: 32, height: 32, child: brand!)
        ]),
        const SizedBox(height: 15),
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(subtitle,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 24),
        Text(expenseLabel,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 7),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(expense,
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                    fontFeatures: [FontFeature.tabularFigures()]))),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _figure(context, incomeLabel, income)),
          const SizedBox(width: 12),
          Expanded(child: _figure(context, savingsLabel, savings))
        ]),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: 21),
          Divider(height: 1, color: BeeCardTheme.of(context).divider),
          const SizedBox(height: 15),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 15,
              runSpacing: 8,
              children: [
                for (final fact in facts)
                  Text('${fact.label} ${fact.value}',
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).hintColor))
              ])
        ],
      ]));
  Widget _figure(BuildContext context, String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 7),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()])))
      ]);
}
