import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:beecount/widgets/biz/bee_icon.dart';

import 'import_page.dart';
import 'login_page.dart';
import 'export_page.dart';
import 'personalize_page.dart';
import '../providers.dart';
import '../widgets/ui/ui.dart';
import '../widgets/biz/biz.dart';
import '../styles/design.dart';
import '../styles/colors.dart';
import '../cloud/auth.dart';
import '../cloud/sync.dart';
import 'cloud_service_page.dart';
import '../utils/logger.dart';
import '../services/restore_service.dart';
import 'restore_progress_page.dart';
import '../utils/format_utils.dart';
import '../l10n/app_localizations.dart';
import 'font_settings_page.dart';
import 'category_manage_page.dart';
import 'category_migration_page.dart';
import 'reminder_settings_page.dart';
import 'language_settings_page.dart';
import '../l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/format_utils.dart';
import '../services/update_service.dart';
import '../utils/ui_scale_extensions.dart';

class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final auth = ref.watch(authServiceProvider);
    final sync = ref.watch(syncServiceProvider);
    final authUserStream = auth.authStateChanges();

    // 登录后一次性触发云端备份检查
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final needCheck = ref.read(restoreCheckRequestProvider);
      final user = await ref.read(authServiceProvider).currentUser();
      if (!needCheck || user == null || !context.mounted) return;
      ref.read(restoreCheckRequestProvider.notifier).state = false;
      try {
        final check = await RestoreService.checkNeedRestore(ref);
        if (!check.needsRestore) return;
        if (!context.mounted) return;
        final ok = await AppDialog.confirm<bool>(context,
                title: AppLocalizations.of(context).cloudBackupFound,
                message: AppLocalizations.of(context).cloudBackupRestoreMessage) ??
            false;
        if (!ok || !context.mounted) return;
        RestoreService.startBackgroundRestore(check.backups, ref);
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RestoreProgressPage()),
        );
        ref.read(syncStatusRefreshProvider.notifier).state++;
        ref.read(statsRefreshProvider.notifier).state++;
      } catch (e) {
        if (!context.mounted) return;
        await AppDialog.error(context, title: AppLocalizations.of(context).cloudBackupRestoreFailed, message: '$e');
      }
    });

    return Scaffold(
      backgroundColor: BeeColors.greyBg,
      body: Column(
        children: [
          PrimaryHeader(
            showBack: false,
            title: AppLocalizations.of(context).mineTitle,
            compact: true,
            showTitleSection: false,
            content: Padding(
              padding: EdgeInsets.fromLTRB(12.0.scaled(context, ref), 8.0.scaled(context, ref), 12.0.scaled(context, ref), 10.0.scaled(context, ref)),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        BeeIcon(
                          color: Theme.of(context).colorScheme.primary,
                          size: 48.0.scaled(context, ref),
                        ),
                        Text(AppLocalizations.of(context).mineTitle, style: AppTextTokens.title(context)),
                      ],
                    ),
                    SizedBox(width: 12.0.scaled(context, ref)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context).mineSlogan,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: BeeColors.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 5.0.scaled(context, ref)), // 标语与统计区间距增大
                          Builder(builder: (ctx) {
                            // 获取当前账本信息
                            final currentLedgerId =
                                ref.watch(currentLedgerIdProvider);
                            final countsAsync = ref.watch(
                                countsForLedgerProvider(currentLedgerId));
                            final balanceAsync = ref
                                .watch(currentBalanceProvider(currentLedgerId));
                            final currentLedgerAsync = ref.watch(currentLedgerProvider);
                            final selectedLocale = ref.watch(languageProvider);

                            final day = countsAsync.asData?.value.dayCount ?? 0;
                            final tx = countsAsync.asData?.value.txCount ?? 0;
                            final balance = balanceAsync.asData?.value ?? 0.0;
                            final currentLedger = currentLedgerAsync.asData?.value;
                            final currencyCode = currentLedger?.currency ?? 'CNY';
                            final isChineseLocale = selectedLocale?.languageCode == 'zh' ||
                                (selectedLocale == null && Localizations.localeOf(context).languageCode == 'zh');

                            final labelStyle = Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: BeeColors.black54);
                            // 需求：统计数字与左侧"我的"标题字号/字重保持一致，取消更粗/更大
                            final numStyle = AppTextTokens.strongTitle(context)
                                .copyWith(
                                    fontSize: 20, color: BeeColors.primaryText);
                            return IntrinsicHeight(
                              child: Row(children: [
                                Expanded(
                                    child: _StatCell(
                                        label: AppLocalizations.of(context).mineDaysCount,
                                        value: day.toString(),
                                        labelStyle: labelStyle,
                                        numStyle: numStyle)),
                                Expanded(
                                    child: _StatCell(
                                        label: AppLocalizations.of(context).mineTotalRecords,
                                        value: tx.toString(),
                                        labelStyle: labelStyle,
                                        numStyle: numStyle)),
                                Expanded(
                                    child: _StatCell(
                                        label: AppLocalizations.of(context).mineCurrentBalance,
                                        value: formatBalance(balance, currencyCode, isChineseLocale: isChineseLocale),
                                        labelStyle: labelStyle,
                                        numStyle: numStyle.copyWith(
                                          color: balance >= 0
                                              ? BeeColors.primaryText
                                              : Colors.red,
                                        ))),
                              ]),
                            );
                          }),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Divider(height: 1),
                SizedBox(height: 8.0.scaled(context, ref)),
                // 同步分组
                SectionCard(
                  margin: EdgeInsets.fromLTRB(12.0.scaled(context, ref), 0, 12.0.scaled(context, ref), 0),
                  child: Column(
                    children: [
                      Consumer(builder: (ctx, r, _) {
                        final activeCfg = r.watch(activeCloudConfigProvider);
                        return AppListTile(
                          leading: Icons.cloud_queue_outlined,
                          title: AppLocalizations.of(context).mineCloudService,
                          subtitle: activeCfg.when(
                            loading: () => AppLocalizations.of(context).mineCloudServiceLoading,
                            error: (e, _) => '${AppLocalizations.of(context).commonError}: $e',
                            data: (cfg) => cfg.builtin
                                ? (cfg.valid ? AppLocalizations.of(context).mineCloudServiceDefault : AppLocalizations.of(context).mineCloudServiceOffline)
                                : AppLocalizations.of(context).mineCloudServiceCustom,
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const CloudServicePage()),
                            );
                          },
                        );
                      }),
                      AppDivider.thin(),
                      StreamBuilder<AuthUser?>(
                        stream: authUserStream,
                        builder: (ctx, snap) {
                          final user = snap.data;
                          final canUseCloud = user != null;
                          final asyncSt =
                              ref.watch(syncStatusProvider(ledgerId));
                          final cached =
                              ref.watch(lastSyncStatusProvider(ledgerId));
                          final st = asyncSt.asData?.value ?? cached;
                          // (旧代码遗留变量 isFirstLoad 已不需要)
                          return _buildSyncSection(
                            context: context,
                            ref: ref,
                            sync: sync,
                            ledgerId: ledgerId,
                            user: user,
                            canUseCloud: canUseCloud,
                            asyncStIsLoading: asyncSt.isLoading,
                            st: st,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // 导入导出
                SizedBox(height: 8.0.scaled(context, ref)),
                _buildImportExportSection(context, ref),
                // 个性化
                SizedBox(height: 8.0.scaled(context, ref)),
                SectionCard(
                  margin: EdgeInsets.fromLTRB(12.0.scaled(context, ref), 0, 12.0.scaled(context, ref), 0),
                  child: Column(
                    children: [
                      AppListTile(
                        leading: Icons.category_outlined,
                        title: AppLocalizations.of(context).mineCategoryManagement,
                        subtitle: AppLocalizations.of(context).mineCategoryManagementSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const CategoryManagePage()),
                          );
                        },
                      ),
                      AppDivider.thin(),
                      AppListTile(
                        leading: Icons.swap_horiz,
                        title: AppLocalizations.of(context).mineCategoryMigration,
                        subtitle: AppLocalizations.of(context).mineCategoryMigrationSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const CategoryMigrationPage()),
                          );
                        },
                      ),
                      AppDivider.thin(),
                      AppListTile(
                        leading: Icons.notifications_outlined,
                        title: AppLocalizations.of(context).mineReminderSettings,
                        subtitle: AppLocalizations.of(context).mineReminderSettingsSubtitle,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ReminderSettingsPage()),
                          );
                        },
                      ),
                      AppDivider.thin(),
                      AppListTile(
                        leading: Icons.brush_outlined,
                        title: AppLocalizations.of(context).minePersonalize,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PersonalizePage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
                SectionCard(
                  margin: EdgeInsets.fromLTRB(12.0.scaled(context, ref), 0, 12.0.scaled(context, ref), 0),
                  child: AppListTile(
                    leading: Icons.zoom_out_map_outlined,
                    title: AppLocalizations.of(context).mineDisplayScale,
                    subtitle: AppLocalizations.of(context).mineDisplayScaleSubtitle,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const FontSettingsPage()),
                      );
                    },
                  ),
                ),
                // 语言设置
                SizedBox(height: 8.0.scaled(context, ref)),
                _buildLanguageSection(context, ref),
                // 关于与版本
                SizedBox(height: 8.0.scaled(context, ref)),
                _buildAboutSection(context, ref),
                // 调试
                if (!const bool.fromEnvironment('dart.vm.product')) ...[
                  SizedBox(height: 8.0.scaled(context, ref)),
                  _buildDebugSection(context, ref),
                ],
                SizedBox(height: AppDimens.p16.scaled(context, ref)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncSection({
    required BuildContext context,
    required WidgetRef ref,
    required SyncService sync,
    required int ledgerId,
    required AuthUser? user,
    required bool canUseCloud,
    required bool asyncStIsLoading,
    required SyncStatus? st,
  }) {
    String subtitle = '';
    IconData icon = Icons.sync_outlined;
    bool inSync = false;
    bool notLoggedIn = false;
    final isFirstLoad = st == null;
    final refreshing = asyncStIsLoading;
    if (!isFirstLoad) {
      switch (st.diff) {
        case SyncDiff.notLoggedIn:
          subtitle = AppLocalizations.of(context).mineSyncNotLoggedIn;
          icon = Icons.lock_outline;
          notLoggedIn = true;
          break;
        case SyncDiff.notConfigured:
          subtitle = AppLocalizations.of(context).mineSyncNotConfigured;
          icon = Icons.cloud_off_outlined;
          break;
        case SyncDiff.noRemote:
          subtitle = AppLocalizations.of(context).mineSyncNoRemote;
          icon = Icons.cloud_queue_outlined;
          break;
        case SyncDiff.inSync:
          subtitle = AppLocalizations.of(context).mineSyncInSync(st.localCount);
          icon = Icons.verified_outlined;
          inSync = true;
          break;
        case SyncDiff.localNewer:
          subtitle = AppLocalizations.of(context).mineSyncLocalNewer(st.localCount);
          icon = Icons.upload_outlined;
          break;
        case SyncDiff.cloudNewer:
          subtitle = AppLocalizations.of(context).mineSyncCloudNewer;
          icon = Icons.download_outlined;
          break;
        case SyncDiff.different:
          subtitle = AppLocalizations.of(context).mineSyncDifferent;
          icon = Icons.change_circle_outlined;
          break;
        case SyncDiff.error:
          // 本地化同步消息
          String? localizedMessage;
          if (st.message != null) {
            switch (st.message!) {
              case '__SYNC_NOT_CONFIGURED__':
                localizedMessage = AppLocalizations.of(context).syncNotConfiguredMessage;
                break;
              case '__SYNC_NOT_LOGGED_IN__':
                localizedMessage = AppLocalizations.of(context).syncNotLoggedInMessage;
                break;
              case '__SYNC_CLOUD_BACKUP_CORRUPTED__':
                localizedMessage = AppLocalizations.of(context).syncCloudBackupCorruptedMessage;
                break;
              case '__SYNC_NO_CLOUD_BACKUP__':
                localizedMessage = AppLocalizations.of(context).syncNoCloudBackupMessage;
                break;
              case '__SYNC_ACCESS_DENIED__':
                localizedMessage = AppLocalizations.of(context).syncAccessDeniedMessage;
                break;
              default:
                localizedMessage = st.message;
            }
          }
          subtitle = localizedMessage ?? AppLocalizations.of(context).mineSyncError;
          icon = Icons.error_outline;
          break;
      }
    }
    bool uploadBusy = false;
    bool downloadBusy = false;

    return StatefulBuilder(builder: (ctx, setSB) {
      return Column(
        children: [
          // 首次全量上传提示按钮
          Consumer(builder: (ctx3, r3, _) {
            final firstFlag = r3.watch(firstFullUploadPendingProvider);
            final activeCfg = r3.watch(activeCloudConfigProvider);
            final show = firstFlag.asData?.value == true &&
                activeCfg.asData?.value.builtin == false &&
                canUseCloud &&
                !notLoggedIn;
            if (!show) return const SizedBox();
            return Column(children: [
              AppListTile(
                leading: Icons.cloud_upload,
                title: AppLocalizations.of(context).mineFirstFullUpload,
                subtitle: AppLocalizations.of(context).mineFirstFullUploadSubtitle,
                onTap: () async {
                  try {
                    await sync.uploadCurrentLedger(ledgerId: ledgerId);
                    if (context.mounted) {
                      await AppDialog.info(context,
                          title: AppLocalizations.of(context).mineFirstFullUploadComplete, message: AppLocalizations.of(context).mineFirstFullUploadMessage);
                    }
                    await r3
                        .read(cloudServiceStoreProvider)
                        .clearFirstFullUploadFlag();
                    r3.invalidate(firstFullUploadPendingProvider);
                    r3.read(syncStatusRefreshProvider.notifier).state++;
                  } catch (e) {
                    if (context.mounted) {
                      await AppDialog.error(context,
                          title: AppLocalizations.of(context).mineFirstFullUploadFailed, message: '$e');
                    }
                  }
                },
              ),
              AppDivider.thin(),
            ]);
          }),
          AppListTile(
            leading: icon,
            title: AppLocalizations.of(context).mineSyncTitle,
            subtitle: isFirstLoad ? null : subtitle,
            enabled: canUseCloud &&
                !isFirstLoad &&
                !refreshing &&
                !uploadBusy &&
                !downloadBusy,
            trailing: (canUseCloud &&
                    (isFirstLoad || refreshing || uploadBusy || downloadBusy))
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
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
                      AppLocalizations.of(context).mineSyncLocalRecords(st.localCount),
                      if (st.cloudCount != null) AppLocalizations.of(context).mineSyncCloudRecords(st.cloudCount!),
                      if (st.cloudExportedAt != null)
                        AppLocalizations.of(context).mineSyncCloudLatest(DateFormat('yyyy-MM-dd HH:mm:ss').format(st.cloudExportedAt!.toLocal())),
                      AppLocalizations.of(context).mineSyncLocalFingerprint(st.localFingerprint),
                      if (st.cloudFingerprint != null)
                        AppLocalizations.of(context).mineSyncCloudFingerprint(st.cloudFingerprint!),
                      if (st.message != null) () {
                        String localizedMessage = st.message!;
                        switch (st.message!) {
                          case '__SYNC_NOT_CONFIGURED__':
                            localizedMessage = AppLocalizations.of(context).syncNotConfiguredMessage;
                            break;
                          case '__SYNC_NOT_LOGGED_IN__':
                            localizedMessage = AppLocalizations.of(context).syncNotLoggedInMessage;
                            break;
                          case '__SYNC_CLOUD_BACKUP_CORRUPTED__':
                            localizedMessage = AppLocalizations.of(context).syncCloudBackupCorruptedMessage;
                            break;
                          case '__SYNC_NO_CLOUD_BACKUP__':
                            localizedMessage = AppLocalizations.of(context).syncNoCloudBackupMessage;
                            break;
                          case '__SYNC_ACCESS_DENIED__':
                            localizedMessage = AppLocalizations.of(context).syncAccessDeniedMessage;
                            break;
                        }
                        return AppLocalizations.of(context).mineSyncMessage(localizedMessage);
                      }(),
                    ];
                    await AppDialog.info(context,
                        title: AppLocalizations.of(context).mineSyncDetailTitle, message: lines.join('\n'));
                  },
          ),
          AppDivider.thin(),
          AppListTile(
            leading: Icons.cloud_upload_outlined,
            title: AppLocalizations.of(context).mineUploadTitle,
            subtitle: isFirstLoad
                ? null
                : (!canUseCloud || notLoggedIn)
                    ? AppLocalizations.of(context).mineUploadNeedLogin
                    : uploadBusy
                        ? AppLocalizations.of(context).mineUploadInProgress
                        : (refreshing ? AppLocalizations.of(context).mineUploadRefreshing : (inSync ? AppLocalizations.of(context).mineUploadSynced : null)),
            enabled: canUseCloud &&
                !inSync &&
                !notLoggedIn &&
                !uploadBusy &&
                !downloadBusy &&
                !isFirstLoad &&
                !refreshing,
            trailing: (uploadBusy || refreshing || (isFirstLoad && canUseCloud))
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: () async {
              setSB(() => uploadBusy = true);
              try {
                await sync.uploadCurrentLedger(ledgerId: ledgerId);
                if (!context.mounted) return;
                await AppDialog.info(context,
                    title: AppLocalizations.of(context).mineUploadSuccess, message: AppLocalizations.of(context).mineUploadSuccessMessage);
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
                        ref
                            .read(lastSyncStatusProvider(ledgerId).notifier)
                            .state = stNow;
                        break;
                      }
                      if (i < maxAttempts - 1) {
                        await Future.delayed(delay);
                        delay *= 2;
                      }
                    }
                    ref.read(syncStatusRefreshProvider.notifier).state++;
                  } catch (_) {}
                });
              } catch (e) {
                if (!context.mounted) return;
                await AppDialog.info(context, title: AppLocalizations.of(context).commonFailed, message: '$e');
              } finally {
                if (ctx.mounted) setSB(() => uploadBusy = false);
              }
            },
          ),
          AppDivider.thin(),
          AppListTile(
            leading: Icons.cloud_download_outlined,
            title: AppLocalizations.of(context).mineDownloadTitle,
            subtitle: isFirstLoad
                ? null
                : (!canUseCloud || notLoggedIn)
                    ? AppLocalizations.of(context).mineUploadNeedLogin
                    : (refreshing ? AppLocalizations.of(context).mineUploadRefreshing : (inSync ? AppLocalizations.of(context).mineUploadSynced : null)),
            enabled: canUseCloud &&
                !inSync &&
                !notLoggedIn &&
                !downloadBusy &&
                !isFirstLoad &&
                !refreshing &&
                !uploadBusy,
            trailing:
                (downloadBusy || refreshing || (isFirstLoad && canUseCloud))
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
            onTap: () async {
              setSB(() => downloadBusy = true);
              try {
                final res = await sync.downloadAndRestoreToCurrentLedger(
                    ledgerId: ledgerId);
                if (!context.mounted) return;
                final msg = AppLocalizations.of(context).mineDownloadResult(res.inserted, res.skipped, res.deletedDup);
                await AppDialog.info(context,
                    title: AppLocalizations.of(context).mineDownloadComplete, message: msg);
                ref.read(syncStatusRefreshProvider.notifier).state++;
              } catch (e) {
                if (!context.mounted) return;
                await AppDialog.error(context, title: AppLocalizations.of(context).commonFailed, message: '$e');
              } finally {
                if (ctx.mounted) setSB(() => downloadBusy = false);
              }
            },
          ),
          AppDivider.thin(),
          // 登录/登出
          Builder(builder: (_) {
            final userNow = user; // capture
            return AppListTile(
              leading:
                  userNow == null ? Icons.login : Icons.verified_user_outlined,
              title: userNow == null ? AppLocalizations.of(context).mineLoginTitle : (userNow.email ?? AppLocalizations.of(context).mineLoggedInEmail),
              subtitle: userNow == null ? AppLocalizations.of(context).mineLoginSubtitle : AppLocalizations.of(context).mineLogoutSubtitle,
              onTap: () async {
                if (userNow == null) {
                  await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginPage()));
                  ref.read(syncStatusRefreshProvider.notifier).state++;
                  ref.read(statsRefreshProvider.notifier).state++;
                } else {
                  final confirmed = await AppDialog.confirm<bool>(
                    context,
                    title: AppLocalizations.of(context).mineLogoutConfirmTitle,
                    message: AppLocalizations.of(context).mineLogoutConfirmMessage,
                    okLabel: AppLocalizations.of(context).mineLogoutButton,
                    cancelLabel: AppLocalizations.of(context).commonCancel,
                  ) ?? false;
                  
                  if (confirmed) {
                    await ref.read(authServiceProvider).signOut();
                    ref.read(syncStatusRefreshProvider.notifier).state++;
                    ref.read(statsRefreshProvider.notifier).state++;
                  }
                }
              },
            );
          }),
          AppDivider.thin(),
          Consumer(builder: (ctx, r, _) {
            final autoSync = r.watch(autoSyncValueProvider);
            final setter = r.read(autoSyncSetterProvider);
            final value = autoSync.asData?.value ?? false;
            final can = canUseCloud;
            return SwitchListTile(
              title: Text(AppLocalizations.of(context).mineAutoSyncTitle),
              subtitle: can ? Text(AppLocalizations.of(context).mineAutoSyncSubtitle) : Text(AppLocalizations.of(context).mineAutoSyncNeedLogin),
              value: can ? value : false,
              onChanged: can
                  ? (v) async {
                      await setter.set(v);
                    }
                  : null,
            );
          }),
        ],
      );
    });
  }

  Widget _buildImportExportSection(BuildContext context, WidgetRef ref) {
    return SectionCard(
      margin: EdgeInsets.fromLTRB(12.0.scaled(context, ref), 0, 12.0.scaled(context, ref), 0),
      child: Column(
        children: [
          Consumer(builder: (ctx, r, _) {
            final p = r.watch(importProgressProvider);
            if (!p.running && p.total == 0) {
              return AppListTile(
                leading: Icons.file_upload_outlined,
                title: AppLocalizations.of(context).mineImport,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImportPage()),
                  );
                },
              );
            }
            if (p.running) {
              final percent =
                  p.total == 0 ? null : (p.done / p.total).clamp(0.0, 1.0);
              return AppListTile(
                leading: Icons.upload_outlined,
                title: AppLocalizations.of(context).mineImportProgressTitle,
                subtitle: AppLocalizations.of(context).mineImportProgressSubtitle(p.done, p.total, p.ok, p.fail),
                trailing: SizedBox(
                    width: 72, child: LinearProgressIndicator(value: percent)),
                onTap: null,
              );
            }
            final allOk = (p.done == p.total) && (p.fail == 0);
            if (allOk) return const _ImportSuccessTile();
            return AppListTile(
              leading: Icons.info_outline,
              title: AppLocalizations.of(context).mineImportCompleteTitle,
              subtitle: '${AppLocalizations.of(context).commonSuccess} ${p.ok}，${AppLocalizations.of(context).commonFailed} ${p.fail}',
              onTap: null,
            );
          }),
          AppDivider.thin(),
          AppListTile(
            leading: Icons.file_download_outlined,
            title: AppLocalizations.of(context).mineExport,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExportPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context, WidgetRef ref) {
    return SectionCard(
      margin: EdgeInsets.fromLTRB(12.0.scaled(context, ref), 0, 12.0.scaled(context, ref), 0),
      child: Column(children: [
        AppListTile(
          leading: Icons.info_outline,
          title: AppLocalizations.of(context).mineAboutTitle,
          onTap: () async {
            final info = await _getAppInfo();
            if (!context.mounted) return;
            final versionText = info.version.startsWith('dev-')
                ? '${info.version} (${info.buildNumber})'
                : info.version;
            final msg =
                '${AppLocalizations.of(context).mineAboutAppName}\n${AppLocalizations.of(context).mineAboutVersion(versionText)}\n${AppLocalizations.of(context).mineAboutRepo}\n${AppLocalizations.of(context).mineAboutLicense}';
            final open = await AppDialog.confirm<bool>(
                  context,
                  title: AppLocalizations.of(context).mineAboutTitle,
                  message: msg,
                  okLabel: AppLocalizations.of(context).mineAboutOpenGitHub,
                  cancelLabel: AppLocalizations.of(context).commonClose,
                ) ??
                false;
            if (open) {
              final url = Uri.parse('https://github.com/TNT-Likely/BeeCount');
              await _tryOpenUrl(url);
            }
          },
        ),
        AppDivider.thin(),
        Consumer(builder: (context, ref2, child) {
          final isLoading = ref2.watch(checkUpdateLoadingProvider);
          final downloadProgress = ref2.watch(updateProgressProvider);
          
          // 确定显示状态
          bool showProgress = false;
          String title = AppLocalizations.of(context).mineCheckUpdate;
          String? subtitle;
          IconData icon = Icons.system_update_alt_outlined;
          Widget? trailing;
          
          if (isLoading) {
            title = AppLocalizations.of(context).mineCheckUpdateDetecting;
            subtitle = AppLocalizations.of(context).mineCheckUpdateSubtitleDetecting;
            icon = Icons.hourglass_empty;
            trailing = const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)
            );
          } else if (downloadProgress.isActive) {
            showProgress = true;
            title = AppLocalizations.of(context).mineUpdateDownloadTitle;
            icon = Icons.download_outlined;
            trailing = SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: downloadProgress.progress,
              )
            );
          }
          
          return AppListTile(
            leading: icon,
            title: title,
            subtitle: showProgress ? downloadProgress.status : subtitle,
            trailing: trailing,
            onTap: (isLoading || showProgress)
                ? null
                : () async {
                    await UpdateService.checkUpdateWithUI(
                      context,
                      setLoading: (loading) => ref2.read(checkUpdateLoadingProvider.notifier).state = loading,
                      setProgress: (progress, status) {
                        if (status.isEmpty) {
                          ref2.read(updateProgressProvider.notifier).state = UpdateProgress.idle();
                        } else {
                          ref2.read(updateProgressProvider.notifier).state = UpdateProgress.active(progress, status);
                        }
                      },
                    );
                  },
          );
        }),
      ]),
    );
  }

  Widget _buildDebugSection(BuildContext context, WidgetRef ref) {
    return SectionCard(
      margin: EdgeInsets.fromLTRB(12.0.scaled(context, ref), 0, 12.0.scaled(context, ref), 0),
      child: Column(children: [
        AppListTile(
          leading: Icons.refresh,
          title: AppLocalizations.of(context).mineDebugRefreshStats,
          subtitle: AppLocalizations.of(context).mineDebugRefreshStatsSubtitle,
          onTap: () {
            ref.read(statsRefreshProvider.notifier).state++;
          },
        ),
        AppDivider.thin(),
        AppListTile(
          leading: Icons.sync,
          title: AppLocalizations.of(context).mineDebugRefreshSync,
          subtitle: AppLocalizations.of(context).mineDebugRefreshSyncSubtitle,
          onTap: () {
            ref.read(syncStatusRefreshProvider.notifier).state++;
          },
        ),
      ]),
    );
  }

  Widget _buildLanguageSection(BuildContext context, WidgetRef ref) {
    final currentLanguage = ref.watch(languageProvider);
    final l10n = AppLocalizations.of(context);

    // 获取当前语言显示名称
    String currentLanguageDisplay;
    if (currentLanguage == null) {
      currentLanguageDisplay = l10n.languageSystemDefault;
    } else {
      switch (currentLanguage.languageCode) {
        case 'zh':
          currentLanguageDisplay = l10n.languageChinese;
          break;
        case 'en':
          currentLanguageDisplay = l10n.languageEnglish;
          break;
        default:
          currentLanguageDisplay = currentLanguage.languageCode;
      }
    }

    return SectionCard(
      margin: EdgeInsets.fromLTRB(12.0.scaled(context, ref), 0, 12.0.scaled(context, ref), 0),
      child: AppListTile(
        leading: Icons.language_outlined,
        title: l10n.mineLanguageSettings,
        subtitle: l10n.mineLanguageSettingsSubtitle,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLanguageDisplay,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const LanguageSettingsPage()),
          );
        },
      ),
    );
  }
}

class _StatCell extends ConsumerWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? numStyle;
  const _StatCell(
      {required this.label,
      required this.value,
      this.labelStyle,
      this.numStyle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: numStyle),
        SizedBox(height: 4.0.scaled(context, ref)), // 数字与标签间距增大
        Text(label, style: labelStyle),
      ],
    );
  }
}

// 导入完成后的短暂动画提示：线性进度条从 0 -> 100%
class _ImportSuccessTile extends StatelessWidget {
  const _ImportSuccessTile();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (ctx, v, child) {
        return AppListTile(
          leading: Icons.check_circle_outline,
          title: AppLocalizations.of(ctx).mineImportCompleteTitle,
          subtitle: AppLocalizations.of(ctx).mineImportCompleteAllSuccess,
          trailing: SizedBox(
            width: 72,
            child: LinearProgressIndicator(
              value: v,
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),
        );
      },
    );
  }
}

// -------- 工具方法：关于与更新 --------
class _AppInfo {
  final String version;
  final String buildNumber;
  final String? commit;
  final String? buildTime;
  const _AppInfo(this.version, this.buildNumber, {this.commit, this.buildTime});
}

// 优先读取 CI 注入的 dart-define（CI_VERSION/GIT_COMMIT/BUILD_TIME），否则回退 PackageInfo
Future<_AppInfo> _getAppInfo() async {
  final p = await PackageInfo.fromPlatform();
  final commit = const String.fromEnvironment('GIT_COMMIT');
  final buildTime = const String.fromEnvironment('BUILD_TIME');
  final ciVersion = const String.fromEnvironment('CI_VERSION');

  // 版本号策略：CI版本优先，本地开发显示 "dev-{pubspec版本}"
  final version =
      ciVersion.isNotEmpty ? ciVersion : 'dev-${p.version}'; // 本地开发版本标识

  return _AppInfo(version, p.buildNumber,
      commit: commit.isEmpty ? null : commit,
      buildTime: buildTime.isEmpty ? null : buildTime);
}









/// 尝试使用多种方式打开URL，提供更好的兼容性
Future<bool> _tryOpenUrl(Uri url) async {
  try {
    // 方式1: 默认外部应用打开
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    }

    // 方式2: 浏览器内打开
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      return true;
    }

    // 方式3: 平台默认方式
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.platformDefault);
      return true;
    }

    logE('MinePage', '无法打开URL: $url');
    return false;
  } catch (e) {
    logE('MinePage', '打开URL失败: $url', e);
    return false;
  }
}

