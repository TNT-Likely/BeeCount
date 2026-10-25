import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;

import '../../../providers.dart';
import '../../../widgets/ui/ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/cloud_shared.dart';
import 'page_scaffold.dart';
import 'cloud_shared_user.dart';
import '../../../styles/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../cloud/sync/sync_engine.dart';
import '../../../services/system/logger_service.dart';
import '../../../pages/auth/login_page.dart';
import '../../../pages/settings/log_center_page.dart';

/// BeeCount Cloud 专属同步页
///
/// 跟老的 `cloud_sync_page.dart` 分开:老页面服务于 iCloud / WebDAV / 本地
/// 备份,UI 语义是"整包快照上传/下载";BeeCount Cloud 是增量 sync_changes 日志,
/// 全自动,用户感知不到"上传/下载"这个动作,所以单独一个页面。
///
/// 页面结构:
///   1. Header + 账号信息(已登录 / 重新登录按钮 / 登录入口)
///   2. 同步状态面板(localTx / remoteTx / localAttachments / remoteAttachments
///      / localAccounts / remoteAccounts / localCategories / remoteCategories
///      / localTags / remoteTags / localBudgets / remoteBudgets / unpushedChanges)
///   3. 下拉刷新:调 checkSyncHealth → 有差异就自动 sync()
class CloudSharedSyncControls extends ConsumerStatefulWidget {
  const CloudSharedSyncControls({super.key});

  @override
  ConsumerState<CloudSharedSyncControls> createState() =>
      _CloudSharedSyncControlsState();
}

class _CloudSharedSyncControlsState
    extends ConsumerState<CloudSharedSyncControls> {
  SyncHealthReport? _latestReport;
  bool _checking = false;
  bool _autoSyncing = false;
  bool _relogging = false;
  String? _checkError;

  @override
  void initState() {
    super.initState();
    // 页面一进来就拉一次 sync health,让"同步状态"面板开屏即有内容。
    // server 版本号改用 [beecountCloudServerVersionProvider] 自动获取(它依赖
    // syncStatusRefreshProvider,每次同步完成自动重新拉一次),不再用本地
    // setState 缓存的死值——server 升级后用户在 app 内任何同步操作完都会刷新。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      unawaited(_onRefresh());
    });
  }

  Future<void> _onRefresh() async {
    // 整个流程异步跑得久(10k 数据可能几分钟),用户随时可能切走页面 →
    // widget dispose,ref 失效。所有访问 ref 的地方都先看 mounted。
    if (!mounted || _checking) return;
    final engine = ref.read(syncServiceProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);
    if (engine is! SyncEngine || ledgerId <= 0) return;

    bool active() => mounted && ref.read(currentLedgerIdProvider) == ledgerId;
    setState(() {
      _checking = true;
      _checkError = null;
    });
    try {
      // Step 1: 对账 profile。把"server 上缺但本地有"的字段补推上去。
      if (!active()) return;
      await reconcileProfileToServer(
        cloudProviderFuture: ref.read(beecountCloudProviderInstance.future),
        currentThemeColor: ref.read(primaryColorProvider),
        currentIncomeIsRed: ref.read(incomeExpenseColorSchemeProvider),
        currentHeaderStyle: ref.read(headerDecorationStyleProvider),
        currentCompactAmount: ref.read(compactAmountProvider),
        currentShowTransactionTime: ref.read(showTransactionTimeProvider),
        currentDisplayName: ref.read(displayNameProvider),
        currentHeaderSkin: ref.read(headerSkinProvider),
        currentNoteDisplayMode: ref.read(noteDisplayModeProvider),
        currentNoteHistoryScope: ref.read(noteHistoryScopeProvider).name,
        currentNoteHistorySort: ref.read(noteHistorySortProvider).name,
        currentNoteHistoryLimit: ref.read(noteHistoryLimitProvider),
      );
      if (!active()) return;
      await engine.syncMyProfile();

      if (!active()) return;
      var report = await engine.checkSyncHealth(ledgerId: ledgerId);
      if (!active()) return;
      setState(() => _latestReport = report);

      if (report.needsBackfill) {
        final backfilled =
            await engine.backfillUntrackedEntities(ledgerId: ledgerId);
        logger.info('CloudSyncPage',
            '_onRefresh: backfill 补写 $backfilled 条 sync_change');
        if (backfilled > 0 && active()) {
          report = await engine.checkSyncHealth(ledgerId: ledgerId);
          if (active()) setState(() => _latestReport = report);
        }
      }

      if (report.hasDiff && active()) {
        setState(() => _autoSyncing = true);
        try {
          final result = await engine.sync(ledgerId: ledgerId.toString());
          if (result.hasError) throw StateError(result.error!);
          if (!active()) return;
          final after = await engine.checkSyncHealth(ledgerId: ledgerId);
          if (active()) setState(() => _latestReport = after);
        } catch (e) {
          if (mounted && active()) {
            setState(() => _checkError = e.toString());
            showToast(
                context, '${AppLocalizations.of(context).commonFailed}: $e');
          }
        } finally {
          if (active()) setState(() => _autoSyncing = false);
        }
      }

      // 不管是否 sync,都 bump 下 UI tick。widget 已 dispose 时跳过 —
      // 否则 ref.read 会抛 StateError "Cannot use ref after the widget was disposed"。
      if (active()) {
        ref.read(syncStatusRefreshProvider.notifier).state++;
      }
    } catch (e) {
      if (active()) setState(() => _checkError = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
          _autoSyncing = false;
        });
        if (ref.read(currentLedgerIdProvider) != ledgerId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _onRefresh();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final l10n = AppLocalizations.of(context);
    ref.listen<int>(currentLedgerIdProvider, (_, __) {
      setState(() {
        _latestReport = null;
        _checkError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onRefresh();
      });
    });
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l10n.cloudSyncPageTitle,
          subtitle: l10n.cloudSyncPageSubtitle,
          leading: const BackButton(),
          actions: ledgerId <= 0
              ? const []
              : [
                  BeeIconButton(
                      label: l10n.v4RecordingRetry,
                      icon: const BeeLineIcon('RefreshCw', size: 21),
                      onPressed: _checking ? null : _onRefresh),
                ]),
      Expanded(
        child: ledgerId <= 0
            ? BeeEmptyState(
                title: l10n.aiOcrNoLedger,
                icon: const BeeLineIcon('BookOpen', size: 36))
            : ref.watch(cloudSharedUserProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => BeeEmptyState(
                    title: '${l10n.commonError}: $error',
                    action: BeeButton(
                        label: l10n.v4RecordingRetry,
                        onPressed: () =>
                            ref.invalidate(cloudSharedUserProvider))),
                data: (user) => RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView(
                        padding: const EdgeInsets.all(17),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          _buildAccountSection(context, user),
                          const SizedBox(height: 12),
                          const _TwoFactorStatusRow(),
                          const SizedBox(height: 12),
                          BeeCloudSharedCard(
                              child: _buildHealthSection(context)),
                          const SizedBox(height: 12),
                          BeeCloudSharedCard(
                              child: _buildSyncHelpSection(context)),
                          Consumer(builder: (context, r, _) {
                            final v = r
                                .watch(beecountCloudServerVersionProvider)
                                .valueOrNull;
                            if (v == null || v.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                child: Text('BeeCount Cloud v$v',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).hintColor)));
                          }),
                        ]))),
      ),
    ]));
  }

  Widget _buildAccountSection(BuildContext context, CloudUser? user) {
    final l10n = AppLocalizations.of(context);
    final cfg = ref.watch(activeCloudConfigProvider).valueOrNull;
    final cachedEmail = cfg?.beecountCloudEmail ?? '';
    final cachedPassword = cfg?.beecountCloudPassword ?? '';
    final hasCredentials = cachedEmail.isNotEmpty && cachedPassword.isNotEmpty;

    if (user != null) {
      return BeeCloudSharedAction(
        icon: const BeeLineIcon('ShieldCheck', size: 21),
        title: user.email ?? l10n.mineLoggedInEmail,
      );
    }

    // 未登录 + 有保存的邮密 → 显示"重新登录"按钮,点击直接调 signInWithEmail
    if (hasCredentials) {
      return BeeCloudSharedAction(
        icon: const BeeLineIcon('RefreshCw', size: 21),
        busy: _relogging,
        title: l10n.cloudReloginTitle,
        subtitle: cachedEmail,
        onTap: () async {
          if (_relogging) return;
          setState(() => _relogging = true);
          try {
            final provider =
                await ref.read(beecountCloudProviderInstance.future);
            if (provider == null) throw StateError(l10n.cloudReloginFailed);
            await provider.auth.signInWithEmail(
              email: cachedEmail,
              password: cachedPassword,
            );
            if (!context.mounted) return;
            showToast(context, l10n.cloudReloginSuccess);
            ref.read(syncStatusRefreshProvider.notifier).state++;
            ref.read(statsRefreshProvider.notifier).state++;
          } catch (e) {
            if (!context.mounted) return;
            showToast(context, '${l10n.cloudReloginFailed}: $e');
          } finally {
            if (mounted) setState(() => _relogging = false);
          }
        },
      );
    }

    // 没凭证 → 跳传统登录页
    return BeeCloudSharedAction(
      icon: const BeeLineIcon('LogIn', size: 21),
      title: l10n.mineLoginTitle,
      subtitle: l10n.mineLoginSubtitle,
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        if (mounted) ref.read(syncStatusRefreshProvider.notifier).state++;
      },
    );
  }

  /// 同步说明(可折叠):增量/全量、何时走全量、断点续传、排查入口。
  Widget _buildSyncHelpSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Theme(
      // 去掉 ExpansionTile 默认的上下分割线,贴合 SectionCard 风格
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        leading:
            Icon(Icons.help_outline, color: BeeTokens.iconSecondary(context)),
        title: Text(
          l10n.cloudSyncHelpTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: BeeTokens.textPrimary(context),
          ),
        ),
        children: [
          _helpBlock(context, l10n.cloudSyncHelpModesTitle,
              l10n.cloudSyncHelpModesBody),
          _helpBlock(context, l10n.cloudSyncHelpWhenFullTitle,
              l10n.cloudSyncHelpWhenFullBody),
          _helpBlock(context, l10n.cloudSyncHelpStuckTitle,
              l10n.cloudSyncHelpStuckBody),
          _helpBlock(context, l10n.cloudSyncHelpTroubleshootTitle,
              l10n.cloudSyncHelpTroubleshootBody),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogCenterPage()),
              ),
              style: TextButton.styleFrom(
                foregroundColor: ref.watch(primaryColorProvider),
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.article_outlined, size: 18),
              label: Text(l10n.cloudSyncHelpOpenLogCenter),
            ),
          ),
        ],
      ),
    );
  }

  /// 同步说明里的一段:加粗小标题 + 正文(正文里用 \n 分条)。
  Widget _helpBlock(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BeeTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: BeeTokens.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthSection(BuildContext context) {
    // SectionCard 已经给了 p12 内边距,这里内部只做垂直间距,不再加横向 padding。
    final l10n = AppLocalizations.of(context);
    final report = _latestReport;
    final title = Row(
      children: [
        Icon(Icons.cloud_sync_outlined,
            color: BeeTokens.iconSecondary(context), size: 20),
        const SizedBox(width: 8),
        Text(l10n.syncHealthTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: BeeTokens.textPrimary(context),
                  fontWeight: FontWeight.w600,
                )),
        const Spacer(),
        if (_checking || _autoSyncing)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );

    // 初次 init 时 report 还没填,仍然把面板骨架 + 占位值画出来(用户要求常驻)。
    final effective = report ??
        const SyncHealthReport(
          ledgerTx: SyncCountPair.missing(),
          ledgerAttachments: SyncCountPair.missing(),
          ledgerBudgets: SyncCountPair.missing(),
          totalTx: SyncCountPair.missing(),
          totalAttachments: SyncCountPair.missing(),
          totalBudgets: SyncCountPair.missing(),
          categoryAttachments: SyncCountPair.missing(),
          accounts: SyncCountPair.missing(),
          categories: SyncCountPair.missing(),
          tags: SyncCountPair.missing(),
          unpushedChanges: 0,
        );

    if (_checkError != null || effective.error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 8),
          Text(
            l10n.syncHealthCheckFailed(_checkError ?? effective.error ?? ''),
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
          const SizedBox(height: 12),
          BeeButton(
              label: l10n.v4RecordingRetry,
              kind: BeeButtonKind.secondary,
              onPressed: _checking ? null : _onRefresh),
        ],
      );
    }

    final summary = report == null
        ? l10n.mineCloudServiceLoading
        : effective.hasDiff
            ? l10n.syncHealthHasDiff
            : l10n.syncHealthInSync;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        const SizedBox(height: 6),
        Text(
          summary,
          style: TextStyle(
            fontSize: 12,
            color: effective.hasDiff
                ? Colors.orange
                : BeeTokens.textSecondary(context),
          ),
        ),
        const SizedBox(height: 8),
        // 当前账本口径:tx / 附件 / 预算随 ledger 走
        _groupHeader(context, l10n.syncHealthGroupCurrentLedger),
        _pairRow(context, l10n.syncHealthRowTx, effective.ledgerTx),
        _pairRow(
            context, l10n.syncHealthRowAttachment, effective.ledgerAttachments),
        _pairRow(context, l10n.syncHealthRowBudget, effective.ledgerBudgets),
        const SizedBox(height: 8),
        // 全部账本口径:tx/附件/预算 合计 + 用户级的 account/category/tag
        _groupHeader(context, l10n.syncHealthGroupAll),
        _pairRow(context, l10n.syncHealthRowTx, effective.totalTx),
        _pairRow(
            context, l10n.syncHealthRowAttachment, effective.totalAttachments),
        _pairRow(context, l10n.syncHealthRowCategoryIcon,
            effective.categoryAttachments),
        _pairRow(context, l10n.syncHealthRowBudget, effective.totalBudgets),
        _pairRow(context, l10n.syncHealthRowAccount, effective.accounts),
        _pairRow(context, l10n.syncHealthRowCategory, effective.categories),
        _pairRow(context, l10n.syncHealthRowTag, effective.tags),
        const SizedBox(height: 8),
        _unpushedRow(context, effective.unpushedChanges),
      ],
    );
  }

  Widget _groupHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: BeeTokens.textTertiary(context),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _pairRow(BuildContext context, String label, SyncCountPair pair) =>
      BeeCloudSharedHealthRow(
        label: label,
        value: pair.remote < 0
            ? AppLocalizations.of(context)
                .syncHealthValueRemoteMissing(pair.local)
            : AppLocalizations.of(context)
                .syncHealthValue(pair.local, pair.remote),
        warning: pair.hasDiff,
      );
  Widget _unpushedRow(BuildContext context, int count) =>
      BeeCloudSharedHealthRow(
          label: AppLocalizations.of(context).syncHealthRowUnpushed,
          value: '$count',
          warning: count > 0);
}

/// 2FA 状态展示行(只读)。
///
/// 拉取 GET /auth/2fa/status,展示「已启用 ✓ · 启用于 YYYY-MM-DD」或「未启用」。
/// 拉取失败(未登录 / 网络错 / 不是 BeeCount Cloud)→ 整行隐藏,不展示假数据。
///
/// 监听 [syncStatusRefreshProvider] tick(用户重新登录 / 同步成功后会 bump),
/// 自动重新拉取,所以切换云方案再切回来也能拿到最新状态。
///
/// 设计文档:.docs/2fa-design.md(第 4.6 节,App 端 only-read 状态)。
class _TwoFactorStatusRow extends ConsumerStatefulWidget {
  const _TwoFactorStatusRow();

  @override
  ConsumerState<_TwoFactorStatusRow> createState() =>
      _TwoFactorStatusRowState();
}

class _TwoFactorStatusRowState extends ConsumerState<_TwoFactorStatusRow> {
  TwoFactorStatus? _status;
  bool _loaded = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    bool active() => mounted && generation == _loadGeneration;
    try {
      final provider = await ref.read(beecountCloudProviderInstance.future);
      if (provider == null) {
        if (active()) {
          setState(() {
            _loaded = true;
            _status = null;
          });
        }
        return;
      }
      // currentUser 是 null 时再请求会拿到 401 / 走 silent recovery 也拿不到
      // session,所以提前判断登录态,避免无谓请求 + 闪烁。
      final user = await provider.auth.currentUser;
      if (user == null) {
        if (active()) {
          setState(() {
            _loaded = true;
            _status = null;
          });
        }
        return;
      }
      final s = await provider.getTwoFactorStatus();
      if (!active()) return;
      setState(() {
        _status = s;
        _loaded = true;
      });
    } catch (e) {
      if (!active()) return;
      setState(() {
        _loaded = true;
        _status = null;
      });
      logger.warning('2fa.status.fetch.failed', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // syncStatusRefreshProvider 在「重新登录成功 / 同步完成」时 bump,
    // 监听它就能让切换云方案后回来 / 用户重新登录后自动重新拉取 2FA 状态。
    ref.listen<int>(syncStatusRefreshProvider, (_, __) => _load());

    // 还没加载完 / 拉取失败 / 未登录 / 不是 BeeCount Cloud → 整行隐藏。
    // 不显示 loading 占位避免初次进入页面时闪一下。
    if (!_loaded || _status == null) {
      return const SizedBox.shrink();
    }
    final status = _status!;

    final enabledLabel =
        status.enabled ? l10n.twofaStatusEnabled : l10n.twofaStatusDisabled;
    final subtitle = status.enabled && status.enabledAt != null
        ? l10n.twofaStatusEnabledAt(
            '${status.enabledAt!.year}-${status.enabledAt!.month.toString().padLeft(2, '0')}-${status.enabledAt!.day.toString().padLeft(2, '0')}',
          )
        : null;

    return BeeCloudSharedAction(
      icon:
          BeeLineIcon(status.enabled ? 'ShieldCheck' : 'LockKeyhole', size: 21),
      title: '${l10n.twofaStatusTitle} · $enabledLabel',
      subtitle: subtitle,
    );
  }
}
