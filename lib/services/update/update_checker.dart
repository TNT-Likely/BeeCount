import 'dart:async';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../system/logger_service.dart';
import 'update_result.dart';

/// 更新检查管理类
class UpdateChecker {
  UpdateChecker._();

  static final Dio _dio = Dio();

  /// 清理 release notes，移除 commit hash 和链接
  static String _cleanReleaseNotes(String body) {
    if (body.isEmpty) return body;

    logger.info('UpdateChecker', '====== 原始 release notes ======');
    logger.info('UpdateChecker', body);
    logger.info('UpdateChecker', '====== 开始清理 ======');

    final lines = body.split('\n');
    final cleanedLines = <String>[];

    for (var line in lines) {
      logger.info('UpdateChecker', '处理行: "$line"');

      // 跳过包含 "Full Changelog" 的行
      if (line.contains('Full Changelog')) {
        logger.info('UpdateChecker', '  -> 跳过: 包含 Full Changelog');
        continue;
      }

      // 移除 commit hash 和链接部分：匹配 ([hash](url)) 格式
      // 使用正则表达式匹配 ([任意字符](任意字符)) 的模式
      final regex =
          RegExp(r'\s*\(\[[a-f0-9]{7}\]\(https://github\.com/[^\)]+\)\)');
      if (regex.hasMatch(line)) {
        line = line.replaceAll(regex, '');
        logger.info('UpdateChecker', '  -> 移除 commit 链接后: "$line"');
      }

      // 跳过空行
      if (line.trim().isEmpty) {
        logger.info('UpdateChecker', '  -> 跳过: 空行');
        continue;
      }

      logger.info('UpdateChecker', '  -> 保留');
      cleanedLines.add(line);
    }

    final result = cleanedLines.join('\n').trim();
    logger.info('UpdateChecker', '====== 清理后的 release notes ======');
    logger.info('UpdateChecker', result);
    logger.info('UpdateChecker', '====== 清理完成 ======');

    return result;
  }

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

    logger.info(
        'UpdateChecker', '使用User-Agent: ${selectedUA.substring(0, 50)}...');
    return selectedUA;
  }

  /// 检查更新信息
  static Future<UpdateResult> checkUpdate() async {
    try {
      // 获取当前版本信息
      final currentInfo = await _getAppInfo();
      final currentVersion = _normalizeVersion(currentInfo.version);

      logger.info('UpdateChecker', '当前版本: $currentVersion');

      // 配置Dio超时
      _dio.options.connectTimeout = const Duration(seconds: 30);
      _dio.options.receiveTimeout = const Duration(minutes: 2);
      _dio.options.sendTimeout = const Duration(minutes: 2);

      // 获取最新 release 信息 - 添加重试机制
      logger.info('UpdateChecker', '开始请求GitHub API...');
      Response? resp;
      int attempts = 0;
      const maxAttempts = 3;

      while (attempts < maxAttempts) {
        attempts++;
        try {
          logger.info('UpdateChecker', '尝试第$attempts次请求GitHub API...');
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
            logger.info('UpdateChecker', 'GitHub API请求成功');
            break;
          } else {
            logger.warning(
                'UpdateChecker', '第$attempts次请求返回错误状态码: ${resp.statusCode}');
            if (attempts == maxAttempts) {
              break; // 最后一次尝试，不再重试
            }
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (e) {
          logger.error('UpdateChecker', '第$attempts次请求失败', e);
          if (attempts == maxAttempts) {
            rethrow; // 最后一次尝试失败时抛出异常
          }
          // 等待1秒后重试
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      logger.info('UpdateChecker', 'GitHub API响应状态码: ${resp?.statusCode}');
      if (resp != null && resp.statusCode == 200) {
        final data = resp.data;
        final latestVersion = _normalizeVersion(data['tag_name']);

        logger.info('UpdateChecker', '最新版本: $latestVersion');

        if (_isNewerVersion(latestVersion, currentVersion)) {
          // 找到 APK 下载链接 — v3.2.1 起 Release 含多个 APK(arm64 主包 /
          // armeabi-v7a / x86_64 / universal),需要按设备选择,否则 arm64 真机
          // 装到 armv7 包会走系统 32-bit 兼容层导致严重卡顿
          final assets = data['assets'] as List;
          final apkUrl = _pickApkUrl(assets, latestVersion);

          if (apkUrl != null) {
            return UpdateResult(
              hasUpdate: true,
              version: latestVersion,
              downloadUrl: apkUrl,
              releaseNotes: _cleanReleaseNotes(data['body'] ?? ''),
            );
          } else {
            return UpdateResult(
              hasUpdate: false,
              message: '__UPDATE_NO_APK_FOUND__',
            );
          }
        } else {
          return UpdateResult(
            hasUpdate: false,
            message: '__UPDATE_ALREADY_LATEST_SIMPLE__',
          );
        }
      } else {
        final statusCode = resp?.statusCode ?? 'unknown';
        final responseData = resp?.data ?? 'no response';
        logger.error('UpdateChecker',
            'GitHub API请求失败: HTTP $statusCode, 响应: $responseData');
        return UpdateResult(
          hasUpdate: false,
          message: '__UPDATE_CHECK_HTTP_FAILED__:$statusCode',
        );
      }
    } catch (e) {
      logger.error('UpdateChecker', '检查更新异常', e);
      return UpdateResult(
        hasUpdate: false,
        message: '__UPDATE_CHECK_EXCEPTION__:$e',
      );
    }
  }

  /// 从 GitHub Release assets 列表里挑出适配当前设备的 APK。
  ///
  /// v3.2.1 起 Release 含多个按 ABI 拆分的 APK:
  ///   - beecount-<ver>.apk             主分发(arm64-v8a,99% 现役真机)
  ///   - beecount-<ver>-armeabi-v7a.apk armv7 老 32-bit 设备
  ///   - beecount-<ver>-x86_64.apk      Intel/Win/Linux 模拟器
  ///   - beecount-<ver>-universal.apk   三 ABI 全打,兜底
  ///
  /// 历史 bug:之前 `endsWith('.apk') break` 取第一个,因 GitHub assets 按
  /// 字母序排列,第一个就是 `-armeabi-v7a.apk` — arm64 真机装上跑 32-bit 兼容
  /// 模式 CPU 指令集降级 + 寄存器宽度从 64bit 切 32bit,体感严重卡顿。
  ///
  /// 选择策略(按优先级):
  ///   1. `beecount-<ver>.apk` 主包(arm64)— 现役真机 99% 是 arm64
  ///   2. universal — 主包不存在时兜底
  ///   3. 任何 .apk — 都没有时取第一个
  static String? _pickApkUrl(List assets, String version) {
    final apkByName = <String, String>{};
    for (final asset in assets) {
      final name = asset['name'].toString();
      if (name.endsWith('.apk')) {
        apkByName[name] = asset['browser_download_url'];
      }
    }
    if (apkByName.isEmpty) return null;

    final mainPkgName = 'beecount-$version.apk';
    final universalName = 'beecount-$version-universal.apk';

    if (apkByName.containsKey(mainPkgName)) return apkByName[mainPkgName];
    if (apkByName.containsKey(universalName)) return apkByName[universalName];
    return apkByName.values.first;
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
