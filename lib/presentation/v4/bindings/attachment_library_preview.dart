import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/settings/attachment_preview_page.dart';
import '../../../services/attachment_export_import_service.dart';
import 'attachment_library_data.dart';
import 'file_workflow_preview.dart';

class LiveAttachmentLibraryPreview extends ConsumerWidget {
  const LiveAttachmentLibraryPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(attachmentWorkflowFilesProvider).when(
          data: (files) => _LibraryPreview(files: files),
          loading: () => const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator())),
          error: (error, stack) => BeeStatus(
              label: '读取图片失败',
              tone: BeeTone.error,
              action: TextButton(
                  onPressed: () =>
                      ref.invalidate(attachmentWorkflowFilesProvider),
                  child: const Text('重试'))));
}

class _LibraryPreview extends StatefulWidget {
  const _LibraryPreview({required this.files});
  final ExportPreviewData files;
  @override
  State<_LibraryPreview> createState() => _LibraryPreviewState();
}

class _LibraryPreviewState extends State<_LibraryPreview> {
  late AttachmentLibraryData data =
      AttachmentLibraryData(exportData: widget.files);
  int group = 0;
  String? selected;
  @override
  void didUpdateWidget(covariant _LibraryPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.files != widget.files) {
      data = AttachmentLibraryData(exportData: widget.files);
      selected = null;
    }
  }

  Future<void> open(int index) async {
    setState(() => selected = data.items(group)[index].id);
    await showAttachmentLibraryItem(context, data, group, index);
    if (mounted) setState(() => selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('真实附件与图标（只读，可放大预览）'),
      const SizedBox(height: 8),
      BeeSegmented<int>(items: [
        BeeSegment(
            0, '${l.v4DataAttachments} (${widget.files.attachments.length})'),
        BeeSegment(1, '${l.v4CustomIcons} (${widget.files.customIcons.length})')
      ], value: group, onChanged: (v) => setState(() => group = v)),
      SizedBox(
          height: 240,
          child: BeeAttachmentLibrary(
              items: data.items(group),
              emptyLabel: l.attachmentPreviewEmpty,
              onOpen: open,
              selectedId: selected,
              metadataBuilder: (index) => data.metadata(group, index))),
      BeeButton(
          label: '打开真实导出预览',
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => AttachmentPreviewPage(
                      exportData: widget.files,
                      title: l.attachmentExportPreviewTitle))))
    ]);
  }
}
