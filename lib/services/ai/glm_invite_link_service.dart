import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../system/logger_service.dart';

/// GLM 邀请注册链接池服务(「获取 Key」按钮用)。
///
/// 本地默认池 + 远端 JSON 池(`{"links": [...]}`,Cloudflare Worker 托管);
/// 有效远端列表**整体替换**本地默认,便于运营端下架失效/满员邀请码。
/// 点击按钮只读本地(缓存优先),零网络等待;刷新在管理页打开时后台静默
/// 进行,6h 节流,任何失败都只记日志、按钮永远可用。
class GlmInviteLinkService {
  GlmInviteLinkService({Dio? dio, String? remoteUrl})
      : _dio = dio ?? Dio(),
        _remoteUrl = remoteUrl ?? remoteConfigUrl {
    _dio.options.connectTimeout = _timeout;
    _dio.options.receiveTimeout = _timeout;
  }

  /// 远端链接池地址(Cloudflare Worker,见 BeeCount-Worker 项目)。
  static const String remoteConfigUrl = 'https://cfg.beejz.com/invite-links';

  /// 本地默认邀请链接池(远端从未拉到 / 拉取失败时的兜底)。
  static const List<String> defaultLinks = [
    'https://www.bigmodel.cn/invite?icode=sxVvBZcZQdcWqFB86%2BAy37C%2Fk7jQAKmT1mpEiZXXnFw%3D',
    'https://www.bigmodel.cn/invite?icode=WxEZVzqqWb1qFnAK7lIHWP2gad6AKpjZefIo3dVEQyA%3D',
  ];

  static const _cacheKey = 'ai_glm_invite_links'; // String: jsonEncode({"links": [...]})
  static const _fetchTimeKey = 'ai_glm_invite_links_time'; // int: 上次拉取尝试的毫秒时间戳
  static const _timeout = Duration(seconds: 4);
  static const _minRefreshInterval = Duration(hours: 6);
  static const _allowedHost = 'www.bigmodel.cn';
  static const _allowedPath = '/invite';
  static const _maxLinks = 50;
  static const _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36';

  final Dio _dio;
  final String _remoteUrl;
  final Random _random = Random();
  Future<void>? _inflightRefresh; // 并发去抖:管理页与编辑页同时触发时只发一次请求

  /// 当前应使用的链接池:已验证的远端缓存优先,否则本地默认。永不为空、不抛异常。
  Future<List<String>> resolveLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        // 读出时再次校验,防手改 prefs / 老版本脏数据
        final links = parseRemoteLinks(jsonDecode(cached));
        if (links.isNotEmpty) return links;
      }
    } catch (e) {
      logger.warning('GlmInviteLink', '读取本地链接池缓存失败: $e');
    }
    return defaultLinks;
  }

  /// 从当前池里随机取一条(按钮点击路径,纯本地,无网络等待)。
  Future<String> pickLink() async {
    final links = await resolveLinks();
    if (links.length == 1) return links.first;
    return links[_random.nextInt(links.length)];
  }

  /// 页面打开时的后台静默刷新:6h 节流 + 4s 超时,全程静默(只写日志)。
  /// [force] 跳过节流,仅供测试/排查使用。
  Future<void> refreshIfNeeded({bool force = false}) {
    final inflight = _inflightRefresh;
    if (inflight != null) return inflight;
    final f =
        _refresh(force: force).whenComplete(() => _inflightRefresh = null);
    _inflightRefresh = f;
    return f;
  }

  Future<void> _refresh({required bool force}) async {
    if (_remoteUrl.isEmpty) {
      logger.info('GlmInviteLink', '未配置远端链接池,跳过刷新');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_fetchTimeKey) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - last;
      if (!force && elapsed < _minRefreshInterval.inMilliseconds) return;
      // 节流按"尝试"记录:失败也推进时间戳,坏地址最多 4 次/天/用户
      await prefs.setInt(_fetchTimeKey, DateTime.now().millisecondsSinceEpoch);

      final decoded = await _fetchRemoteJson();
      final links = parseRemoteLinks(decoded);
      if (links.isEmpty) {
        logger.warning('GlmInviteLink', '远端链接池为空或全部非法,保留现有缓存');
        return;
      }
      await prefs.setString(_cacheKey, jsonEncode({'links': links}));
      logger.info('GlmInviteLink', '远端链接池更新成功: ${links.length} 条');
    } catch (e) {
      logger.warning('GlmInviteLink', '远端链接池刷新失败: $e');
    }
  }

  /// 唯一知道取数地址的方法;将来换源只改这里。
  /// 响应可能是 String(text/plain,如 GitHub raw)或已解码 Map(Worker 的
  /// Response.json 返回 application/json),都要处理。
  Future<Object?> _fetchRemoteJson() async {
    final resp = await _dio.get(
      _remoteUrl,
      options: Options(headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      }),
    );
    final data = resp.data;
    if (data is String) return data.isEmpty ? null : jsonDecode(data);
    return data;
  }

  /// 纯函数:校验远端 JSON → 合法链接列表(保序、去重、上限 [_maxLinks] 条)。
  /// 全部非法/结构错误返回空列表 —— 调用方不得用空列表覆盖缓存。
  ///
  /// 注意保留原始字符串:Uri.toString() 会重编码 icode 里的 %2B/%2F/%3D,
  /// 部分后端会视为不同的邀请码。
  static List<String> parseRemoteLinks(Object? decoded) {
    if (decoded is! Map) return const [];
    final raw = decoded['links'];
    if (raw is! List) return const [];
    final out = <String>[];
    for (final e in raw) {
      if (e is! String) continue;
      final s = e.trim();
      final uri = Uri.tryParse(s);
      if (uri == null) continue;
      if (uri.scheme != 'https') continue;
      if (uri.host != _allowedHost) continue;
      if (uri.path != _allowedPath) continue;
      final icode = uri.queryParameters['icode'];
      if (icode == null || icode.isEmpty) continue;
      if (out.contains(s)) continue;
      out.add(s);
      if (out.length >= _maxLinks) break;
    }
    return out;
  }
}
