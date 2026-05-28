/// 重构后的账本列表页面
///
/// 集成本地账本 + 远程账本管理
library;

import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' show CloudBackendType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers.dart';
import '../../models/ledger_display_item.dart';
import '../../cloud/transactions_sync_manager.dart';
import '../../cloud/sync_service.dart';
import '../../cloud/sync/sync_engine.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../cloud/member_list_page.dart';
import '../cloud/member_stats_page.dart';
import '../cloud/join_shared_ledger_page.dart';
import '../budget/budget_page.dart';
import '../../styles/tokens.dart';
import '../../utils/currencies.dart';
import '../../services/system/logger_service.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../utils/format_utils.dart';
import '../../services/billing/post_processor.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';

class LedgersPageNew extends ConsumerStatefulWidget {
  /// 进入页面后自动弹出「创建账本」对话框。用于首页账本胶囊在没账本时直接
  /// 引导用户新建,省一步点击。
  final bool autoOpenCreateDialog;

  const LedgersPageNew({super.key, this.autoOpenCreateDialog = false});

  @override
  ConsumerState<LedgersPageNew> createState() => _LedgersPageNewState();
}

class _LedgersPageNewState extends ConsumerState<LedgersPageNew> {
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenCreateDialog) {
      // 等首帧渲染完再弹,否则 context 上面没 Navigator 栈无法 showDialog。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCreateLedgerDialog(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(currentLedgerIdProvider);
    // 使用新的分离提供者：本地（快速）和远程（慢速）
    final localLedgersAsync = ref.watch(localLedgersProvider);
    final remoteLedgersAsync = ref.watch(remoteLedgersProvider);

    // 监听导入进度，当导入完成时自动刷新账本列表和同步状态
    ref.listen<ImportProgress>(importProgressProvider, (previous, next) {
      // 检测到导入完成（从运行中变为完成状态）
      if (previous?.running == true && next.isJustCompleted && next.ledgerId != null) {
        print('🟢 [LedgersPage] 检测到导入完成: ledgerId=${next.ledgerId}');
        // 触发同步状态刷新和账本列表刷新
        PostProcessor.sync(ref, ledgerId: next.ledgerId!);
      }
    });

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context).ledgersTitle,
            // 唯一入口是首页 ledger picker 的「管理账本」按钮通过 Navigator.push
            // 进来,可以 pop。showBack=true 让用户回到首页。
            showBack: true,
            actions: [
              // 新建账本
              IconButton(
                tooltip: AppLocalizations.of(context).ledgersCreate,
                onPressed: () => _showCreateLedgerDialog(context),
                icon: Icon(Icons.add, color: BeeTokens.textPrimary(context)),
              ),
              // 刷新
              IconButton(
                onPressed: () {
                  ref.read(ledgerListRefreshProvider.notifier).state++;
                },
                icon: Icon(Icons.refresh, color: BeeTokens.textPrimary(context)),
              ),
            ],
          ),
          Expanded(
            child: _buildProgressiveList(
              context,
              ref,
              currentId,
              localLedgersAsync,
              remoteLedgersAsync,
            ),
          ),
        ],
      ),
    );
  }

  /// 渐进式加载列表：先显示本地，再加载远程
  Widget _buildProgressiveList(
    BuildContext context,
    WidgetRef ref,
    int? currentId,
    AsyncValue<List<LedgerDisplayItem>> localAsync,
    AsyncValue<List<LedgerDisplayItem>> remoteAsync,
  ) {
    // 获取本地账本（快速）
    final localLedgers = localAsync.valueOrNull ?? [];
    final localError = localAsync.error;

    // 获取远程账本（慢速）
    final remoteLedgers = remoteAsync.valueOrNull ?? [];
    final remoteLoading = remoteAsync.isLoading;
    final remoteError = remoteAsync.error;

    // 如果本地也在加载中且没有缓存数据，显示全局加载
    if (localAsync.isLoading && localLedgers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 如果本地加载失败，显示错误
    if (localError != null && localLedgers.isEmpty) {
      return Center(
        child: Text('${AppLocalizations.of(context).commonError}: $localError'),
      );
    }

    // 如果本地和远程都为空 — 用 AppEmpty(蜜蜂图标 + 文案)符合空态规范,
    // 下面加一个 OutlinedButton 引导新建账本(welcome 未勾默认账本 / 老用户
    // 导入配置不含账本的场景第一时间能直接动手)
    if (localLedgers.isEmpty && remoteLedgers.isEmpty && !remoteLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppEmpty(text: AppLocalizations.of(context).ledgersEmpty),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showCreateLedgerDialog(context),
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).ledgersNew),
            ),
          ],
        ),
      );
    }

    // 构建列表（本地 + 远程）
    return _buildSplitLedgerList(
      context,
      ref,
      localLedgers,
      remoteLedgers,
      currentId,
      remoteLoading: remoteLoading,
      remoteError: remoteError,
    );
  }

  /// 构建分离的账本列表（本地 + 远程）
  Widget _buildSplitLedgerList(
    BuildContext context,
    WidgetRef ref,
    List<LedgerDisplayItem> localLedgers,
    List<LedgerDisplayItem> remoteLedgers,
    int? currentId, {
    bool remoteLoading = false,
    Object? remoteError,
  }) {
    // 共享账本是 BeeCount Cloud 独有能力(server 端的成员管理 / WS fan-out
     // 都在 BeeCount Cloud 后端),非 BeeCount Cloud 用户(local / WebDAV /
     // S3 / Supabase 等)就算扫码也走不通,按钮藏起来避免误导。
    final cloudConfigAsync = ref.watch(activeCloudConfigProvider);
    final isBeeCountCloud =
        cloudConfigAsync.valueOrNull?.type == CloudBackendType.beecountCloud;

    return ListView(
      padding: EdgeInsets.symmetric(
        vertical: 8.0.scaled(context, ref),
      ),
      children: [
        // §7 共享账本入口 — 跟 web 端 LedgersSection 顶部"加入共享账本"
        // 按钮一致,放在列表顶部,比 header 角落 icon 显眼。
        if (isBeeCountCloud)
          Padding(
            padding: EdgeInsets.fromLTRB(
              16.0.scaled(context, ref),
              4.0.scaled(context, ref),
              16.0.scaled(context, ref),
              8.0.scaled(context, ref),
            ),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: Text(AppLocalizations.of(context).sharedJoinPageTitle),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const JoinSharedLedgerPage(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 40.0.scaled(context, ref)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        // 本地账本区域
        if (localLedgers.isNotEmpty) ...[
          _SectionHeader(
            title: AppLocalizations.of(context).ledgersLocal,
            trailing: localLedgers.length.toString(),
          ),
          ...localLedgers.map((ledger) => LedgerCard(
                ledger: ledger,
                selected: !ledger.isRemoteOnly && ledger.id == currentId,
                onTap: () => _handleLocalLedgerTap(ledger),
                onLongPress: () => _showLocalLedgerActions(context, ledger),
              )),
        ],

        // 远程账本区域（仅在加载中或有远程账本时显示）
        if (remoteLoading || remoteLedgers.isNotEmpty || remoteError != null) ...[
          SizedBox(height: 16.0.scaled(context, ref)),
          _SectionHeader(
            title: AppLocalizations.of(context).ledgersRemote,
            trailing: remoteLoading
                ? null
                : remoteLedgers.length.toString(),
            action: remoteLedgers.isNotEmpty
                ? TextButton.icon(
                    icon: const Icon(Icons.cloud_download, size: 18),
                    label: Text(AppLocalizations.of(context).ledgersRestoreAll),
                    onPressed: _isRestoring ? null : () => _handleBatchRestore(context),
                  )
                : null,
          ),

          // 远程账本加载状态
          if (remoteLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0.scaled(context, ref)),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (remoteError != null)
            Padding(
              padding: EdgeInsets.all(16.0.scaled(context, ref)),
              child: Center(
                child: Text(
                  '${AppLocalizations.of(context).commonError}: $remoteError',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          else
            ...remoteLedgers.map((ledger) => LedgerCard(
                  ledger: ledger,
                  onTap: () => _handleRemoteLedgerTap(context, ledger),
                  onLongPress: () => _showRemoteLedgerActions(context, ledger),
                )),
        ],

        SizedBox(height: 60.0.scaled(context, ref)),
      ],
    );
  }

  /// 构建账本列表（旧版，保留用于兼容）
  Widget _buildLedgerList(
    BuildContext context,
    WidgetRef ref,
    List<LedgerDisplayItem> ledgers,
    int? currentId, {
    bool showLoadingOverlay = false,
  }) {
    // 分组：本地账本 vs 远程账本
    final localLedgers = ledgers.where((l) => !l.isRemoteOnly).toList();
    final remoteLedgers = ledgers.where((l) => l.isRemoteOnly).toList();

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.symmetric(
            vertical: 8.0.scaled(context, ref),
          ),
          children: [
                    // 账本区域
                    if (localLedgers.isNotEmpty) ...[
                      _SectionHeader(
                        title: AppLocalizations.of(context).ledgersLocal,
                        trailing: localLedgers.length.toString(),
                      ),
                      ...localLedgers.map((ledger) => LedgerCard(
                            ledger: ledger,
                            selected: !ledger.isRemoteOnly && ledger.id == currentId,
                            onTap: () => _handleLocalLedgerTap(ledger),
                            onLongPress: () => _showLocalLedgerActions(context, ledger),
                          )),
                    ],

                    // 远程账本区域
                    if (remoteLedgers.isNotEmpty) ...[
                      SizedBox(height: 16.0.scaled(context, ref)),
                      _SectionHeader(
                        title: AppLocalizations.of(context).ledgersRemote,
                        trailing: remoteLedgers.length.toString(),
                        action: TextButton.icon(
                          icon: const Icon(Icons.cloud_download, size: 18),
                          label: Text(AppLocalizations.of(context).ledgersRestoreAll),
                          onPressed: _isRestoring ? null : () => _handleBatchRestore(context),
                        ),
                      ),
                      ...remoteLedgers.map((ledger) => LedgerCard(
                            ledger: ledger,
                            onTap: () => _handleRemoteLedgerTap(context, ledger),
                            onLongPress: () => _showRemoteLedgerActions(context, ledger),
                          )),
                    ],

            SizedBox(height: 60.0.scaled(context, ref)),
          ],
        ),

        // 加载蒙层：刷新时显示
        if (showLoadingOverlay)
          Positioned.fill(
            child: Container(
              color: BeeTokens.surfaceElevated(context).withValues(alpha: 0.7),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  /// 处理本地账本点击 - 切换账本或显示冲突对话框
  Future<void> _handleLocalLedgerTap(LedgerDisplayItem ledger) async {
    // 获取同步状态
    final syncStatusAsync = ref.read(syncStatusProvider(ledger.id));
    final syncStatus = syncStatusAsync.valueOrNull;

    // 检查是否有冲突
    if (syncStatus?.diff == SyncDiff.different) {
      // 显示冲突解决对话框
      await _showConflictResolutionDialog(context, ledger);
      return;
    }

    // 正常切换账本
    ref.read(currentLedgerIdProvider.notifier).state = ledger.id;
    // 清除缓存的交易数据，确保切换后刷新
    ref.invalidate(cachedTransactionsWithCategoryProvider);
    showToast(context, AppLocalizations.of(context).ledgersSwitched(translateLedgerName(context, ledger.name)));
  }

  /// 处理远程账本点击 - 下载
  Future<void> _handleRemoteLedgerTap(BuildContext context, LedgerDisplayItem ledger) async {
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: AppLocalizations.of(context).ledgersDownloadTitle,
      message: AppLocalizations.of(context).ledgersDownloadMessage(translateLedgerName(context, ledger.name)),
    );

    if (confirmed != true || !mounted) return;

    try {
      showToast(context, AppLocalizations.of(context).ledgersDownloading);

      final syncService = ref.read(syncServiceProvider);
      if (syncService is SyncEngine) {
        // BeeCount Cloud 路径（sync_changes 增量日志模型）：
        // 1) syncLedgersFromServer 把账本行插到本地 Drift
        // 2) replayAllChanges 从 cursor=0 重拉整段 sync_changes 并幂等应用，
        //    把历史 tx/account/category/tag 挂到刚刚插好的新账本上
        //
        // 不走 `_fullPull`（整包 JSON 下载）—— 那是 S3/WebDAV 的玩法，BeeCount
        // Cloud 的模型就是 sync_changes，所有恢复都应该走这条日志。apply 是
        // 按 entity_sync_id upsert 幂等的，重放不会产生副本。
        await syncService.syncLedgersFromServer();
        await syncService.replayAllChanges();
      } else if (syncService is TransactionsSyncManager) {
        // 老的 Supabase 路径
        await syncService.downloadRemoteLedger(
          name: ledger.name,
          currency: ledger.currency,
          remotePath: 'ledger_${ledger.id}.json',
        );
      } else {
        throw Exception('Cloud sync not available');
      }

      if (!mounted) return;

      // 刷新列表和同步状态
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;
      ref.read(syncStatusRefreshProvider.notifier).state++;

      showToast(context, AppLocalizations.of(context).ledgersDownloadSuccess(translateLedgerName(context, ledger.name)));
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).commonFailed,
        message: '$e',
      );
    }
  }

  /// 显示本地账本操作菜单
  Future<void> _showLocalLedgerActions(BuildContext context, LedgerDisplayItem ledger) async {
    // v24 共享账本权限矩阵(详见 .docs/shared-ledger/01-product-design.md §6):
    // - Owner / 单人账本:edit / clear / deleteLocal / delete + members 全部可用
    // - Editor(共享账本 + myRole != owner):仅 members(看成员/退出),
    //   隐藏 edit / clear / deleteLocal / delete 4 项 owner-only 操作
    final isOwner = ledger.myRole == 'owner';
    // 共享账本/成员管理是 BeeCount Cloud 独有能力,非 BeeCount Cloud 模式
    // (local / WebDAV / S3 / Supabase 等)直接隐藏这些入口。
    final cloudConfig = ref.read(activeCloudConfigProvider).valueOrNull;
    final isBeeCountCloud =
        cloudConfig?.type == CloudBackendType.beecountCloud;
    final action = await showDialog<String>(
      context: context,
      builder: (dctx) {
        final primary = Theme.of(dctx).colorScheme.primary;
        return SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppLocalizations.of(context).ledgersActions),
          children: [
            if (isOwner)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dctx, 'edit'),
                child: Row(
                  children: [
                    Icon(Icons.edit, color: primary),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context).ledgersEdit),
                  ],
                ),
              ),
            // 预算管理入口 — 每个账本独立预算,Owner/Editor 都能看(Editor 进
            // BudgetPage 后 isEditorInShared 隐藏 + 按钮和编辑入口,只看不改)。
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dctx, 'budget'),
              child: Row(
                children: [
                  Icon(Icons.pie_chart_outline_rounded, color: primary),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).budgetManagement),
                ],
              ),
            ),
            // v24 共享账本:成员管理入口(任意 member 可看,owner 可邀请 / 踢人,
            // Editor 可看列表 + 退出账本)。非 BeeCount Cloud 模式没成员概念,
            // 整个入口隐藏。
            if (isBeeCountCloud) ...[
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dctx, 'members'),
                child: Row(
                  children: [
                    Icon(Icons.people, color: primary),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context).sharedMembersPageTitle),
                    if (ledger.isShared) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${ledger.memberCount})',
                        style: TextStyle(
                          color: BeeTokens.textSecondary(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 共享账本成员收支统计(简版)— 只对已同步的共享账本展示。
              if (ledger.isShared)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dctx, 'memberStats'),
                  child: Row(
                    children: [
                      Icon(Icons.insert_chart_outlined, color: primary),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)
                          .sharedMembersStatsTitle),
                    ],
                  ),
                ),
            ],
            if (isOwner) ...[
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dctx, 'clear'),
                child: Row(
                  children: [
                    const Icon(Icons.clear_all, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context).ledgersClear),
                  ],
                ),
              ),
            ],
            // "仅删除本地"对 Owner 和 Editor 都可用 — 这是本地清理动作,
            // 不影响 server。Editor 用这个清掉 Owner 已删账本残留;Owner
            // 用来清不想要的本地副本但保留 server 数据。
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dctx, 'deleteLocal'),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).ledgersDeleteLocal),
                ],
              ),
            ),
            if (isOwner) ...[
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dctx, 'delete'),
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context).ledgersDelete),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );

    if (!mounted) return;

    if (action == 'edit') {
      await _handleEditLedger(context, ledger);
    } else if (action == 'budget') {
      // 切到长按的账本(BudgetPage 内部 watch currentLedger,不接 ledgerId 参
      // 数),再 push。语义上"从账本列表 → 长按 A → 预算管理"自然就是切到 A。
      if (ref.read(currentLedgerIdProvider) != ledger.id) {
        ref.read(currentLedgerIdProvider.notifier).state = ledger.id;
        ref.invalidate(currentLedgerProvider);
      }
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BudgetPage()),
        );
      }
    } else if (action == 'members') {
      // 跳转成员管理 — 需要 ledger.syncId(server external_id)。本地仅 ledger
      // (没 syncId,从未同步过的)无成员概念,提示用户先建云账户。
      final row = await ref.read(repositoryProvider).getLedgerById(ledger.id);
      final syncId = row?.syncId;
      if (syncId == null || syncId.isEmpty) {
        if (mounted) showToast(context, AppLocalizations.of(context).sharedRequiresCloudSync);
        return;
      }
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MemberListPage(
            ledgerExternalId: syncId,
            ledgerName: ledger.name,
          ),
        ));
      }
    } else if (action == 'memberStats') {
      // 跟成员管理同源:取 ledger.syncId 再跳 MemberStatsPage。
      final row = await ref.read(repositoryProvider).getLedgerById(ledger.id);
      final syncId = row?.syncId;
      if (syncId == null || syncId.isEmpty) {
        if (mounted) showToast(context, AppLocalizations.of(context).sharedRequiresCloudSync);
        return;
      }
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MemberStatsPage(
            ledgerExternalId: syncId,
            ledgerName: ledger.name,
          ),
        ));
      }
    } else if (action == 'clear') {
      await _handleClearLedger(context, ledger);
    } else if (action == 'deleteLocal') {
      await _handleDeleteLocalLedgerOnly(context, ledger);
    } else if (action == 'delete') {
      await _handleDeleteLocalLedger(context, ledger);
    }
  }

  /// 显示远程账本操作菜单
  Future<void> _showRemoteLedgerActions(BuildContext context, LedgerDisplayItem ledger) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dctx) {
        final primary = Theme.of(dctx).colorScheme.primary;
        return SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppLocalizations.of(context).ledgersActions),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dctx, 'download'),
              child: Row(
                children: [
                  Icon(Icons.cloud_download, color: primary),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).ledgersDownload),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dctx, 'delete'),
              child: Row(
                children: [
                  const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context).ledgersDeleteRemote),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (action == 'download') {
      await _handleRemoteLedgerTap(context, ledger);
    } else if (action == 'delete') {
      await _handleDeleteRemoteLedger(context, ledger);
    }
  }

  /// 编辑账本
  Future<void> _handleEditLedger(BuildContext context, LedgerDisplayItem ledger) async {
    final repo = ref.read(repositoryProvider);
    final ledgerData = await repo.getLedgerById(ledger.id);

    if (ledgerData == null || !mounted) return;

    final result = await _showLedgerEditorDialog(
      context,
      title: AppLocalizations.of(context).ledgersEdit,
      initialName: ledgerData.name,
      initialCurrency: ledgerData.currency,
    );

    if (result == null || !mounted) return;

    await repo.updateLedger(
      id: ledger.id,
      name: result.name.trim(),
      currency: result.currency,
    );

    // 修改账本名称/币种后，需要触发同步以更新云端账本文件
    await PostProcessor.sync(ref, ledgerId: ledger.id);

    ref.read(ledgerListRefreshProvider.notifier).state++;
    // 同时 invalidate currentLedgerProvider —— 它是 FutureProvider,只看
    // currentLedgerIdProvider 变不变,名字改了但 id 没变 → 不会自动重跑,
    // home 页 header 会继续显示旧名字。手动 invalidate 让 FutureProvider
    // 下次读取时重取 Ledger row。
    ref.invalidate(currentLedgerProvider);
  }

  /// 清空账本（删除所有账单，保留账本）
  Future<void> _handleClearLedger(BuildContext context, LedgerDisplayItem ledger) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.ledgersClearTitle,
      message: l10n.ledgersClearMessage(translateLedgerName(context, ledger.name)),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);

      // 删除该账本的所有账单
      await repo.clearLedgerTransactions(ledger.id);

      if (!mounted) return;

      // 清空缓存的交易数据（避免首页使用旧缓存）
      ref.read(cachedTransactionsProvider.notifier).state = null;

      // 触发同步状态刷新
      await PostProcessor.sync(ref, ledgerId: ledger.id);

      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;

      showToast(context, l10n.ledgersClearSuccess);
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: l10n.commonFailed,
        message: '$e',
      );
    }
  }

  /// 仅删除本地账本（保留云端备份）
  Future<void> _handleDeleteLocalLedgerOnly(BuildContext context, LedgerDisplayItem ledger) async {
    final l10n = AppLocalizations.of(context);

    final repo = ref.read(repositoryProvider);
    final allLedgers = await repo.getAllLedgers();

    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.ledgersDeleteLocalTitle,
      message: l10n.ledgersDeleteLocalMessage(translateLedgerName(context, ledger.name)),
    );

    if (confirmed != true || !mounted) return;

    try {
      final current = ref.read(currentLedgerIdProvider);

      // 如果删除的是当前账本,有其他账本就切一下;没有就让 currentLedger 落空
      // (currentLedgerProvider 查不到 ledger 返 null,首页胶囊回到「+ 新建账本」
      // 引导用户重新创建,符合"允许删完所有账本"的语义)。
      if (current == ledger.id) {
        final remainAfterDelete =
            allLedgers.where((l) => l.id != ledger.id).toList();
        if (remainAfterDelete.isNotEmpty) {
          ref.read(currentLedgerIdProvider.notifier).state =
              remainAfterDelete.first.id;
        }
      }

      // 只删除本地账本，不删除云端备份
      await repo.deleteLedger(ledger.id);

      if (!mounted) return;

      // currentLedgerProvider 是 FutureProvider,Drift 删行不会自动重算;
      // 即便 ledgerId 没变(没其他账本可切的场景)也得显式 invalidate,否则
      // 它一直 cache 旧 Ledger 对象,首页胶囊还显示已被删的账本名。
      ref.invalidate(currentLedgerProvider);
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;

      showToast(context, l10n.ledgersDeleteLocalSuccess);
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: l10n.commonFailed,
        message: '$e',
      );
    }
  }

  /// 删除本地账本
  Future<void> _handleDeleteLocalLedger(BuildContext context, LedgerDisplayItem ledger) async {
    final l10n = AppLocalizations.of(context);

    final repo = ref.read(repositoryProvider);
    final allLedgers = await repo.getAllLedgers();

    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: l10n.ledgersDeleteConfirm,
      message: l10n.ledgersDeleteMessage,
    );

    if (confirmed != true || !mounted) return;

    try {
      final sync = ref.read(syncServiceProvider);
      final current = ref.read(currentLedgerIdProvider);
      final deletedLedgerId = ledger.id;

      // 如果删除的是当前账本,有其他账本就切一下;没有就让 currentLedger 落空
      // (首页胶囊会回到「+ 新建账本」引导,允许删完所有账本)
      if (current == deletedLedgerId) {
        final remainAfterDelete =
            allLedgers.where((l) => l.id != deletedLedgerId).toList();
        if (remainAfterDelete.isNotEmpty) {
          ref.read(currentLedgerIdProvider.notifier).state =
              remainAfterDelete.first.id;
        }
      }

      // 先调 deleteRemoteBackup:此刻 ledger 行还在,deleteRemoteBackup 内部能
      // 查到 syncId 构造正确的 storage path。如果放到 deleteLedger 之后,
      // ledger 行已被删,fallback 到 ledger.id.toString() 对 UUID 账本会
      // miss(404),storage 快照清不掉。
      try {
        await sync.deleteRemoteBackup(ledgerId: deletedLedgerId);
      } catch (e) {
        logger.warning('ledger', '删除云端备份失败（忽略）：$e');
      }

      // 删除本地账本(repo.deleteLedger 内部会捕获 syncId,登记
      // ledger_snapshot:delete + 级联 transaction:delete + budget:delete change)
      await repo.deleteLedger(deletedLedgerId);

      // 显式触发对被删账本的 sync,把 delete change 推到 server 清掉 canonical
      // state。SyncCoordinator 的 ledgerIdResolver 拿的是新切换的 currentLedger,
      // 不会触发被删账本的 sync,不调这里 → delete change 永远 stranded → server
      // 还保留账本和它的全部记录,remote ledgers 列表里还会显示。
      // sync_engine.sync() 内部已对 ledgerRow==null 短路:跳过 hasRemote/fullPush/
      // pull,只走 _push 把 delete change 推上去。
      // ignore: unawaited_futures
      PostProcessor.sync(ref, ledgerId: deletedLedgerId);

      if (!mounted) return;

      // 同 _handleDeleteLocalLedgerOnly:显式 invalidate currentLedgerProvider,
      // 哪怕 ledgerId 没切(没其他账本可切),也得让首页胶囊重读 → 查不到行 →
      // 显示 "+ 新建账本"。
      ref.invalidate(currentLedgerProvider);
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;

      showToast(context, AppLocalizations.of(context).ledgersDeleted);
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).ledgersDeleteFailed,
        message: '$e',
      );
    }
  }

  /// 删除远程账本
  Future<void> _handleDeleteRemoteLedger(BuildContext context, LedgerDisplayItem ledger) async {
    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: AppLocalizations.of(context).ledgersDeleteRemoteConfirm,
      message: AppLocalizations.of(context).ledgersDeleteRemoteMessage(translateLedgerName(context, ledger.name)),
    );

    if (confirmed != true || !mounted) return;

    try {
      showToast(context, AppLocalizations.of(context).ledgersDeleting);

      final syncService = ref.read(syncServiceProvider);
      if (syncService is! TransactionsSyncManager) {
        throw Exception('Cloud sync not available');
      }

      await syncService.deleteRemoteLedger(remotePath: 'ledger_${ledger.id}.json');

      if (!mounted) return;

      ref.read(ledgerListRefreshProvider.notifier).state++;

      showToast(context, AppLocalizations.of(context).ledgersDeleteRemoteSuccess);
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).commonFailed,
        message: '$e',
      );
    }
  }

  /// 批量恢复所有远程账本
  Future<void> _handleBatchRestore(BuildContext context) async {
    // 获取远程账本数量
    final remoteLedgersAsync = ref.read(remoteLedgersProvider);
    final remoteLedgers = remoteLedgersAsync.value ?? [];

    final confirmed = await AppDialog.confirm<bool>(
      context,
      title: AppLocalizations.of(context).ledgersRestoreAllTitle,
      message: AppLocalizations.of(context).ledgersRestoreAllMessage(remoteLedgers.length),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);

    try {
      showToast(context, AppLocalizations.of(context).ledgersRestoring);

      final syncService = ref.read(syncServiceProvider);
      int success = 0;
      int failed = 0;
      if (syncService is SyncEngine) {
        // BeeCount Cloud 批量（sync_changes 日志模型）：
        // 1) syncLedgersFromServer 把所有 remote-only ledger 插到本地
        // 2) replayAllChanges 一次性从 cursor=0 重拉历史 sync_changes，apply
        //    按 entity_sync_id 幂等 upsert，把所有账本的历史统一刷回来
        // 不走 `_fullPull` 的 JSON snapshot 下载 —— 那是 S3/WebDAV 的模型。
        await syncService.syncLedgersFromServer();
        try {
          await syncService.replayAllChanges();
          success = remoteLedgers.length;
        } catch (e, st) {
          logger.warning('LedgersPage', '批量恢复远程账本失败: $e', st);
          failed = remoteLedgers.length;
        }
      } else if (syncService is TransactionsSyncManager) {
        final result = await syncService.restoreAllRemoteLedgers();
        success = result.success;
        failed = result.failed;
      } else {
        throw Exception('Cloud sync not available');
      }

      if (!mounted) return;

      setState(() => _isRestoring = false);

      // 刷新列表和同步状态
      ref.read(ledgerListRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;
      ref.read(syncStatusRefreshProvider.notifier).state++;

      // 显示结果
      await AppDialog.info(
        context,
        title: AppLocalizations.of(context).ledgersRestoreComplete,
        message: AppLocalizations.of(context).ledgersRestoreResult(
          success,
          failed,
        ),
      );
    } catch (e) {
      setState(() => _isRestoring = false);

      if (!mounted) return;

      await AppDialog.error(
        context,
        title: AppLocalizations.of(context).commonFailed,
        message: '$e',
      );
    }
  }

  /// 显示创建账本对话框
  Future<void> _showCreateLedgerDialog(BuildContext context) async {
    final result = await _showLedgerEditorDialog(
      context,
      title: AppLocalizations.of(context).ledgersNew,
    );

    if (result == null || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);
      final newLedgerId = await repo.createLedger(
        name: result.name.trim(),
        currency: result.currency,
      );

      // 空账本场景(welcome 未勾默认账本 / 老用户导入配置不含账本)进入此页
      // 创建第一个账本时,currentLedgerIdProvider 还指向默认值 1(无效),
      // 必须切到新账本 id 否则首页 header 胶囊继续显示「新建账本」、列表为
      // 空。已有账本时不动 currentLedger,保留用户当前所在账本。
      if (!mounted) return;
      final currentLedger = await ref.read(currentLedgerProvider.future);
      if (currentLedger == null) {
        ref.read(currentLedgerIdProvider.notifier).state = newLedgerId;
        ref.invalidate(currentLedgerProvider);
      }

      ref.read(ledgerListRefreshProvider.notifier).state++;

      // 显式触发新账本的同步。createLedger 不会切换 currentLedger,所以
      // SyncCoordinator 的 ledgerIdResolver 拿的还是旧账本,新账本的同步永
      // 远不会被自动触发。这里直接对 newLedgerId 调一次 sync,让 server 立
      // 即创建对应账本(走 sync 内的 !hasRemote → fullPush 路径)。
      // 不调的话,要等到用户切到新账本并加第一笔交易才会被动同步,违反"创
      // 建后立即可见"预期。
      // ignore: unawaited_futures
      PostProcessor.sync(ref, ledgerId: newLedgerId);

      if (!mounted) return;
      showToast(context, '账本创建成功');
    } catch (e) {
      if (!mounted) return;
      showToast(context, '创建失败: ${e.toString()}');
    }
  }

  /// 账本编辑对话框
  Future<({String name, String currency})?> _showLedgerEditorDialog(
    BuildContext context, {
    String? title,
    String? initialName,
    String? initialCurrency,
  }) async {
    String name = initialName ?? '';
    String currency = initialCurrency ?? 'CNY';
    final nameCtrl = TextEditingController(text: name);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final primary = Theme.of(ctx).colorScheme.primary;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          content: StatefulBuilder(builder: (ctx, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title ?? AppLocalizations.of(ctx).ledgersEdit,
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(ctx).ledgersName,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppLocalizations.of(ctx).ledgersCurrency),
                  subtitle: Text(displayCurrency(currency, context)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await _showCurrencyPicker(ctx, initial: currency);
                    if (picked != null) {
                      setState(() => currency = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary),
                      ),
                      child: Text(AppLocalizations.of(ctx).commonCancel),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        title == AppLocalizations.of(ctx).ledgersNew
                            ? AppLocalizations.of(ctx).ledgersCreate
                            : AppLocalizations.of(ctx).commonSave,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            );
          }),
        );
      },
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      return (name: nameCtrl.text.trim(), currency: currency);
    }

    return null;
  }

  /// 货币选择器
  Future<String?> _showCurrencyPicker(BuildContext context, {String? initial}) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeeTokens.surfaceElevated(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bctx) {
        String query = '';
        String? selected = initial;
        return StatefulBuilder(builder: (sctx, setState) {
          final filtered = getCurrencies(context).where((c) {
            final q = query.trim();
            if (q.isEmpty) return true;
            final uq = q.toUpperCase();
            return c.code.contains(uq) || c.name.contains(q);
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(bctx).viewInsets.bottom,
            ),
            child: SizedBox(
              height: 420,
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: BeeTokens.textTertiary(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(bctx).ledgersSelectCurrency,
                    style: Theme.of(bctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: AppLocalizations.of(bctx).ledgersSearchCurrency,
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final sel = c.code == selected;
                        return ListTile(
                          title: Text('${c.name} (${c.code})'),
                          trailing: sel
                              ? Icon(Icons.check, color: BeeTokens.textPrimary(context))
                              : null,
                          onTap: () => Navigator.pop(bctx, c.code),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  /// 显示冲突解决对话框
  Future<void> _showConflictResolutionDialog(BuildContext context, LedgerDisplayItem ledger) async {
    

    final l10n = AppLocalizations.of(context);
    final syncService = ref.read(syncServiceProvider);

    // 获取同步状态详情
    final syncStatus = await syncService.getStatus(ledgerId: ledger.id);

    if (!mounted) return;

    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stateContext, setState) {
            bool isProcessing = false;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Text(l10n.ledgersConflictTitle),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ledgersConflictMessage,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),

                    // 本地信息
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.ledgersConflictLocalInfo(syncStatus.localCount),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.ledgersConflictLocalFingerprint(
                              syncStatus.localFingerprint.substring(0, 8),
                            ),
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 云端信息
                    if (syncStatus.cloudFingerprint != null && syncStatus.cloudExportedAt != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.ledgersConflictRemoteInfo(syncStatus.cloudCount ?? 0),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.ledgersConflictRemoteUpdated(
                                dateFormat.format(syncStatus.cloudExportedAt!.toLocal()),
                              ),
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.ledgersConflictRemoteFingerprint(
                                syncStatus.cloudFingerprint!.substring(0, 8),
                              ),
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                if (isProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(l10n.commonCancel),
                  ),
                  TextButton(
                    onPressed: () async {
                      setState(() => isProcessing = true);
                      try {
                        showToast(context, l10n.ledgersConflictDownloading);
                        final result = await syncService.downloadAndRestoreToCurrentLedger(
                          ledgerId: ledger.id,
                        );

                        if (stateContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (!mounted) return;

                        // 下载完成后，触发刷新状态和账本列表
                        await PostProcessor.sync(ref, ledgerId: ledger.id);

                        // 刷新统计
                        ref.read(statsRefreshProvider.notifier).state++;

                        showToast(
                          context,
                          l10n.ledgersConflictDownloadSuccess(result.inserted),
                        );
                      } catch (e) {
                        setState(() => isProcessing = false);
                        if (stateContext.mounted) {
                          await AppDialog.error(
                            stateContext,
                            title: l10n.commonFailed,
                            message: '$e',
                          );
                        }
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.download, size: 18),
                        const SizedBox(width: 4),
                        Text(l10n.ledgersConflictDownload),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () async {
                      setState(() => isProcessing = true);
                      try {
                        showToast(context, l10n.ledgersConflictUploading);
                        await syncService.uploadCurrentLedger(ledgerId: ledger.id);

                        if (stateContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (!mounted) return;

                        // 刷新列表和同步状态
                        ref.read(ledgerListRefreshProvider.notifier).state++;
                        ref.read(syncStatusRefreshProvider.notifier).state++;

                        showToast(context, l10n.ledgersConflictUploadSuccess);
                      } catch (e) {
                        setState(() => isProcessing = false);
                        if (stateContext.mounted) {
                          await AppDialog.error(
                            stateContext,
                            title: l10n.commonFailed,
                            message: '$e',
                          );
                        }
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.upload, size: 18),
                        const SizedBox(width: 4),
                        Text(l10n.ledgersConflictUpload),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// 区域标题
class _SectionHeader extends ConsumerWidget {
  final String title;
  final String? trailing;
  final Widget? action;

  const _SectionHeader({
    required this.title,
    this.trailing,
    this.action,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16.0.scaled(context, ref),
        8.0.scaled(context, ref),
        16.0.scaled(context, ref),
        8.0.scaled(context, ref),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.0.scaled(context, ref),
              fontWeight: FontWeight.w600,
              color: BeeTokens.textSecondary(context),
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: 8.0.scaled(context, ref)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8.0.scaled(context, ref),
                vertical: 2.0.scaled(context, ref),
              ),
              decoration: BoxDecoration(
                color: BeeTokens.surfaceSecondary(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                trailing!,
                style: TextStyle(
                  fontSize: 12.0.scaled(context, ref),
                  color: BeeTokens.textTertiary(context),
                ),
              ),
            ),
          ],
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}
