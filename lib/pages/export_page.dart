import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
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
          PrimaryHeader(title: AppLocalizations.of(context)!.exportTitle, showBack: true),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.exportDescription),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: exporting ? null : () => _export(repo, ledgerId),
                    icon: const Icon(Icons.save_alt_outlined),
                    label: Text(Platform.isIOS ? AppLocalizations.of(context)!.exportButtonIOS : AppLocalizations.of(context)!.exportButtonAndroid),
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
                    Text(AppLocalizations.of(context)!.exportSavedTo(savedPath!)),
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
          dialogTitle: AppLocalizations.of(context)!.exportSelectFolder,
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
      rows.add([AppLocalizations.of(context)!.exportCsvHeaders]);
      for (int i = 0; i < rowsJoin.length; i++) {
        final r = rowsJoin[i];
        final t = r.readTable(repo.db.transactions);
        final c = r.readTableOrNull(repo.db.categories);
        // 使用完整的时间格式，包含年份和秒，添加前导空格增加列宽
        final timeStr = t.happenedAt != null
            ? () {
                try {
                  final localTime = t.happenedAt.toLocal();
                  // 完整时间格式: YYYY-MM-DD HH:mm:ss，前面添加空格增加列宽
                  return '  ${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}:${localTime.second.toString().padLeft(2, '0')}  ';
                } catch (e) {
                  return '';
                }
              }()
            : '';
        final typeStr = _getTypeDisplayName(t.type);
        rows.add([
          typeStr,
          c?.name ?? '',
          t.amount.toStringAsFixed(2),
          t.note ?? '',
          timeStr
        ]);
        if (i % 50 == 0) {
          setState(() => progress = (i + 1) / (total == 0 ? 1 : total));
        }
      }

      final csvStr = const ListToCsvConverter(eol: '\n').convert(rows);
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = p.join(directory, 'beecount_$ts.csv');
      
      // 添加UTF-8 BOM标记，确保Excel正确识别中文编码
      const utf8Bom = '\uFEFF';
      await File(path).writeAsString(utf8Bom + csvStr, encoding: Encoding.getByName('utf-8')!);
      setState(() {
        savedPath = path;
        exporting = false;
        progress = 1;
      });
      if (!mounted) return;
      if (shareAfter) {
        // 触发分享面板
        await Share.shareXFiles([XFile(path)], text: AppLocalizations.of(context)!.exportShareText);
        await AppDialog.info(context,
            title: AppLocalizations.of(context)!.exportSuccessTitle, message: AppLocalizations.of(context)!.exportSuccessMessageIOS(path));
      } else {
        await AppDialog.info(context, title: AppLocalizations.of(context)!.exportSuccessTitle, message: AppLocalizations.of(context)!.exportSuccessMessageAndroid(path));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => exporting = false);
      await AppDialog.error(context, title: AppLocalizations.of(context)!.exportFailedTitle, message: e.toString());
    }
  }

  /// 将英文类型转换为中文显示名称
  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'income':
        return AppLocalizations.of(context)!.exportTypeIncome;
      case 'expense':
        return AppLocalizations.of(context)!.exportTypeExpense;
      case 'transfer':
        return AppLocalizations.of(context)!.exportTypeTransfer;
      default:
        return type; // 兜底返回原始值
    }
  }
}
