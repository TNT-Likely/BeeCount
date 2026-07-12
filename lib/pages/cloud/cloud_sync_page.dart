import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;

import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../services/billing/post_processor.dart';
import '../../cloud/sync_service.dart';
import '../../cloud/transactions_sync_manager.dart';
import '../auth/login_page.dart';
import 'sync_preview_dialog.dart';

/// 云同步与备份二级页面 - 包含所有同步操作
class CloudSyncPage extends ConsumerStatefulWidget {
  const CloudSyncPage({super.key});

  @override
  ConsumerState<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends ConsumerState<CloudSyncPage> {
  bool uploadBusy = false;
  bool downloadBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // 仅在多设备同步开关开启时，清除状态缓存并强制刷新
      final prefs = await SharedPreferences.getInstance();
      final multiDevice = prefs.getBool('multi_device_sync') ?? false;
      if (!multiDevice || !mounted) return;
      final sync = ref.read(syncServiceProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);
      sync.clearStatusCache(ledgerId: ledgerId);
      ref.read(syncStatusRefreshProvider.notifier).state++;
    });
  }

  Future<void> _onRefresh() async {
    final sync = ref.read(syncServiceProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);
    sync.clearStatusCache(ledgerId: ledgerId);
    ref.read(syncStatusRefreshProvider.notifier).state++;
    // 等待状态刷新完成
    await ref.read(syncStatusProvider(ledgerId).future);
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authServiceProvider);
    final sync = ref.watch(syncServiceProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);

    if (ledgerId == 0) {
      return Scaffold(
        backgroundColor: BeeTokens.scaffoldBackground(context),
        body: Column(
          children: [
            PrimaryHeader(
              title: AppLocalizations.of(context).cloudSyncPageTitle,
              subtitle: AppLocalizations.of(context).cloudSyncPageSubtitle,
              showBack: true,
            ),
            Expanded(
              child: Center(
                child: Text(
                  AppLocalizations.of(context).aiOcrNoLedger,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BeeTokens.textSecondary(context),
                      ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context).cloudSyncPageTitle,
            subtitle: AppLocalizations.of(context).cloudSyncPageSubtitle,
            showBack: true,
          ),
          Expanded(
            child: authAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('${AppLocalizations.of(context).commonError}: $e'),
              ),
              data: (auth) => FutureBuilder<CloudUser?>(
                future: auth.currentUser,
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final user = snap.data;
                  final cloudConfig = ref.watch(activeCloudConfigProvider);
                  final isLocalMode = cloudConfig.hasValue &&
                      cloudConfig.value!.type == CloudBackendType.local;
                  final isBeeCountCloud = cloudConfig.hasValue &&
                      cloudConfig.value!.type == CloudBackendType.beecountCloud;
                  final needsLogin = cloudConfig.hasValue &&
                      (cloudConfig.value!.type == CloudBackendType.supabase ||
                          cloudConfig.value!.type ==
                              CloudBackendType.beecountCloud);
                  // Supabase 和 BeeCount Cloud 需要登录，其他云服务（iCloud/S3/WebDAV）使用配置文件认证
                  final canUseCloud =
                      !isLocalMode && (!needsLogin || user != null);

                  final asyncSt = ref.watch(syncStatusProvider(ledgerId));
                  final cached = ref.watch(lastSyncStatusProvider(ledgerId));
                  final st = asyncSt.asData?.value ?? cached;

                  final isFirstLoad = st == null;
                  final refreshing = asyncSt.isLoading;
                  bool inSync = false;
                  bool notLoggedIn = false;

                  // 计算同步状态显示
                  String subtitle = '';
                  IconData icon = Icons.sync_outlined;

                  if (!isFirstLoad) {
                    switch (st.diff) {
                      case SyncDiff.notLoggedIn:
                        subtitle =
                            AppLocalizations.of(context).mineSyncNotLoggedIn;
                        icon = Icons.lock_outline;
                        notLoggedIn = true;
                        break;
                      case SyncDiff.notConfigured:
                        subtitle =
                            AppLocalizations.of(context).mineSyncNotConfigured;
                        icon = Icons.cloud_off_outlined;
                        break;
                      case SyncDiff.noRemote:
                        subtitle =
                            AppLocalizations.of(context).mineSyncNoRemote;
                        icon = Icons.cloud_queue_outlined;
                        break;
                      case SyncDiff.inSync:
                        subtitle = AppLocalizations.of(context)
                            .mineSyncInSync(st.localCount);
                        icon = Icons.verified_outlined;
                        inSync = true;
                        break;
                      case SyncDiff.localNewer:
                        subtitle = AppLocalizations.of(context)
                            .mineSyncLocalNewer(st.localCount);
                        icon = Icons.upload_outlined;
                        break;
                      case SyncDiff.cloudNewer:
                        subtitle =
                            AppLocalizations.of(context).mineSyncCloudNewer;
                        icon = Icons.download_outlined;
                        break;
                      case SyncDiff.different:
                        subtitle =
                            AppLocalizations.of(context).mineSyncDifferent;
                        icon = Icons.change_circle_outlined;
                        break;
                      case SyncDiff.error:
                        String? localizedMessage;
                        if (st.message != null) {
                          switch (st.message!) {
                            case '__SYNC_NOT_CONFIGURED__':
                              localizedMessage = AppLocalizations.of(context)
                                  .syncNotConfiguredMessage;
                              break;
                            case '__SYNC_NOT_LOGGED_IN__':
                              localizedMessage = AppLocalizations.of(context)
                                  .syncNotLoggedInMessage;
                              break;
                            case '__SYNC_CLOUD_BACKUP_CORRUPTED__':
                              localizedMessage = AppLocalizations.of(context)
                                  .syncCloudBackupCorruptedMessage;
                              break;
                            case '__SYNC_NO_CLOUD_BACKUP__':
                              localizedMessage = AppLocalizations.of(context)
                                  .syncNoCloudBackupMessage;
                              break;
                            case '__SYNC_ACCESS_DENIED__':
                              localizedMessage = AppLocalizations.of(context)
                                  .syncAccessDeniedMessage;
                              break;
                            default:
                              localizedMessage = st.message;
                          }
                        }
                        subtitle = localizedMessage ??
                            AppLocalizations.of(context).mineSyncError;
                        icon = Icons.error_outline;
                        break;
                    }
                  }

                  return RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // 提示文案（仅非 BeeCount Cloud 模式显示）
                          if (!isBeeCountCloud)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                AppLocalizations.of(context).cloudSyncHint,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BeeTokens.textTertiary(context),
                                ),
                              ),
                            ),
                          // 同步操作 Section
                          SectionCard(
                            margin: EdgeInsets.zero,
                            child: Column(
                              children: [
                                // 同步状态
                                AppListTile(
                                  leading: icon,
                                  title: AppLocalizations.of(context)
                                      .mineSyncTitle,
                                  subtitle: isFirstLoad ? null : subtitle,
                                  enabled: canUseCloud &&
                                      !isFirstLoad &&
                                      !refreshing &&
                                      !uploadBusy &&
                                      !downloadBusy,
                                  trailing: (canUseCloud &&
                                          (isFirstLoad ||
                                              refreshing ||
                                              uploadBusy ||
                                              downloadBusy))
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : null,
                                  onTap: (isFirstLoad ||
                                          !canUseCloud ||
                                          refreshing ||
                                          uploadBusy ||
                                          downloadBusy)
                                      ? null
                                      : () async {
                                          if (!context.mounted) return;
                                          final lines = <String>[
                                            AppLocalizations.of(context)
                                                .mineSyncLocalRecords(
                                                    st.localCount),
                                            if (st.cloudCount != null)
                                              AppLocalizations.of(context)
                                                  .mineSyncCloudRecords(
                                                      st.cloudCount!),
                                            if (st.cloudExportedAt != null)
                                              AppLocalizations.of(context)
                                                  .mineSyncCloudLatest(DateFormat(
                                                          'yyyy-MM-dd HH:mm:ss')
                                                      .format(st
                                                          .cloudExportedAt!
                                                          .toLocal())),
                                            AppLocalizations.of(context)
                                                .mineSyncLocalFingerprint(
                                                    st.localFingerprint),
                                            if (st.cloudFingerprint != null)
                                              AppLocalizations.of(context)
                                                  .mineSyncCloudFingerprint(
                                                      st.cloudFingerprint!),
                                            if (st.message != null)
                                              () {
                                                String localizedMessage =
                                                    st.message!;
                                                switch (st.message!) {
                                                  case '__SYNC_NOT_CONFIGURED__':
                                                    localizedMessage =
                                                        AppLocalizations.of(
                                                                context)
                                                            .syncNotConfiguredMessage;
                                                    break;
                                                  case '__SYNC_NOT_LOGGED_IN__':
                                                    localizedMessage =
                                                        AppLocalizations.of(
                                                                context)
                                                            .syncNotLoggedInMessage;
                                                    break;
                                                  case '__SYNC_CLOUD_BACKUP_CORRUPTED__':
                                                    localizedMessage =
                                                        AppLocalizations.of(
                                                                context)
                                                            .syncCloudBackupCorruptedMessage;
                                                    break;
                                                  case '__SYNC_NO_CLOUD_BACKUP__':
                                                    localizedMessage =
                                                        AppLocalizations.of(
                                                                context)
                                                            .syncNoCloudBackupMessage;
                                                    break;
                                                  case '__SYNC_ACCESS_DENIED__':
                                                    localizedMessage =
                                                        AppLocalizations.of(
                                                                context)
                                                            .syncAccessDeniedMessage;
                                                    break;
                                                }
                                                return AppLocalizations.of(
                                                        context)
                                                    .mineSyncMessage(
                                                        localizedMessage);
                                              }(),
                                          ];
                                          await AppDialog.info(context,
                                              title:
                                                  AppLocalizations.of(context)
                                                      .mineSyncDetailTitle,
                                              message: lines.join('\n'));
                                        },
                                ),
                                // ===== BeeCount Cloud 模式：同步状态 + 登录（无需手动操作） =====
                                if (isBeeCountCloud) ...[
                                  // 登录（未登录时显示登录入口）
                                  Consumer(builder: (ctx, r, _) {
                                    final userNow = user;
                                    final cfg = r
                                        .watch(activeCloudConfigProvider)
                                        .valueOrNull;
                                    final cachedEmail =
                                        cfg?.beecountCloudEmail ?? '';
                                    final cachedPassword =
                                        cfg?.beecountCloudPassword ?? '';
                                    final hasCachedCredentials =
                                        cachedEmail.isNotEmpty &&
                                            cachedPassword.isNotEmpty;
                                    if (userNow != null) {
                                      // 已登录：仅显示账号信息，不提供退出
                                      return Column(
                                        children: [
                                          BeeTokens.cardDivider(context),
                                          AppListTile(
                                            leading:
                                                Icons.verified_user_outlined,
                                            title: userNow.email ??
                                                AppLocalizations.of(context)
                                                    .mineLoggedInEmail,
                                          ),
                                        ],
                                      );
                                    }
                                    // 未登录：如果 config 里有保存的邮密,直接给"重新登录"
                                    // 按钮,不需要跳登录页;否则才显示老的跳登录页入口。
                                    if (hasCachedCredentials) {
                                      return Column(
                                        children: [
                                          BeeTokens.cardDivider(context),
                                          AppListTile(
                                            leading: Icons.refresh,
                                            title: AppLocalizations.of(context)
                                                .cloudReloginTitle,
                                            subtitle: cachedEmail,
                                            onTap: () async {
                                              final providerAsync = ref.read(
                                                  beecountCloudProviderInstance);
                                              final provider =
                                                  providerAsync.valueOrNull;
                                              if (provider == null) {
                                                showToast(
                                                    context,
                                                    AppLocalizations.of(context)
                                                        .cloudReloginFailed);
                                                return;
                                              }
                                              try {
                                                await provider.auth
                                                    .signInWithEmail(
                                                  email: cachedEmail,
                                                  password: cachedPassword,
                                                );
                                                if (!context.mounted) return;
                                                showToast(
                                                    context,
                                                    AppLocalizations.of(context)
                                                        .cloudReloginSuccess);
                                                ref
                                                    .read(
                                                        syncStatusRefreshProvider
                                                            .notifier)
                                                    .state++;
                                                ref
                                                    .read(statsRefreshProvider
                                                        .notifier)
                                                    .state++;
                                              } catch (e) {
                                                if (!context.mounted) return;
                                                showToast(context,
                                                    '${AppLocalizations.of(context).cloudReloginFailed}: $e');
                                              }
                                            },
                                          ),
                                        ],
                                      );
                                    }
                                    // 没凭证时,走原来的登录页
                                    return Column(
                                      children: [
                                        BeeTokens.cardDivider(context),
                                        AppListTile(
                                          leading: Icons.login,
                                          title: AppLocalizations.of(context)
                                              .mineLoginTitle,
                                          subtitle: AppLocalizations.of(context)
                                              .mineLoginSubtitle,
                                          onTap: () async {
                                            await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const LoginPage()));
                                            ref
                                                .read(syncStatusRefreshProvider
                                                    .notifier)
                                                .state++;
                                            ref
                                                .read(statsRefreshProvider
                                                    .notifier)
                                                .state++;
                                          },
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                                // ===== 其他 Provider 模式：上传/下载按钮 =====
                                if (!isBeeCountCloud) ...[
                                  BeeTokens.cardDivider(context),
                                  // 上传
                                  AppListTile(
                                    leading: Icons.cloud_upload_outlined,
                                    title: AppLocalizations.of(context)
                                        .mineUploadTitle,
                                    subtitle: isFirstLoad
                                        ? null
                                        : !canUseCloud
                                            ? AppLocalizations.of(context)
                                                .mineUploadNeedCloudService
                                            : notLoggedIn
                                                ? AppLocalizations.of(context)
                                                    .mineUploadNeedLogin
                                                : uploadBusy
                                                    ? AppLocalizations.of(
                                                            context)
                                                        .mineUploadInProgress
                                                    : (refreshing
                                                        ? AppLocalizations.of(
                                                                context)
                                                            .mineUploadRefreshing
                                                        : (inSync
                                                            ? AppLocalizations
                                                                    .of(context)
                                                                .mineUploadSynced
                                                            : null)),
                                    enabled: canUseCloud &&
                                        !inSync &&
                                        !notLoggedIn &&
                                        !uploadBusy &&
                                        !downloadBusy &&
                                        !isFirstLoad &&
                                        !refreshing,
                                    trailing: (uploadBusy ||
                                            refreshing ||
                                            (isFirstLoad && canUseCloud))
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : null,
                                    onTap: () async {
                                      setState(() => uploadBusy = true);
                                      // 标记为上传中
                                      final uploadingIds =
                                          ref.read(uploadingLedgerIdsProvider);
                                      ref
                                          .read(uploadingLedgerIdsProvider
                                              .notifier)
                                          .state = {...uploadingIds, ledgerId};

                                      try {
                                        await sync.uploadCurrentLedger(
                                            ledgerId: ledgerId);
                                        if (!context.mounted) return;

                                        // 刷新账本列表
                                        ref
                                            .read(ledgerListRefreshProvider
                                                .notifier)
                                            .state++;

                                        await AppDialog.info(context,
                                            title: AppLocalizations.of(context)
                                                .mineUploadSuccess,
                                            message:
                                                AppLocalizations.of(context)
                                                    .mineUploadSuccessMessage);
                                        Future(() async {
                                          try {
                                            await sync.refreshCloudFingerprint(
                                                ledgerId: ledgerId);
                                          } catch (_) {}
                                          try {
                                            const maxAttempts = 6;
                                            var delay = const Duration(
                                                milliseconds: 500);
                                            for (var i = 0;
                                                i < maxAttempts;
                                                i++) {
                                              final stNow =
                                                  await sync.getStatus(
                                                      ledgerId: ledgerId);
                                              if (stNow.diff ==
                                                  SyncDiff.inSync) {
                                                ref
                                                    .read(
                                                        lastSyncStatusProvider(
                                                                ledgerId)
                                                            .notifier)
                                                    .state = stNow;
                                                break;
                                              }
                                              if (i < maxAttempts - 1) {
                                                await Future.delayed(delay);
                                                delay *= 2;
                                              }
                                            }
                                            ref
                                                .read(syncStatusRefreshProvider
                                                    .notifier)
                                                .state++;
                                            // 再次刷新账本列表确保状态更新
                                            ref
                                                .read(ledgerListRefreshProvider
                                                    .notifier)
                                                .state++;
                                          } catch (_) {}
                                        });
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        await AppDialog.info(context,
                                            title: AppLocalizations.of(context)
                                                .commonFailed,
                                            message: '$e');
                                      } finally {
                                        if (mounted)
                                          setState(() => uploadBusy = false);
                                        // 移除上传中标记
                                        final uploadingIds = ref
                                            .read(uploadingLedgerIdsProvider);
                                        ref
                                                .read(uploadingLedgerIdsProvider
                                                    .notifier)
                                                .state =
                                            uploadingIds
                                                .where((id) => id != ledgerId)
                                                .toSet();
                                      }
                                    },
                                  ),
                                  BeeTokens.cardDivider(context),
                                  // 下载
                                  AppListTile(
                                    leading: Icons.cloud_download_outlined,
                                    title: AppLocalizations.of(context)
                                        .mineDownloadTitle,
                                    subtitle: isFirstLoad
                                        ? null
                                        : !canUseCloud
                                            ? AppLocalizations.of(context)
                                                .mineDownloadNeedCloudService
                                            : notLoggedIn
                                                ? AppLocalizations.of(context)
                                                    .mineUploadNeedLogin
                                                : (refreshing
                                                    ? AppLocalizations.of(
                                                            context)
                                                        .mineUploadRefreshing
                                                    : (inSync
                                                        ? AppLocalizations.of(
                                                                context)
                                                            .mineUploadSynced
                                                        : null)),
                                    enabled: canUseCloud &&
                                        !inSync &&
                                        !notLoggedIn &&
                                        !downloadBusy &&
                                        !isFirstLoad &&
                                        !refreshing &&
                                        !uploadBusy,
                                    trailing: (downloadBusy ||
                                            refreshing ||
                                            (isFirstLoad && canUseCloud))
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : null,
                                    onTap: () async {
                                      setState(() => downloadBusy = true);
                                      try {
                                        // 尝试使用 diff 预览模式
                                        final syncManager =
                                            sync is TransactionsSyncManager
                                                ? sync
                                                : null;

                                        if (syncManager != null) {
                                          final previewResult =
                                              await syncManager
                                                  .downloadAndPreview(
                                            ledgerId: ledgerId,
                                          );

                                          if (!context.mounted) return;

                                          if (previewResult == null) {
                                            // 云端无数据
                                            await AppDialog.info(context,
                                                title:
                                                    AppLocalizations.of(context)
                                                        .mineDownloadComplete,
                                                message:
                                                    AppLocalizations.of(context)
                                                        .mineDownloadResult(0));
                                          } else if (previewResult.preview !=
                                              null) {
                                            // v6+ 格式，有 diff 预览
                                            final preview =
                                                previewResult.preview!;
                                            if (preview.isEmpty) {
                                              await AppDialog.info(context,
                                                  title: AppLocalizations.of(
                                                          context)
                                                      .mineDownloadComplete,
                                                  message: AppLocalizations.of(
                                                          context)
                                                      .syncPreviewEmpty);
                                            } else {
                                              final primaryColor = ref
                                                  .read(primaryColorProvider);
                                              final selected =
                                                  await showSyncPreviewDialog(
                                                context,
                                                preview: preview,
                                                primaryColor: primaryColor,
                                              );

                                              if (selected != null &&
                                                  selected.isNotEmpty &&
                                                  context.mounted) {
                                                final result = await syncManager
                                                    .applyPreviewChanges(
                                                  ledgerId: ledgerId,
                                                  selectedChanges: selected,
                                                  importData:
                                                      previewResult.importData,
                                                );

                                                if (!context.mounted) return;
                                                await AppDialog.info(context,
                                                    title: AppLocalizations.of(
                                                            context)
                                                        .mineDownloadComplete,
                                                    message: AppLocalizations
                                                            .of(context)
                                                        .syncPreviewApplied(
                                                            result.totalCount));

                                                PostProcessor.runAfterDownload(
                                                    ref);
                                              }
                                            }
                                          } else {
                                            // 旧格式（v5 及以下），全量替换
                                            final confirmed =
                                                await AppDialog.confirm<bool>(
                                                      context,
                                                      title: AppLocalizations
                                                              .of(context)
                                                          .syncPreviewOldFormat,
                                                      message: AppLocalizations
                                                              .of(context)
                                                          .syncPreviewOldFormatMessage,
                                                    ) ??
                                                    false;

                                            if (confirmed && context.mounted) {
                                              final res = await sync
                                                  .downloadAndRestoreToCurrentLedger(
                                                      ledgerId: ledgerId);
                                              if (!context.mounted) return;
                                              await AppDialog.info(context,
                                                  title: AppLocalizations.of(
                                                          context)
                                                      .mineDownloadComplete,
                                                  message: AppLocalizations.of(
                                                          context)
                                                      .mineDownloadResult(
                                                          res.inserted));
                                              PostProcessor.runAfterDownload(
                                                  ref);
                                            }
                                          }
                                        } else {
                                          // 非 TransactionsSyncManager，走原逻辑
                                          final res = await sync
                                              .downloadAndRestoreToCurrentLedger(
                                                  ledgerId: ledgerId);
                                          if (!context.mounted) return;
                                          await AppDialog.info(context,
                                              title:
                                                  AppLocalizations.of(context)
                                                      .mineDownloadComplete,
                                              message:
                                                  AppLocalizations.of(context)
                                                      .mineDownloadResult(
                                                          res.inserted));
                                          PostProcessor.runAfterDownload(ref);
                                        }
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        await AppDialog.error(context,
                                            title: AppLocalizations.of(context)
                                                .commonFailed,
                                            message: '$e');
                                      } finally {
                                        if (mounted)
                                          setState(() => downloadBusy = false);
                                      }
                                    },
                                  ),
                                  // 登录/登出 (仅 Supabase 需要，其他云服务使用配置文件认证)
                                  if (!isLocalMode &&
                                      cloudConfig.value!.type ==
                                          CloudBackendType.supabase)
                                    Consumer(builder: (ctx, r, _) {
                                      final userNow = user;
                                      final cloudConfig =
                                          r.watch(activeCloudConfigProvider);

                                      // 根据云服务类型显示不同的用户信息
                                      String getUserDisplayName() {
                                        if (userNow == null) {
                                          return AppLocalizations.of(context)
                                              .mineLoginTitle;
                                        }

                                        if (cloudConfig.hasValue &&
                                            cloudConfig.value!.type ==
                                                CloudBackendType.webdav) {
                                          // WebDAV: 显示用户名（去掉 @webdav 后缀）
                                          return userNow.id;
                                        } else {
                                          // Supabase: 显示邮箱
                                          return userNow.email ??
                                              AppLocalizations.of(context)
                                                  .mineLoggedInEmail;
                                        }
                                      }

                                      return Column(
                                        children: [
                                          BeeTokens.cardDivider(context),
                                          AppListTile(
                                            leading: userNow == null
                                                ? Icons.login
                                                : Icons.verified_user_outlined,
                                            title: getUserDisplayName(),
                                            subtitle: userNow == null
                                                ? AppLocalizations.of(context)
                                                    .mineLoginSubtitle
                                                : AppLocalizations.of(context)
                                                    .mineLogoutSubtitle,
                                            onTap: () async {
                                              if (userNow == null) {
                                                await Navigator.of(context)
                                                    .push(MaterialPageRoute(
                                                        builder: (_) =>
                                                            const LoginPage()));
                                                ref
                                                    .read(
                                                        syncStatusRefreshProvider
                                                            .notifier)
                                                    .state++;
                                                ref
                                                    .read(statsRefreshProvider
                                                        .notifier)
                                                    .state++;
                                              } else {
                                                final confirmed =
                                                    await AppDialog.confirm<
                                                            bool>(
                                                          context,
                                                          title: AppLocalizations
                                                                  .of(context)
                                                              .mineLogoutConfirmTitle,
                                                          message: AppLocalizations
                                                                  .of(context)
                                                              .mineLogoutConfirmMessage,
                                                          okLabel: AppLocalizations
                                                                  .of(context)
                                                              .mineLogoutButton,
                                                          cancelLabel:
                                                              AppLocalizations.of(
                                                                      context)
                                                                  .commonCancel,
                                                        ) ??
                                                        false;

                                                if (confirmed) {
                                                  final authService = await ref
                                                      .read(authServiceProvider
                                                          .future);
                                                  await authService.signOut();

                                                  // 刷新认证服务和同步服务以触发状态更新
                                                  ref.invalidate(
                                                      authServiceProvider);
                                                  ref.invalidate(
                                                      syncServiceProvider);

                                                  ref
                                                      .read(
                                                          syncStatusRefreshProvider
                                                              .notifier)
                                                      .state++;
                                                  ref
                                                      .read(statsRefreshProvider
                                                          .notifier)
                                                      .state++;
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      );
                                    }),
                                  // 自动同步 (非 BeeCount Cloud 的其他云服务)
                                  if (!isLocalMode)
                                    Consumer(builder: (ctx, r, _) {
                                      final autoSync =
                                          r.watch(autoSyncValueProvider);
                                      final setter =
                                          r.read(autoSyncSetterProvider);
                                      final value =
                                          autoSync.asData?.value ?? false;
                                      final can = canUseCloud;

                                      return Column(
                                        children: [
                                          BeeTokens.cardDivider(context),
                                          SwitchListTile(
                                            title: Text(
                                                AppLocalizations.of(context)
                                                    .mineAutoSyncTitle),
                                            subtitle: can
                                                ? Text(
                                                    AppLocalizations.of(context)
                                                        .mineAutoSyncSubtitle)
                                                : Text(
                                                    AppLocalizations.of(context)
                                                        .mineAutoSyncNeedLogin),
                                            value: can ? value : false,
                                            onChanged: can
                                                ? (v) async {
                                                    await setter.set(v);
                                                  }
                                                : null,
                                          ),
                                        ],
                                      );
                                    }),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
