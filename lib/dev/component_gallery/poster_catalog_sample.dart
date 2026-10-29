import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/share_posters.dart';
import 'package:flutter/material.dart';
import '../../pages/report/annual_report_page.dart';
import '../../services/export/share_poster_types.dart';
import '../../utils/app_localizations_resolver.dart';
import '../../pages/shared/branding/bee_artwork.dart';
import '../../pages/report/annual/bindings/annual_poster_projection.dart';
import '../../pages/shared/sharing/bindings/app_promo_poster.dart';
import '../../pages/shared/sharing/bindings/ledger_summary_poster.dart';
import '../../pages/shared/sharing/bindings/month_summary_poster.dart';
import '../../pages/shared/sharing/bindings/user_profile_poster.dart';
import '../../pages/shared/sharing/bindings/year_summary_poster.dart';

/// The original gallery values, laid out together. No database or export calls.
/// Current-ledger projections remain in the existing share/annual live sections.
class PosterCatalogSample extends StatefulWidget {
  const PosterCatalogSample({super.key});
  @override
  State<PosterCatalogSample> createState() => _PosterCatalogSampleState();
}

class _PosterCatalogSampleState extends State<PosterCatalogSample> {
  bool hidden = false;
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context)),
        color = Theme.of(context).colorScheme.primary;
    const month = MonthSummaryPosterData(
        year: 2026,
        month: 10,
        recordCount: 48,
        totalIncome: 6200,
        totalExpense: 3100,
        topExpenseCategories: [
          CategoryTotal(name: '餐饮', total: 3100, percentage: 1)
        ],
        topIncomeCategories: [],
        avgDailyExpense: 124,
        balance: 3100);
    const year = YearSummaryPosterData(
        year: 2026,
        recordDays: 120,
        recordCount: 360,
        totalIncome: 62000,
        totalExpense: 31000,
        topExpenseCategories: [
          CategoryTotal(name: '餐饮', total: 31000, percentage: 1)
        ],
        topIncomeCategories: [],
        avgMonthlyExpense: 3100,
        avgMonthlyIncome: 6200,
        balance: 31000);
    final posters = <String, Widget>{
      '个人档案': UserProfilePoster(
          l10n: l,
          primaryColor: color,
          data: const UserProfilePosterData(
              recordDays: 120,
              recordCount: 360,
              ledgerCount: 2,
              ledgerName: 'QA ledger')),
      '应用分享': AppPromoPoster(l10n: l, primaryColor: color),
      '月度总结': MonthSummaryPoster(
          primaryColor: color, hideIncome: hidden, data: month),
      '年度总结': YearSummaryPoster(
          primaryColor: color, hideIncome: hidden, data: year),
      '账本总结': LedgerSummaryPoster(
          primaryColor: color,
          hideIncome: hidden,
          data: const LedgerSummaryPosterData(
              ledgerName: 'QA ledger',
              recordDays: 120,
              recordCount: 360,
              totalIncome: 62000,
              totalExpense: 31000,
              topExpenseCategories: [
                CategoryTotal(name: '餐饮', total: 31000, percentage: 1)
              ],
              topIncomeCategories: [],
              balance: 31000)),
      '年度长图': AnnualReportPoster(
          primaryColor: color,
          hideIncome: hidden,
          now: DateTime(2026, 10, 25),
          data: AnnualReportData(
              year: 2026,
              totalDays: 120,
              totalRecords: 360,
              totalIncome: 62000,
              totalExpense: 31000,
              netSavings: 31000,
              topExpenseCategories: const [
                CategoryTotal(name: '餐饮', total: 31000, percentage: 1)
              ],
              monthlyData: List.generate(
                  12,
                  (i) =>
                      (month: i + 1, income: 62000 / 12, expense: 31000 / 12)),
              maxConsecutiveDays: 28)),
      '账单小票': BeeReceiptPoster(
          brand: Row(mainAxisSize: MainAxisSize.min, children: [
            BeeIcon(size: 26, color: color),
            const SizedBox(width: 6),
            Text(l.sharePosterAppName, style: const TextStyle(fontSize: 15))
          ]),
          amount: '−¥32.00',
          currency: 'CNY',
          kind: l.homeExpense,
          rows: const [
            BeeReceiptRow('分类', Text('餐饮 / 午餐')),
            BeeReceiptRow('日期', Text('2026.10.20 12:34')),
            BeeReceiptRow('账户', Text('QA 现金账户'))
          ],
          noteLabel: l.importFieldNote,
          note: const Text('QA 一顿简单的午餐'),
          footer: l.transactionReceiptFooter),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('沿用原目录的受控样例值；全部平铺。真实数据继续使用“分享卡与原海报预览”和“年度账单七段内容”中的当前账本入口。',
          style: TextStyle(fontSize: 11)),
      SwitchListTile(
          title: const Text('隐藏样例海报收入'),
          value: hidden,
          onChanged: (v) => setState(() => hidden = v)),
      for (final entry in posters.entries) ...[
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: Text(entry.key,
                  key: ValueKey('poster-label-${entry.key}'),
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          TextButton(
              onPressed: () => showBeeDialog<void>(context,
                  title: entry.key,
                  child: LayoutBuilder(
                      builder: (_, box) => SizedBox(
                          width: box.maxWidth,
                          child: FittedBox(
                              alignment: Alignment.topCenter,
                              fit: BoxFit.fitWidth,
                              child: SizedBox(
                                  width: entry.key == '账单小票' ? 340 : 720,
                                  child: entry.value))))),
              child: const Text('放大查看'))
        ]),
        SizedBox(
            height: entry.key == '年度长图' ? 420 : 320,
            child: ClipRect(
                child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                        width: entry.key == '账单小票' ? 340 : 720,
                        child: entry.value)))),
      ],
      const SizedBox(height: 18),
      const Text('海报片段：高光事件与未解锁状态'),
      SizedBox(
          height: 210,
          child: FittedBox(
              child: SizedBox(
                  width: 620,
                  child: Column(children: [
                    const BeePosterMoment(
                        label: '最大支出',
                        amount: '¥32.00',
                        date: '2026.10.20',
                        note: 'QA 一顿简单的午餐',
                        icon: Icon(Icons.restaurant_outlined)),
                    BeePosterMoment(
                        label: '待达成',
                        amount: '28天',
                        date: '连续记录',
                        note: '未解锁展示',
                        unlocked: false,
                        icon: Icon(Icons.local_fire_department_outlined,
                            color: color)),
                  ])))),
    ]);
  }
}
