import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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
// 快捷入口已移除，不再需要跳转到账本页
import '../widgets/common.dart';
import '../styles/design.dart';
import '../styles/colors.dart';
import '../cloud/auth.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final auth = ref.watch(authServiceProvider);
    final sync = ref.watch(syncServiceProvider);
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
          // 导出全部：收入 + 支出
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

        // 选择保存地址，若取消则保存到应用文档目录下的 exports
        final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        String? targetPath;
        try {
          targetPath = await FilePicker.platform.saveFile(
            dialogTitle: '保存导出的 CSV',
            fileName: 'beecount_expense_$ts.csv',
            type: FileType.custom,
            allowedExtensions: ['csv'],
          );
        } catch (_) {
          // 某些平台不支持 saveFile
          targetPath = null;
        }
        if (targetPath == null || targetPath.isEmpty) {
          try {
            final dirPath = await FilePicker.platform.getDirectoryPath(
              dialogTitle: '选择保存文件夹',
            );
            if (dirPath != null && dirPath.isNotEmpty) {
              targetPath = p.join(dirPath, 'beecount_expense_$ts.csv');
            }
          } catch (_) {
            // ignore and fallback
          }
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
          // 写入失败则落到应用文档目录
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
          // 顶部：上行头像+名字，下一行统计信息
          PrimaryHeader(
            showBack: false,
            title: '',
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: BeeColors.primaryText),
                      ),
                      const SizedBox(width: 12),
                      Text('我的',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color: BeeColors.primaryText,
                                  fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                        children: [
                          _StatCell(
                              label: '账本',
                              value: data.ledgerCount.toString(),
                              labelStyle: labelStyle,
                              numStyle: numStyle),
                          const SizedBox(width: 24),
                          _StatCell(
                              label: '记账天数',
                              value: data.dayCount.toString(),
                              labelStyle: labelStyle,
                              numStyle: numStyle),
                          const SizedBox(width: 24),
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

          // 分组：工具
          const SizedBox(height: 8),
          SectionCard(
            child: Column(
              children: [
                // 登录/注册/同步
                StreamBuilder<AuthUser?>(
                  stream: authUserStream,
                  builder: (ctx, snap) {
                    final user = snap.data;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppListTile(
                          leading: user == null
                              ? Icons.login
                              : Icons.verified_user_outlined,
                          title: user == null
                              ? '登录 / 注册（用于云同步）'
                              : (user.email ?? '已登录'),
                          subtitle:
                              user == null ? '不登录也可使用，仅在同步时需要' : '点击可退出登录',
                          onTap: () async {
                            if (user == null) {
                              await _showAuthSheet(context, auth);
                            } else {
                              await auth.signOut();
                            }
                          },
                        ),
                        AppDivider.thin(),
                        AppListTile(
                          leading: Icons.cloud_upload_outlined,
                          title: '上传当前账本到云端',
                          subtitle: '需登录后使用',
                          onTap: () async {
                            try {
                              await sync.uploadCurrentLedger(
                                  ledgerId: ledgerId);
                              await _showNiceDialog(context,
                                  title: '上传完成',
                                  message: '已将当前账本上传到云端',
                                  success: true);
                            } catch (e) {
                              await _showNiceDialog(context,
                                  title: '失败', message: '$e', success: false);
                            }
                          },
                        ),
                        AppDivider.thin(),
                        AppListTile(
                          leading: Icons.cloud_download_outlined,
                          title: '从云端下载并合并到当前账本',
                          subtitle: '需登录后使用',
                          onTap: () async {
                            try {
                              final count =
                                  await sync.downloadAndRestoreToCurrentLedger(
                                      ledgerId: ledgerId);
                              await _showNiceDialog(context,
                                  title: '下载完成',
                                  message: '导入 $count 条记录',
                                  success: true);
                            } catch (e) {
                              await _showNiceDialog(context,
                                  title: '失败', message: '$e', success: false);
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
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
                AppDivider.thin(),
                AppListTile(
                  leading: Icons.brush_outlined,
                  title: '个性化',
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
          const SizedBox(height: AppDimens.p16),
        ],
      ),
    );
  }
}

Future<void> _showAuthSheet(BuildContext context, AuthService auth) async {
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
