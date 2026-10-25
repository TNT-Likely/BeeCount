import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/cloud_backup.dart';
import '../../../providers.dart';
import '../../../widgets/ui/ui.dart' show AppDialog, showToast;
import '../../../l10n/app_localizations.dart';
import '../../../services/billing/post_processor.dart';
import '../../../cloud/sync_service.dart';
import '../../../cloud/transactions_sync_manager.dart';
import '../../../pages/auth/login_page.dart';
import '../../../pages/cloud/sync_preview_dialog.dart';
import 'page_scaffold.dart';

/// Cache the original auth query outside build; page repaints must not log in again.
final cloudBackupUserProvider =
    FutureProvider.autoDispose<CloudUser?>((ref) async {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final auth = await ref.watch(authServiceProvider.future);
  final user = await auth.currentUser;
  if (!disposed) {
    var previous = user;
    final subscription = auth.authStateChanges.listen((next) {
      if (!disposed && next != previous) {
        previous = next;
        ref.invalidateSelf();
      }
    }, onError: (Object error, StackTrace stack) {
      if (!disposed) ref.invalidateSelf();
    });
    ref.onDispose(subscription.cancel);
  }
  return user;
});

class CloudBackupControls extends ConsumerStatefulWidget {
  const CloudBackupControls({super.key});
  @override
  ConsumerState<CloudBackupControls> createState() =>
      _CloudBackupControlsState();
}

class _CloudBackupControlsState extends ConsumerState<CloudBackupControls> {
  bool uploadBusy = false, downloadBusy = false;
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
    try {
      await ref.read(syncStatusProvider(ledgerId).future);
    } catch (_) {
      // The page exposes the provider error and a retry action.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.cloudSyncPageTitle,
          subtitle: l.cloudSyncPageSubtitle,
          leading: const BackButton(),
          actions: ledgerId == 0
              ? const []
              : [
                  BeeIconButton(
                      label: l.v4RecordingRetry,
                      icon: const BeeLineIcon('RefreshCw', size: 21),
                      onPressed: _onRefresh),
                ]),
      Expanded(
          child: ledgerId == 0
              ? BeeEmptyState(
                  title: l.aiOcrNoLedger,
                  icon: const BeeLineIcon('BookOpen', size: 36))
              : ref.watch(activeCloudConfigProvider).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _error(
                      error, () => ref.invalidate(activeCloudConfigProvider)),
                  data: (config) => ref.watch(cloudBackupUserProvider).when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => _error(
                          error, () => ref.invalidate(cloudBackupUserProvider)),
                      data: (user) => _content(config, user, ledgerId)))),
    ]));
  }

  Widget _error(Object error, VoidCallback retry) {
    final l = AppLocalizations.of(context);
    return BeeEmptyState(
        title: '${l.commonError}: $error',
        icon: const BeeLineIcon('CircleAlert', size: 36),
        action: BeeButton(label: l.v4RecordingRetry, onPressed: retry));
  }

  Widget _content(CloudServiceConfig config, CloudUser? user, int ledgerId) {
    final l = AppLocalizations.of(context);
    final sync = ref.watch(syncServiceProvider);
    final isLocalMode = config.type == CloudBackendType.local;
    final isBeeCountCloud = config.type == CloudBackendType.beecountCloud;
    final needsLogin =
        config.type == CloudBackendType.supabase || isBeeCountCloud;
    final canUseCloud = !isLocalMode && (!needsLogin || user != null);
    final asyncSt = ref.watch(syncStatusProvider(ledgerId));
    final st =
        asyncSt.asData?.value ?? ref.watch(lastSyncStatusProvider(ledgerId));
    final first = st == null, refreshing = asyncSt.isLoading;
    final initialError = first && asyncSt.hasError;
    final inSync = st?.diff == SyncDiff.inSync,
        notLoggedIn = st?.diff == SyncDiff.notLoggedIn;
    final busy = uploadBusy || downloadBusy;
    final ready = canUseCloud && !first && !refreshing && !busy;
    final presentation = cloudBackupPresentation(st, l);
    final operationReady = ready && !inSync && !notLoggedIn;
    final cachedEmail = config.beecountCloudEmail ?? '';
    final cachedPassword = config.beecountCloudPassword ?? '';
    return RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(17),
            children: [
              if (!isBeeCountCloud) ...[
                Text(l.cloudSyncHint,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.55,
                        color: Theme.of(context).hintColor)),
                const SizedBox(height: 12)
              ],
              BeeCloudBackupSummary(
                  title: l.mineSyncTitle,
                  status: initialError
                      ? l.mineSyncError
                      : first
                          ? l.mineCloudServiceLoading
                          : presentation.label,
                  icon: BeeLineIcon(
                      initialError ? 'CircleAlert' : presentation.icon,
                      size: 23),
                  tone: initialError ? BeeTone.error : presentation.tone,
                  busy: canUseCloud &&
                      (busy || refreshing || (first && !asyncSt.hasError)),
                  localSummary:
                      st == null ? null : l.mineSyncLocalRecords(st.localCount),
                  remoteSummary: st?.cloudCount == null
                      ? null
                      : l.mineSyncCloudRecords(st!.cloudCount!),
                  backupTime: st?.cloudExportedAt == null
                      ? null
                      : l.mineSyncCloudLatest(DateFormat('yyyy-MM-dd HH:mm:ss')
                          .format(st!.cloudExportedAt!.toLocal())),
                  error: asyncSt.hasError
                      ? '${l.commonError}: ${asyncSt.error}'
                      : null,
                  retryLabel: l.v4RecordingRetry,
                  onRetry: asyncSt.hasError ? _onRefresh : null,
                  onDetails: ready ? () => _showDetails(st) : null),
              const SizedBox(height: 12),
              if (isBeeCountCloud) ...[
                if (user != null)
                  BeeCloudBackupAction(
                      title: user.email ?? l.mineLoggedInEmail,
                      icon: const BeeLineIcon('ShieldCheck', size: 21))
                else if (cachedEmail.isNotEmpty && cachedPassword.isNotEmpty)
                  BeeCloudBackupAction(
                      title: l.cloudReloginTitle,
                      subtitle: cachedEmail,
                      icon: const BeeLineIcon('RefreshCw', size: 21),
                      onTap: () => _relogin(cachedEmail, cachedPassword))
                else
                  BeeCloudBackupAction(
                      title: l.mineLoginTitle,
                      subtitle: l.mineLoginSubtitle,
                      icon: const BeeLineIcon('LogIn', size: 21),
                      onTap: _openLogin),
              ] else ...[
                BeeCloudBackupAction(
                    key: const ValueKey('cb95-upload'),
                    title: l.mineUploadTitle,
                    icon: const BeeLineIcon('CloudUpload', size: 21),
                    enabled: operationReady,
                    busy: uploadBusy ||
                        refreshing ||
                        (first && canUseCloud && !asyncSt.hasError),
                    subtitle: first
                        ? null
                        : !canUseCloud
                            ? l.mineUploadNeedCloudService
                            : notLoggedIn
                                ? l.mineUploadNeedLogin
                                : uploadBusy
                                    ? l.mineUploadInProgress
                                    : refreshing
                                        ? l.mineUploadRefreshing
                                        : inSync
                                            ? l.mineUploadSynced
                                            : null,
                    onTap: () => _upload(sync, ledgerId)),
                const SizedBox(height: 12),
                BeeCloudBackupAction(
                    key: const ValueKey('cb95-download'),
                    title: l.mineDownloadTitle,
                    icon: const BeeLineIcon('CloudDownload', size: 21),
                    enabled: operationReady,
                    busy: downloadBusy ||
                        refreshing ||
                        (first && canUseCloud && !asyncSt.hasError),
                    subtitle: first
                        ? null
                        : !canUseCloud
                            ? l.mineDownloadNeedCloudService
                            : notLoggedIn
                                ? l.mineUploadNeedLogin
                                : refreshing
                                    ? l.mineUploadRefreshing
                                    : inSync
                                        ? l.mineUploadSynced
                                        : null,
                    onTap: () => _download(sync, ledgerId)),
                if (!isLocalMode &&
                    config.type == CloudBackendType.supabase) ...[
                  const SizedBox(height: 12),
                  BeeCloudBackupAction(
                      title: user == null
                          ? l.mineLoginTitle
                          : user.email ?? l.mineLoggedInEmail,
                      subtitle: user == null
                          ? l.mineLoginSubtitle
                          : l.mineLogoutSubtitle,
                      icon: BeeLineIcon(user == null ? 'LogIn' : 'ShieldCheck',
                          size: 21),
                      onTap: () => _accountAction(user)),
                ],
                if (!isLocalMode) ...[
                  const SizedBox(height: 12),
                  BeeCloudBackupPreference(
                      title: l.mineAutoSyncTitle,
                      subtitle: canUseCloud
                          ? l.mineAutoSyncSubtitle
                          : l.mineAutoSyncNeedLogin,
                      value: canUseCloud
                          ? ref.watch(autoSyncValueProvider).valueOrNull ??
                              false
                          : false,
                      onChanged: canUseCloud
                          ? (value) async =>
                              ref.read(autoSyncSetterProvider).set(value)
                          : null),
                ],
              ],
            ]));
  }

  Future<void> _showDetails(SyncStatus st) async {
    if (!mounted) return;
    final lines = <String>[
      AppLocalizations.of(context).mineSyncLocalRecords(st.localCount),
      if (st.cloudCount != null)
        AppLocalizations.of(context).mineSyncCloudRecords(st.cloudCount!),
      if (st.cloudExportedAt != null)
        AppLocalizations.of(context).mineSyncCloudLatest(
            DateFormat('yyyy-MM-dd HH:mm:ss')
                .format(st.cloudExportedAt!.toLocal())),
      AppLocalizations.of(context)
          .mineSyncLocalFingerprint(st.localFingerprint),
      if (st.cloudFingerprint != null)
        AppLocalizations.of(context)
            .mineSyncCloudFingerprint(st.cloudFingerprint!),
      if (st.message != null)
        () {
          String localizedMessage = st.message!;
          switch (st.message!) {
            case '__SYNC_NOT_CONFIGURED__':
              localizedMessage =
                  AppLocalizations.of(context).syncNotConfiguredMessage;
              break;
            case '__SYNC_NOT_LOGGED_IN__':
              localizedMessage =
                  AppLocalizations.of(context).syncNotLoggedInMessage;
              break;
            case '__SYNC_CLOUD_BACKUP_CORRUPTED__':
              localizedMessage =
                  AppLocalizations.of(context).syncCloudBackupCorruptedMessage;
              break;
            case '__SYNC_NO_CLOUD_BACKUP__':
              localizedMessage =
                  AppLocalizations.of(context).syncNoCloudBackupMessage;
              break;
            case '__SYNC_ACCESS_DENIED__':
              localizedMessage =
                  AppLocalizations.of(context).syncAccessDeniedMessage;
              break;
          }
          return AppLocalizations.of(context).mineSyncMessage(localizedMessage);
        }(),
    ];
    await AppDialog.info(context,
        title: AppLocalizations.of(context).mineSyncDetailTitle,
        message: lines.join('\n'));
  }

  Future<void> _relogin(String cachedEmail, String cachedPassword) async {
    try {
      final provider = await ref.read(beecountCloudProviderInstance.future);
      if (!mounted) return;
      if (provider == null) {
        showToast(context, AppLocalizations.of(context).cloudReloginFailed);
        return;
      }
      await provider.auth
          .signInWithEmail(email: cachedEmail, password: cachedPassword);
      if (!mounted) return;
      showToast(context, AppLocalizations.of(context).cloudReloginSuccess);
      ref.invalidate(cloudBackupUserProvider);
      ref.read(syncStatusRefreshProvider.notifier).state++;
      ref.read(statsRefreshProvider.notifier).state++;
    } catch (error) {
      if (!mounted) return;
      showToast(context,
          '${AppLocalizations.of(context).cloudReloginFailed}: $error');
    }
  }

  Future<void> _openLogin() async {
    final container = ProviderScope.containerOf(context, listen: false);

    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LoginPage()));
    container.invalidate(cloudBackupUserProvider);
    container.read(syncStatusRefreshProvider.notifier).state++;
    container.read(statsRefreshProvider.notifier).state++;
  }

  Future<void> _upload(SyncService sync, int ledgerId) async {
    final container = ProviderScope.containerOf(context, listen: false);

    setState(() => uploadBusy = true);
    // 标记为上传中
    final uploadingIds = container.read(uploadingLedgerIdsProvider);
    container.read(uploadingLedgerIdsProvider.notifier).state = {
      ...uploadingIds,
      ledgerId
    };

    try {
      await sync.uploadCurrentLedger(ledgerId: ledgerId);
      if (!mounted) return;

      // 刷新账本列表
      container.read(ledgerListRefreshProvider.notifier).state++;

      await AppDialog.info(context,
          title: AppLocalizations.of(context).mineUploadSuccess,
          message: AppLocalizations.of(context).mineUploadSuccessMessage);
      Future(() async {
        try {
          await sync.refreshCloudFingerprint(ledgerId: ledgerId);
        } catch (_) {}
        try {
          const maxAttempts = 6;
          var delay = const Duration(milliseconds: 500);
          for (var i = 0; i < maxAttempts; i++) {
            final stNow = await sync.getStatus(ledgerId: ledgerId);
            if (stNow.diff == SyncDiff.inSync) {
              container.read(lastSyncStatusProvider(ledgerId).notifier).state =
                  stNow;
              break;
            }
            if (i < maxAttempts - 1) {
              await Future.delayed(delay);
              delay *= 2;
            }
          }
          container.read(syncStatusRefreshProvider.notifier).state++;
          // 再次刷新账本列表确保状态更新
          container.read(ledgerListRefreshProvider.notifier).state++;
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      await AppDialog.info(context,
          title: AppLocalizations.of(context).commonFailed, message: '$e');
    } finally {
      if (mounted) setState(() => uploadBusy = false);
      // 移除上传中标记
      final uploadingIds = container.read(uploadingLedgerIdsProvider);
      container.read(uploadingLedgerIdsProvider.notifier).state =
          uploadingIds.where((id) => id != ledgerId).toSet();
    }
  }

  Future<void> _download(SyncService sync, int ledgerId) async {
    final container = ProviderScope.containerOf(context, listen: false);

    setState(() => downloadBusy = true);
    try {
      // 尝试使用 diff 预览模式
      final syncManager = sync is TransactionsSyncManager ? sync : null;

      if (syncManager != null) {
        final previewResult = await syncManager.downloadAndPreview(
          ledgerId: ledgerId,
        );

        if (!mounted) return;

        if (previewResult == null) {
          // 云端无数据
          await AppDialog.info(context,
              title: AppLocalizations.of(context).mineDownloadComplete,
              message: AppLocalizations.of(context).mineDownloadResult(0));
        } else if (previewResult.preview != null) {
          // v6+ 格式，有 diff 预览
          final preview = previewResult.preview!;
          if (preview.isEmpty) {
            await AppDialog.info(context,
                title: AppLocalizations.of(context).mineDownloadComplete,
                message: AppLocalizations.of(context).syncPreviewEmpty);
          } else {
            final primaryColor = container.read(primaryColorProvider);
            final selected = await showSyncPreviewDialog(
              context,
              preview: preview,
              primaryColor: primaryColor,
            );

            if (selected != null && selected.isNotEmpty && mounted) {
              final result = await syncManager.applyPreviewChanges(
                ledgerId: ledgerId,
                selectedChanges: selected,
                importData: previewResult.importData,
              );

              if (!mounted) return;
              await AppDialog.info(context,
                  title: AppLocalizations.of(context).mineDownloadComplete,
                  message: AppLocalizations.of(context)
                      .syncPreviewApplied(result.totalCount));

              PostProcessor.runAfterDownloadC(container);
            }
          }
        } else {
          // 旧格式（v5 及以下），全量替换
          final confirmed = await AppDialog.confirm<bool>(
                context,
                title: AppLocalizations.of(context).syncPreviewOldFormat,
                message:
                    AppLocalizations.of(context).syncPreviewOldFormatMessage,
              ) ??
              false;

          if (confirmed && mounted) {
            final res = await syncManager.restoreLegacyBackupToCurrentLedger(
                ledgerId: ledgerId);
            if (!mounted) return;
            await AppDialog.info(context,
                title: AppLocalizations.of(context).mineDownloadComplete,
                message: AppLocalizations.of(context)
                    .mineDownloadResult(res.inserted));
            PostProcessor.runAfterDownloadC(container);
          }
        }
      } else {
        // 非 TransactionsSyncManager，走原逻辑
        final res =
            await sync.downloadAndRestoreToCurrentLedger(ledgerId: ledgerId);
        if (!mounted) return;
        await AppDialog.info(context,
            title: AppLocalizations.of(context).mineDownloadComplete,
            message:
                AppLocalizations.of(context).mineDownloadResult(res.inserted));
        PostProcessor.runAfterDownloadC(container);
      }
    } catch (e) {
      if (!mounted) return;
      await AppDialog.error(context,
          title: AppLocalizations.of(context).commonFailed, message: '$e');
    } finally {
      if (mounted) setState(() => downloadBusy = false);
    }
  }

  Future<void> _accountAction(CloudUser? userNow) async {
    final container = ProviderScope.containerOf(context, listen: false);

    if (userNow == null) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LoginPage()));
      container.invalidate(cloudBackupUserProvider);
      container.read(syncStatusRefreshProvider.notifier).state++;
      container.read(statsRefreshProvider.notifier).state++;
    } else {
      final confirmed = await AppDialog.confirm<bool>(
            context,
            title: AppLocalizations.of(context).mineLogoutConfirmTitle,
            message: AppLocalizations.of(context).mineLogoutConfirmMessage,
            okLabel: AppLocalizations.of(context).mineLogoutButton,
            cancelLabel: AppLocalizations.of(context).commonCancel,
          ) ??
          false;

      if (confirmed) {
        final authService = await container.read(authServiceProvider.future);
        await authService.signOut();

        // 刷新认证服务和同步服务以触发状态更新
        container.invalidate(authServiceProvider);

        container.read(syncStatusRefreshProvider.notifier).state++;
        container.read(statsRefreshProvider.notifier).state++;
      }
    }
  }
}

({String label, String icon, BeeTone tone}) cloudBackupPresentation(
    SyncStatus? st, AppLocalizations l) {
  if (st == null) {
    return (
      label: l.mineCloudServiceLoading,
      icon: 'Cloud',
      tone: BeeTone.neutral
    );
  }
  return switch (st.diff) {
    SyncDiff.notLoggedIn => (
        label: l.mineSyncNotLoggedIn,
        icon: 'LockKeyhole',
        tone: BeeTone.warning
      ),
    SyncDiff.notConfigured => (
        label: l.mineSyncNotConfigured,
        icon: 'CloudOff',
        tone: BeeTone.neutral
      ),
    SyncDiff.noRemote => (
        label: l.mineSyncNoRemote,
        icon: 'Cloud',
        tone: BeeTone.neutral
      ),
    SyncDiff.inSync => (
        label: l.mineSyncInSync(st.localCount),
        icon: 'CircleCheck',
        tone: BeeTone.success
      ),
    SyncDiff.localNewer => (
        label: l.mineSyncLocalNewer(st.localCount),
        icon: 'CloudUpload',
        tone: BeeTone.neutral
      ),
    SyncDiff.cloudNewer => (
        label: l.mineSyncCloudNewer,
        icon: 'CloudDownload',
        tone: BeeTone.neutral
      ),
    SyncDiff.different => (
        label: l.mineSyncDifferent,
        icon: 'RefreshCw',
        tone: BeeTone.warning
      ),
    SyncDiff.error => (
        label: cloudBackupMessage(st.message, l) ?? l.mineSyncError,
        icon: 'CircleAlert',
        tone: BeeTone.error
      ),
  };
}

String? cloudBackupMessage(String? message, AppLocalizations l) =>
    switch (message) {
      '__SYNC_NOT_CONFIGURED__' => l.syncNotConfiguredMessage,
      '__SYNC_NOT_LOGGED_IN__' => l.syncNotLoggedInMessage,
      '__SYNC_CLOUD_BACKUP_CORRUPTED__' => l.syncCloudBackupCorruptedMessage,
      '__SYNC_NO_CLOUD_BACKUP__' => l.syncNoCloudBackupMessage,
      '__SYNC_ACCESS_DENIED__' => l.syncAccessDeniedMessage,
      _ => message,
    };
