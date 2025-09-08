import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart' as d;

import 'import_page.dart';
import 'personalize_page.dart';
import '../providers.dart';
import '../widgets/ui/ui.dart';
import '../widgets/biz/biz.dart';
import '../styles/design.dart';
import '../styles/colors.dart';
import '../cloud/auth.dart';
import '../cloud/sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MinePage extends ConsumerWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final auth = ref.watch(authServiceProvider);
    final sync = ref.watch(syncServiceProvider);
    final refreshTick = ref.watch(syncStatusRefreshProvider);
    final authUserStream = auth.authStateChanges();

    // 导出 CSV（当前账本）
    Future<void> exportCsv() async {
      try {
        final q = (repo.db.select(repo.db.transactions)
              ..where((t) => t.ledgerId.equals(ledgerId))
              ..orderBy([
                (t) => d.OrderingTerm(
                    expression: t.happenedAt, mode: d.OrderingMode.desc)
              ]))
            .join([
          d.leftOuterJoin(repo.db.categories,
              repo.db.categories.id.equalsExp(repo.db.transactions.categoryId)),
        ]);
        final rowsJoin = await q.get();
        final rows = <List<dynamic>>[];
        rows.add(['时间', '类型', '分类', '金额', '备注']);
        for (final r in rowsJoin) {
          final t = r.readTable(repo.db.transactions);
          final c = r.readTableOrNull(repo.db.categories);
          final timeStr =
              DateFormat('yyyy-MM-dd HH:mm').format(t.happenedAt.toLocal());
          rows.add([
            timeStr,
            t.type,
            c?.name ?? '',
            t.amount.toStringAsFixed(2),
            t.note ?? '',
          ]);
        }
        final csvStr = const ListToCsvConverter(eol: '\n').convert(rows);
        final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        String? targetPath = await FilePicker.platform.saveFile(
          dialogTitle: '保存导出的 CSV',
          fileName: 'beecount_$ts.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
        if (targetPath == null) return; // 用户取消
        await File(targetPath).writeAsString(csvStr);
        await AppDialog.info(context,
            title: '导出成功', message: '已保存到：\n$targetPath');
      } catch (e) {
        await AppDialog.info(context, title: '导出失败', message: '$e');
      }
    }

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
                  FutureBuilder<({int ledgerCount, int dayCount, int txCount})>(
                    future: () async {
                      final lCount = await repo.ledgerCount();
                      final c = await repo.countsForLedger(ledgerId: ledgerId);
                      return (
                        ledgerCount: lCount,
                        dayCount: c.dayCount,
                        txCount: c.txCount,
                      );
                    }(),
                    builder: (ctx, snap) {
                      final data = snap.data ??
                          (ledgerCount: 1, dayCount: 0, txCount: 0);
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
                    },
                  ),
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
                    return FutureBuilder<SyncStatus>(
                      key: ValueKey(refreshTick),
                      future: sync.getStatus(ledgerId: ledgerId),
                      builder: (c, s) {
                        String subtitle = '';
                        IconData icon = Icons.sync_outlined;
                        bool inSync = false;
                        final st = s.data;
                        if (st != null) {
                          switch (st.diff) {
                            case SyncDiff.notLoggedIn:
                              subtitle = '未登录';
                              icon = Icons.lock_outline;
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
                        } else if (s.hasError) {
                          subtitle = '${s.error}';
                          icon = Icons.error_outline;
                        } else {
                          subtitle = '读取中…';
                        }

                        bool uploadBusy = false;
                        bool downloadBusy = false;

                        return Column(
                          children: [
                            AppListTile(
                              leading: icon,
                              title: '同步',
                              subtitle: subtitle,
                              onTap: () async {
                                final st2 =
                                    await sync.getStatus(ledgerId: ledgerId);
                                final lines = <String>[];
                                lines.add('本地记录数: ${st2.localCount}');
                                if (st2.cloudCount != null) {
                                  lines.add('云端记录数: ${st2.cloudCount}');
                                }
                                if (st2.cloudExportedAt != null) {
                                  final cloudTime = st2.cloudExportedAt;
                                  final cloudTimeStr = cloudTime != null
                                      ? DateFormat('yyyy-MM-dd HH:mm:ss')
                                          .format(cloudTime.toLocal())
                                      : '';
                                  lines.add('云端最新记账时间: $cloudTimeStr');
                                }
                                lines.add('本地指纹: ${st2.localFingerprint}');
                                if (st2.cloudFingerprint != null) {
                                  lines.add('云端指纹: ${st2.cloudFingerprint}');
                                }
                                if (st2.message != null) {
                                  lines.add('说明: ${st2.message}');
                                }
                                await AppDialog.info(
                                  context,
                                  title: '同步状态详情',
                                  message: lines.join('\n'),
                                );
                                ref
                                    .read(syncStatusRefreshProvider.notifier)
                                    .state++;
                              },
                            ),
                            AppDivider.thin(),
                            // 去除一键去重修复入口，避免误操作与死代码告警
                            // 同步相关操作保留“上传/下载/登录/自动同步”等
                            StatefulBuilder(builder: (ctx, setSB) {
                              return AppListTile(
                                leading: Icons.cloud_upload_outlined,
                                title: '上传',
                                subtitle: canUseCloud
                                    ? (inSync ? '已同步' : null)
                                    : '需登录',
                                enabled: canUseCloud && !inSync && !uploadBusy,
                                trailing: uploadBusy
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
                                    ref
                                        .read(
                                            syncStatusRefreshProvider.notifier)
                                        .state++;
                                  } catch (e) {
                                    await AppDialog.info(context,
                                        title: '失败', message: '$e');
                                  } finally {
                                    if (ctx.mounted)
                                      setSB(() => uploadBusy = false);
                                  }
                                },
                              );
                            }),
                            AppDivider.thin(),
                            StatefulBuilder(builder: (ctx, setSB) {
                              return AppListTile(
                                leading: Icons.cloud_download_outlined,
                                title: '下载',
                                subtitle: canUseCloud
                                    ? (inSync ? '已同步' : null)
                                    : '需登录',
                                enabled:
                                    canUseCloud && !inSync && !downloadBusy,
                                trailing: downloadBusy
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
                                        .read(
                                            syncStatusRefreshProvider.notifier)
                                        .state++;
                                  } catch (e) {
                                    await AppDialog.error(context,
                                        title: '失败', message: '$e');
                                  } finally {
                                    if (ctx.mounted)
                                      setSB(() => downloadBusy = false);
                                  }
                                },
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
                                  await _showAuthSheet(context, auth,
                                      onChanged: () {
                                    ref
                                        .read(
                                            syncStatusRefreshProvider.notifier)
                                        .state++;
                                  });
                                } else {
                                  await auth.signOut();
                                  ref
                                      .read(syncStatusRefreshProvider.notifier)
                                      .state++;
                                }
                              },
                            ),
                            AppDivider.thin(),
                            StatefulBuilder(builder: (ctx, setState) {
                              return FutureBuilder<bool>(
                                future: _getAutoSync(),
                                builder: (ctx2, snapAuto) {
                                  final value = snapAuto.data ?? false;
                                  return SwitchListTile(
                                    title: const Text('自动同步账本'),
                                    subtitle: const Text('记账后自动上传到云端'),
                                    value: value,
                                    onChanged: (v) async {
                                      await _setAutoSync(v);
                                      if (ctx.mounted) setState(() {});
                                    },
                                  );
                                },
                              );
                            }),
                          ],
                        );
                      },
                    );
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
                AppListTile(
                  leading: Icons.file_upload_outlined,
                  title: '导入',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ImportPage()),
                    );
                  },
                ),
                AppDivider.thin(),
                AppListTile(
                  leading: Icons.file_download_outlined,
                  title: '导出',
                  onTap: exportCsv,
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

          const SizedBox(height: AppDimens.p16),
        ],
      ),
    );
  }
}

Future<bool> _getAutoSync() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('auto_sync') ?? false;
}

Future<void> _setAutoSync(bool v) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('auto_sync', v);
}

Future<void> _showAuthSheet(BuildContext context, AuthService auth,
    {VoidCallback? onChanged}) async {
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('登录 / 注册',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '邮箱'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await auth.signInWithEmail(
                            email: emailCtrl.text.trim(),
                            password: pwdCtrl.text);
                        Navigator.pop(ctx);
                        onChanged?.call();
                      } catch (e, st) {
                        debugPrint('Login failed: $e\n$st');
                        showToast(context, '登录失败：$e');
                      }
                    },
                    child: const Text('登录'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await auth.signUpWithEmail(
                            email: emailCtrl.text.trim(),
                            password: pwdCtrl.text);
                        Navigator.pop(ctx);
                        onChanged?.call();
                      } catch (e, st) {
                        debugPrint('Signup failed: $e\n$st');
                        showToast(context, '注册失败：$e');
                      }
                    },
                    child: const Text('注册'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('提示：不登录也可以正常使用；仅在需要同步账本时登录。',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: BeeColors.black54)),
          ],
        ),
      );
    },
  );
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
