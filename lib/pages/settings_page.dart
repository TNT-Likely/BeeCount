import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';

import 'import_page.dart';
import 'personalize_page.dart';
import '../providers.dart';
import '../widgets/primary_header.dart';
import '../widgets/common.dart';
import '../styles/design.dart';
import '../styles/colors.dart';
import '../cloud/auth.dart';
import '../cloud/sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final auth = ref.watch(authServiceProvider);
    final sync = ref.watch(syncServiceProvider);
    final refreshTick = ref.watch(syncStatusRefreshProvider);
    final authUserStream = auth.authStateChanges();

    Future<void> exportCsv() async {
      try {
        final joined =
            await repo.transactionsWithCategoryAll(ledgerId: ledgerId).first;
        if (joined.isEmpty) {
          await _showNiceDialog(context,
              title: '没有数据', message: '当前账本还没有任何记账，无法导出。', success: false);
          return;
        }
        final rows = <List<dynamic>>[];
        rows.add(['日期', '类型', '金额', '分类', '备注']);
        final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
        for (final r in joined) {
          final t = r.t;
          final cat = r.category?.name ?? '未分类';
          rows.add([
            fmt.format(t.happenedAt.toLocal()),
            t.type,
            t.amount,
            cat,
            t.note ?? ''
          ]);
        }
        final csv = const ListToCsvConverter(eol: '\n').convert(rows);
        final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

        String? targetPath;
        try {
          targetPath = await FilePicker.platform.saveFile(
            dialogTitle: '保存导出的 CSV',
            fileName: 'beecount_expense_$ts.csv',
            type: FileType.custom,
            allowedExtensions: ['csv'],
          );
        } catch (_) {}

        if (targetPath == null || targetPath.isEmpty) {
          try {
            final dirPath = await FilePicker.platform.getDirectoryPath(
              dialogTitle: '选择保存文件夹',
            );
            if (dirPath != null && dirPath.isNotEmpty) {
              targetPath = p.join(dirPath, 'beecount_expense_$ts.csv');
            }
          } catch (_) {}
        }

        if (targetPath == null || targetPath.isEmpty) {
          final dir = await getApplicationDocumentsDirectory();
          final exportDir = Directory(p.join(dir.path, 'exports'));
          if (!await exportDir.exists()) {
            await exportDir.create(recursive: true);
          }
          targetPath = p.join(exportDir.path, 'beecount_expense_$ts.csv');
        }

        final file = File(targetPath);
        try {
          await file.writeAsString(csv);
        } catch (e) {
          final dir = await getApplicationDocumentsDirectory();
          final fallback =
              File(p.join(dir.path, 'exports', 'beecount_expense_$ts.csv'))
                ..createSync(recursive: true);
          await fallback.writeAsString(csv);
          await _showNiceDialog(context,
              title: '部分受限',
              message: '所选位置不可写，已改为保存到:\n${fallback.path}',
              success: false,
              copyText: fallback.path);
          return;
        }
        await _showNiceDialog(context,
            title: '导出完成',
            message: file.path,
            success: true,
            copyText: file.path);
      } catch (e) {
        await _showNiceDialog(context,
            title: '导出失败', message: '$e', success: false);
      }
    }

    return Scaffold(
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
                      final ledgers =
                          await ref.read(repositoryProvider).ledgers().first;
                      final list = await repo
                          .transactionsWithCategoryAll(ledgerId: ledgerId)
                          .first;
                      final days = <String>{};
                      for (final r in list) {
                        final d = r.t.happenedAt.toLocal();
                        days.add('${d.year}-${d.month}-${d.day}');
                      }
                      return (
                        ledgerCount: ledgers.length,
                        dayCount: days.length,
                        txCount: list.length,
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
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                        bool busy = false;
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
                                  lines.add('云端最新记账时间: ${st2.cloudExportedAt}');
                                }
                                lines.add('本地指纹: ${st2.localFingerprint}');
                                if (st2.cloudFingerprint != null) {
                                  lines.add('云端指纹: ${st2.cloudFingerprint}');
                                }
                                if (st2.message != null) {
                                  lines.add('说明: ${st2.message}');
                                }
                                await _showNiceDialog(context,
                                    title: '同步状态详情',
                                    message: lines.join('\n'),
                                    success: st2.diff == SyncDiff.inSync);
                                ref
                                    .read(syncStatusRefreshProvider.notifier)
                                    .state++;
                              },
                            ),
                            AppDivider.thin(),
                            StatefulBuilder(builder: (ctx, setState) {
                              // ignore: dead_code
                              return AppListTile(
                                leading: Icons.cloud_upload_outlined,
                                title: busy ? '正在上传…' : '上传',
                                subtitle: canUseCloud
                                    ? (inSync ? '已同步' : null)
                                    : '需登录',
                                enabled: canUseCloud && !inSync && !busy,
                                onTap: () async {
                                  setState(() => busy = true);
                                  try {
                                    await sync.uploadCurrentLedger(
                                        ledgerId: ledgerId);
                                    await _showNiceDialog(context,
                                        title: '已上传',
                                        message: '当前账本已同步到云端',
                                        success: true);
                                    ref
                                        .read(
                                            syncStatusRefreshProvider.notifier)
                                        .state++;
                                  } catch (e) {
                                    await _showNiceDialog(context,
                                        title: '失败',
                                        message: '$e',
                                        success: false);
                                  } finally {
                                    if (ctx.mounted)
                                      setState(() => busy = false);
                                  }
                                },
                              );
                            }),
                            AppDivider.thin(),
                            StatefulBuilder(builder: (ctx, setState) {
                              bool busy2 = false;
                              return AppListTile(
                                leading: Icons.cloud_download_outlined,
                                title: busy2 ? '正在下载…' : '下载',
                                subtitle: canUseCloud
                                    ? (inSync ? '已同步' : null)
                                    : '需登录',
                                enabled: canUseCloud && !inSync && !busy2,
                                onTap: () async {
                                  setState(() => busy2 = true);
                                  try {
                                    final count = await sync
                                        .downloadAndRestoreToCurrentLedger(
                                            ledgerId: ledgerId);
                                    await _showNiceDialog(context,
                                        title: '已下载',
                                        message: '导入 $count 条记录',
                                        success: true);
                                    ref
                                        .read(
                                            syncStatusRefreshProvider.notifier)
                                        .state++;
                                  } catch (e) {
                                    await _showNiceDialog(context,
                                        title: '失败',
                                        message: '$e',
                                        success: false);
                                  } finally {
                                    if (ctx.mounted)
                                      setState(() => busy2 = false);
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
                  title: '导出账单',
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
                        _showToast(context, '登录失败：$e');
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
                        _showToast(context, '注册失败：$e');
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

// 已移除底部快捷入口行

// 旧 GroupCard 已替换为 SectionCard

Future<void> _showNiceDialog(BuildContext context,
    {required String title,
    required String message,
    required bool success,
    String? copyText}) async {
  final color = success ? Colors.green : Colors.red;
  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: Icon(
                    success ? Icons.check_circle : Icons.error_outline,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          color: Colors.black87, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(message,
                style:
                    Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.3)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (copyText != null)
                  TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: copyText));
                        Navigator.pop(ctx);
                      },
                      child: const Text('复制')),
                const SizedBox(width: 4),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('确定')),
              ],
            )
          ],
        ),
      ),
    ),
  );
}

void _showToast(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 2)}) {
  // 使用根 Overlay，确保在所有弹窗（Dialog/BottomSheet）之上显示
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (ctx) => IgnorePointer(
      ignoring: true,
      child: Positioned.fill(
        child: SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(duration, () {
    entry.remove();
  });
}
