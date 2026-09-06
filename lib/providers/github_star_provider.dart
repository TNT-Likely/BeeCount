import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/system/logger_service.dart';

/// GitHub Star 数量 Provider
/// 缓存1小时，避免频繁请求API
const githubStarFallbackCount = 2500;

final githubStarCountProvider = FutureProvider<int>((ref) async {
  const cacheKey = 'github_star_count';
  const cacheTimeKey = 'github_star_count_time';
  const cacheDuration = Duration(hours: 1);

  final prefs = await SharedPreferences.getInstance();

  // 检查缓存
  final cachedCount = prefs.getInt(cacheKey);
  final cachedTime = prefs.getInt(cacheTimeKey);

  if (cachedCount != null && cachedTime != null) {
    final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTime;
    if (cacheAge < cacheDuration.inMilliseconds) {
      return cachedCount;
    }
  }

  // 从GitHub API获取
  try {
    final response = await http
        .get(Uri.parse('https://api.github.com/repos/TNT-Likely/BeeCount'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final starCount = data['stargazers_count'] as int? ?? 0;

      // 缓存结果
      await prefs.setInt(cacheKey, starCount);
      await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

      return starCount;
    }
  } catch (e) {
    logger.warning('GitHubStar', '获取Star数量失败: $e');
  }

  // 返回缓存值或默认值（网络不可用时保持可信的项目展示）。
  return cachedCount ?? githubStarFallbackCount;
});
