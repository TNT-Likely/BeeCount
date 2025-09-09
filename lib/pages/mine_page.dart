import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final auth = ref.watch(authServiceProvider);
    final sync = ref.watch(syncServiceProvider);
    // note: refresh tick is handled inside provider; no local watch needed here
    final authUserStream = auth.authStateChanges();

    // 导出功能已迁移到 ExportPage

    return Scaffold(
      backgroundColor: BeeColors.greyBg,
      body: ListView(
        children: [
          // 顶部：居中标题 + 统计（无头像）
          PrimaryHeader(
            showBack: false,
            title: '我的',
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 6),
                  Builder(builder: (ctx) {
                    final lCount = ref.watch(ledgerCountProvider);
                    // 顶部统计改为全应用聚合：使用异步值或回退到缓存，避免刷新时闪烁
                    final countsAsync = ref.watch(countsAllProvider);
                    final countsCached = ref.watch(lastCountsAllProvider);
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
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatCell(
                            label: '账本',
                            value: data.ledgerCount.toString(),
                            labelStyle: labelStyle,
                            numStyle: numStyle),
                        _StatCell(
                            label: '记账天数',
                            value: data.dayCount.toString(),
                            labelStyle: labelStyle,
                            numStyle: numStyle),
                        _StatCell(
                            label: '总笔数',
                            value: data.txCount.toString(),
                            labelStyle: labelStyle,
                            numStyle: numStyle),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),

          // 分组：同步
          const SizedBox(height: 8),
          SectionCard(
            child: Column(
              children: [
                StreamBuilder<AuthUser?>(
                  stream: authUserStream,
                  builder: (ctx, snap) {
                    final user = snap.data;
                    final canUseCloud = user != null;
                    final asyncSt = ref.watch(syncStatusProvider(ledgerId));
                    final cached = ref.watch(lastSyncStatusProvider(ledgerId));
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
                                          child: CircularProgressIndicator(
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
                                          final st2 = await sync.getStatus(
                                              ledgerId: ledgerId);
                                          final lines = <String>[];
                                          lines.add('本地记录数: ${st2.localCount}');
                                          if (st2.cloudCount != null) {
                                            lines.add(
                                                '云端记录数: ${st2.cloudCount}');
                                          }
                                          if (st2.cloudExportedAt != null) {
                                            final cloudTime =
                                                st2.cloudExportedAt!;
                                            final cloudTimeStr = DateFormat(
                                                    'yyyy-MM-dd HH:mm:ss')
                                                .format(cloudTime.toLocal());
                                            lines
                                                .add('云端最新记账时间: $cloudTimeStr');
                                          }
                                          lines.add(
                                              '本地指纹: ${st2.localFingerprint}');
                                          if (st2.cloudFingerprint != null) {
                                            lines.add(
                                                '云端指纹: ${st2.cloudFingerprint}');
                                          }
                                          if (st2.message != null) {
                                            lines.add('说明: ${st2.message}');
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
                                                  : (inSync ? '已同步' : null)),
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
                                              strokeWidth: 2),
                                        )
                                      : null,
                                  onTap: () async {
                                    setSB(() => uploadBusy = true);
                                    try {
                                      await sync.uploadCurrentLedger(
                                          ledgerId: ledgerId);
                                      await AppDialog.info(context,
                                          title: '已上传', message: '当前账本已同步到云端');
                                      // 上传后先主动刷新云端指纹，若一致将直接更新缓存
                                      Future(() async {
                                        try {
                                          logI('sync/ui', '上传后开始刷新云端指纹');
                                          await sync.refreshCloudFingerprint(
                                              ledgerId: ledgerId);
                                        } catch (_) {}
                                      });
                                      // 然后在后台轮询一次远端，避免对象存储延迟导致仍显示“本地较新”
                                      Future(() async {
                                        const maxAttempts = 6; // 最长约 ~12s
                                        var delay =
                                            const Duration(milliseconds: 500);
                                        for (var i = 0; i < maxAttempts; i++) {
                                          try {
                                            // 注意：不要在此处调用 markLocalChanged，避免打断“上传后短窗”的 inSync 判断
                                          } catch (_) {}
                                          final stNow = await sync.getStatus(
                                              ledgerId: ledgerId);
                                          if (stNow.diff == SyncDiff.inSync) {
                                            // 立即更新缓存供 UI 显示
                                            ref
                                                .read(lastSyncStatusProvider(
                                                        ledgerId)
                                                    .notifier)
                                                .state = stNow;
                                            break;
                                          }
                                          if (i < maxAttempts - 1) {
                                            await Future.delayed(delay);
                                            delay *= 2; // 0.5s,1s,2s,4s,8s
                                          }
                                        }
                                        // 最终触发 Provider 刷新
                                        ref
                                            .read(syncStatusRefreshProvider
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
                                          child: CircularProgressIndicator(
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
                                        ..writeln('新增导入：${res.inserted} 条')
                                        ..writeln('已存在跳过：${res.skipped} 条')
                                        ..writeln('清理历史重复：${res.deletedDup} 条');
                                      await AppDialog.info(context,
                                          title: '完成', message: msg.toString());
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
                            subtitle: user == null ? '仅在同步时需要' : '点击可退出登录',
                            onTap: () async {
                              if (user == null) {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const LoginPage()),
                                );
                                ref
                                    .read(syncStatusRefreshProvider.notifier)
                                    .state++;
                              } else {
                                await auth.signOut();
                                ref
                                    .read(syncStatusRefreshProvider.notifier)
                                    .state++;
                              }
                            },
                          ),
                          AppDivider.thin(),
                          Consumer(builder: (ctx, r, _) {
                            final autoSync = r.watch(autoSyncValueProvider);
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
                          MaterialPageRoute(builder: (_) => const ImportPage()),
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
                      MaterialPageRoute(builder: (_) => const ExportPage()),
                    );
                  },
                ),
              ],
            ),
          ),

          // 分组：个性化
          const SizedBox(height: 8),
          SectionCard(
            child: AppListTile(
              leading: Icons.brush_outlined,
              title: '个性化',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PersonalizePage()),
                );
              },
            ),
          ),

          // 分组：调试工具（仅开发环境可见）
          if (!const bool.fromEnvironment('dart.vm.product')) ...[
            const SizedBox(height: 8),
            SectionCard(
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
                      ref.read(syncStatusRefreshProvider.notifier).state++;
                    },
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppDimens.p16),
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
