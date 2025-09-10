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
import '../utils/logger.dart';
import '../services/restore_service.dart';
import 'restore_progress_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import 'dart:io' show Platform;

class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final auth = ref.watch(authServiceProvider);
    final sync = ref.watch(syncServiceProvider);
    // note: refresh tick is handled inside provider; no local watch needed here
    final authUserStream = auth.authStateChanges();

    // 登录后一次性触发云端备份检查：如需恢复则进入进度页，完成后返回本页
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final needCheck = ref.read(restoreCheckRequestProvider);
      final user = await ref.read(authServiceProvider).currentUser();
      if (!needCheck || user == null || !context.mounted) return;
      // 立刻重置，确保只触发一次
      ref.read(restoreCheckRequestProvider.notifier).state = false;
      try {
        final check = await RestoreService.checkNeedRestore(ref);
        if (!check.needsRestore) return;
        final ok = await AppDialog.confirm<bool>(context,
                title: '发现云端备份',
                message: '检测到云端与本地账本不一致，是否恢复到本地？\n(将进入恢复进度页)') ??
            false;
        if (!ok || !context.mounted) return;
        // 启动后台恢复并打开进度页
        RestoreService.startBackgroundRestore(check.backups, ref);
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RestoreProgressPage()),
        );
        // 返回后刷新同步状态与统计
        ref.read(syncStatusRefreshProvider.notifier).state++;
        ref.read(statsRefreshProvider.notifier).state++;
      } catch (e) {
        await AppDialog.error(context, title: '恢复失败', message: '$e');
      }
    });

    // 导出功能已迁移到 ExportPage

    return Scaffold(
      backgroundColor: BeeColors.greyBg,
      body: Column(
        children: [
          // 顶部：紧凑标题 + 统计
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
                    // 左侧：用户图标与“我的”上下对齐，图标顶对齐，"我的"底对齐
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
                    // 右侧：slogan + 账本信息（上下排列）
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
                                    fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Builder(builder: (ctx) {
                            final lCount = ref.watch(ledgerCountProvider);
                            final countsAsync = ref.watch(countsAllProvider);
                            final countsCached =
                                ref.watch(lastCountsAllProvider);
                            final day = countsAsync.asData?.value.dayCount ??
                                (countsCached?.dayCount ?? 0);
                            final tx = countsAsync.asData?.value.txCount ??
                                (countsCached?.txCount ?? 0);
                            final data = (
                              ledgerCount: lCount.asData?.value ?? 1,
                              dayCount: day,
                              txCount: tx,
                            );
                            final labelStyle = Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: BeeColors.black54);
                            final numStyle = Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    color: BeeColors.primaryText,
                                    fontWeight: FontWeight.w600);
                            return Row(
                              children: [
                                Expanded(
                                  child: _StatCell(
                                      label: '账本',
                                      value: data.ledgerCount.toString(),
                                      labelStyle: labelStyle,
                                      numStyle: numStyle),
                                ),
                                Expanded(
                                  child: _StatCell(
                                      label: '记账天数',
                                      value: data.dayCount.toString(),
                                      labelStyle: labelStyle,
                                      numStyle: numStyle),
                                ),
                                Expanded(
                                  child: _StatCell(
                                      label: '总笔数',
                                      value: data.txCount.toString(),
                                      labelStyle: labelStyle,
                                      numStyle: numStyle),
                                ),
                              ],
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

          // 内容：其余部分可滚动
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Divider(height: 1),
                // 分组：同步
                const SizedBox(height: 8),
                SectionCard(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: Column(
                    children: [
                      StreamBuilder<AuthUser?>(
                        stream: authUserStream,
                        builder: (ctx, snap) {
                          final user = snap.data;
                          final canUseCloud = user != null;
                          final asyncSt =
                              ref.watch(syncStatusProvider(ledgerId));
                          final cached =
                              ref.watch(lastSyncStatusProvider(ledgerId));
                          // 优先使用已加载的数据；加载中则回退到缓存，避免整块 loading
                          final st = asyncSt.asData?.value ?? cached;
                          final isFirstLoad = st == null; // 首次进入且无缓存
                          return Builder(builder: (_) {
                            String subtitle = '';
                            IconData icon = Icons.sync_outlined;
                            bool inSync = false;
                            bool notLoggedIn = false;
                            final refreshing = asyncSt.isLoading; // 正在刷新同步状态
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

                            return Column(
                              children: [
                                // 登录后一键恢复：后台进度显示
                                Consumer(builder: (ctx, r, _) {
                                  final p =
                                      r.watch(cloudRestoreProgressProvider);
                                  final summary =
                                      r.watch(cloudRestoreSummaryProvider);
                                  // 显示进行中的进度
                                  if (p.running) {
                                    final lead = Icons.cloud_download_outlined;
                                    final title =
                                        '云端恢复中… (${p.currentIndex}/${p.totalLedgers})';
                                    final sub = [
                                      if (p.currentLedgerName != null)
                                        '账本：${p.currentLedgerName}',
                                      '记录：${p.currentDone}/${p.currentTotal}'
                                    ].join('  ');
                                    final percent = p.currentTotal == 0
                                        ? null
                                        : (p.currentDone / p.currentTotal)
                                            .clamp(0.0, 1.0);
                                    return Column(
                                      children: [
                                        AppListTile(
                                          leading: lead,
                                          title: title,
                                          subtitle: sub,
                                          trailing: SizedBox(
                                            width: 72,
                                            child: LinearProgressIndicator(
                                                value: percent),
                                          ),
                                          onTap: null,
                                        ),
                                        AppDivider.thin(),
                                      ],
                                    );
                                  }
                                  // 显示完成摘要
                                  if (summary != null) {
                                    return Column(
                                      children: [
                                        AppListTile(
                                          leading: Icons.info_outline,
                                          title: '恢复完成',
                                          subtitle:
                                              '账本：${summary.successLedgers}/${summary.totalLedgers} 成功，失败 ${summary.failedLedgers}，总处理 ${summary.totalImported} 条',
                                          onTap: () async {
                                            final details =
                                                summary.failedDetails;
                                            final msg = details.isEmpty
                                                ? '全部成功'
                                                : '失败列表:\n${details.join('\n')}';
                                            await AppDialog.info(context,
                                                title: '完成摘要', message: msg);
                                            // 清空摘要，避免反复提示
                                            r
                                                .read(
                                                    cloudRestoreSummaryProvider
                                                        .notifier)
                                                .state = null;
                                          },
                                        ),
                                        AppDivider.thin(),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }),
                                StatefulBuilder(builder: (ctx, setSB) {
                                  return Column(
                                    children: [
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
                                                (isFirstLoad ||
                                                    refreshing ||
                                                    uploadBusy ||
                                                    downloadBusy))
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            : null,
                                        onTap: (isFirstLoad ||
                                                !canUseCloud ||
                                                refreshing ||
                                                uploadBusy ||
                                                downloadBusy)
                                            ? null
                                            : () async {
                                                final st2 =
                                                    await sync.getStatus(
                                                        ledgerId: ledgerId);
                                                final lines = <String>[];
                                                lines.add(
                                                    '本地记录数: ${st2.localCount}');
                                                if (st2.cloudCount != null) {
                                                  lines.add(
                                                      '云端记录数: ${st2.cloudCount}');
                                                }
                                                if (st2.cloudExportedAt !=
                                                    null) {
                                                  final cloudTime =
                                                      st2.cloudExportedAt!;
                                                  final cloudTimeStr = DateFormat(
                                                          'yyyy-MM-dd HH:mm:ss')
                                                      .format(
                                                          cloudTime.toLocal());
                                                  lines.add(
                                                      '云端最新记账时间: $cloudTimeStr');
                                                }
                                                lines.add(
                                                    '本地指纹: ${st2.localFingerprint}');
                                                if (st2.cloudFingerprint !=
                                                    null) {
                                                  lines.add(
                                                      '云端指纹: ${st2.cloudFingerprint}');
                                                }
                                                if (st2.message != null) {
                                                  lines.add(
                                                      '说明: ${st2.message}');
                                                }
                                                await AppDialog.info(
                                                  context,
                                                  title: '同步状态详情',
                                                  message: lines.join('\n'),
                                                );
                                                // 查看详情不修改状态，不触发刷新
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
                                                    : (refreshing
                                                        ? '刷新中…'
                                                        : (inSync
                                                            ? '已同步'
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
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            : null,
                                        onTap: () async {
                                          setSB(() => uploadBusy = true);
                                          try {
                                            await sync.uploadCurrentLedger(
                                                ledgerId: ledgerId);
                                            await AppDialog.info(context,
                                                title: '已上传',
                                                message: '当前账本已同步到云端');
                                            // 上传后先主动刷新云端指纹，若一致将直接更新缓存
                                            Future(() async {
                                              try {
                                                logI('sync/ui', '上传后开始刷新云端指纹');
                                                await sync
                                                    .refreshCloudFingerprint(
                                                        ledgerId: ledgerId);
                                              } catch (_) {}
                                            });
                                            // 然后在后台轮询一次远端，避免对象存储延迟导致仍显示“本地较新”
                                            Future(() async {
                                              const maxAttempts = 6; // 最长约 ~12s
                                              var delay = const Duration(
                                                  milliseconds: 500);
                                              for (var i = 0;
                                                  i < maxAttempts;
                                                  i++) {
                                                try {
                                                  // 注意：不要在此处调用 markLocalChanged，避免打断“上传后短窗”的 inSync 判断
                                                } catch (_) {}
                                                final stNow =
                                                    await sync.getStatus(
                                                        ledgerId: ledgerId);
                                                if (stNow.diff ==
                                                    SyncDiff.inSync) {
                                                  // 立即更新缓存供 UI 显示
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
                                                  delay *=
                                                      2; // 0.5s,1s,2s,4s,8s
                                                }
                                              }
                                              // 最终触发 Provider 刷新
                                              ref
                                                  .read(
                                                      syncStatusRefreshProvider
                                                          .notifier)
                                                  .state++;
                                            });
                                          } catch (e) {
                                            await AppDialog.info(context,
                                                title: '失败', message: '$e');
                                          } finally {
                                            if (ctx.mounted)
                                              setSB(() => uploadBusy = false);
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
                                                : (refreshing
                                                    ? '刷新中…'
                                                    : (inSync ? '已同步' : null)),
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
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            : null,
                                        onTap: () async {
                                          setSB(() => downloadBusy = true);
                                          try {
                                            final res = await sync
                                                .downloadAndRestoreToCurrentLedger(
                                                    ledgerId: ledgerId);
                                            final msg = StringBuffer()
                                              ..writeln(
                                                  '新增导入：${res.inserted} 条')
                                              ..writeln(
                                                  '已存在跳过：${res.skipped} 条')
                                              ..writeln(
                                                  '清理历史重复：${res.deletedDup} 条');
                                            await AppDialog.info(context,
                                                title: '完成',
                                                message: msg.toString());
                                            ref
                                                .read(syncStatusRefreshProvider
                                                    .notifier)
                                                .state++;
                                          } catch (e) {
                                            await AppDialog.error(context,
                                                title: '失败', message: '$e');
                                          } finally {
                                            if (ctx.mounted)
                                              setSB(() => downloadBusy = false);
                                          }
                                        },
                                      ),
                                    ],
                                  );
                                }),
                                AppDivider.thin(),
                                AppListTile(
                                  leading: user == null
                                      ? Icons.login
                                      : Icons.verified_user_outlined,
                                  title: user == null
                                      ? '登录 / 注册'
                                      : (user.email ?? '已登录'),
                                  subtitle:
                                      user == null ? '仅在同步时需要' : '点击可退出登录',
                                  onTap: () async {
                                    if (user == null) {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => const LoginPage()),
                                      );
                                      ref
                                          .read(syncStatusRefreshProvider
                                              .notifier)
                                          .state++;
                                      // 登录流程可能触发云端恢复；强制刷新统计
                                      ref
                                          .read(statsRefreshProvider.notifier)
                                          .state++;
                                    } else {
                                      await auth.signOut();
                                      ref
                                          .read(syncStatusRefreshProvider
                                              .notifier)
                                          .state++;
                                      // 退出登录也刷新统计，避免显示过期数
                                      ref
                                          .read(statsRefreshProvider.notifier)
                                          .state++;
                                    }
                                  },
                                ),
                                AppDivider.thin(),
                                Consumer(builder: (ctx, r, _) {
                                  final autoSync =
                                      r.watch(autoSyncValueProvider);
                                  final setter = r.read(autoSyncSetterProvider);
                                  final value = autoSync.asData?.value ?? false;
                                  return SwitchListTile(
                                    title: const Text('自动同步账本'),
                                    subtitle: canUseCloud
                                        ? const Text('记账后自动上传到云端')
                                        : const Text('需登录后可开启'),
                                    value: canUseCloud ? value : false,
                                    onChanged: canUseCloud
                                        ? (v) async {
                                            await setter.set(v);
                                          }
                                        : null,
                                  );
                                }),
                              ],
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 分组：导入/导出
                const SizedBox(height: 8),
                SectionCard(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: Column(
                    children: [
                      // 将导入状态融合到“导入”这一行，不再新增额外行
                      Consumer(builder: (ctx, r, _) {
                        final p = r.watch(importProgressProvider);
                        // 默认：正常“导入”入口
                        if (!p.running && p.total == 0) {
                          return AppListTile(
                            leading: Icons.file_upload_outlined,
                            title: '导入',
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const ImportPage()),
                              );
                            },
                          );
                        }
                        // 运行中：在同一行展示进度
                        if (p.running) {
                          final percent = p.total == 0
                              ? null
                              : (p.done / p.total).clamp(0.0, 1.0);
                          return AppListTile(
                            leading: Icons.upload_outlined,
                            title: '后台导入中…',
                            subtitle:
                                '进度：${p.done}/${p.total}，成功 ${p.ok}，失败 ${p.fail}',
                            trailing: SizedBox(
                              width: 72,
                              child: LinearProgressIndicator(value: percent),
                            ),
                            onTap: null,
                          );
                        }
                        // 完成：短暂停留动画后会被清空，自动恢复为默认“导入”
                        final allOk = (p.done == p.total) && (p.fail == 0);
                        if (allOk) {
                          return const _ImportSuccessTile();
                        }
                        // 有失败时的完成摘要
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
                            MaterialPageRoute(
                                builder: (_) => const ExportPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // 分组：个性化
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

                // 分组：关于与版本
                const SizedBox(height: 8),
                SectionCard(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: Column(
                    children: [
                      AppListTile(
                        leading: Icons.info_outline,
                        title: '关于',
                        onTap: () async {
                          final info = await _getAppInfo();
                          final msg =
                              '应用：蜜蜂记账\n版本：${info.version} (${info.buildNumber})\n开源地址：https://github.com/TNT-Likely/BeeCount\n开源协议：详见仓库 LICENSE';
                          final open = await AppDialog.confirm<bool>(
                                context,
                                title: '关于',
                                message: msg,
                                okLabel: '打开 GitHub',
                                cancelLabel: '关闭',
                              ) ??
                              false;
                          if (open) {
                            final url = Uri.parse(
                                'https://github.com/TNT-Likely/BeeCount');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                      ),
                      AppDivider.thin(),
                      AppListTile(
                        leading: Icons.system_update_alt_outlined,
                        title: '检测更新',
                        onTap: () async {
                          await _checkUpdate(context);
                        },
                      ),
                    ],
                  ),
                ),

                // 分组：调试工具（仅开发环境可见）
                if (!const bool.fromEnvironment('dart.vm.product')) ...[
                  const SizedBox(height: 8),
                  SectionCard(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Column(
                      children: [
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
                            ref
                                .read(syncStatusRefreshProvider.notifier)
                                .state++;
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppDimens.p16),
              ],
            ),
          ),
        ],
      ),
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
        const SizedBox(height: 2),
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
  final version = ciVersion.isNotEmpty 
      ? ciVersion 
      : 'dev-${p.version}'; // 本地开发版本标识
      
  return _AppInfo(version, p.buildNumber,
      commit: commit.isEmpty ? null : commit,
      buildTime: buildTime.isEmpty ? null : buildTime);
}

Future<void> _checkUpdate(BuildContext context) async {
  try {
    // 获取最新 release 信息
    final resp = await http.get(
      Uri.parse(
          'https://api.github.com/repos/TNT-Likely/BeeCount/releases/latest'),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'BeeCount-App',
      },
    ).timeout(const Duration(seconds: 8));
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

      // 弹窗提示最新版本与更新说明（截断过长文案）
      final previewBody =
          (body.length > 400) ? ('${body.substring(0, 400)}...') : body;
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
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
      }
      // 回退：打开 Releases 页面
      final fall = Uri.parse('https://github.com/TNT-Likely/BeeCount/releases');
      if (await canLaunchUrl(fall)) {
        await launchUrl(fall, mode: LaunchMode.externalApplication);
        return;
      }
    } else {
      // API 失败：提示并引导前往 Releases
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
        if (await canLaunchUrl(fall)) {
          await launchUrl(fall, mode: LaunchMode.externalApplication);
          return;
        }
      }
    }
  } catch (e) {
    // 异常：同样给出提示
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
      if (await canLaunchUrl(fall)) {
        await launchUrl(fall, mode: LaunchMode.externalApplication);
        return;
      }
    }
  }
  // 用户取消或无法打开浏览器：不再弹窗
  return;
}
