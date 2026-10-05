// GLM 邀请链接池:解析校验、缓存整体替换(删码生效)、节流与失败静默。
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/services/ai/glm_invite_link_service.dart';

class _StubAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions) handler;
  _StubAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

const _linkA =
    'https://www.bigmodel.cn/invite?icode=sxVvBZcZQdcWqFB86%2BAy37C%2Fk7jQAKmT1mpEiZXXnFw%3D';
const _linkB =
    'https://www.bigmodel.cn/invite?icode=WxEZVzqqWb1qFnAK7lIHWP2gad6AKpjZefIo3dVEQyA%3D';

ResponseBody _json(Map<String, dynamic> body) => ResponseBody.fromString(
      jsonEncode(body), 200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

GlmInviteLinkService _svc(ResponseBody Function(RequestOptions) handler) {
  final dio = Dio();
  dio.httpClientAdapter = _StubAdapter(handler);
  return GlmInviteLinkService(
      dio: dio, remoteUrl: 'https://example.test/pool.json');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('parseRemoteLinks', () {
    test('合法两条保序保留', () {
      final r = GlmInviteLinkService.parseRemoteLinks({
        'links': [_linkA, _linkB],
      });
      expect(r, [_linkA, _linkB]);
    });

    test('混入非法项只留合法', () {
      final r = GlmInviteLinkService.parseRemoteLinks({
        'links': [
          _linkA,
          'http://www.bigmodel.cn/invite?icode=x', // 非 https
          'https://open.bigmodel.cn/invite?icode=x', // host 不符
          'https://www.bigmodel.cn/invited?icode=x', // path 不符
          'https://www.bigmodel.cn/invite', // 缺 icode
          'https://www.bigmodel.cn/invite?icode=', // 空 icode
          42, // 非字符串
        ],
      });
      expect(r, [_linkA]);
    });

    test('去重保序', () {
      final r = GlmInviteLinkService.parseRemoteLinks({
        'links': [_linkA, _linkB, _linkA],
      });
      expect(r, [_linkA, _linkB]);
    });

    test('结构错误返回空列表', () {
      expect(GlmInviteLinkService.parseRemoteLinks('not a map'), isEmpty);
      expect(GlmInviteLinkService.parseRemoteLinks(null), isEmpty);
      expect(GlmInviteLinkService.parseRemoteLinks([_linkA]), isEmpty);
      expect(GlmInviteLinkService.parseRemoteLinks({'nope': [_linkA]}), isEmpty);
      expect(GlmInviteLinkService.parseRemoteLinks({'links': 'x'}), isEmpty);
      expect(GlmInviteLinkService.parseRemoteLinks({'links': []}), isEmpty);
    });

    test('icode 的 URL 编码原样保留(不重编码)', () {
      const encoded = 'https://www.bigmodel.cn/invite?icode=a%2Bb%2Fc%3D';
      final r = GlmInviteLinkService.parseRemoteLinks({
        'links': [encoded],
      });
      expect(r, [encoded]);
    });

    test('超过上限截断为 50 条', () {
      final many = List.generate(
          60, (i) => 'https://www.bigmodel.cn/invite?icode=c$i');
      final r = GlmInviteLinkService.parseRemoteLinks({'links': many});
      expect(r.length, 50);
    });
  });

  group('resolveLinks / pickLink', () {
    test('无缓存返回默认池', () async {
      final svc = GlmInviteLinkService();
      expect(await svc.resolveLinks(), GlmInviteLinkService.defaultLinks);
    });

    test('有合法缓存时整体替换默认池(远程删码生效)', () async {
      SharedPreferences.setMockInitialValues({
        'ai_glm_invite_links': jsonEncode({'links': [_linkB]}),
      });
      final svc = GlmInviteLinkService();
      expect(await svc.resolveLinks(), [_linkB]);
    });

    test('脏缓存回退默认池不抛异常', () async {
      SharedPreferences.setMockInitialValues({
        'ai_glm_invite_links': 'not-json{',
      });
      final svc = GlmInviteLinkService();
      expect(await svc.resolveLinks(), GlmInviteLinkService.defaultLinks);
    });

    test('pickLink 始终在池内', () async {
      final svc = GlmInviteLinkService();
      for (var i = 0; i < 10; i++) {
        final link = await svc.pickLink();
        expect(GlmInviteLinkService.defaultLinks.contains(link), isTrue);
      }
    });
  });

  group('refreshIfNeeded', () {
    test('成功拉取写缓存与节流时间戳', () async {
      var hits = 0;
      final svc = _svc((o) {
        hits++;
        return _json({'links': [_linkB]});
      });
      await svc.refreshIfNeeded();
      expect(hits, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_glm_invite_links'), jsonEncode({'links': [_linkB]}));
      expect(prefs.getInt('ai_glm_invite_links_time'), isNotNull);
      expect(await svc.resolveLinks(), [_linkB]);
    });

    test('远端全非法时保留现有缓存', () async {
      SharedPreferences.setMockInitialValues({
        'ai_glm_invite_links': jsonEncode({'links': [_linkA]}),
      });
      final svc = _svc((o) => _json({'links': ['https://evil.example.com/x']}));
      await svc.refreshIfNeeded();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_glm_invite_links'), jsonEncode({'links': [_linkA]}));
    });

    test('远端畸形 JSON 不抛异常且缓存不变', () async {
      SharedPreferences.setMockInitialValues({
        'ai_glm_invite_links': jsonEncode({'links': [_linkA]}),
      });
      final svc = _svc((o) => ResponseBody.fromString('not json{', 200));
      await svc.refreshIfNeeded();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_glm_invite_links'), jsonEncode({'links': [_linkA]}));
    });

    test('6h 内节流不发请求,force 跳过节流', () async {
      SharedPreferences.setMockInitialValues({
        'ai_glm_invite_links_time': DateTime.now().millisecondsSinceEpoch,
      });
      var hits = 0;
      final svc = _svc((o) {
        hits++;
        return _json({'links': [_linkB]});
      });
      await svc.refreshIfNeeded();
      expect(hits, 0);
      await svc.refreshIfNeeded(force: true);
      expect(hits, 1);
    });

    test('连接失败静默且推进节流时间戳', () async {
      final svc = _svc((o) =>
          throw DioException.connectionError(requestOptions: o, reason: 'down'));
      await svc.refreshIfNeeded(); // 不抛
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('ai_glm_invite_links_time'), isNotNull);
      expect(await svc.resolveLinks(), GlmInviteLinkService.defaultLinks);
    });

    test('404 静默且缓存不变', () async {
      final svc = _svc((o) => ResponseBody.fromString('Not Found', 404));
      await svc.refreshIfNeeded(); // 不抛
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_glm_invite_links'), isNull);
    });
  });
}
