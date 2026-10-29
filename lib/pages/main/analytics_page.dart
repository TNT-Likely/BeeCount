import '../ai/ai_chat_page.dart';
import '../report/annual_report_page.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../shared/pickers/wheel_date_picker.dart';
import '../../services/export/share_poster_service.dart';
import '../../utils/month_range.dart';
import 'analytics/bindings/analytics_data.dart';
import 'analytics/widgets/analytics_content.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
part 'analytics/bindings/analytics_actions.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key, this.showBack = false});
  final bool showBack;
  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage>
    with _AnalyticsActions {
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 350;
    final l = AppLocalizations.of(context),
        repo = ref.watch(repositoryProvider),
        id = ref.watch(currentLedgerIdProvider),
        month = ref.watch(selectedMonthProvider),
        sd = ref.watch(currentMonthStartDayProvider),
        tick = ref.watch(statsRefreshProvider);
    final key =
        (repo, id, month, _scope, sd, tick, DateUtils.dateOnly(DateTime.now()));
    if (_queryKey != key) {
      _queryKey = key;
      _query = loadAnalyticsViews(repo,
          ledgerId: id, scope: _scope, selMonth: month, startDay: sd);
    }
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.tabInsights,
          compact: true,
          padding:
              EdgeInsets.symmetric(horizontal: compact ? 17 : 20, vertical: 8),
          leading: widget.showBack ? const BackButton() : null,
          actions: [
            TextButton.icon(
                label: const Text('AI', style: TextStyle(fontSize: 13)),
                icon: const BeeLineIcon('Sparkles', size: 17),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const AIChatPage()))),
            BeeIconButton(
                label: l.sharePosterShare,
                icon: const BeeLineIcon('Share2'),
                onPressed: _share)
          ]),
      Padding(
          padding:
              EdgeInsets.fromLTRB(compact ? 15 : 19, 0, compact ? 15 : 19, 2),
          child: BeeCompactTabs<String>(
              trackHeight: compact ? 29 : 31,
              fontSize: compact ? 11 : 12,
              value: _scope,
              items: [
                BeeSegment('month', l.analyticsMonth),
                BeeSegment('year', l.analyticsYear),
                BeeSegment('all', l.analyticsAll)
              ],
              onChanged: (v) => setState(() => _scope = v))),
      Expanded(
          child: FutureBuilder<Map<String, AnalyticsResult>>(
              key: ValueKey((
                repo,
                id,
                month,
                _scope,
                sd,
                DateUtils.dateOnly(DateTime.now())
              )),
              future: _query,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return BeeEmptyState(
                      title: l.commonError,
                      message: '${snapshot.error}',
                      action: BeeButton(
                          label: l.v4RecordingRetry,
                          onPressed: () => setState(() => _queryKey = null)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return AnalyticsContent(
                    data: snapshot.data![_type]!,
                    scope: _scope,
                    type: _type,
                    month: month,
                    onTypeChanged: _selectType,
                    onAnnual: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                AnnualReportPage(initialYear: month.year))),
                    onShare: _share,
                    onPeriod: _scope == 'all' ? null : _showPeriodPicker,
                    onRecalculate: _runRecalcForeignTx,
                    onPrevious: _scope == 'all' ? null : () => _movePeriod(-1),
                    onNext: _canGoNext ? () => _movePeriod(1) : null);
              }))
    ]));
  }
}
