/// 账本卡片组件
///
/// 展示账本基本信息，同步状态通过 syncStatusProvider 单独获取
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ledger_display_item.dart';
import '../../cloud/sync_service.dart';
import '../../providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../utils/format_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';

/// 账本卡片
class LedgerCard extends ConsumerWidget {
  final LedgerDisplayItem ledger;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 右下角「⋯」按钮回调 —— 与 [onLongPress] 调同一个操作菜单。
  /// 长按是不可发现的手势,预算管理等入口藏在里面没人找得到,
  /// 必须有一个可见的等价入口。
  final VoidCallback? onMore;
  final bool selected;
  final VoidCallback? onBudget, onEdit, onMembers;

  const LedgerCard({
    super.key,
    required this.ledger,
    this.onTap,
    this.onLongPress,
    this.onMore,
    this.selected = false,
    this.onBudget,
    this.onEdit,
    this.onMembers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(primaryColorProvider);
    final l10n = AppLocalizations.of(context);

    // 获取同步状态
    final syncStatusAsync = ref.watch(syncStatusProvider(ledger.id));
    final syncStatus = syncStatusAsync.valueOrNull;

    // 检查是否正在上传
    final uploadingIds = ref.watch(uploadingLedgerIdsProvider);
    final isUploading =
        !ledger.isRemoteOnly && uploadingIds.contains(ledger.id);

    // 判断同步状态
    final isRemote = ledger.isRemoteOnly;
    final isSynced = syncStatus?.diff == SyncDiff.inSync;

    // 非同步状态：除了inSync和noRemote之外的所有状态
    final isNotSynced = syncStatusAsync.hasError ||
        syncStatus != null &&
            syncStatus.diff != SyncDiff.inSync &&
            syncStatus.diff != SyncDiff.noRemote &&
            syncStatus.diff != SyncDiff.notConfigured;

    final statusLabel = isUploading
        ? l10n.mineUploadInProgress
        : isRemote
            ? l10n.ledgerCardDownloadCloud
            : syncStatusAsync.hasError
                ? l10n.mineSyncError
                : switch (syncStatus?.diff) {
                    SyncDiff.notLoggedIn => l10n.mineSyncNotLoggedIn,
                    SyncDiff.noRemote => l10n.mineSyncNoRemote,
                    SyncDiff.inSync => l10n.mineSyncInSyncSimple,
                    SyncDiff.localNewer => l10n.mineSyncLocalNewerSimple,
                    SyncDiff.cloudNewer => l10n.mineSyncCloudNewerSimple,
                    SyncDiff.different => l10n.mineSyncDifferent,
                    SyncDiff.error => l10n.mineSyncError,
                    _ => l10n.mineSyncNotConfigured,
                  };
    final params = (
      ledgerId: ledger.id,
      month: DateTime(DateTime.now().year, DateTime.now().month)
    );
    final totals = ledger.isRemoteOnly
        ? null
        : ref.watch(monthlyTotalsProvider(params)).valueOrNull;
    final hidden = ref.watch(hideAmountsProvider);
    String money(double value) =>
        hidden ? '••••' : formatBalanceFull(value, ledger.currency);
    return BeeLedgerCard(
      name: translateLedgerName(context, ledger.name),
      subtitle:
          '${ledger.currency} · ${l10n.ledgersRecords('${ledger.transactionCount}')}'
          '${ledger.isShared ? ' · ${ledger.memberCount}' : ''}',
      icon: BeeLineIcon(ledger.isShared ? 'Users' : 'BookOpen', size: 21),
      current: selected,
      currentLabel: l10n.commonCurrent,
      expenseLabel: l10n.v4HomeMonthExpense,
      incomeLabel: l10n.v4HomeMonthIncome,
      expense: totals == null ? '—' : money(totals.$2),
      income: totals == null ? '—' : money(totals.$1),
      onSelect: onTap ?? () {},
      onMenu: onMore ?? onLongPress ?? () {},
      status: Semantics(
          label: statusLabel,
          child: Tooltip(
              message: statusLabel,
              child: ExcludeSemantics(
                  child: _buildStatusIcon(context, ref, primaryColor, isSynced,
                      isNotSynced, isRemote, isUploading)))),
      footer: Align(
          alignment: Alignment.centerLeft,
          child: Text(
              isRemote
                  ? l10n.ledgerCardDownloadCloud
                  : l10n.ledgersBalance(money(ledger.balance)),
              style: TextStyle(
                  fontSize: 12,
                  color: isRemote
                      ? primaryColor
                      : BeeTokens.textSecondary(context)))),
      actions: [
        if (onBudget != null)
          BeeButton(
              label: l10n.budgetManagement,
              icon: const BeeLineIcon('ChartPie', size: 14),
              kind: BeeButtonKind.secondary,
              compact: true,
              onPressed: onBudget),
        if (onMembers != null)
          BeeButton(
              label: l10n.sharedMembersPageTitle,
              icon: const BeeLineIcon('Users', size: 14),
              kind: BeeButtonKind.secondary,
              compact: true,
              onPressed: onMembers)
        else if (onEdit != null)
          BeeButton(
              label: l10n.ledgersEdit,
              icon: const BeeLineIcon('Settings2', size: 14),
              kind: BeeButtonKind.secondary,
              compact: true,
              onPressed: onEdit),
        if (isRemote)
          BeeButton(
              label: l10n.ledgersDownload,
              icon: const BeeLineIcon('CloudDownload', size: 14),
              kind: BeeButtonKind.secondary,
              compact: true,
              onPressed: onTap),
      ],
    );
  }

  /// 状态图标
  Widget _buildStatusIcon(
    BuildContext context,
    WidgetRef ref,
    Color primaryColor,
    bool isSynced,
    bool isNotSynced,
    bool isRemote,
    bool isUploading,
  ) {
    // 优先显示上传中状态
    if (isUploading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
        ),
      );
    }

    if (isRemote) {
      // 远程账本：云下载图标
      return Icon(
        Icons.cloud_download,
        color: primaryColor,
        size: 20,
      );
    } else if (isSynced) {
      // 已同步：绿色云勾选图标
      return const Icon(
        Icons.cloud_done,
        color: Colors.green,
        size: 20,
      );
    } else if (isNotSynced) {
      // 未同步（包括：localNewer、cloudNewer、different、error、notLoggedIn）：红色云图标
      return const Icon(
        Icons.cloud_off,
        color: Colors.red,
        size: 20,
      );
    } else {
      // 纯本地账本（离线模式/未配置）：灰色云关闭图标
      return const Icon(
        Icons.cloud_off,
        color: Colors.grey,
        size: 20,
      );
    }
  }
}
