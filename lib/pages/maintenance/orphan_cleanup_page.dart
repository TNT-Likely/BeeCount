import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/database_providers.dart';
import '../../providers/maintenance_providers.dart';
import '../../services/maintenance/orphan_record.dart';
import '../../services/maintenance/orphan_seeder.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../widgets/biz/section_card.dart';
import '../../widgets/ui/ui.dart';

/// 数据清理页面 — 展示扫到的孤儿数据,用户勾选后批量或单条删。
class OrphanCleanupPage extends ConsumerStatefulWidget {
  const OrphanCleanupPage({super.key});

  @override
  ConsumerState<OrphanCleanupPage> createState() => _OrphanCleanupPageState();
}

class _OrphanCleanupPageState extends ConsumerState<OrphanCleanupPage> {
  /// 已勾选 record 的 uniqueKey 集合。每次重扫不清空(新结果里没有的会自然
  /// 被过滤,新增的默认 unchecked)。
  final Set<String> _selected = <String>{};
  bool _cleaning = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reportAsync = ref.watch(orphanScanReportProvider);
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.maintenanceOrphanCleanupTitle,
            subtitle: l10n.maintenanceOrphanCleanupSubtitle,
            showBack: true,
            actions: [
              // 仅 debug build 显示:塞各类孤儿数据用于联调
              if (kDebugMode)
                IconButton(
                  tooltip: 'Seed orphan data (debug)',
                  onPressed: _cleaning ? null : _seedDebugOrphans,
                  icon: const Icon(Icons.bug_report_outlined),
                ),
              IconButton(
                tooltip: l10n.maintenanceOrphanRescan,
                onPressed: _cleaning
                    ? null
                    : () => ref.invalidate(orphanScanReportProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Expanded(
            child: reportAsync.when(
              skipLoadingOnReload: true,
              data: (report) => _buildBody(context, ref, l10n, report),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('${l10n.commonError}: $err',
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
          if (reportAsync.hasValue)
            _buildBottomBar(context, l10n, reportAsync.requireValue),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, OrphanScanReport report) {
    if (report.totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 64.0.scaled(context, ref),
                  color: BeeTokens.textTertiary(context)),
              SizedBox(height: 16.0.scaled(context, ref)),
              Text(l10n.maintenanceOrphanEmpty,
                  style: TextStyle(
                      color: BeeTokens.textSecondary(context))),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: 12.0.scaled(context, ref),
        vertical: 8.0.scaled(context, ref),
      ),
      children: [
        _buildSummary(context, l10n, report),
        SizedBox(height: 8.0.scaled(context, ref)),
        if (report.dbOrphans.isNotEmpty)
          _buildGroup(context, l10n, l10n.maintenanceOrphanGroupDb,
              report.dbOrphans),
        if (report.fileOrphans.isNotEmpty)
          _buildGroup(context, l10n, l10n.maintenanceOrphanGroupFile,
              report.fileOrphans),
        if (report.syncOrphans.isNotEmpty)
          _buildGroup(context, l10n, l10n.maintenanceOrphanGroupSync,
              report.syncOrphans),
      ],
    );
  }

  Widget _buildSummary(
      BuildContext context, AppLocalizations l10n, OrphanScanReport report) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16.0.scaled(context, ref),
          vertical: 12.0.scaled(context, ref),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined,
                color: Colors.orange,
                size: 22.0.scaled(context, ref)),
            SizedBox(width: 12.0.scaled(context, ref)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.maintenanceOrphanSummary(report.totalCount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                  if (report.totalSizeBytes > 0)
                    Text(
                      l10n.maintenanceOrphanSummarySize(
                          _humanSize(report.totalSizeBytes)),
                      style: TextStyle(
                        fontSize: 12,
                        color: BeeTokens.textSecondary(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(BuildContext context, AppLocalizations l10n,
      String groupTitle, List<OrphanRecord> records) {
    final allSelected = records.every((r) => _selected.contains(r.uniqueKey));
    return Padding(
      padding: EdgeInsets.only(bottom: 12.0.scaled(context, ref)),
      child: SectionCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 组头:标题 + 数量 + 全选按钮
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.0.scaled(context, ref),
                vertical: 8.0.scaled(context, ref),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$groupTitle (${records.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: BeeTokens.textPrimary(context),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _cleaning
                        ? null
                        : () => _toggleGroupSelected(records, !allSelected),
                    child: Text(allSelected
                        ? l10n.maintenanceOrphanDeselectAll
                        : l10n.maintenanceOrphanSelectAll),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...records.map((r) => _buildRecordTile(context, l10n, r)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordTile(
      BuildContext context, AppLocalizations l10n, OrphanRecord r) {
    final checked = _selected.contains(r.uniqueKey);
    final sizeHint =
        r.sizeBytes != null ? ' · ${_humanSize(r.sizeBytes!)}' : '';
    return CheckboxListTile(
      value: checked,
      onChanged: _cleaning
          ? null
          : (v) {
              setState(() {
                if (v == true) {
                  _selected.add(r.uniqueKey);
                } else {
                  _selected.remove(r.uniqueKey);
                }
              });
            },
      title: Text(r.title,
          style: TextStyle(
              fontSize: 14,
              color: BeeTokens.textPrimary(context))),
      subtitle: Text('${r.subtitle}$sizeHint',
          style: TextStyle(
              fontSize: 12,
              color: BeeTokens.textSecondary(context))),
      secondary: IconButton(
        tooltip: l10n.maintenanceOrphanDeleteOne,
        icon: const Icon(Icons.delete_outline),
        onPressed: _cleaning ? null : () => _cleanOne(r),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }

  Widget _buildBottomBar(
      BuildContext context, AppLocalizations l10n, OrphanScanReport report) {
    if (report.totalCount == 0) return const SizedBox.shrink();
    final selectedCount = report.all
        .where((r) => _selected.contains(r.uniqueKey))
        .length;
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16.0.scaled(context, ref),
          vertical: 8.0.scaled(context, ref),
        ),
        decoration: BoxDecoration(
          color: BeeTokens.surface(context),
          border: Border(
              top: BorderSide(color: BeeTokens.divider(context))),
        ),
        child: Row(
          children: [
            Text(
              l10n.maintenanceOrphanSelectedHint(selectedCount),
              style: TextStyle(color: BeeTokens.textSecondary(context)),
            ),
            const Spacer(),
            TextButton(
              onPressed:
                  _cleaning ? null : () => _toggleAll(report, selectedCount == 0),
              child: Text(selectedCount == 0
                  ? l10n.maintenanceOrphanSelectAll
                  : l10n.maintenanceOrphanDeselectAll),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: primary),
              onPressed: (_cleaning || selectedCount == 0)
                  ? null
                  : () => _cleanSelected(report),
              icon: _cleaning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.delete_sweep_outlined,
                      color: Colors.white),
              label: Text(l10n.maintenanceOrphanCleanSelected,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleGroupSelected(List<OrphanRecord> records, bool select) {
    setState(() {
      for (final r in records) {
        if (select) {
          _selected.add(r.uniqueKey);
        } else {
          _selected.remove(r.uniqueKey);
        }
      }
    });
  }

  void _toggleAll(OrphanScanReport report, bool select) {
    setState(() {
      if (select) {
        for (final r in report.all) {
          _selected.add(r.uniqueKey);
        }
      } else {
        _selected.clear();
      }
    });
  }

  Future<void> _cleanOne(OrphanRecord r) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _showConfirm(
      title: l10n.maintenanceOrphanConfirmTitle,
      message: l10n.maintenanceOrphanConfirmDeleteOne(r.title),
    );
    if (!confirmed) return;
    await _runClean([r], l10n);
  }

  Future<void> _cleanSelected(OrphanScanReport report) async {
    final l10n = AppLocalizations.of(context);
    final selected = report.all
        .where((r) => _selected.contains(r.uniqueKey))
        .toList();
    if (selected.isEmpty) return;
    final confirmed = await _showConfirm(
      title: l10n.maintenanceOrphanConfirmTitle,
      message: l10n.maintenanceOrphanConfirmDeleteBatch(selected.length),
    );
    if (!confirmed) return;
    await _runClean(selected, l10n);
  }

  Future<void> _runClean(
      List<OrphanRecord> records, AppLocalizations l10n) async {
    setState(() => _cleaning = true);
    try {
      final cleaner = ref.read(orphanCleanerProvider);
      final result = await cleaner.clean(records);
      // 清掉已成功 record 的勾选(失败的保留勾选,便于用户重试 / 复查)
      final failedKeys = result.failures.map((f) => f.record.uniqueKey).toSet();
      for (final r in records) {
        if (!failedKeys.contains(r.uniqueKey)) _selected.remove(r.uniqueKey);
      }
      if (!mounted) return;
      if (result.hasFailure) {
        showToast(
            context,
            l10n.maintenanceOrphanCleanPartial(
                result.successCount, result.failures.length));
      } else {
        showToast(
            context, l10n.maintenanceOrphanCleanSuccess(result.successCount));
      }
      ref.invalidate(orphanScanReportProvider);
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  Future<bool> _showConfirm(
      {required String title, required String message}) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// debug 按钮:塞 ≥10 项孤儿到本地 DB / 磁盘,然后重扫。
  Future<void> _seedDebugOrphans() async {
    setState(() => _cleaning = true);
    try {
      final db = ref.read(databaseProvider);
      final seeder = OrphanSeeder(db: db);
      final report = await seeder.seedAll();
      if (!mounted) return;
      showToast(context, '已塞入测试孤儿数据\n$report');
      ref.invalidate(orphanScanReportProvider);
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  String _humanSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double v = bytes.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }
}
