import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/logger.dart';

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
      logI('UpdateCache', '检查缓存APK，URL文件名: $fileName');

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
        logI('UpdateCache', '从URL提取的版本号: $version');
      }

      if (version == null) {
        logW('UpdateCache', '无法从URL中提取版本号: $downloadUrl');
        return null;
      }

      // 在下载目录中查找对应版本的BeeCount APK
      // 文件名格式应该是 BeeCount_v{version}.apk
      final targetFileName = 'BeeCount_v$version.apk';
      final expectedFilePath = '${downloadDir.path}/$targetFileName';
      final file = File(expectedFilePath);

      if (await file.exists()) {
        final fileSize = await file.length();
        logI('UpdateCache', '找到缓存的APK: ${file.path}, 大小: $fileSize字节');
        return file.path;
      } else {
        logI('UpdateCache', '缓存APK不存在: $expectedFilePath');

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
              logI('UpdateCache',
                  '找到旧格式的缓存APK: ${checkFile.path}, 大小: $fileSize字节');
              return checkFile.path;
            }
          }
        }
      }

      logI('UpdateCache', '未找到版本 $version 的缓存APK');
      return null;
    } catch (e) {
      logE('UpdateCache', '检查缓存APK失败', e);
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

      logI('UpdateCache', '已保存APK路径到缓存: $filePath');
    } catch (e) {
      logE('UpdateCache', '保存APK路径失败', e);
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
            logI('UpdateCache', '找到有效的缓存APK: $cachedPath');
            return cachedPath;
          } else {
            logI('UpdateCache', '缓存APK已过期（$daysSinceDownload天），清理缓存');
            await clearCachedApk();
          }
        } else {
          logI('UpdateCache', '缓存APK文件不存在，清理缓存');
          await clearCachedApk();
        }
      }

      return null;
    } catch (e) {
      logE('UpdateCache', '获取缓存APK路径失败', e);
      return null;
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
          logI('UpdateCache', '已删除缓存APK文件: $cachedPath');
        }
      }

      await prefs.remove(_cachedApkPathKey);
      await prefs.remove(_cachedApkVersionKey);
      await prefs.remove('cached_apk_timestamp');

      logI('UpdateCache', '已清理APK缓存');
    } catch (e) {
      logE('UpdateCache', '清理APK缓存失败', e);
    }
  }
}