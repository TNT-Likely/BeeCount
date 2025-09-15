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
import 'font_settings_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import 'dart:io' show Platform;
import '../utils/format_utils.dart';

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
                title: '发现云端备份',
                message: '检测到云端与本地账本不一致，是否恢复到本地？\n(将进入恢复进度页)') ??
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
        await AppDialog.error(context, title: '恢复失败', message: '$e');
      }
    });

    return Scaffold(
      backgroundColor: BeeColors.greyBg,
      body: Column(
        children: [
          PrimaryHeader(
            showBack: false,
            title: '我的',
            compact: true,
            showTitleSection: false,
            content: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
                          size: 48,
                        ),
                        Text('我的', style: AppTextTokens.title(context)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '蜜蜂记账，一笔一蜜',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: BeeColors.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5), // 标语与统计区间距增大
                          Builder(builder: (ctx) {
                            // 获取当前账本信息
                            final currentLedgerId =
                                ref.watch(currentLedgerIdProvider);
                            final countsAsync = ref.watch(
                                countsForLedgerProvider(currentLedgerId));
                            final balanceAsync = ref
                                .watch(currentBalanceProvider(currentLedgerId));

                            final day = countsAsync.asData?.value.dayCount ?? 0;
                            final tx = countsAsync.asData?.value.txCount ?? 0;
                            final balance = balanceAsync.asData?.value ?? 0.0;

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
                                        label: '记账天数',
                                        value: day.toString(),
                                        labelStyle: labelStyle,
                                        numStyle: numStyle)),
                                Expanded(
                                    child: _StatCell(
                                        label: '总笔数',
                                        value: tx.toString(),
                                        labelStyle: labelStyle,
                                        numStyle: numStyle)),
                                Expanded(
                                    child: _StatCell(
                                        label: '当前余额',
                                        value: formatBalance(balance),
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
                const SizedBox(height: 8),
                // 同步分组
                SectionCard(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: Column(
                    children: [
                      Consumer(builder: (ctx, r, _) {
                        final activeCfg = r.watch(activeCloudConfigProvider);
                        return AppListTile(
                          leading: Icons.cloud_queue_outlined,
                          title: '云服务',
                          subtitle: activeCfg.when(
                            loading: () => '加载中…',
                            error: (e, _) => '错误: $e',
                            data: (cfg) => cfg.builtin
                                ? (cfg.valid ? '默认云服务 (已启用)' : '默认模式 (离线)')
                                : '自定义 Supabase',
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
                const SizedBox(height: 8),
                _buildImportExportSection(context),
                // 个性化
                const SizedBox(height: 8),
                SectionCard(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: AppListTile(
                    leading: Icons.brush_outlined,
                    title: '个性装扮',
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PersonalizePage()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SectionCard(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: AppListTile(
                    leading: Icons.text_fields_outlined,
                    title: '字体与字号',
                    subtitle: '微调显示大小',
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const FontSettingsPage()),
                      );
                    },
                  ),
                ),
                // 关于与版本
                const SizedBox(height: 8),
                _buildAboutSection(context, ref),
                // 调试
                if (!const bool.fromEnvironment('dart.vm.product')) ...[
                  const SizedBox(height: 8),
                  _buildDebugSection(ref),
                ],
                const SizedBox(height: AppDimens.p16),
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
          subtitle = '未登录';
          icon = Icons.lock_outline;
          notLoggedIn = true;
          break;
        case SyncDiff.notConfigured:
          subtitle = '未配置云端';
          icon = Icons.cloud_off_outlined;
          break;
        case SyncDiff.noRemote:
          subtitle = '云端暂无备份';
          icon = Icons.cloud_queue_outlined;
          break;
        case SyncDiff.inSync:
          subtitle = '已同步 (本地${st.localCount}条)';
          icon = Icons.verified_outlined;
          inSync = true;
          break;
        case SyncDiff.localNewer:
          subtitle = '本地较新 (本地${st.localCount}条, 建议上传)';
          icon = Icons.upload_outlined;
          break;
        case SyncDiff.cloudNewer:
          subtitle = '云端较新 (建议下载并合并)';
          icon = Icons.download_outlined;
          break;
        case SyncDiff.different:
          subtitle = '本地与云端不同步';
          icon = Icons.change_circle_outlined;
          break;
        case SyncDiff.error:
          subtitle = st.message ?? '状态获取失败';
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
                title: '首次全量上传',
                subtitle: '将所有本地账本上传到当前 Supabase',
                onTap: () async {
                  try {
                    await sync.uploadCurrentLedger(ledgerId: ledgerId);
                    if (context.mounted) {
                      await AppDialog.info(context,
                          title: '完成', message: '已上传当前账本。其它账本请切换后再上传。');
                    }
                    await r3
                        .read(cloudServiceStoreProvider)
                        .clearFirstFullUploadFlag();
                    r3.invalidate(firstFullUploadPendingProvider);
                    r3.read(syncStatusRefreshProvider.notifier).state++;
                  } catch (e) {
                    if (context.mounted) {
                      await AppDialog.error(context,
                          title: '失败', message: '$e');
                    }
                  }
                },
              ),
              AppDivider.thin(),
            ]);
          }),
          AppListTile(
            leading: icon,
            title: '同步',
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
                    final st2 = await sync.getStatus(ledgerId: ledgerId);
                    if (!context.mounted) return;
                    final lines = <String>[
                      '本地记录数: ${st2.localCount}',
                      if (st2.cloudCount != null) '云端记录数: ${st2.cloudCount}',
                      if (st2.cloudExportedAt != null)
                        '云端最新记账时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(st2.cloudExportedAt!.toLocal())}',
                      '本地指纹: ${st2.localFingerprint}',
                      if (st2.cloudFingerprint != null)
                        '云端指纹: ${st2.cloudFingerprint}',
                      if (st2.message != null) '说明: ${st2.message}',
                    ];
                    await AppDialog.info(context,
                        title: '同步状态详情', message: lines.join('\n'));
                  },
          ),
          AppDivider.thin(),
          AppListTile(
            leading: Icons.cloud_upload_outlined,
            title: '上传',
            subtitle: isFirstLoad
                ? null
                : (!canUseCloud || notLoggedIn)
                    ? '需登录'
                    : uploadBusy
                        ? '正在上传中…'
                        : (refreshing ? '刷新中…' : (inSync ? '已同步' : null)),
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
                    title: '已上传', message: '当前账本已同步到云端');
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
                await AppDialog.info(context, title: '失败', message: '$e');
              } finally {
                if (ctx.mounted) setSB(() => uploadBusy = false);
              }
            },
          ),
          AppDivider.thin(),
          AppListTile(
            leading: Icons.cloud_download_outlined,
            title: '下载',
            subtitle: isFirstLoad
                ? null
                : (!canUseCloud || notLoggedIn)
                    ? '需登录'
                    : (refreshing ? '刷新中…' : (inSync ? '已同步' : null)),
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
                final msg = StringBuffer()
                  ..writeln('新增导入：${res.inserted} 条')
                  ..writeln('已存在跳过：${res.skipped} 条')
                  ..writeln('清理历史重复：${res.deletedDup} 条');
                await AppDialog.info(context,
                    title: '完成', message: msg.toString());
                ref.read(syncStatusRefreshProvider.notifier).state++;
              } catch (e) {
                if (!context.mounted) return;
                await AppDialog.error(context, title: '失败', message: '$e');
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
              title: userNow == null ? '登录 / 注册' : (userNow.email ?? '已登录'),
              subtitle: userNow == null ? '仅在同步时需要' : '点击可退出登录',
              onTap: () async {
                if (userNow == null) {
                  await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginPage()));
                  ref.read(syncStatusRefreshProvider.notifier).state++;
                  ref.read(statsRefreshProvider.notifier).state++;
                } else {
                  final confirmed = await AppDialog.confirm<bool>(
                    context,
                    title: '退出登录',
                    message: '确定要退出当前账号登录吗？\n退出后将无法使用云同步功能。',
                    okLabel: '退出',
                    cancelLabel: '取消',
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
              title: const Text('自动同步账本'),
              subtitle: can ? const Text('记账后自动上传到云端') : const Text('需登录后可开启'),
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

  Widget _buildImportExportSection(BuildContext context) {
    return SectionCard(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Column(
        children: [
          Consumer(builder: (ctx, r, _) {
            final p = r.watch(importProgressProvider);
            if (!p.running && p.total == 0) {
              return AppListTile(
                leading: Icons.file_upload_outlined,
                title: '导入',
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
                title: '后台导入中…',
                subtitle: '进度：${p.done}/${p.total}，成功 ${p.ok}，失败 ${p.fail}',
                trailing: SizedBox(
                    width: 72, child: LinearProgressIndicator(value: percent)),
                onTap: null,
              );
            }
            final allOk = (p.done == p.total) && (p.fail == 0);
            if (allOk) return const _ImportSuccessTile();
            return AppListTile(
              leading: Icons.info_outline,
              title: '导入完成',
              subtitle: '成功 ${p.ok}，失败 ${p.fail}',
              onTap: null,
            );
          }),
          AppDivider.thin(),
          AppListTile(
            leading: Icons.file_download_outlined,
            title: '导出',
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
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Column(children: [
        AppListTile(
          leading: Icons.info_outline,
          title: '关于',
          onTap: () async {
            final info = await _getAppInfo();
            if (!context.mounted) return;
            final versionText = info.version.startsWith('dev-')
                ? '${info.version} (${info.buildNumber})'
                : info.version;
            final msg =
                '应用：蜜蜂记账\n版本：$versionText\n开源地址：https://github.com/TNT-Likely/BeeCount\n开源协议：详见仓库 LICENSE';
            final open = await AppDialog.confirm<bool>(
                  context,
                  title: '关于',
                  message: msg,
                  okLabel: '打开 GitHub',
                  cancelLabel: '关闭',
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
          return AppListTile(
            leading: isLoading
                ? Icons.hourglass_empty
                : Icons.system_update_alt_outlined,
            title: isLoading ? '检测更新中...' : '检测更新',
            trailing: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: isLoading
                ? null
                : () async {
                    await _checkUpdateWithLoading(context, ref2);
                  },
          );
        }),
      ]),
    );
  }

  Widget _buildDebugSection(WidgetRef ref) {
    return SectionCard(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Column(children: [
        AppListTile(
          leading: Icons.refresh,
          title: '刷新统计信息（临时）',
          subtitle: '触发全局统计 Provider 重新计算',
          onTap: () {
            ref.read(statsRefreshProvider.notifier).state++;
          },
        ),
        AppDivider.thin(),
        AppListTile(
          leading: Icons.sync,
          title: '刷新同步状态（临时）',
          subtitle: '触发同步状态 Provider 重新获取',
          onTap: () {
            ref.read(syncStatusRefreshProvider.notifier).state++;
          },
        ),
      ]),
    );
  }
}

class _StatCell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: numStyle),
        const SizedBox(height: 4), // 数字与标签间距增大
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
          title: '导入完成',
          subtitle: '全部成功',
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

/// 带加载状态的检查更新封装函数
Future<void> _checkUpdateWithLoading(
    BuildContext context, WidgetRef ref) async {
  // 防重复点击
  if (ref.read(checkUpdateLoadingProvider)) return;

  try {
    ref.read(checkUpdateLoadingProvider.notifier).state = true;
    await _checkUpdate(context);
  } finally {
    ref.read(checkUpdateLoadingProvider.notifier).state = false;
  }
}

Future<void> _checkUpdate(BuildContext context) async {
  try {
    // 获取当前版本信息
    final currentInfo = await _getAppInfo();
    final currentVersion = _normalizeVersion(currentInfo.version);

    // 获取最新 release 信息
    final resp = await http.get(
      Uri.parse(
          'https://api.github.com/repos/TNT-Likely/BeeCount/releases/latest'),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'BeeCount-App',
      },
    ).timeout(const Duration(seconds: 5));
    if (resp.statusCode == 200) {
      final data = convert.jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?) ?? '';
      final name = (data['name'] as String?) ?? tag;
      final body = (data['body'] as String?) ?? '';
      final assets =
          (data['assets'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final apk = assets.firstWhere(
          (a) =>
              (a['name'] as String?)?.toLowerCase().endsWith('.apk') ?? false,
          orElse: () => {});

      // 比较版本，只有远程版本更新时才提示
      final remoteVersion = _normalizeVersion(tag);
      if (!_isNewerVersion(remoteVersion, currentVersion)) {
        if (!context.mounted) return;
        await AppDialog.info(context,
            title: '检查更新', message: '当前已是最新版本 $currentVersion');
        return;
      }

      // 弹窗提示最新版本与更新说明（截断过长文案）
      final previewBody =
          (body.length > 400) ? ('${body.substring(0, 400)}...') : body;
      if (!context.mounted) return;
      final ok = await AppDialog.confirm<bool>(
            context,
            title: '发现新版本：$name',
            message: previewBody.isEmpty ? '是否前往更新？' : previewBody,
            okLabel: Platform.isAndroid ? '下载/前往' : '前往',
            cancelLabel: '稍后',
          ) ??
          false;
      if (!ok) return;

      if (Platform.isAndroid && apk.isNotEmpty) {
        final url = Uri.parse(apk['browser_download_url'] as String);
        final opened = await _tryOpenUrl(url);
        if (opened) return;
      }
      // 回退：打开 Releases 页面
      final fall = Uri.parse('https://github.com/TNT-Likely/BeeCount/releases');
      await _tryOpenUrl(fall);
    } else {
      // API 失败：提示并引导前往 Releases
      if (!context.mounted) return;
      final go = await AppDialog.confirm<bool>(
            context,
            title: '无法获取最新版本',
            message: '是否前往 Releases 查看？',
            okLabel: '前往',
            cancelLabel: '取消',
          ) ??
          false;
      if (go) {
        final fall =
            Uri.parse('https://github.com/TNT-Likely/BeeCount/releases');
        await _tryOpenUrl(fall);
      }
    }
  } catch (e) {
    // 异常：同样给出提示
    if (!context.mounted) return;
    final go = await AppDialog.confirm<bool>(
          context,
          title: '网络异常',
          message: '无法获取更新信息，是否前往 Releases 查看？',
          okLabel: '前往',
          cancelLabel: '取消',
        ) ??
        false;
    if (go) {
      final fall = Uri.parse('https://github.com/TNT-Likely/BeeCount/releases');
      await _tryOpenUrl(fall);
    }
  }
  // 用户取消或无法打开浏览器：不再弹窗
  return;
}

/// 标准化版本号，移除 'v' 前缀和 '-' 后缀
String _normalizeVersion(String version) {
  String normalized = version;
  // 移除 'v' 前缀
  if (normalized.startsWith('v')) {
    normalized = normalized.substring(1);
  }
  // 移除 'dev-' 前缀
  if (normalized.startsWith('dev-')) {
    normalized = normalized.substring(4);
  }
  // 移除 '-' 后缀（如 -alpha, -beta, -dev 等）
  final dashIndex = normalized.indexOf('-');
  if (dashIndex != -1) {
    normalized = normalized.substring(0, dashIndex);
  }
  return normalized;
}

/// 比较两个版本号，判断 newVersion 是否比 currentVersion 更新
bool _isNewerVersion(String newVersion, String currentVersion) {
  final newParts = newVersion
      .split('.')
      .map(int.tryParse)
      .where((e) => e != null)
      .cast<int>()
      .toList();
  final currentParts = currentVersion
      .split('.')
      .map(int.tryParse)
      .where((e) => e != null)
      .cast<int>()
      .toList();

  // 补齐长度，短的用 0 填充
  final maxLength =
      [newParts.length, currentParts.length].reduce((a, b) => a > b ? a : b);
  while (newParts.length < maxLength) {
    newParts.add(0);
  }
  while (currentParts.length < maxLength) {
    currentParts.add(0);
  }

  // 逐位比较
  for (int i = 0; i < maxLength; i++) {
    if (newParts[i] > currentParts[i]) return true;
    if (newParts[i] < currentParts[i]) return false;
  }

  return false; // 版本相等
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
