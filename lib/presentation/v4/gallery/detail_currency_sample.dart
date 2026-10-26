import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_business_ui/detail_currency.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/app_localizations_resolver.dart';

/// Local controlled states; this widget never reads a repository or changes a
/// real quote, ledger or transaction. The host may attach a read-only preview.
class DetailCurrencySample extends StatefulWidget {
  const DetailCurrencySample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<DetailCurrencySample> createState() => _DetailCurrencySampleState();
}

class _DetailCurrencySampleState extends State<DetailCurrencySample> {
  String selected = 'complete';
  bool hidden = false;
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    final missing = selected == 'missing', stale = selected == 'stale';
    final amount = hidden
        ? '••••'
        : missing
            ? '—'
            : '152.00';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('局部合成示例 · 当前账本 CNY；不更改真实汇率和历史账单'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 6, children: [
        for (final item in [
          ('complete', '完整'),
          ('missing', '缺失'),
          ('stale', '陈旧')
        ])
          BeeChoiceChip(
              label: item.$2,
              selected: selected == item.$1,
              onSelected: (_) => setState(() => selected = item.$1))
      ]),
      const SizedBox(height: 8),
      BeeToggleRow(
          title: '隐私',
          value: hidden,
          onChanged: (value) => setState(() => hidden = value)),
      const SizedBox(height: 12),
      BeeResourceHero(
          title: 'QA 分类 / 标签汇总',
          caption: '全部账本 · CNY / USD',
          icon: const BeeLineIcon('ChartNoAxesCombined'),
          amountLabel: l.tagDetailTotalExpense,
          prefix: hidden || missing ? '' : '¥',
          amount: amount,
          metrics: [
            BeeResourceMetric(
                label: l.tagDetailTotalCount, value: l.tagTransactionCount(2)),
            BeeResourceMetric(
                label: l.categoryDetailAverageAmount,
                value: hidden
                    ? '••••'
                    : missing
                        ? '—'
                        : '¥76.00'),
            BeeResourceMetric(
                label: l.v4DetailShare,
                value: hidden
                    ? '••••'
                    : missing
                        ? '—'
                        : '100.0%'),
          ]),
      const SizedBox(height: 12),
      BeeDetailCurrencyNotice(
          scopeLabel: l.v4DetailConvertedScope('CNY'),
          missingLabel: missing ? l.v4DetailMissingConversion(1, 'USD') : null,
          rateDateLabel: stale ? l.v4DetailRatesStale('2020-01-01') : null,
          stale: stale),
      if (widget.liveData != null) ...[
        const SizedBox(height: 18),
        widget.liveData!,
      ]
    ]);
  }
}
