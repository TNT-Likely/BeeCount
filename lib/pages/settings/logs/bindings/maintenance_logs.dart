import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/maintenance.dart';
import '../../../../services/system/logger_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/bindings/maintenance_access.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';

class MaintenanceLogsControls extends ConsumerStatefulWidget {
  const MaintenanceLogsControls({super.key});
  @override
  ConsumerState<MaintenanceLogsControls> createState() => _LogsState();
}

class _LogsState extends ConsumerState<MaintenanceLogsControls> {
  final _levels = LogLevel.values.toSet(),
      _sources = LogPlatform.values.toSet();
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

  List<LogEntry> get _filtered => _logger.logs
      .where((log) {
        if (!_levels.contains(log.level) || !_sources.contains(log.platform)) {
          return false;
        }
        final keyword = _keyword.toLowerCase();
        return keyword.isEmpty ||
            log.message.toLowerCase().contains(keyword) ||
            log.tag.toLowerCase().contains(keyword);
      })
      .toList()
      .reversed
      .toList();
  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      // Preserve the original platform sharing contract and complete-log scope.
      // ignore: deprecated_member_use
      await Share.share(_logger.exportAsText(), subject: 'BeeCount 日志导出');
    } catch (_) {
      if (mounted) {
        showBeeToast(context, AppLocalizations.of(context).logCenterExportFailed);
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
        showBeeToast(context, l.logCenterCleared);
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _copy(LogEntry log) async {
    try {
      await Clipboard.setData(ClipboardData(text: log.toFormattedString()));
      if (mounted) {
        showBeeToast(context, AppLocalizations.of(context).logCenterCopied);
      }
    } catch (_) {
      if (mounted) {
        showBeeToast(context, AppLocalizations.of(context).commonFailed);
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        logs = _filtered,
        platform = ref.watch(maintenancePlatformProvider);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.logCenterTitle,
          subtitle: l.logCenterSubtitle,
          leading: const BackButton(),
          actions: [
            BeeIconButton(
                label: l.logCenterExport,
                icon: const BeeLineIcon('Share2', size: 20),
                onPressed: _exporting ? null : _export),
            BeeIconButton(
                label: l.logCenterClear,
                icon: const BeeLineIcon('Trash2', size: 20),
                onPressed: _clearing ? null : _clear)
          ]),
      Expanded(
          child: CustomScrollView(slivers: [
        SliverPadding(
            padding: const EdgeInsets.fromLTRB(17, 10, 17, 0),
            sliver: SliverToBoxAdapter(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  BeeSurface(
                      child: BeeSearchField(
                          key: const ValueKey('maintenance-log-search'),
                          controller: _search,
                          hint: l.logCenterSearchHint,
                          clearLabel: l.searchClearFilter,
                          onChanged: (value) =>
                              setState(() => _keyword = value))),
                  const SizedBox(height: 12),
                  BeeMaintenanceLogFilters(
                      levelLabel: l.logCenterFilterLevel,
                      sourceLabel: l.logCenterFilterPlatform,
                      levels: [
                        for (final level in LogLevel.values)
                          BeeMaintenanceFilterChoice(
                              key: ValueKey('maintenance-level-${level.name}'),
                              label: level.displayName,
                              selected: _levels.contains(level),
                              onSelected: (selected) => setState(() {
                                    if (selected) {
                                      _levels.add(level);
                                    } else {
                                      _levels.remove(level);
                                    }
                                  }))
                      ],
                      sources: [
                        for (final source in LogPlatform.values)
                          if (!(platform == TargetPlatform.android &&
                                  source == LogPlatform.ios) &&
                              !(platform == TargetPlatform.iOS &&
                                  source == LogPlatform.android))
                            BeeMaintenanceFilterChoice(
                                key: ValueKey(
                                    'maintenance-source-${source.name}'),
                                label: source.displayName,
                                selected: _sources.contains(source),
                                onSelected: (selected) => setState(() {
                                      if (selected) {
                                        _sources.add(source);
                                      } else {
                                        _sources.remove(source);
                                      }
                                    }))
                      ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 16, runSpacing: 5, children: [
                    Text('${l.logCenterTotal}: ${_logger.logs.length}',
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).hintColor)),
                    Text('${l.logCenterFiltered}: ${logs.length}',
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).hintColor))
                  ]),
                  const SizedBox(height: 12),
                ]))),
        if (logs.isEmpty)
          SliverToBoxAdapter(
              child: BeeEmptyState(
                  title: l.logCenterEmpty,
                  icon: const BeeLineIcon('Inbox', size: 36)))
        else
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(17, 0, 17, 24),
              sliver: SliverList.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BeeMaintenanceLogCard(
                            key: ValueKey(
                                'maintenance-log-${log.timestamp.microsecondsSinceEpoch}-${log.tag}'),
                            level: log.level.displayName,
                            source: log.platform.displayName,
                            time:
                                '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}.${log.timestamp.millisecond.toString().padLeft(3, '0')}',
                            tag: log.tag,
                            message: log.message,
                            error: log.error?.toString(),
                            levelColor: switch (log.level) {
                              LogLevel.debug => Colors.grey,
                              LogLevel.info => Colors.blue,
                              LogLevel.warning => Colors.orange,
                              LogLevel.error => Colors.red
                            },
                            tone: switch (log.level) {
                              LogLevel.debug => BeeTone.neutral,
                              LogLevel.info => BeeTone.neutral,
                              LogLevel.warning => BeeTone.warning,
                              LogLevel.error => BeeTone.error
                            },
                            onDetails: () => _details(log),
                            onCopy: () => _copy(log)));
                  })),
      ])),
    ]));
  }
}
