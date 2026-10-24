import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../pages/main/analytics_page.dart';
import '../../../providers.dart';
import '../../../widgets/biz/format_money.dart';
import 'analytics_data.dart';

class LiveAnalyticsPreview extends ConsumerStatefulWidget {
  const LiveAnalyticsPreview({super.key});
  @override
  ConsumerState<LiveAnalyticsPreview> createState() =>
      _LiveAnalyticsPreviewState();
}

class _LiveAnalyticsPreviewState extends ConsumerState<LiveAnalyticsPreview> {
  Object? queryKey;
  Future<AnalyticsResult>? query;
  @override
  Widget build(BuildContext context) {
    final id = ref.watch(currentLedgerIdProvider),
        sd = ref.watch(currentMonthStartDayProvider),
        tick = ref.watch(statsRefreshProvider),
        repo = ref.watch(repositoryProvider),
        now = DateTime.now(),
        month = DateTime(DateTime.now().year, DateTime.now().month),
        hide = ref.watch(hideAmountsProvider),
        base = ref.watch(currentLedgerCurrencyProvider);
    final key = (id, sd, tick, repo, month, DateUtils.dateOnly(now));
    if (queryKey != key) {
      queryKey = key;
      query = loadAnalyticsData(repo,
          ledgerId: id,
          scope: 'month',
          type: 'expense',
          selMonth: month,
          startDay: sd);
    }
    String money(double v) => hide
        ? '****'
        : formatDisplayAmount(v,
            signed: false, showCurrency: true, currencyCode: base);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实洞察汇总（只读）'),
      const SizedBox(height: 8),
      FutureBuilder<AnalyticsResult>(
          future: query,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('${snapshot.error}');
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final d = snapshot.data!;
            return BeeAnalyticsSummary(
                period: '${now.year}-${now.month.toString().padLeft(2, '0')}',
                viewLabel: '支出',
                totalLabel: '总支出：',
                total: money(d.total),
                countLabel: '记账笔数',
                count: '${d.count}',
                averageLabel: '日均',
                average: money(d.average),
                onView: () {});
          }),
      const SizedBox(height: 12),
      BeeButton(
          label: '打开真实洞察',
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const AnalyticsPage(showBack: true))))
    ]);
  }
}
