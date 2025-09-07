import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'import_page.dart';
import 'personalize_page.dart';
import '../providers.dart';
import '../widgets/primary_header.dart';
import 'ledgers_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);

    Future<void> exportCsv() async {
      try {
        final joined =
            await repo.transactionsWithCategoryAll(ledgerId: ledgerId).first;
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
        final dir = await getApplicationDocumentsDirectory();
        final exportDir = Directory(p.join(dir.path, 'exports'));
        if (!await exportDir.exists()) {
          await exportDir.create(recursive: true);
        }
        final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final file = File(p.join(exportDir.path, 'beecount_$ts.csv'));
        await file.writeAsString(csv);
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导出完成'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('文件已保存到：'),
                const SizedBox(height: 8),
                SelectableText(file.path,
                    style: Theme.of(ctx).textTheme.bodySmall),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: file.path));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制路径')),
                  );
                },
                child: const Text('复制路径'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('好的'),
              )
            ],
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    }

    return Scaffold(
      body: ListView(
        children: [
          // 顶部大卡片样式
          PrimaryHeader(
            showBack: false,
            title: '',
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FutureBuilder<
                        ({int ledgerCount, int dayCount, int txCount})>(
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
                            ?.copyWith(color: Colors.black54);
                        final numStyle = Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('我的',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Row(
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
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 快捷入口（与截图风格类似，保留少量常用项）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _QuickIcon(
                    title: '我的账本',
                    icon: Icons.menu_book_outlined,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LedgersPage()),
                      );
                    }),
                _QuickIcon(
                    title: '个性化',
                    icon: Icons.brush_outlined,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PersonalizePage()),
                      );
                    }),
                _QuickIcon(
                    title: '导入',
                    icon: Icons.file_upload_outlined,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ImportPage()),
                      );
                    }),
                _QuickIcon(
                    title: '导出',
                    icon: Icons.file_download_outlined,
                    onTap: exportCsv),
              ],
            ),
          ),

          // 分组：工具
          const SizedBox(height: 8),
          _GroupCard(children: [
            ListTile(
              leading: const Icon(Icons.today_outlined),
              title: const Text('跳转到本月'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final now = DateTime.now();
                ref.read(selectedMonthProvider.notifier).state =
                    DateTime(now.year, now.month, 1);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('导入账单（CSV 文件/粘贴）'),
              subtitle: const Text('日期,类型,金额,备注'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ImportPage()),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('导出账单到本地文件（CSV）'),
              trailing: const Icon(Icons.chevron_right),
              onTap: exportCsv,
            ),
          ]),

          const SizedBox(height: 8),
          _GroupCard(children: const [
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('关于'),
              subtitle: Text('版本与开源协议'),
              trailing: Icon(Icons.chevron_right),
            ),
          ]),
          const SizedBox(height: 12),
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

class _QuickIcon extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickIcon(
      {required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Icon(icon, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(title, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(children: children),
    );
  }
}
