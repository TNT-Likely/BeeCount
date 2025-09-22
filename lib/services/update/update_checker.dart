import 'dart:async';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../utils/logger.dart';
import 'update_result.dart';

/// 更新检查管理类
class UpdateChecker {
  UpdateChecker._();

  static final Dio _dio = Dio();

  /// 生成随机User-Agent，避免被GitHub限制
  static String _generateRandomUserAgent() {
    final userAgents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/119.0',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/119.0',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/119.0',
    ];

    // 使用时间戳作为随机种子，确保每次调用都可能不同
    final random = (DateTime.now().millisecondsSinceEpoch % userAgents.length);
    final selectedUA = userAgents[random];

    logI('UpdateChecker', '使用User-Agent: ${selectedUA.substring(0, 50)}...');
    return selectedUA;
  }

  /// 检查更新信息
  static Future<UpdateResult> checkUpdate() async {
    try {
      // 获取当前版本信息
      final currentInfo = await _getAppInfo();
      final currentVersion = _normalizeVersion(currentInfo.version);

      logI('UpdateChecker', '当前版本: $currentVersion');

      // 配置Dio超时
      _dio.options.connectTimeout = const Duration(seconds: 30);
      _dio.options.receiveTimeout = const Duration(minutes: 2);
      _dio.options.sendTimeout = const Duration(minutes: 2);

      // 获取最新 release 信息 - 添加重试机制
      logI('UpdateChecker', '开始请求GitHub API...');
      Response? resp;
      int attempts = 0;
      const maxAttempts = 3;

      while (attempts < maxAttempts) {
        attempts++;
        try {
          logI('UpdateChecker', '尝试第$attempts次请求GitHub API...');
          resp = await _dio.get(
            'https://api.github.com/repos/TNT-Likely/BeeCount/releases/latest',
            options: Options(
              headers: {
                'Accept': 'application/vnd.github+json',
                'User-Agent': _generateRandomUserAgent(),
              },
            ),
          );
          // 如果是成功响应，跳出循环
          if (resp.statusCode == 200) {
            logI('UpdateChecker', 'GitHub API请求成功');
            break;
          } else {
            logW('UpdateChecker', '第$attempts次请求返回错误状态码: ${resp.statusCode}');
            if (attempts == maxAttempts) {
              break; // 最后一次尝试，不再重试
            }
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (e) {
          logE('UpdateChecker', '第$attempts次请求失败', e);
          if (attempts == maxAttempts) {
            rethrow; // 最后一次尝试失败时抛出异常
          }
          // 等待1秒后重试
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      logI('UpdateChecker', 'GitHub API响应状态码: ${resp?.statusCode}');
      if (resp != null && resp.statusCode == 200) {
        final data = resp.data;
        final latestVersion = _normalizeVersion(data['tag_name']);

        logI('UpdateChecker', '最新版本: $latestVersion');

        if (_isNewerVersion(latestVersion, currentVersion)) {
          // 找到APK下载链接
          final assets = data['assets'] as List;
          String? apkUrl;

          for (final asset in assets) {
            if (asset['name'].toString().endsWith('.apk')) {
              apkUrl = asset['browser_download_url'];
              break;
            }
          }

          if (apkUrl != null) {
            return UpdateResult(
              hasUpdate: true,
              version: latestVersion,
              downloadUrl: apkUrl,
              releaseNotes: data['body'] ?? '',
            );
          } else {
            return UpdateResult(
              hasUpdate: false,
              message: 'APK download link not found',
            );
          }
        } else {
          return UpdateResult(
            hasUpdate: false,
            message: 'Already latest version',
          );
        }
      } else {
        final statusCode = resp?.statusCode ?? 'unknown';
        final responseData = resp?.data ?? 'no response';
        logE('UpdateChecker',
            'GitHub API请求失败: HTTP $statusCode, 响应: $responseData');
        return UpdateResult(
          hasUpdate: false,
          message: 'Update check failed: HTTP $statusCode',
        );
      }
    } catch (e) {
      logE('UpdateChecker', '检查更新异常', e);
      return UpdateResult(
        hasUpdate: false,
        message: 'Update check failed: $e',
      );
    }
  }

  // 辅助方法
  static Future<AppInfo> _getAppInfo() async {
    final p = await PackageInfo.fromPlatform();
    final commit = const String.fromEnvironment('GIT_COMMIT');
    final buildTime = const String.fromEnvironment('BUILD_TIME');
    final ciVersion = const String.fromEnvironment('CI_VERSION');

    final version = ciVersion.isNotEmpty ? ciVersion : 'dev-${p.version}';

    return AppInfo(version, p.buildNumber,
        commit: commit.isEmpty ? null : commit,
        buildTime: buildTime.isEmpty ? null : buildTime);
  }

  static String _normalizeVersion(String version) {
    String normalized = version;
    if (normalized.startsWith('v')) {
      normalized = normalized.substring(1);
    }
    if (normalized.startsWith('dev-')) {
      normalized = normalized.substring(4);
    }
    final dashIndex = normalized.indexOf('-');
    if (dashIndex != -1) {
      normalized = normalized.substring(0, dashIndex);
    }
    return normalized;
  }

  static bool _isNewerVersion(String newVersion, String currentVersion) {
    final newParts = newVersion
        .split('.')
        .map(int.tryParse)
        .where((e) => e != null)
        .cast<int>()
        .toList();
    final currentParts = currentVersion
        .split('.')
        .map(int.tryParse)
        .where((e) => e != null)
        .cast<int>()
        .toList();

    final maxLength =
        [newParts.length, currentParts.length].reduce((a, b) => a > b ? a : b);
    while (newParts.length < maxLength) {
      newParts.add(0);
    }
    while (currentParts.length < maxLength) {
      currentParts.add(0);
    }

    for (int i = 0; i < maxLength; i++) {
      if (newParts[i] > currentParts[i]) return true;
      if (newParts[i] < currentParts[i]) return false;
    }

    return false;
  }
}