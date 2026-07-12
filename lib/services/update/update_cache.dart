import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../system/logger_service.dart';

/// 更新缓存管理类
class UpdateCache {
  UpdateCache._();

  // APK缓存相关常量
  static const String _cachedApkPathKey = 'cached_apk_path';
  static const String _cachedApkVersionKey = 'cached_apk_version';

  /// 检查是否有缓存的APK文件对应给定的下载URL
  static Future<String?> checkCachedApkForUrl(String downloadUrl) async {
    try {
      // 从URL中提取版本信息
      final uri = Uri.parse(downloadUrl);
      final fileName = uri.pathSegments.last;
      logger.info('UpdateCache', '检查缓存APK，URL文件名: $fileName');

      // 获取下载目录
      Directory? downloadDir;
      if (Platform.isAndroid) {
        downloadDir = await getExternalStorageDirectory();
      }
      downloadDir ??= await getApplicationDocumentsDirectory();

      // 从URL文件名提取版本号（格式如 beecount-0.8.1.apk）
      String? version;
      final versionMatch = RegExp(r'beecount-([0-9]+\.[0-9]+\.[0-9]+)\.apk')
          .firstMatch(fileName);
      if (versionMatch != null) {
        version = versionMatch.group(1);
        logger.info('UpdateCache', '从URL提取的版本号: $version');
      }

      if (version == null) {
        logger.warning('UpdateCache', '无法从URL中提取版本号: $downloadUrl');
        return null;
      }

      // 在下载目录中查找对应版本的BeeCount APK
      // 文件名格式应该是 BeeCount_v{version}.apk
      final targetFileName = 'BeeCount_v$version.apk';
      final expectedFilePath = '${downloadDir.path}/$targetFileName';
      final file = File(expectedFilePath);

      if (await file.exists()) {
        final fileSize = await file.length();
        logger.info('UpdateCache', '找到缓存的APK: ${file.path}, 大小: $fileSize字节');
        return file.path;
      } else {
        logger.info('UpdateCache', '缓存APK不存在: $expectedFilePath');

        // 也检查一下旧的文件名格式作为备选
        final files = downloadDir.listSync();
        for (final checkFile in files) {
          if (checkFile is File &&
              checkFile.path.contains('BeeCount') &&
              checkFile.path.endsWith('.apk') &&
              checkFile.path.contains(version)) {
            // 验证文件是否存在且可读
            if (await checkFile.exists()) {
              final fileSize = await checkFile.length();
              logger.info('UpdateCache',
                  '找到旧格式的缓存APK: ${checkFile.path}, 大小: $fileSize字节');
              return checkFile.path;
            }
          }
        }
      }

      logger.info('UpdateCache', '未找到版本 $version 的缓存APK');
      return null;
    } catch (e) {
      logger.error('UpdateCache', '检查缓存APK失败', e);
      return null;
    }
  }

  /// 保存APK路径到缓存
  static Future<void> saveApkPath(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedApkPathKey, filePath);

      // 同时保存当前时间戳，用于判断APK是否过期
      await prefs.setInt(
          'cached_apk_timestamp', DateTime.now().millisecondsSinceEpoch);

      logger.info('UpdateCache', '已保存APK路径到缓存: $filePath');
    } catch (e) {
      logger.error('UpdateCache', '保存APK路径失败', e);
    }
  }

  /// 获取缓存的APK路径
  static Future<String?> getCachedApkPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPath = prefs.getString(_cachedApkPathKey);

      if (cachedPath != null) {
        // 检查文件是否还存在
        final file = File(cachedPath);
        if (await file.exists()) {
          // 检查是否在7天内下载的（避免过期的APK）
          final timestamp = prefs.getInt('cached_apk_timestamp') ?? 0;
          final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final daysSinceDownload =
              DateTime.now().difference(cachedTime).inDays;

          if (daysSinceDownload <= 7) {
            logger.info('UpdateCache', '找到有效的缓存APK: $cachedPath');
            return cachedPath;
          } else {
            logger.info('UpdateCache', '缓存APK已过期（$daysSinceDownload天），清理缓存');
            await clearCachedApk();
          }
        } else {
          logger.info('UpdateCache', '缓存APK文件不存在，清理缓存');
          await clearCachedApk();
        }
      }

      return null;
    } catch (e) {
      logger.error('UpdateCache', '获取缓存APK路径失败', e);
      return null;
    }
  }

  /// 验证APK文件完整性
  /// 返回true表示文件可能完整，false表示明显损坏
  static Future<bool> validateApkFile(String filePath) async {
    try {
      final file = File(filePath);

      // 1. 检查文件是否存在
      if (!await file.exists()) {
        logger.warning('UpdateCache', 'APK文件不存在: $filePath');
        return false;
      }

      // 2. 检查文件大小是否合理（APK通常至少几MB）
      final fileSize = await file.length();
      const minValidSize = 5 * 1024 * 1024; // 5MB
      const maxValidSize = 200 * 1024 * 1024; // 200MB

      if (fileSize < minValidSize) {
        logger.warning(
            'UpdateCache', 'APK文件太小，可能不完整: $fileSize字节 (最小$minValidSize字节)');
        return false;
      }

      if (fileSize > maxValidSize) {
        logger.warning(
            'UpdateCache', 'APK文件太大，可能异常: $fileSize字节 (最大$maxValidSize字节)');
        return false;
      }

      // 3. 检查文件是否可读
      try {
        await file.open();
      } catch (e) {
        logger.warning('UpdateCache', 'APK文件无法打开: $e');
        return false;
      }

      // 4. 检查ZIP魔数（APK本质是ZIP文件）
      final bytes = await file.openRead(0, 4).first;
      // ZIP文件魔数: PK (0x50 0x4B)
      if (bytes.length < 2 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
        logger.warning('UpdateCache', 'APK文件格式错误，不是有效的ZIP/APK文件');
        return false;
      }

      logger.info('UpdateCache', 'APK文件验证通过: $filePath ($fileSize字节)');
      return true;
    } catch (e) {
      logger.error('UpdateCache', '验证APK文件失败', e);
      return false;
    }
  }

  /// 清理缓存的APK
  static Future<void> clearCachedApk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPath = prefs.getString(_cachedApkPathKey);

      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          await file.delete();
          logger.info('UpdateCache', '已删除缓存APK文件: $cachedPath');
        }
      }

      await prefs.remove(_cachedApkPathKey);
      await prefs.remove(_cachedApkVersionKey);
      await prefs.remove('cached_apk_timestamp');

      logger.info('UpdateCache', '已清理APK缓存');
    } catch (e) {
      logger.error('UpdateCache', '清理APK缓存失败', e);
    }
  }

  /// 删除指定的APK文件
  static Future<void> deleteApkFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        logger.info('UpdateCache', '已删除APK文件: $filePath');
      }
    } catch (e) {
      logger.error('UpdateCache', '删除APK文件失败', e);
    }
  }
}
