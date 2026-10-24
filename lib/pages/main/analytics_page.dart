import '../ai/ai_chat_page.dart';
import '../report/annual_report_page.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../widgets/ui/wheel_date_picker.dart';
import '../../widgets/ui/toast.dart';
import '../../services/export/share_poster_service.dart';
import '../../presentation/v4/bindings/analytics_data.dart';
import '../../presentation/v4/bindings/analytics_content.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
part '../../presentation/v4/bindings/analytics_actions.dart';

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
    final l = AppLocalizations.of(context),
        repo = ref.watch(repositoryProvider),
        id = ref.watch(currentLedgerIdProvider),
        month = ref.watch(selectedMonthProvider),
        sd = ref.watch(currentMonthStartDayProvider),
        tick = ref.watch(statsRefreshProvider);
    final key = (
      repo,
      id,
      month,
      _scope,
      _type,
      sd,
      tick,
      DateUtils.dateOnly(DateTime.now())
    );
    if (_queryKey != key) {
      _queryKey = key;
      _query = loadAnalyticsData(repo,
          ledgerId: id,
          scope: _scope,
          type: _type,
          selMonth: month,
          startDay: sd);
    }
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.tabInsights,
          leading: widget.showBack ? const BackButton() : null,
          actions: [
            BeeIconButton(
                label: l.aiChatTitle,
                icon: const BeeLineIcon('Sparkles'),
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
          padding: const EdgeInsets.fromLTRB(17, 0, 17, 8),
          child: BeeSegmented<String>(
              value: _scope,
              items: [
                BeeSegment('month', l.analyticsMonth),
                BeeSegment('year', l.analyticsYear),
                BeeSegment('all', l.analyticsAll)
              ],
              onChanged: (v) => setState(() => _scope = v))),
      Expanded(
          child: FutureBuilder<AnalyticsResult>(
              key: ValueKey('analytics_$_type'),
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
                if (snapshot.connectionState == ConnectionState.waiting ||
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return AnalyticsContent(
                    data: snapshot.data!,
                    scope: _scope,
                    type: _type,
                    month: month,
                    viewLabel: _viewLabel(l),
                    showPie: _showPieChart,
                    headerDismissed: _localHeaderDismissed ||
                        (ref
                                .watch(analyticsHeaderHintDismissedProvider)
                                .valueOrNull ??
                            false),
                    chartDismissed: _localChartDismissed ||
                        (ref
                                .watch(analyticsChartHintDismissedProvider)
                                .valueOrNull ??
                            false),
                    onAnnual: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                AnnualReportPage(initialYear: month.year))),
                    onShare: _share,
                    onPeriod: _scope == 'all' ? null : _showPeriodPicker,
                    onView: _showTypeMenu,
                    onSwitch: _cycleTypeForward,
                    onTogglePie: () =>
                        setState(() => _showPieChart = !_showPieChart),
                    onDismissHeader: () => _dismissHint(false),
                    onDismissChart: () => _dismissHint(true),
                    onRecalculate: _runRecalcForeignTx,
                    onPrevious: _onChartSwipeRight,
                    onNext: _onChartSwipeLeft,
                    onChartSwipe: (previous) {
                      previous ? _onChartSwipeRight() : _onChartSwipeLeft();
                      _chartSwiped = true;
                    },
                    onBodySwipe: (previous) {
                      if (_chartSwiped) {
                        _chartSwiped = false;
                        return;
                      }
                      previous ? _cycleTypeBackward() : _cycleTypeForward();
                    });
              }))
    ]));
  }
}
