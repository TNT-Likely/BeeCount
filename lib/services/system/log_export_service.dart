import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'logger_service.dart';

/// Capture the text of live exceptions and stacks once for preview and export.
class LogExportSnapshot {
  LogExportSnapshot._(this.count, this.file);

  final int count;
  final LogExportFile file;

  static Future<LogExportSnapshot> capture(LoggerService logger) async {
    final entries = await logger.snapshotForExport();
    final capturedAt = DateTime.now();
    final stamp = capturedAt.toUtc().toIso8601String().replaceAll(':', '-');
    return LogExportSnapshot._(
      entries.length,
      LogExportFile._(
        'BeeCount-logs-$stamp.txt',
        LoggerService.formatExport(entries, capturedAt, includeDates: true),
      ),
    );
  }
}

class LogExportFile {
  LogExportFile._(this.fileName, this.text);

  final String fileName;
  final String text;
  late final Uint8List bytes = utf8.encode(text).asUnmodifiableView();
}

class LogExportPlatform {
  const LogExportPlatform({
    Future<Directory> Function() temporaryDirectory = getTemporaryDirectory,
  }) : _temporaryDirectory = temporaryDirectory;

  final Future<Directory> Function() _temporaryDirectory;

  Future<ShareResultStatus> share(
    LogExportFile file, {
    required Rect origin,
    required String subject,
  }) async {
    if (!origin.isFinite ||
        origin.isEmpty ||
        origin.left < 0 ||
        origin.top < 0) {
      throw ArgumentError.value(origin, 'origin', 'Invalid share anchor');
    }
    final directory =
        await (await _temporaryDirectory()).createTemp('beecount-logs-');
    try {
      final attachment = File(p.join(directory.path, file.fileName));
      await attachment.writeAsBytes(file.bytes, flush: true);
      final result = await SharePlus.instance.share(ShareParams(
        files: [XFile(attachment.path, mimeType: 'text/plain')],
        subject: subject,
        sharePositionOrigin: origin,
      ));
      return result.status;
    } finally {
      // Android makes its own share-provider copy. iOS reads this file until
      // the activity completes. Keep the source available throughout that call.
      try {
        await directory.delete(recursive: true);
      } on FileSystemException {
        // Cache eviction may already have removed it. Preserve the share result.
      }
    }
  }

  Future<bool> save(LogExportFile file, {String? dialogTitle}) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: file.fileName,
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      bytes: file.bytes,
    );
    return path != null && path.isNotEmpty;
  }
}
