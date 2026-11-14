import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../services/system/logger_service.dart';

/// 文件选择器辅助工具类
///
/// 提供对 FilePicker 的封装，处理部分 Android 设备不支持扩展名过滤的问题。
class FilePickerHelper {
  FilePickerHelper._();

  /// 选择指定扩展名的文件
  ///
  /// [allowedExtensions] - 允许的文件扩展名列表（不含点号），如 ['yml', 'yaml']
  /// [validateExtension] - 是否在选择后验证扩展名（默认 true）
  ///
  /// 部分 Android 设备不支持扩展名过滤，会抛出 PlatformException。
  /// 此方法会自动 fallback 到选择任意文件，然后手动验证扩展名。
  ///
  /// 如果用户取消选择，返回 null。
  /// 如果选择的文件扩展名不匹配且 [validateExtension] 为 true，抛出 [FileExtensionException]。
  static Future<FilePickerResult?> pickFileWithExtensions({
    required List<String> allowedExtensions,
    bool validateExtension = true,
  }) async {
    FilePickerResult? result;

    try {
      // 尝试使用扩展名过滤
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
    } on PlatformException catch (e) {
      // 设备不支持扩展名过滤，fallback 到选择任意文件
      logger.warning('FilePickerHelper', '设备不支持扩展名过滤，fallback 到选择任意文件: $e');
      result = await FilePicker.platform.pickFiles(type: FileType.any);
    }

    // 用户取消选择
    if (result == null || result.files.isEmpty) {
      return null;
    }

    // 验证扩展名
    if (validateExtension) {
      final filePath = result.files.first.path;
      if (filePath != null) {
        final fileName = filePath.toLowerCase();
        final hasValidExtension = allowedExtensions.any(
          (ext) => fileName.endsWith('.${ext.toLowerCase()}'),
        );

        if (!hasValidExtension) {
          throw FileExtensionException(
            expectedExtensions: allowedExtensions,
            actualPath: filePath,
          );
        }
      }
    }

    return result;
  }

  /// 选择 YAML 配置文件 (.yml, .yaml)
  static Future<FilePickerResult?> pickYamlFile() async {
    return pickFileWithExtensions(
      allowedExtensions: ['yml', 'yaml'],
      validateExtension: true,
    );
  }

  /// 选择附件压缩归档文件 (.tar.gz)
  static Future<FilePickerResult?> pickArchiveFile() async {
    return pickFileWithExtensions(
      allowedExtensions: ['gz'],
      validateExtension: true,
    );
  }
}

/// 文件扩展名不匹配异常
class FileExtensionException implements Exception {
  final List<String> expectedExtensions;
  final String actualPath;

  FileExtensionException({
    required this.expectedExtensions,
    required this.actualPath,
  });

  @override
  String toString() {
    final extensionsText = expectedExtensions.map((e) => '.$e').join(', ');
    return '请选择以下格式的文件：$extensionsText';
  }
}
