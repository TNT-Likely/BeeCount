import 'package:beecount_ui/paper.dart';
import 'package:flutter/material.dart';

/// Fixed export bounds with a layout that can scale for long content.
/// Source values and localized strings remain owned by the App.
class BeePosterCanvas extends StatelessWidget {
  const BeePosterCanvas(
      {super.key,
      required this.children,
      this.height = 1334,
      this.padding = const EdgeInsets.all(48)});
  final List<Widget> children;
  final double? height;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    Widget contents = BeePaper(
        radius: 16,
        padding: padding,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children));
    if (height == null) return SizedBox(width: 750, child: contents);
    contents = BeePaper(
        radius: 16,
        padding: padding,
        child: IntrinsicHeight(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children)));
    return SizedBox(
        width: 750,
        height: height,
        child: ColoredBox(
            color: const Color(0xfffffefa),
            child: FittedBox(
                key: const ValueKey('bee-poster-fit'),
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                    key: const ValueKey('bee-poster-content'),
                    constraints: BoxConstraints(minHeight: height!),
                    child: SizedBox(width: 750, child: contents)))));
  }
}

class BeePosterBrand extends StatelessWidget {
  const BeePosterBrand(
      {super.key,
      required this.logo,
      required this.name,
      this.size = 54,
      this.centered = false,
      this.caption = 'BEECOUNT',
      this.nameSize,
      this.captionSize});
  final Widget logo;
  final String name, caption;
  final double size;
  final double? nameSize, captionSize;
  final bool centered;
  @override
  Widget build(BuildContext context) {
    final labels = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(name,
              style: TextStyle(
                  fontSize: nameSize ?? (centered ? 30 : 22),
                  height: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(caption,
              style: TextStyle(
                  fontSize: captionSize ?? 12,
                  letterSpacing: 2.5,
                  color: BeePaper.muted))
        ]);
    return centered
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: size, height: size, child: logo),
            const SizedBox(height: 14),
            labels
          ])
        : Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: size, height: size, child: logo),
            const SizedBox(width: 14),
            Flexible(child: labels)
          ]);
  }
}

class BeePosterHeader extends StatelessWidget {
  const BeePosterHeader(
      {super.key, required this.brand, required this.caption});
  final Widget brand;
  final String caption;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: brand),
        const SizedBox(width: 16),
        Text(caption,
            style: const TextStyle(
                fontSize: 15, letterSpacing: 1, color: BeePaper.muted))
      ]);
}

class BeePosterFooter extends StatelessWidget {
  const BeePosterFooter(
      {super.key, required this.slogan, required this.caption, this.qr});
  final String slogan, caption;
  final Widget? qr;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BeePaperRule(),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(slogan,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 9),
                Text(caption,
                    style: const TextStyle(
                        fontSize: 15, height: 1.8, color: BeePaper.muted)),
                const Text('github.com/TNT-Likely/BeeCount',
                    style: TextStyle(
                        fontSize: 14, height: 1.8, color: BeePaper.muted))
              ])),
          if (qr != null) ...[
            const SizedBox(width: 22),
            SizedBox(width: 112, height: 112, child: qr!)
          ]
        ]),
      ]);
}

class BeePosterAmount extends StatelessWidget {
  const BeePosterAmount(this.value,
      {super.key,
      this.size = 80,
      this.color = BeePaper.ink,
      this.alignment = Alignment.centerLeft,
      this.fontWeight = FontWeight.w700});
  final String value;
  final double size;
  final Color color;
  final Alignment alignment;
  final FontWeight fontWeight;
  @override
  Widget build(BuildContext context) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(value,
          style: TextStyle(
              fontSize: size,
              height: 1.15,
              color: color,
              fontWeight: fontWeight,
              letterSpacing: -size * .03,
              fontFeatures: const [FontFeature.tabularFigures()])));
}

class BeePosterMetric {
  const BeePosterMetric(this.label, this.value);
  final String label, value;
}

class BeePosterMetricPair extends StatelessWidget {
  const BeePosterMetricPair(
      {super.key,
      required this.metrics,
      this.soft = true,
      this.valueSize = 33});
  final List<BeePosterMetric> metrics;
  final bool soft;
  final double valueSize;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: soft ? BeePaper.soft : Colors.transparent,
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
          padding: soft ? const EdgeInsets.all(23) : EdgeInsets.zero,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(width: 24),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(metrics[i].label,
                        style: const TextStyle(
                            fontSize: 19, color: BeePaper.muted)),
                    const SizedBox(height: 9),
                    BeePosterAmount(metrics[i].value, size: valueSize)
                  ]))
            ]
          ])));
}

class BeePosterCategory {
  const BeePosterCategory(
      {required this.name,
      required this.amount,
      required this.percent,
      required this.ratio,
      this.icon});
  final String name, amount, percent;
  final double ratio;
  final Widget? icon;
}

class BeePosterRanking extends StatelessWidget {
  const BeePosterRanking(
      {super.key,
      required this.title,
      required this.categories,
      required this.accent,
      required this.emptyLabel,
      this.limit = 3});
  final String title, emptyLabel;
  final List<BeePosterCategory> categories;
  final Color accent;
  final int limit;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        if (categories.isEmpty)
          Text(emptyLabel,
              style: const TextStyle(fontSize: 19, color: BeePaper.muted)),
        for (final item in categories.take(limit))
          Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      if (item.icon != null) ...[
                        SizedBox(
                            width: 25,
                            height: 25,
                            child: IconTheme(
                                data: const IconThemeData(
                                    size: 25, color: BeePaper.ink),
                                child: item.icon!)),
                        const SizedBox(width: 7)
                      ],
                      Expanded(
                          child: Text(item.name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontSize: 21, height: 1.4)))
                    ]),
                    const SizedBox(height: 5),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                          child: BeePosterAmount(item.amount,
                              size: 20, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 5),
                      Text(item.percent,
                          style: const TextStyle(
                              fontSize: 17, color: BeePaper.muted))
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            value: item.ratio.isFinite
                                ? item.ratio.clamp(0, 1)
                                : 0,
                            color: accent,
                            backgroundColor: BeePaper.rule,
                            minHeight: 5))
                  ]))
      ]);
}

class BeePosterChapter extends StatelessWidget {
  const BeePosterChapter(
      {super.key,
      required this.title,
      required this.children,
      this.index,
      this.subtitle});
  final String title;
  final String? index, subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 40),
        const BeePaperRule(),
        const SizedBox(height: 32),
        if (index != null) ...[
          Text(index!,
              style: const TextStyle(fontSize: 18, color: BeePaper.muted)),
          const SizedBox(height: 12)
        ],
        Text(title,
            style: const TextStyle(
                fontSize: 31, height: 1.4, fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle!,
              style: const TextStyle(
                  fontSize: 22, height: 1.6, color: BeePaper.muted))
        ],
        const SizedBox(height: 24),
        ...children
      ]);
}

class BeePosterTrendPoint {
  const BeePosterTrendPoint(this.label, this.ratio, {this.selected = false});
  final String label;
  final double ratio;
  final bool selected;
}

class BeePosterTrend extends StatelessWidget {
  const BeePosterTrend({super.key, required this.points, required this.accent});
  final List<BeePosterTrendPoint> points;
  final Color accent;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 210,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final point in points)
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                            child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                    widthFactor: 1,
                                    heightFactor: point.ratio.isFinite
                                        ? point.ratio.clamp(.005, 1)
                                        : .005,
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: accent.withValues(
                                                alpha:
                                                    point.selected ? 1 : .23),
                                            borderRadius: const BorderRadius
                                                .vertical(
                                                top: Radius.circular(5))))))),
                        const SizedBox(height: 12),
                        Text(point.label,
                            style: const TextStyle(
                                fontSize: 17, color: BeePaper.muted))
                      ])))
      ]));
}

class BeePosterMoment extends StatelessWidget {
  const BeePosterMoment(
      {super.key,
      required this.label,
      required this.amount,
      required this.date,
      required this.note,
      required this.icon,
      this.unlocked = true});
  final String label, amount, date, note;
  final Widget icon;
  final bool unlocked;
  @override
  Widget build(BuildContext context) => Opacity(
      opacity: unlocked ? 1 : .45,
      child: Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: BeePaper.soft,
                    borderRadius: BorderRadius.circular(16)),
                child: IconTheme(
                    data: const IconThemeData(size: 30, color: BeePaper.ink),
                    child: icon)),
            const SizedBox(width: 22),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 25, fontWeight: FontWeight.w600)),
                  if (amount.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    BeePosterAmount(amount, size: 32)
                  ],
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(date,
                        style: const TextStyle(
                            fontSize: 19, color: BeePaper.muted))
                  ],
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(note,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 21, height: 1.7, color: BeePaper.muted))
                  ]
                ]))
          ])));
}
