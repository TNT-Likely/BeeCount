import 'package:beecount_ui/paper.dart';
import 'package:flutter/material.dart';
import 'share_poster_components.dart';

/// Already formatted, privacy-filtered milestone supplied by the host.
class BeeAnnualPosterMoment {
  const BeeAnnualPosterMoment(
      {required this.label,
      required this.note,
      required this.icon,
      this.amount = '',
      this.date = '',
      this.unlocked = true});
  final String label, amount, date, note;
  final Widget icon;
  final bool unlocked;
}

/// A chapter's source values. Calendar cutoffs, rates, financial arithmetic and
/// localization remain outside the presentation package.
class BeeAnnualPosterChapter {
  const BeeAnnualPosterChapter(
      {required this.index,
      required this.title,
      this.subtitle,
      this.metricGroups = const [],
      this.trend,
      this.categories,
      this.rankingTitle,
      this.emptyLabel,
      this.moments = const [],
      this.emptyMomentLabel,
      this.body});
  final String index, title;
  final String? subtitle, rankingTitle, emptyLabel, emptyMomentLabel, body;
  final List<List<BeePosterMetric>> metricGroups;
  final List<BeePosterTrendPoint>? trend;
  final List<BeePosterCategory>? categories;
  final List<BeeAnnualPosterMoment> moments;
}

/// Complete yearly export layout, shared by preview and capture.
class BeeAnnualReportPoster extends StatelessWidget {
  const BeeAnnualReportPoster(
      {super.key,
      required this.header,
      required this.footer,
      required this.year,
      required this.subtitle,
      required this.expenseLabel,
      required this.expense,
      required this.summaryMetrics,
      required this.chapters,
      required this.accent});
  final Widget header, footer;
  final String year, subtitle, expenseLabel, expense;
  final Color accent;
  final List<BeePosterMetric> summaryMetrics;
  final List<BeeAnnualPosterChapter> chapters;

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
          child: BeePosterCanvas(height: null, children: [
        header,
        const SizedBox(height: 65),
        Text(year,
            style: const TextStyle(
                fontSize: 105,
                fontWeight: FontWeight.w700,
                height: 1.15,
                letterSpacing: -4)),
        const SizedBox(height: 17),
        Text(subtitle,
            style: const TextStyle(fontSize: 25, color: BeePaper.muted)),
        const SizedBox(height: 45),
        Text(expenseLabel,
            style: const TextStyle(fontSize: 22, color: BeePaper.muted)),
        const SizedBox(height: 14),
        BeePosterAmount(expense),
        const SizedBox(height: 32),
        BeePosterMetricPair(metrics: summaryMetrics),
        for (final chapter in chapters)
          BeePosterChapter(
              index: chapter.index,
              title: chapter.title,
              subtitle: chapter.subtitle,
              children: [
                if (chapter.trend != null) ...[
                  BeePosterTrend(accent: accent, points: chapter.trend!),
                  const SizedBox(height: 27),
                ],
                for (final metrics in chapter.metricGroups)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child:
                          BeePosterMetricPair(metrics: metrics, soft: false)),
                if (chapter.categories != null)
                  BeePosterRanking(
                      title: chapter.rankingTitle ?? '',
                      categories: chapter.categories!,
                      accent: accent,
                      emptyLabel: chapter.emptyLabel ?? '',
                      limit: 5),
                for (final moment in chapter.moments)
                  BeePosterMoment(
                      label: moment.label,
                      amount: moment.amount,
                      date: moment.date,
                      note: moment.note,
                      icon: moment.icon,
                      unlocked: moment.unlocked),
                if (chapter.emptyMomentLabel != null)
                  Text(chapter.emptyMomentLabel!,
                      style:
                          const TextStyle(fontSize: 22, color: BeePaper.muted)),
                if (chapter.body != null)
                  Text(chapter.body!,
                      style: const TextStyle(
                          fontSize: 23, height: 1.8, color: BeePaper.muted)),
              ]),
        const SizedBox(height: 42),
        footer,
      ]));
}
