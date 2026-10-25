import 'package:beecount_business_ui/share_card.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/export/share_poster_types.dart';
import '../../../widgets/posters/app_promo_poster.dart';
import '../../../widgets/posters/ledger_summary_poster.dart';
import '../../../widgets/posters/month_summary_poster.dart';
import '../../../widgets/posters/user_profile_poster.dart';
import '../../../widgets/posters/year_summary_poster.dart';

/// Controlled synthetic examples; export callbacks only update local feedback.
class ShareCardSample extends StatefulWidget {
  const ShareCardSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<ShareCardSample> createState() => _ShareCardSampleState();
}

class _ShareCardSampleState extends State<ShareCardSample> {
  String selected = 'profile', event = 'QA local share callbacks';
  bool hidden = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        color = Theme.of(context).colorScheme.primary;
    final Widget art = switch (selected) {
      'app' => AppPromoPoster(l10n: l, primaryColor: color),
      'month' => MonthSummaryPoster(
          primaryColor: color,
          hideIncome: hidden,
          data: const MonthSummaryPosterData(
              year: 2026,
              month: 10,
              recordCount: 48,
              totalIncome: 6200,
              totalExpense: 3100,
              topExpenseCategories: [],
              topIncomeCategories: [],
              avgDailyExpense: 124,
              balance: 3100)),
      'year' => YearSummaryPoster(
          primaryColor: color,
          hideIncome: hidden,
          data: const YearSummaryPosterData(
              year: 2026,
              recordDays: 120,
              recordCount: 360,
              totalIncome: 62000,
              totalExpense: 31000,
              topExpenseCategories: [],
              topIncomeCategories: [],
              avgMonthlyExpense: 3100,
              avgMonthlyIncome: 6200,
              balance: 31000)),
      'ledger' => LedgerSummaryPoster(
          primaryColor: color,
          hideIncome: hidden,
          data: const LedgerSummaryPosterData(
              ledgerName: 'QA ledger',
              recordDays: 120,
              recordCount: 360,
              totalIncome: 62000,
              totalExpense: 31000,
              topExpenseCategories: [],
              topIncomeCategories: [],
              balance: 31000)),
      _ => UserProfilePoster(
          l10n: l,
          primaryColor: color,
          data: const UserProfilePosterData(
              recordDays: 120,
              recordCount: 360,
              ledgerCount: 2,
              ledgerName: 'QA ledger')),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSurface(child: Text(event)),
      const SizedBox(height: 12),
      SizedBox(
          height: 760,
          child: BeeShareCard(
            title: l.v4ShareCardTitle,
            closeLabel: l.commonClose,
            saveLabel: l.sharePosterSave,
            shareLabel: l.sharePosterShare,
            generatingLabel: l.sharePosterGenerating,
            retryLabel: l.helpCenterRetry,
            templates: [
              BeeShareCardTemplate('profile', l.v4ShareCardProfile),
              BeeShareCardTemplate('app', l.mineShareApp),
              BeeShareCardTemplate('month', l.analyticsMonth),
              BeeShareCardTemplate('year', l.analyticsYear),
              BeeShareCardTemplate('ledger', l.sharePosterLedgerName)
            ],
            selected: selected,
            onTemplate: (id) => setState(() => selected = id),
            preview: FittedBox(
                fit: BoxFit.contain,
                child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.noScaling,
                        padding: EdgeInsets.zero),
                    child: art)),
            hideIncome: hidden,
            privacyLabel: ['month', 'year', 'ledger'].contains(selected)
                ? (hidden ? l.sharePosterShowIncome : l.sharePosterHideIncome)
                : null,
            onPrivacy: () => setState(() => hidden = !hidden),
            onClose: () => setState(() => event = 'QA · ${l.commonClose}'),
            onSave: () => setState(() => event = 'QA · ${l.sharePosterSave}'),
            onShare: (_) =>
                setState(() => event = 'QA · ${l.sharePosterShare}'),
          )),
      if (widget.liveData != null) ...[
        const SizedBox(height: 16),
        widget.liveData!
      ],
    ]);
  }
}
