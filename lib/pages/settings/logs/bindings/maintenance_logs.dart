import 'package:flutter/foundation.dart' show mergeSort;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/maintenance.dart';
import '../../../../services/system/logger_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/bindings/maintenance_access.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';
import 'log_share_sheet.dart';

class MaintenanceLogsControls extends ConsumerStatefulWidget {
  const MaintenanceLogsControls({super.key});
  @override
  ConsumerState<MaintenanceLogsControls> createState() => _LogsState();
}

class _LogsState extends ConsumerState<MaintenanceLogsControls> {
  var _levels = LogLevel.values.toSet();
  var _sources = LogPlatform.values.toSet();
  bool _errorsOnly = true;
  final _search = TextEditingController();
  String _keyword = '';
  bool _clearing = false, _exporting = false;
  late LoggerService _logger;
  @override
  void initState() {
    super.initState();
    _logger = ref.read(maintenanceLoggerProvider);
    _logger.addListener(_changed);
  }

  @override
  void dispose() {
    _logger.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool _isReportedError(LogEntry log) =>
      log.level == LogLevel.error &&
      // Older Android builds injected this exact smoke-test record on launch.
      // Keep its original entry available in All and in full-log exports.
      !(log.platform == LogPlatform.android &&
          log.tag == 'MainActivity' &&
          log.message == '这是一条 ERROR 日志');

  bool _matchesText(LogEntry log, String keyword) =>
      log.message.toLowerCase().contains(keyword) ||
      log.tag.toLowerCase().contains(keyword) ||
      (log.error?.toString().toLowerCase().contains(keyword) ?? false) ||
      (log.stackTrace?.toString().toLowerCase().contains(keyword) ?? false);

  bool get _hasFilters =>
      _sources.length != LogPlatform.values.length ||
      (!_errorsOnly && _levels.length != LogLevel.values.length);

  void _viewAll({bool keepSearch = false}) {
    setState(() {
      _errorsOnly = false;
      _levels = LogLevel.values.toSet();
      _sources = LogPlatform.values.toSet();
      if (!keepSearch) {
        _search.clear();
        _keyword = '';
      }
    });
  }

  Future<void> _chooseFilters(TargetPlatform platform) async {
    final l = AppLocalizations.of(context);
    final levels = {..._levels}, sources = {..._sources};
    final apply = await showBeeSheet<bool>(
      context,
      title: l.searchFilterTitle,
      child: StatefulBuilder(builder: (context, setDraft) {
        void toggle<T>(Set<T> draft, T item, bool selected) {
          setDraft(() {
            if (selected) {
              draft.add(item);
            } else {
              draft.remove(item);
            }
          });
        }

        return SingleChildScrollView(
          child: BeeMaintenanceLogFilters(
            levelLabel: l.logCenterFilterLevel,
            sourceLabel: l.logCenterFilterPlatform,
            levels: [
              if (!_errorsOnly)
                for (final level in LogLevel.values)
                  BeeMaintenanceFilterChoice(
                    key: ValueKey('maintenance-level-${level.name}'),
                    label: level.displayName,
                    selected: levels.contains(level),
                    onSelected: (value) => toggle(levels, level, value),
                  ),
            ],
            sources: [
              for (final source in LogPlatform.values)
                if (!(platform == TargetPlatform.android &&
                        source == LogPlatform.ios) &&
                    !(platform == TargetPlatform.iOS &&
                        source == LogPlatform.android))
                  BeeMaintenanceFilterChoice(
                    key: ValueKey('maintenance-source-${source.name}'),
                    label: source.displayName,
                    selected: sources.contains(source),
                    onSelected: (value) => toggle(sources, source, value),
                  ),
            ],
          ),
        );
      }),
      footer: Builder(
          builder: (sheetContext) => BeeButton(
                key: const ValueKey('maintenance-apply-filters'),
                label: l.commonConfirm,
                onPressed: () => Navigator.pop(sheetContext, true),
              )),
    );
    if (apply == true && mounted) {
      setState(() {
        _levels = levels;
        _sources = sources;
      });
    }
  }

  Future<void> _export(BuildContext anchor) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await showLogShareSheet(anchor, _logger);
    } catch (_) {
      if (mounted) {
        showBeeToast(
            context, AppLocalizations.of(context).logCenterExportFailed,
            tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _clear() async {
    if (_clearing) return;
    setState(() => _clearing = true);
    final l = AppLocalizations.of(context);
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => BeeDialog(
                  showClose: false,
                  title: Text(l.logCenterClearConfirmTitle),
                  content: Text(l.logCenterClearConfirmMessage),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.commonCancel)),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l.commonConfirm))
                  ]));
      if (confirmed == true && mounted) {
        _logger.clear();
        showBeeToast(context, l.logCenterCleared, tone: BeeTone.success);
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _copy(LogEntry log) async {
    try {
      await Clipboard.setData(ClipboardData(text: log.toFormattedString()));
      if (mounted) {
        showBeeToast(context, AppLocalizations.of(context).logCenterCopied,
            tone: BeeTone.success);
      }
    } catch (_) {
      if (mounted) {
        showBeeToast(context, AppLocalizations.of(context).commonFailed,
            tone: BeeTone.error);
      }
    }
  }

  void _details(LogEntry log) {
    showDialog<void>(
        context: context,
        builder: (ctx) => BeeDialog(
                showClose: false,
                title: Text('[${log.tag}]'),
                content: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      BeeMaintenanceDetailRow(
                          label: '时间', value: log.timestamp.toString()),
                      BeeMaintenanceDetailRow(
                          label: '级别', value: log.level.displayName),
                      BeeMaintenanceDetailRow(
                          label: '平台', value: log.platform.displayName),
                      const Divider(),
                      Text(log.message, style: const TextStyle(fontSize: 14)),
                      if (log.error != null) ...[
                        const Divider(),
                        Text('Error: ${log.error}',
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12))
                      ],
                      if (log.stackTrace != null) ...[
                        const Divider(),
                        Text('Stack Trace:\n${log.stackTrace}',
                            style: const TextStyle(
                                fontSize: 10, fontFamily: 'monospace'))
                      ],
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => _copy(log), child: const Text('复制')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('关闭'))
                ]));
  }

  Widget _emptyState(
    AppLocalizations l, {
    required int total,
    required int errorCount,
    required int otherLevels,
    required int searchMatches,
  }) {
    if (total == 0) {
      return BeeEmptyState(
          title: l.logCenterEmpty, icon: const BeeLineIcon('Inbox', size: 36));
    }
    final noErrors = _errorsOnly && errorCount == 0;
    final canExpandSearch =
        _errorsOnly && _keyword.trim().isNotEmpty && searchMatches > 0;
    final String action;
    if (canExpandSearch) {
      action = l.logCenterSearchAll(searchMatches);
    } else if (noErrors) {
      action = l.logCenterViewAll;
    } else {
      action = l.logCenterResetFilters;
    }
    return BeeSurface(
      padding: EdgeInsets.zero,
      child: BeeEmptyState(
        title: noErrors ? l.logCenterNoErrors : l.logCenterNoMatches,
        message: noErrors && otherLevels > 0
            ? l.logCenterOtherLogs(otherLevels)
            : null,
        icon: BeeLineIcon(noErrors ? 'CircleCheck' : 'Search', size: 32),
        action: BeeButton(
          label: action,
          kind: BeeButtonKind.secondary,
          onPressed: () => _viewAll(keepSearch: canExpandSearch),
        ),
      ),
    );
  }

  Widget _dateHeading(BuildContext context, DateTime date, DateTime now) {
    final l = AppLocalizations.of(context);
    final calendar = MaterialLocalizations.of(context);
    var label = calendar.formatShortDate(date);
    if (DateUtils.isSameDay(date, now)) {
      label = '${l.calendarToday} · ${calendar.formatShortMonthDay(date)}';
    } else if (DateUtils.isSameDay(
        date, DateTime(now.year, now.month, now.day - 1))) {
      label = '${l.commonYesterday} · ${calendar.formatShortMonthDay(date)}';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 7, 2, 8),
      child: Row(children: [
        Flexible(
            child: Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ))),
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final platform = ref.watch(maintenancePlatformProvider);
    final logs = _logger.logs;
    final errorCount = logs.where(_isReportedError).length;
    final keyword = _keyword.trim().toLowerCase();
    final matches = keyword.isEmpty
        ? logs
        : logs.where((log) => _matchesText(log, keyword)).toList();
    final visible = matches.reversed
        .where((log) =>
            _sources.contains(log.platform) &&
            (_errorsOnly ? _isReportedError(log) : _levels.contains(log.level)))
        .toList();
    // Recovered history can arrive after the first current-session records.
    mergeSort(visible, compare: (a, b) => b.timestamp.compareTo(a.timestamp));
    final now = DateTime.now();
    return V4PageScaffold(
      body: Column(children: [
        BeePageHeader(
          title: l.logCenterTitle,
          subtitle: l.logCenterSubtitle,
          leading: const BackButton(),
          actions: [
            Builder(
                builder: (anchor) => BeeIconButton(
                      label: l.logCenterExport,
                      icon: const BeeLineIcon('Share2', size: 20),
                      onPressed: _exporting ? null : () => _export(anchor),
                    )),
            BeeIconButton(
              label: l.logCenterClear,
              icon: const BeeLineIcon('Trash2', size: 20),
              onPressed: _clearing ? null : _clear,
            ),
          ],
        ),
        Expanded(
            child: CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(17, 8, 17, 8),
            sliver: SliverToBoxAdapter(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BeeSegmented<bool>(
                  key: const ValueKey('maintenance-log-group'),
                  value: _errorsOnly,
                  items: [
                    BeeSegment(true, '${l.logCenterErrors}  $errorCount'),
                    BeeSegment(false, '${l.v4SearchAll}  ${logs.length}'),
                  ],
                  onChanged: (errorsOnly) =>
                      setState(() => _errorsOnly = errorsOnly),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: BeeSearchField(
                    key: const ValueKey('maintenance-log-search'),
                    controller: _search,
                    hint: l.logCenterSearchHint,
                    clearLabel: l.searchClearFilter,
                    onChanged: (value) => setState(() => _keyword = value),
                  )),
                  const SizedBox(width: 8),
                  BeeIconButton(
                    key: const ValueKey('maintenance-filter-logs'),
                    label: l.searchFilterTitle,
                    icon: const BeeLineIcon('SlidersHorizontal', size: 20),
                    selected: _hasFilters,
                    onPressed: () => _chooseFilters(platform),
                  ),
                ]),
                if (_hasFilters || keyword.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${l.logCenterFiltered}: ${visible.length}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).hintColor))),
              ],
            )),
          ),
          if (visible.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              sliver: SliverToBoxAdapter(
                  child: _emptyState(
                l,
                total: logs.length,
                errorCount: errorCount,
                otherLevels:
                    logs.where((entry) => entry.level != LogLevel.error).length,
                searchMatches: matches.length,
              )),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(17, 0, 17, 24),
              sliver: SliverList.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final log = visible[index], date = log.timestamp.toLocal();
                  final startsDay = index == 0 ||
                      !DateUtils.isSameDay(
                          date, visible[index - 1].timestamp.toLocal());
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (startsDay) _dateHeading(context, date, now),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BeeMaintenanceLogCard(
                            key: ObjectKey(log),
                            level: log.level.displayName,
                            source: log.platform.displayName,
                            time: date.toIso8601String().substring(11, 23),
                            tag: log.tag,
                            message: log.message,
                            error: log.error?.toString(),
                            levelColor: switch (log.level) {
                              LogLevel.debug => Theme.of(context).hintColor,
                              LogLevel.info => Colors.blue,
                              _ => null,
                            },
                            tone: switch (log.level) {
                              LogLevel.warning => BeeTone.warning,
                              LogLevel.error => BeeTone.error,
                              _ => BeeTone.neutral,
                            },
                            onDetails: () => _details(log),
                            onCopy: () => _copy(log),
                          ),
                        ),
                      ]);
                },
              ),
            ),
        ])),
      ]),
    );
  }
}
