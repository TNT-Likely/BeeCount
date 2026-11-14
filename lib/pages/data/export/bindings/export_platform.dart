import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// App-owned boundary for the existing system save/share contract.
abstract interface class TransactionExportPlatform {
  bool get shareAfterSave;
  Future<String> exportDirectory();
  Future<void> writeCsv(String path, String csv);
  Future<void> shareCsv(String path, String text);
}

final transactionExportPlatformProvider = Provider<TransactionExportPlatform>(
    (ref) => const SystemTransactionExportPlatform());

class SystemTransactionExportPlatform implements TransactionExportPlatform {
  const SystemTransactionExportPlatform();

  @override
  bool get shareAfterSave => Platform.isIOS;

  @override
  Future<String> exportDirectory() async {
    if (Platform.isIOS) {
      // iOS: 写入应用文档目录，然后使用系统分享
      final docDir = await getApplicationDocumentsDirectory();
      return docDir.path;
    }
    // Android: 直接保存到公共 Download/BeeCount 目录
    const downloadPath = '/storage/emulated/0/Download/BeeCount';
    final dir = Directory(downloadPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return downloadPath;
  }

  @override
  Future<void> writeCsv(String path, String csv) async {
    // 添加UTF-8 BOM标记，确保Excel正确识别中文编码
    const utf8Bom = '\uFEFF';
    await File(path)
        .writeAsString(utf8Bom + csv, encoding: Encoding.getByName('utf-8')!);
  }

  @override
  Future<void> shareCsv(String path, String text) async {
    // Keep the original sharing API and dismissal contract for this UI migration.
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(path)], text: text);
  }
}
