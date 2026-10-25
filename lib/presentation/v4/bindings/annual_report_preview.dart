import 'package:beecount_business_ui/annual_report.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../pages/report/annual_report_page.dart';
import '../../../providers.dart';
import '../../../utils/currencies.dart';

/// Reads the production annual projection without generating or sharing a file.
class LiveAnnualReportPreview extends ConsumerWidget {
  const LiveAnnualReportPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), year = DateTime.now().year;
    final ledger = ref.watch(currentLedgerProvider).valueOrNull;
    final data = ref.watch(annualReportDataProvider(year));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => BeeStatus(label: '$error', tone: BeeTone.error),
          data: (value) {
            if (value == null) return BeeEmptyState(title: l.commonEmpty);
            final number = NumberFormat('#,##0.00', l.localeName);
            String money(double amount) =>
                '${getCurrencySymbol(value.currencyCode)}${number.format(amount)}';
            return BeeAnnualOverview(
                year: '$year',
                title: l.annualReportPage1Title,
                subtitle: '${ledger?.name ?? ''} · ${value.currencyCode}',
                expenseLabel: l.annualReportTotalExpense,
                expense: money(value.totalExpense),
                incomeLabel: l.annualReportTotalIncome,
                income: money(value.totalIncome),
                savingsLabel: l.annualReportNetSavings,
                savings: money(value.netSavings));
          }),
      const SizedBox(height: 12),
      BeeButton(
          label: l.annualReportTitle,
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => AnnualReportPage(initialYear: year)))),
    ]);
  }
}
