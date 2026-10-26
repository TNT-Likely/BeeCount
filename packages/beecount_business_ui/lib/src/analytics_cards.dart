import 'dart:math' as math;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'finance_components.dart' show BeeRankItem;

class BeeAnalyticsShare {
  const BeeAnalyticsShare(
      {required this.label, required this.fraction, required this.valueLabel});
  final String label, valueLabel;
  final double fraction;
}

/// One selected theme-colored wedge; other categories remain neutral.
class BeeAnalyticsProportion extends StatelessWidget {
  const BeeAnalyticsProportion(
      {super.key,
      required this.items,
      required this.selected,
      required this.onSelected,
      required this.hint});
  final List<BeeAnalyticsShare> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final String hint;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final index = selected.clamp(0, items.length - 1),
        item = items[index],
        muted = Theme.of(context).hintColor,
        accent = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(builder: (context, bounds) {
      final compact = bounds.maxWidth < 280, diameter = compact ? 111.0 : 132.0;
      return Column(children: [
        Row(children: [
          Semantics(
              image: true,
              label: '${item.label} ${item.valueLabel}',
              child: SizedBox(
                  width: diameter,
                  height: diameter,
                  child: CustomPaint(
                      painter: _SharePainter(
                          item.fraction, accent, BeeCardTheme.of(context).soft),
                      child: Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: muted)),
                        const SizedBox(height: 3),
                        FittedBox(
                            child: Text(item.valueLabel,
                                style: TextStyle(
                                    fontSize: compact ? 20 : 22,
                                    fontWeight: FontWeight.w600)))
                      ]))))),
          SizedBox(width: compact ? 15 : 19),
          Expanded(
              child: Column(children: [
            for (var i = 0; i < items.length; i++)
              Semantics(
                  selected: i == index,
                  child: InkWell(
                      key: ValueKey('analytics-share-$i'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onSelected(i),
                      child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: compact ? 29 : 32),
                          child: Row(children: [
                            Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == index
                                        ? accent
                                        : muted.withValues(alpha: .25))),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(items[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: compact ? 10 : 11))),
                            const SizedBox(width: 6),
                            Text(items[i].valueLabel,
                                style: TextStyle(
                                    fontSize: compact ? 10 : 11,
                                    fontWeight: FontWeight.w500))
                          ]))))
          ]))
        ]),
        const SizedBox(height: 10),
        Text(hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: muted))
      ]);
    });
  }
}

class _SharePainter extends CustomPainter {
  _SharePainter(this.fraction, this.accent, this.track);
  final double fraction;
  final Color accent, track;
  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .114;
    final arc = (Offset.zero & size).deflate(size.width * .106);
    canvas.drawArc(arc, 0, 2 * math.pi, false, pen..color = track);
    if (fraction.isFinite) {
      canvas.drawArc(arc, -math.pi / 2, fraction.clamp(0, 1) * 2 * math.pi,
          false, pen..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _SharePainter old) =>
      fraction != old.fraction || accent != old.accent || track != old.track;
}

/// Explicit detail and expansion targets; prepared icons include custom images.
class BeeAnalyticsRankingList extends StatelessWidget {
  const BeeAnalyticsRankingList(
      {super.key,
      required this.items,
      required this.expanded,
      required this.onExpand,
      required this.onDetail});
  final List<BeeRankItem> items;
  final Set<String> expanded;
  final ValueChanged<String> onExpand, onDetail;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(height: 1, color: BeeCardTheme.of(context).divider),
          _row(context, items[i]),
          if (expanded.contains(items[i].id))
            Padding(
                padding: const EdgeInsets.only(left: 37, bottom: 10),
                child: Column(children: [
                  for (final child in items[i].children)
                    InkWell(
                        key: ValueKey('analytics-child-${child.id}'),
                        onTap: () => onDetail(child.id),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 43),
                            child: Row(children: [
                              SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Center(child: child.icon)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(child.label,
                                      style: const TextStyle(fontSize: 11))),
                              const SizedBox(width: 6),
                              Text(child.amount,
                                  style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 5),
                              const BeeLineIcon('ChevronRight', size: 12)
                            ])))
                ]))
        ]
      ]);
  Widget _row(BuildContext context, BeeRankItem item) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 66),
      child: Row(children: [
        InkWell(
            key: ValueKey('analytics-category-icon-${item.id}'),
            onTap: () => onDetail(item.id),
            child: SizedBox(
                width: 38, height: 44, child: Center(child: item.icon))),
        const SizedBox(width: 7),
        Expanded(
            child: InkWell(
                key: ValueKey('analytics-category-detail-${item.id}'),
                onTap: () => onDetail(item.id),
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12))),
                            const SizedBox(width: 9),
                            Flexible(
                                child: Text(item.amount,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12)))
                          ]),
                          const SizedBox(height: 8),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                  value: item.fraction.clamp(0, 1),
                                  minHeight: 3,
                                  color: Theme.of(context).colorScheme.primary,
                                  backgroundColor:
                                      BeeCardTheme.of(context).soft))
                        ])))),
        if (item.description != null)
          Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(item.description!,
                  style: TextStyle(
                      fontSize: 10, color: Theme.of(context).hintColor))),
        SizedBox(
            width: 27,
            child: IconButton(
                key: ValueKey('analytics-category-expand-${item.id}'),
                padding: EdgeInsets.zero,
                tooltip: item.label,
                onPressed: () => item.children.isNotEmpty
                    ? onExpand(item.id)
                    : onDetail(item.id),
                icon: BeeLineIcon(
                    item.children.isEmpty
                        ? 'ChevronRight'
                        : expanded.contains(item.id)
                            ? 'ChevronUp'
                            : 'ChevronDown',
                    size: 14)))
      ]));
}

class BeeAnalyticsComposition extends StatelessWidget {
  const BeeAnalyticsComposition(
      {super.key,
      required this.incomeLabel,
      required this.expenseLabel,
      required this.income,
      required this.expense,
      required this.onIncome,
      required this.onExpense});
  final String incomeLabel, expenseLabel, income, expense;
  final VoidCallback onIncome, onExpense;
  @override
  Widget build(BuildContext context) => Row(children: [
        _cell(context, incomeLabel, income, onIncome),
        const SizedBox(width: 12),
        _cell(context, expenseLabel, expense, onExpense)
      ]);
  Widget _cell(BuildContext context, String label, String value,
          VoidCallback onTap) =>
      Expanded(
          child: Material(
              color: BeeCardTheme.of(context).soft,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(label,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(context).hintColor))),
                              BeeLineIcon('ChevronRight',
                                  size: 12, color: Theme.of(context).hintColor)
                            ]),
                            const SizedBox(height: 7),
                            FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(value,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600)))
                          ])))));
}
