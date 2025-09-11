import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../data/repository.dart';
import '../widgets/ui/ui.dart';
import 'package:drift/drift.dart' as d;

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});
  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  bool exporting = false;
  double progress = 0;
  String? savedPath;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    return Scaffold(
      body: Column(
        children: [
          const PrimaryHeader(title: '导出', showBack: true),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('点击下方按钮选择保存位置，开始导出当前账本为 CSV 文件。'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: exporting ? null : () => _export(repo, ledgerId),
                    icon: const Icon(Icons.save_alt_outlined),
                    label: Text(Platform.isIOS ? '导出并分享 (iOS)' : '选择文件夹并导出'),
                  ),
                  const SizedBox(height: 16),
                  if (exporting)
                    Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                              value: progress == 0 ? null : progress),
                        ),
                      ],
                    ),
                  if (savedPath != null) ...[
                    const SizedBox(height: 12),
                    Text('已保存到：$savedPath'),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _export(BeeRepository repo, int ledgerId) async {
    try {
      setState(() {
        exporting = true;
        progress = 0;
        savedPath = null;
      });
      String? directory;
      bool shareAfter = false;
      if (Platform.isIOS) {
        // iOS: 写入应用文档目录，然后使用系统分享，不使用 getDirectoryPath（iOS 不支持）
        final docDir = await getApplicationDocumentsDirectory();
        directory = docDir.path;
        shareAfter = true;
      } else {
        directory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: '选择导出文件夹',
        );
        if (directory == null) {
          setState(() => exporting = false);
          return;
        }
      }

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
      final total = rowsJoin.length;
      final rows = <List<dynamic>>[];
      rows.add(['时间', '类型', '分类', '金额', '备注']);
      for (int i = 0; i < rowsJoin.length; i++) {
        final r = rowsJoin[i];
        final t = r.readTable(repo.db.transactions);
        final c = r.readTableOrNull(repo.db.categories);
        final timeStr =
            DateFormat('yyyy-MM-dd HH:mm').format(t.happenedAt.toLocal());
        rows.add([
          timeStr,
          t.type,
          c?.name ?? '',
          t.amount.toStringAsFixed(2),
          t.note ?? ''
        ]);
        if (i % 50 == 0) {
          setState(() => progress = (i + 1) / (total == 0 ? 1 : total));
        }
      }

      final csvStr = const ListToCsvConverter(eol: '\n').convert(rows);
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = p.join(directory, 'beecount_$ts.csv');
      await File(path).writeAsString(csvStr);
      setState(() {
        savedPath = path;
        exporting = false;
        progress = 1;
      });
      if (!mounted) return;
      if (shareAfter) {
        // 触发分享面板
        await Share.shareXFiles([XFile(path)], text: 'BeeCount 导出文件');
        await AppDialog.info(context,
            title: '导出成功', message: '已保存并可在分享历史中找到：\n$path');
      } else {
        await AppDialog.info(context, title: '导出成功', message: '已保存到：\n$path');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => exporting = false);
      await AppDialog.error(context, title: '导出失败', message: '$e');
    }
  }
}
