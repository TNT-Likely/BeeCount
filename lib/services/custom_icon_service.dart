import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'system/logger_service.dart';

/// 自定义图标异常
class CustomIconException implements Exception {
  final String message;
  CustomIconException(this.message);

  @override
  String toString() => message;
}

/// 自定义图标服务
/// 负责自定义图标的选择、处理、存储和管理
class CustomIconService {
  // 存储规格
  static const int targetSize = 96; // 存储尺寸
  static const int thumbSize = 48; // 缩略图尺寸
  static const int quality = 85; // 压缩质量
  static const int maxStorageSize = 100 * 1024; // 100KB 存储限制

  // 上传限制
  static const int maxUploadSize = 5 * 1024 * 1024; // 5MB 上传限制
  static const int maxDimension = 2048; // 最大边长
  static const int minDimension = 64; // 最小边长

  final ImagePicker _picker = ImagePicker();

  CustomIconService();

  /// 获取自定义图标存储目录
  Future<Directory> getIconDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/custom_icons');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 将相对路径解析为绝对路径
  ///
  /// [relativePath] - 相对路径(如: custom_icons/6_1767927021604.png)
  /// 返回绝对路径
  Future<String> resolveIconPath(String relativePath) async {
    final dir = await getIconDirectory();
    final fileName = path.basename(relativePath);
    return path.join(dir.path, fileName);
  }

  /// §7 决策 — Editor 拉 Owner 自定义图标走 sha256 cache:
  /// 1. 按 sha256 命名 cache 文件(`shared_<sha256>.png`),命中直接返
  /// 2. miss 时由调用方走 `provider.downloadAttachment(fileId)` 拉二进制,
  ///    再调 [writeCachedSharedIcon] 落地
  /// 返回 cache 文件路径(可能不存在,调用方应检查)
  Future<String> resolveCachedSharedIconPath(String sha256) async {
    final dir = await getIconDirectory();
    return path.join(dir.path, 'shared_$sha256.png');
  }

  /// 落地 Editor 拉到的自定义图标二进制 — 按 sha256 命名,
  /// 同 sha256 反复下载会命中本地缓存(去重)。
  /// 校验 actual sha256 跟 expected 一致(防中间人),不一致抛 [CustomIconException]。
  Future<String> writeCachedSharedIcon({
    required String expectedSha256,
    required Uint8List bytes,
  }) async {
    final actualHex = sha256.convert(bytes).toString();
    if (actualHex.toLowerCase() != expectedSha256.toLowerCase()) {
      throw CustomIconException(
        'sha256 mismatch: expected=$expectedSha256 actual=$actualHex',
      );
    }
    final cachePath = await resolveCachedSharedIconPath(expectedSha256);
    final file = File(cachePath);
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return cachePath;
  }

  /// 从相册选择图片
  Future<File?> pickFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxDimension.toDouble(),
        maxHeight: maxDimension.toDouble(),
      );
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      logger.error('CustomIconService', '从相册选择图片失败', e);
      return null;
    }
  }

  /// 拍照
  Future<File?> takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxDimension.toDouble(),
        maxHeight: maxDimension.toDouble(),
      );
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      logger.error('CustomIconService', '拍照失败', e);
      return null;
    }
  }

  /// 验证图片文件
  Future<void> validateImage(File file) async {
    // 检查文件是否存在
    if (!await file.exists()) {
      throw CustomIconException('图片文件不存在');
    }

    // 检查文件大小
    final fileSize = await file.length();
    if (fileSize > maxUploadSize) {
      throw CustomIconException('图片文件过大，最大支持 5MB');
    }

    // 检查文件扩展名
    final ext = path.extension(file.path).toLowerCase();
    final validExts = ['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'];
    if (!validExts.contains(ext)) {
      throw CustomIconException('不支持的图片格式');
    }
  }

  /// 保存自定义图标
  /// 将图片裁剪为正方形并压缩后保存
  /// 返回保存后的相对路径（如: custom_icons/6_1767927021604.png）
  Future<String> saveCustomIcon(File sourceFile, int categoryId) async {
    try {
      // 1. 验证文件
      await validateImage(sourceFile);

      // 2. 生成文件名
      final dir = await getIconDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${categoryId}_$timestamp.png';
      final destPath = '${dir.path}/$fileName';

      // 3. 压缩并保存（正方形裁剪）
      final result = await FlutterImageCompress.compressAndGetFile(
        sourceFile.path,
        destPath,
        minWidth: targetSize,
        minHeight: targetSize,
        quality: quality,
        format: CompressFormat.png,
        // 注意：flutter_image_compress 不支持直接裁剪为正方形
        // 这里先压缩，后续可以用 image 包进行精确裁剪
      );

      if (result == null) {
        throw CustomIconException('图片压缩失败');
      }

      // 4. 删除源文件（如果是临时文件）
      if (sourceFile.path.contains('cache') ||
          sourceFile.path.contains('tmp')) {
        try {
          await sourceFile.delete();
        } catch (_) {}
      }

      // 5. 返回相对路径（用于跨设备同步）
      final relativePath = 'custom_icons/$fileName';
      logger.info(
          'CustomIconService', '自定义图标已保存: $destPath (相对路径: $relativePath)');

      return relativePath;
    } catch (e) {
      if (e is CustomIconException) rethrow;
      logger.error('CustomIconService', '保存自定义图标失败', e);
      throw CustomIconException('保存图标失败: $e');
    }
  }

  /// 删除自定义图标
  Future<void> deleteCustomIcon(String iconPath) async {
    try {
      final file = File(iconPath);
      if (await file.exists()) {
        await file.delete();
        logger.info('CustomIconService', '自定义图标已删除: $iconPath');
      }

      // 删除缩略图（如果存在）
      final thumbPath = iconPath.replaceAll('.png', '_thumb.png');
      final thumbFile = File(thumbPath);
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
    } catch (e) {
      logger.error('CustomIconService', '删除自定义图标失败', e);
    }
  }

  /// 获取用户已保存的图标数量
  Future<int> getIconCount() async {
    final dir = await getIconDirectory();
    if (!await dir.exists()) return 0;

    int count = 0;
    await for (final entity in dir.list()) {
      if (entity is File &&
          entity.path.endsWith('.png') &&
          !entity.path.contains('_thumb')) {
        count++;
      }
    }
    return count;
  }

  /// 清理未使用的图标
  /// 传入当前正在使用的图标路径列表
  Future<int> cleanupUnusedIcons(List<String> usedPaths) async {
    final dir = await getIconDirectory();
    if (!await dir.exists()) return 0;

    int deletedCount = 0;
    final usedSet = usedPaths.toSet();

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.png')) {
        if (!usedSet.contains(entity.path)) {
          try {
            await entity.delete();
            deletedCount++;
            logger.info('CustomIconService', '清理未使用图标: ${entity.path}');
          } catch (e) {
            logger.error('CustomIconService', '清理图标失败: ${entity.path}', e);
          }
        }
      }
    }

    return deletedCount;
  }

  /// 获取存储目录大小（字节）
  Future<int> getStorageSize() async {
    final dir = await getIconDirectory();
    if (!await dir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// 格式化存储大小
  String formatStorageSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
