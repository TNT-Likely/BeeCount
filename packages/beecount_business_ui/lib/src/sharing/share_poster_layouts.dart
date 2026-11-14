import 'package:beecount_ui/paper.dart';
import 'package:flutter/material.dart';
import 'share_poster_components.dart';

class BeeProfileSharePoster extends StatelessWidget {
  const BeeProfileSharePoster(
      {super.key,
      required this.header,
      required this.footer,
      required this.accent,
      required this.title,
      required this.eyebrow,
      required this.avatar,
      required this.days,
      required this.daysCaption,
      required this.metrics,
      required this.journey,
      required this.description});
  final Widget header, footer, avatar;
  final Color accent;
  final String title, eyebrow, days, daysCaption, journey, description;
  final List<BeePosterMetric> metrics;
  @override
  Widget build(BuildContext context) => BeePosterCanvas(children: [
        header,
        const SizedBox(height: 65),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(eyebrow,
                    style:
                        const TextStyle(fontSize: 21, color: BeePaper.muted)),
                const SizedBox(height: 16),
                Text(title,
                    style: const TextStyle(
                        fontSize: 52, height: 1.3, fontWeight: FontWeight.w700))
              ])),
          const SizedBox(width: 20),
          ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: SizedBox(
                  width: 96,
                  height: 96,
                  child: ColoredBox(color: BeePaper.soft, child: avatar)))
        ]),
        const SizedBox(height: 48),
        SizedBox(
            height: 350,
            child: Stack(children: [
              Positioned(
                  left: 225,
                  top: 5,
                  child: Container(
                      width: 322,
                      height: 322,
                      decoration: BoxDecoration(
                          color: accent, shape: BoxShape.circle))),
              Positioned(
                  left: 0,
                  right: 0,
                  top: 28,
                  child: BeePosterAmount(days, size: 212)),
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Text(daysCaption,
                      style: const TextStyle(
                          fontSize: 29, fontWeight: FontWeight.w500)))
            ])),
        const SizedBox(height: 36),
        const BeePaperRule(),
        const SizedBox(height: 31),
        BeePosterMetricPair(metrics: metrics, soft: false, valueSize: 52),
        const SizedBox(height: 31),
        const BeePaperRule(),
        const SizedBox(height: 32),
        Text(journey,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Text(description,
            style: const TextStyle(
                fontSize: 21, height: 1.85, color: BeePaper.muted)),
        const Spacer(),
        const SizedBox(height: 36),
        footer
      ]);
}

class BeePromoFeature {
  const BeePromoFeature(this.label, this.icon);
  final String label;
  final Widget icon;
}

class BeeAppSharePoster extends StatelessWidget {
  const BeeAppSharePoster(
      {super.key,
      required this.header,
      required this.footer,
      required this.title,
      required this.accent,
      required this.features,
      required this.qr,
      required this.invitation,
      required this.tags});
  final Widget header, footer, qr;
  final String title, invitation;
  final Color accent;
  final List<BeePromoFeature> features;
  final List<String> tags;
  @override
  Widget build(BuildContext context) => BeePosterCanvas(children: [
        header,
        const SizedBox(height: 88),
        Align(
            alignment: Alignment.centerLeft,
            child: IntrinsicWidth(
                child: Stack(children: [
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 9,
                  child:
                      SizedBox(height: 22, child: ColoredBox(color: accent))),
              Text(title,
                  style: const TextStyle(
                      fontSize: 75,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2))
            ]))),
        const SizedBox(height: 65),
        for (var i = 0; i < features.length; i += 2)
          Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var j = i; j < i + 2 && j < features.length; j++) ...[
                  if (j > i) const SizedBox(width: 22),
                  Expanded(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        IconTheme(
                            data: const IconThemeData(
                                size: 29, color: BeePaper.ink),
                            child: features[j].icon),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(features[j].label,
                                style: const TextStyle(
                                    fontSize: 21, height: 1.55)))
                      ]))
                ]
              ])),
        const SizedBox(height: 32),
        Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: BeePaper.soft,
                border: Border.all(color: BeePaper.rule),
                borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              SizedBox(width: 170, height: 170, child: qr),
              const SizedBox(width: 28),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(invitation,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    const Text('github.com/TNT-Likely/BeeCount',
                        style: TextStyle(fontSize: 17, color: BeePaper.muted)),
                    const SizedBox(height: 15),
                    Wrap(spacing: 9, runSpacing: 9, children: [
                      for (final tag in tags)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                                border: Border.all(color: BeePaper.rule),
                                borderRadius: BorderRadius.circular(7)),
                            child:
                                Text(tag, style: const TextStyle(fontSize: 17)))
                    ])
                  ]))
            ])),
        const Spacer(),
        const SizedBox(height: 42),
        footer
      ]);
}

class BeeFinancialSharePoster extends StatelessWidget {
  const BeeFinancialSharePoster(
      {super.key,
      required this.header,
      required this.footer,
      required this.title,
      required this.subtitle,
      required this.expenseLabel,
      required this.expense,
      required this.metrics,
      required this.facts,
      required this.accent,
      required this.expenseCategories,
      required this.incomeCategories,
      required this.expenseRankingLabel,
      required this.incomeRankingLabel,
      required this.emptyLabel,
      this.description,
      this.period,
      this.titleIcon,
      this.year = false});
  final Widget header, footer;
  final Widget? titleIcon;
  final String title,
      subtitle,
      expenseLabel,
      expense,
      expenseRankingLabel,
      incomeRankingLabel,
      emptyLabel;
  final String? description, period;
  final List<BeePosterMetric> metrics, facts;
  final List<BeePosterCategory> expenseCategories, incomeCategories;
  final Color accent;
  final bool year;
  @override
  Widget build(BuildContext context) => BeePosterCanvas(children: [
        header,
        const SizedBox(height: 59),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: year ? 102 : 56,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: year ? -3 : -1))),
          if (titleIcon != null) ...[
            const SizedBox(width: 20),
            Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: accent, borderRadius: BorderRadius.circular(18)),
                child: IconTheme(
                    data: const IconThemeData(size: 35, color: BeePaper.ink),
                    child: titleIcon!))
          ]
        ]),
        const SizedBox(height: 14),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 23, height: 1.5, color: BeePaper.muted)),
        if (period != null) ...[
          const SizedBox(height: 15),
          Text(period!,
              style: const TextStyle(fontSize: 20, color: BeePaper.muted))
        ],
        const SizedBox(height: 47),
        Text(expenseLabel,
            style: const TextStyle(fontSize: 22, color: BeePaper.muted)),
        const SizedBox(height: 13),
        BeePosterAmount(expense),
        const SizedBox(height: 31),
        BeePosterMetricPair(metrics: metrics),
        const SizedBox(height: 27),
        Wrap(spacing: 23, runSpacing: 10, children: [
          for (final fact in facts)
            Text('${fact.label}  ${fact.value}',
                style: const TextStyle(fontSize: 20, color: BeePaper.muted))
        ]),
        const SizedBox(height: 36),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: BeePosterRanking(
                  title: expenseRankingLabel,
                  categories: expenseCategories,
                  accent: accent,
                  emptyLabel: emptyLabel)),
          const SizedBox(width: 42),
          Expanded(
              child: BeePosterRanking(
                  title: incomeRankingLabel,
                  categories: incomeCategories,
                  accent: accent,
                  emptyLabel: emptyLabel))
        ]),
        if (description != null) ...[
          const SizedBox(height: 18),
          Text(description!,
              style: const TextStyle(
                  fontSize: 20, height: 1.8, color: BeePaper.muted))
        ],
        const Spacer(),
        const SizedBox(height: 34),
        footer
      ]);
}

class BeeReceiptRow {
  const BeeReceiptRow(this.label, this.value);
  final String label;
  final Widget value;
}

class BeeReceiptPoster extends StatelessWidget {
  const BeeReceiptPoster(
      {super.key,
      required this.brand,
      required this.amount,
      required this.currency,
      required this.kind,
      required this.rows,
      required this.footer,
      this.noteLabel,
      this.note});
  final Widget brand;
  final String amount, currency, kind, footer;
  final String? noteLabel;
  final Widget? note;
  final List<BeeReceiptRow> rows;
  @override
  Widget build(BuildContext context) => BeePaper(
      tearEdge: true,
      padding: const EdgeInsets.fromLTRB(24, 27, 24, 32),
      child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 12, height: 1.65),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: brand),
                const SizedBox(height: 25),
                const BeePaperRule(dashed: true),
                const SizedBox(height: 24),
                Text(kind,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 11, color: BeePaper.muted)),
                const SizedBox(height: 10),
                BeePosterAmount(amount,
                    size: 40,
                    alignment: Alignment.center,
                    key: const ValueKey('receipt-amount')),
                const SizedBox(height: 7),
                Text(currency,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.5,
                        color: BeePaper.muted)),
                const SizedBox(height: 25),
                const BeePaperRule(dashed: true),
                const SizedBox(height: 22),
                for (final row in rows)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 58,
                                child: Text(row.label,
                                    style: const TextStyle(
                                        fontSize: 11, color: BeePaper.muted))),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Align(
                                    alignment: Alignment.centerRight,
                                    child: DefaultTextStyle.merge(
                                        textAlign: TextAlign.right,
                                        child: row.value)))
                          ])),
                if (note != null) ...[
                  const SizedBox(height: 3),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                        width: 58,
                        child: Text(noteLabel ?? '',
                            style: const TextStyle(
                                fontSize: 11, color: BeePaper.muted))),
                    const SizedBox(width: 16),
                    Expanded(child: note!)
                  ])
                ],
                const SizedBox(height: 28),
                const BeePaperRule(dashed: true),
                const SizedBox(height: 25),
                Text(footer,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10, height: 1.9, color: BeePaper.muted)),
                const SizedBox(height: 9),
                const Text('BEECOUNT · DAILY RECEIPT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 8, letterSpacing: 1, color: BeePaper.muted))
              ])));
}
