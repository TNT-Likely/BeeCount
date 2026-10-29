import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import '../../../../services/attachment_export_import_service.dart';
import '../../../../utils/image_file_info.dart';

/// Original file/header readers and cache; neither export data nor bytes mutate.
class AttachmentLibraryData {
  AttachmentLibraryData({this.exportData, this.archiveData})
      : assert((exportData != null) != (archiveData != null));
  final ExportPreviewData? exportData;
  final ArchivePreviewData? archiveData;
  final Map<String, Future<ImageFileInfo>> _info = {};
  List<BeeAttachment> items(int group) {
    if (exportData != null) {
      final files =
          group == 0 ? exportData!.attachments : exportData!.customIcons;
      return [
        for (var i = 0; i < files.length; i++)
          BeeAttachment(
              id: '$group:$i',
              image: FileImage(files[i]),
              label: files[i].path.split('/').last,
              info: '')
      ];
    }
    final files =
        group == 0 ? archiveData!.attachments : archiveData!.customIcons;
    return [
      for (var i = 0; i < files.length; i++)
        BeeAttachment(
            id: '$group:$i',
            image: MemoryImage(files[i].bytes),
            label: files[i].fileName,
            info: '')
    ];
  }

  Future<ImageFileInfo> info(int group, int index) {
    if (exportData != null) {
      final File file = (group == 0
          ? exportData!.attachments
          : exportData!.customIcons)[index];
      return _info.putIfAbsent(file.path, () => ImageFileInfo.fromFile(file));
    }
    final item = (group == 0
        ? archiveData!.attachments
        : archiveData!.customIcons)[index];
    return _info.putIfAbsent(
        'archive:$group:$index', () => ImageFileInfo.fromBytes(item.bytes));
  }

  Widget metadata(int group, int index, {bool badge = true}) =>
      FutureBuilder<ImageFileInfo>(
          future: info(group, index),
          builder: (context, snapshot) => BeeAttachmentFileMetadata(
              badge: badge,
              fileName: badge ? null : items(group)[index].label,
              sizeText:
                  snapshot.hasData ? formatSize(snapshot.data!.fileSize) : '',
              dimensionsText:
                  snapshot.data?.width != null && snapshot.data?.height != null
                      ? '${snapshot.data!.width} × ${snapshot.data!.height}'
                      : null));
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

Future<void> showAttachmentLibraryItem(
    BuildContext context, AttachmentLibraryData data, int group, int index) {
  final item = data.items(group)[index];
  return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialog) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.black,
          child: SizedBox(
              height: MediaQuery.sizeOf(dialog).height * .85,
              width: double.infinity,
              child: BeeAttachmentViewer(
                  items: [item],
                  showHeaderLabel: false,
                  fullScreen: true,
                  maxScale: 2.5,
                  onClose: () => Navigator.pop(dialog),
                  metadataBuilder: (_) =>
                      data.metadata(group, index, badge: false)))));
}
