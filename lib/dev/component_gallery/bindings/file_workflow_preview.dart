import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../pages/settings/data_management_page.dart';
import '../../../providers/import_export_providers.dart';
import '../../../services/attachment_export_import_service.dart';

final attachmentWorkflowFilesProvider =
    FutureProvider.autoDispose<ExportPreviewData>((ref) => ref
        .watch(attachmentExportImportServiceProvider)
        .getExportPreviewImages());

/// Reads the actual import progress and original service file scan; no writes.
class LiveFileWorkflowPreview extends ConsumerWidget {
  const LiveFileWorkflowPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(importProgressProvider),
        files = ref.watch(attachmentWorkflowFilesProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实文件与导入任务（只读）'),
      const SizedBox(height: 8),
      files.when(
          data: (f) => Text(
              '真实文件 · ${f.attachments.length} 附件 / ${f.customIcons.length} 分类图标'),
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => const Text('读取文件失败，可重新扫描')),
      Text(
          '真实导入任务 · ${progress.done}/${progress.total} · ${progress.ok} 成功 / ${progress.fail} 失败'),
      TextButton(
          onPressed: () => ref.invalidate(attachmentWorkflowFilesProvider),
          child: const Text('重新扫描真实文件')),
      BeeButton(
          label: '打开真实数据管理',
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const DataManagementPage())))
    ]);
  }
}
