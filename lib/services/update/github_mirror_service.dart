import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../system/logger_service.dart';

/// GitHub 镜像加速服务
///
/// 常见的 GitHub 加速镜像：
/// - ghproxy.com - 国内加速代理
/// - mirror.ghproxy.com - 备用加速
/// - gh.ddlc.top - 加速代理
/// - github.moeyy.xyz - Moeyy 加速
/// - gh-proxy.com - 加速代理
class GitHubMirrorService {
  GitHubMirrorService._();

  static const String _prefKeySelectedMirror = 'github_mirror_selected';

  /// 所有支持的镜像源
  static final List<GitHubMirror> mirrors = [
    GitHubMirror(
      id: 'direct',
      name: 'GitHub 直连',
      nameEn: 'GitHub Direct',
      urlPrefix: '',
      testUrl: 'https://github.com',
      isDefault: true,
    ),
    GitHubMirror(
      id: 'ghproxy',
      name: 'ghproxy.com',
      nameEn: 'ghproxy.com',
      urlPrefix: 'https://ghproxy.com/',
      testUrl: 'https://ghproxy.com',
    ),
    GitHubMirror(
      id: 'mirror_ghproxy',
      name: 'mirror.ghproxy.com',
      nameEn: 'mirror.ghproxy.com',
      urlPrefix: 'https://mirror.ghproxy.com/',
      testUrl: 'https://mirror.ghproxy.com',
    ),
    GitHubMirror(
      id: 'gh_ddlc',
      name: 'gh.ddlc.top',
      nameEn: 'gh.ddlc.top',
      urlPrefix: 'https://gh.ddlc.top/',
      testUrl: 'https://gh.ddlc.top',
    ),
    GitHubMirror(
      id: 'moeyy',
      name: 'github.moeyy.xyz',
      nameEn: 'github.moeyy.xyz',
      urlPrefix: 'https://github.moeyy.xyz/',
      testUrl: 'https://github.moeyy.xyz',
    ),
    GitHubMirror(
      id: 'gh_proxy',
      name: 'gh-proxy.com',
      nameEn: 'gh-proxy.com',
      urlPrefix: 'https://gh-proxy.com/',
      testUrl: 'https://gh-proxy.com',
    ),
  ];

  /// 获取保存的镜像选择
  static Future<String> getSelectedMirrorId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeySelectedMirror) ?? 'direct';
  }

  /// 保存镜像选择
  static Future<void> setSelectedMirrorId(String mirrorId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySelectedMirror, mirrorId);
    logger.info('GitHubMirror', '已保存镜像选择: $mirrorId');
  }

  /// 获取当前选择的镜像
  static Future<GitHubMirror> getSelectedMirror() async {
    final selectedId = await getSelectedMirrorId();
    return mirrors.firstWhere(
      (m) => m.id == selectedId,
      orElse: () => mirrors.first,
    );
  }

  /// 根据 ID 获取镜像
  static GitHubMirror? getMirrorById(String id) {
    try {
      return mirrors.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 将原始 GitHub 下载 URL 转换为镜像 URL
  static String convertToMirrorUrl(String originalUrl, GitHubMirror mirror) {
    if (mirror.urlPrefix.isEmpty) {
      // 直连，不转换
      return originalUrl;
    }
    // 加速镜像通常是在 URL 前面加上代理前缀
    return '${mirror.urlPrefix}$originalUrl';
  }

  /// 测试单个镜像的延迟
  static Future<MirrorTestResult> testMirrorLatency(GitHubMirror mirror) async {
    final dio = Dio()
      ..options.connectTimeout = const Duration(seconds: 10)
      ..options.receiveTimeout = const Duration(seconds: 10);

    final stopwatch = Stopwatch()..start();

    try {
      logger.info('GitHubMirror', '开始测试镜像: ${mirror.name}');

      // 对于直连，测试 GitHub API
      final testUrl =
          mirror.isDefault ? 'https://api.github.com' : mirror.testUrl;

      final response = await dio.head(
        testUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ),
      );

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (response.statusCode == 200 ||
          response.statusCode == 301 ||
          response.statusCode == 302) {
        logger.info('GitHubMirror', '镜像 ${mirror.name} 测试成功，延迟: ${latency}ms');
        return MirrorTestResult(
          mirror: mirror,
          latency: latency,
          isAvailable: true,
        );
      } else {
        logger.warning(
            'GitHubMirror', '镜像 ${mirror.name} 响应异常: ${response.statusCode}');
        return MirrorTestResult(
          mirror: mirror,
          latency: -1,
          isAvailable: false,
          error: 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      stopwatch.stop();
      logger.warning('GitHubMirror', '镜像 ${mirror.name} 测试失败: $e');
      return MirrorTestResult(
        mirror: mirror,
        latency: -1,
        isAvailable: false,
        error: e.toString(),
      );
    }
  }

  /// 测试所有镜像的延迟（并行）
  static Future<List<MirrorTestResult>> testAllMirrors({
    void Function(int completed, int total)? onProgress,
  }) async {
    logger.info('GitHubMirror', '开始测试所有镜像...');

    final results = <MirrorTestResult>[];
    int completed = 0;

    // 并行测试所有镜像
    final futures = mirrors.map((mirror) async {
      final result = await testMirrorLatency(mirror);
      completed++;
      onProgress?.call(completed, mirrors.length);
      return result;
    }).toList();

    results.addAll(await Future.wait(futures));

    // 按延迟排序（可用的在前，按延迟升序）
    results.sort((a, b) {
      if (a.isAvailable && !b.isAvailable) return -1;
      if (!a.isAvailable && b.isAvailable) return 1;
      if (!a.isAvailable && !b.isAvailable) return 0;
      return a.latency.compareTo(b.latency);
    });

    logger.info('GitHubMirror',
        '所有镜像测试完成，可用数量: ${results.where((r) => r.isAvailable).length}');
    return results;
  }

  /// 自动选择最快的可用镜像
  static Future<GitHubMirror?> selectFastestMirror() async {
    final results = await testAllMirrors();
    final availableResults = results.where((r) => r.isAvailable).toList();

    if (availableResults.isEmpty) {
      logger.warning('GitHubMirror', '没有可用的镜像');
      return null;
    }

    final fastest = availableResults.first;
    logger.info('GitHubMirror',
        '自动选择最快镜像: ${fastest.mirror.name} (${fastest.latency}ms)');
    await setSelectedMirrorId(fastest.mirror.id);
    return fastest.mirror;
  }
}

/// GitHub 镜像源配置
class GitHubMirror {
  final String id;
  final String name;
  final String nameEn;
  final String urlPrefix;
  final String testUrl;
  final bool isDefault;

  const GitHubMirror({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.urlPrefix,
    required this.testUrl,
    this.isDefault = false,
  });
}

/// 镜像测试结果
class MirrorTestResult {
  final GitHubMirror mirror;
  final int latency; // 延迟（毫秒），-1 表示不可用
  final bool isAvailable;
  final String? error;

  const MirrorTestResult({
    required this.mirror,
    required this.latency,
    required this.isAvailable,
    this.error,
  });

  /// 获取延迟显示文本
  String get latencyText {
    if (!isAvailable) return '不可用';
    if (latency < 0) return '未知';
    if (latency < 100) return '${latency}ms (极快)';
    if (latency < 300) return '${latency}ms (快)';
    if (latency < 800) return '${latency}ms (一般)';
    return '${latency}ms (慢)';
  }

  /// 获取延迟显示文本（英文）
  String get latencyTextEn {
    if (!isAvailable) return 'Unavailable';
    if (latency < 0) return 'Unknown';
    if (latency < 100) return '${latency}ms (Fast)';
    if (latency < 300) return '${latency}ms (Good)';
    if (latency < 800) return '${latency}ms (Normal)';
    return '${latency}ms (Slow)';
  }
}
