import 'package:beecount_business_ui/annual_report.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/app_localizations_resolver.dart';

/// Controlled synthetic values. This gallery never invokes a native export.
class AnnualReportSample extends StatefulWidget {
  const AnnualReportSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<AnnualReportSample> createState() => _AnnualReportSampleState();
}

class _AnnualReportSampleState extends State<AnnualReportSample> {
  String event = '合成示例；保存和分享只记录本地回调';
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSurface(child: Text(event)),
      const SizedBox(height: 12),
      BeeAnnualOverview(
          year: '2026',
          title: l.annualReportPage1Title,
          subtitle: 'QA 日常账本 · TWD',
          expenseLabel: l.annualReportTotalExpense,
          expense: 'NT\$38,286.50',
          incomeLabel: l.annualReportTotalIncome,
          income: 'NT\$120,000.00',
          savingsLabel: l.annualReportNetSavings,
          savings: '+NT\$81,713.50',
          brand: Image.asset('assets/logo2.png', width: 48, height: 48)),
      const SizedBox(height: 12),
      BeeAnnualRank(
          rank: 1,
          title: 'QA 餐饮与日常生活',
          amount: 'NT\$13,246.50',
          percentage: '34.6%',
          fraction: .346,
          icon: const BeeLineIcon('Utensils')),
      const SizedBox(height: 12),
      BeeAnnualComparisonRow(
          month: '10',
          income: 'NT\$12,000',
          expense: 'NT\$3,286',
          incomeRatio: 1,
          expenseRatio: .274,
          incomeLabel: l.analyticsIncome,
          expenseLabel: l.analyticsExpense,
          highlights: [l.annualReportHighestIncome]),
      const SizedBox(height: 12),
      BeeAnnualTrend(
          points: List.generate(
              12,
              (i) => BeeAnnualTrendPoint(
                  label: '${i + 1}',
                  amount: 'TWD ${300 + i * 50}',
                  fraction: (i + 1) / 12))),
      const SizedBox(height: 12),
      BeeAnnualMoment(
          label: l.annualReportLargestExpense,
          amount: '\$100.00',
          date: '10/20',
          note: 'QA 原币种 USD；比较最大单笔时使用折算金额',
          icon: const BeeLineIcon('ArrowDown')),
      const SizedBox(height: 12),
      BeeAnnualAchievement(
          title: l.annualReportAchievementConsistent,
          description: l.annualReportAchievementConsistentDesc(28),
          icon: const BeeLineIcon('Flame'),
          unlocked: true),
      const SizedBox(height: 12),
      BeeButton(
          label: l.annualReportShareButton,
          onPressed: () => setState(() => event = '已调用合成年度海报预览；不打开系统分享')),
      if (widget.liveData != null) ...[
        const SizedBox(height: 18),
        widget.liveData!
      ],
    ]);
  }
}
