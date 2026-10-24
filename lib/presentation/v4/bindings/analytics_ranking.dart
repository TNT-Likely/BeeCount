import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/transaction/category_detail_page.dart';
import '../../../providers.dart';
import '../../../utils/category_utils.dart';
import '../../../widgets/biz/format_money.dart';
import 'analytics_data.dart';
import 'recording_category_icon.dart';

class AnalyticsRanking extends ConsumerStatefulWidget {
  const AnalyticsRanking(
      {super.key,
      required this.data,
      required this.scope,
      required this.month});
  final AnalyticsResult data;
  final String scope;
  final DateTime month;
  @override
  ConsumerState<AnalyticsRanking> createState() => _AnalyticsRankingState();
}

class _AnalyticsRankingState extends ConsumerState<AnalyticsRanking> {
  final expanded = <String>{};
  @override
  Widget build(BuildContext context) {
    final hide = ref.watch(hideAmountsProvider);
    String amount(double n) =>
        hide ? '****' : formatMoneyCompact(n, signed: false, maxDecimals: 0);
    BeeRankItem item(int? id, String name, dynamic category, double total,
            [List<BeeRankItem> children = const []]) =>
        BeeRankItem(
            id: '$id',
            label: CategoryUtils.getDisplayName(name, context),
            amount: amount(total),
            fraction: widget.data.total == 0 ? 0 : total / widget.data.total,
            description: hide
                ? '****'
                : '${(widget.data.total == 0 ? 0 : total / widget.data.total * 100).toStringAsFixed(1)}%',
            icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: BeeCardTheme.of(context).soft,
                    borderRadius: BorderRadius.circular(11)),
                child: Center(
                    child: category == null
                        ? BeeLineIcon('Shapes',
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface)
                        : RecordingCategoryIcon(
                            category: category,
                            color: Theme.of(context).colorScheme.onSurface))),
            children: children);
    final list = widget.data.categories
        .map((e) => item(
            e.id,
            e.name,
            e.category,
            e.total,
            e.subCategories
                .where((s) => s.total > 0)
                .map((s) => item(s.id, s.name, s.category, s.total))
                .toList()))
        .toList();
    void detail(String id) {
      final categoryId = int.tryParse(id);
      if (categoryId == null) return;
      final names = <int?, String>{
        for (final e in widget.data.categories) e.id: e.name,
        for (final e in widget.data.categories)
          for (final s in e.subCategories) s.id: s.name
      };
      final name = names[categoryId]!;
      Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => CategoryDetailPage(
                  categoryId: categoryId,
                  categoryName: name,
                  startDate: widget.scope == 'all' ? null : widget.data.start,
                  endDate: widget.scope == 'all' ? null : widget.data.end,
                  periodLabel: widget.scope == 'all'
                      ? null
                      : widget.scope == 'year'
                          ? '${widget.month.year}'
                          : '${widget.month.year}.${widget.month.month.toString().padLeft(2, '0')}')));
    }

    return BeeCategoryRanking(
        items: list,
        expanded: expanded,
        onExpand: (id) => setState(() {
              expanded.contains(id) ? expanded.remove(id) : expanded.add(id);
            }),
        onDetail: detail);
  }
}

class AnalyticsPie extends ConsumerStatefulWidget {
  const AnalyticsPie({super.key, required this.data});
  final AnalyticsResult data;
  @override
  ConsumerState<AnalyticsPie> createState() => _AnalyticsPieState();
}

class _AnalyticsPieState extends ConsumerState<AnalyticsPie> {
  int selected = -1;
  @override
  void didUpdateWidget(AnalyticsPie old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) selected = -1;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        hide = ref.watch(hideAmountsProvider),
        sorted = List<AnalyticsCategory>.of(widget.data.categories)
          ..sort((a, b) => b.total.compareTo(a.total));
    const colors = [
      0xff5b8ff9,
      0xff5ad8a6,
      0xfff6bd16,
      0xffe86452,
      0xff6dc8ec,
      0xff945fb9,
      0xffff9845,
      0xff1e9493
    ];
    final entries = <({String name, double total, Color color})>[];
    double other = 0;
    for (final e in sorted) {
      if (e.total <= 0) continue;
      if (entries.length < 8) {
        entries.add((
          name: CategoryUtils.getDisplayName(e.name, context),
          total: e.total,
          color: Color(colors[entries.length])
        ));
      } else {
        other += e.total;
      }
    }
    if (other > 0) {
      entries.add((
        name: l.commonOther,
        total: other,
        color: Theme.of(context).hintColor
      ));
    }
    if (entries.isEmpty) return const SizedBox.shrink();
    String value(double n) =>
        hide ? '****' : formatMoneyCompact(n, maxDecimals: 0, signed: false);
    final chosen =
        selected >= 0 && selected < entries.length ? entries[selected] : null;
    return BeeDonutChart(
        items: entries
            .map((e) => BeeChartSlice(
                label: e.name,
                value: e.total,
                valueLabel: hide
                    ? '****'
                    : '${value(e.total)} (${(e.total / widget.data.total * 100).toStringAsFixed(1)}%)',
                color: e.color))
            .toList(),
        centerLabel:
            '${chosen?.name ?? l.analyticsTotalAmount}\n${value(chosen?.total ?? widget.data.total)}',
        selected: selected,
        onSelected: (i) => setState(() => selected = i));
  }
}
