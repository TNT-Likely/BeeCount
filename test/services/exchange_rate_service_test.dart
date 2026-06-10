// 源链契约:首源失败滑到次源;成功记住源下次先试;全挂抛 RateFetchException;
// fawazahmed0 小写键解析;frankfurter 解析。
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/services/currency/exchange_rate_service.dart';

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

ResponseBody _json(Map<String, dynamic> body) => ResponseBody.fromString(
      jsonEncode(body), 200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('首源失败滑到次源,并记住成功源', () async {
    final dio = Dio();
    dio.httpClientAdapter = _StubAdapter((o) {
      if (o.uri.host == 'fastly.jsdelivr.net') {
        throw DioException.connectionTimeout(
            timeout: const Duration(seconds: 4), requestOptions: o);
      }
      return _json({
        'date': '2026-06-10',
        'cny': {'usd': 0.1477, 'jpy': 21.65}
      });
    });
    final svc = ExchangeRateService(dio: dio);
    final r = await svc.fetch('CNY');
    expect(r.source, 'gcore.jsdelivr.net');
    expect(r.rateDate, '2026-06-10');
    expect(r.ratesBaseToQuote['USD'], '0.1477'); // 键转大写,值转字符串
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('rateSourceIndex'), 1); // 下次从 gcore 起跳
  });

  test('全链失败抛 RateFetchException', () async {
    final dio = Dio();
    dio.httpClientAdapter = _StubAdapter((o) =>
        throw DioException.connectionError(requestOptions: o, reason: 'down'));
    final svc = ExchangeRateService(dio: dio);
    expect(() => svc.fetch('CNY'), throwsA(isA<RateFetchException>()));
  });

  test('frankfurter 解析', () {
    final r = ExchangeRateService.parseFrankfurter('USD', {
      'base': 'USD',
      'date': '2026-06-10',
      'rates': {'CNY': 6.7715, 'JPY': 146.6},
    });
    expect(r.ratesBaseToQuote['CNY'], '6.7715');
    expect(r.rateDate, '2026-06-10');
  });

  test('记住源后下次从它起跳(跳过更靠前的源)', () async {
    SharedPreferences.setMockInitialValues({'rateSourceIndex': 1});
    final hitHosts = <String>[];
    final dio = Dio();
    dio.httpClientAdapter = _StubAdapter((o) {
      hitHosts.add(o.uri.host);
      return _json({'date': '2026-06-10', 'cny': {'usd': 0.1477}});
    });
    final svc = ExchangeRateService(dio: dio);
    final r = await svc.fetch('CNY');
    expect(hitHosts.first, 'gcore.jsdelivr.net'); // 从 idx1 起跳,fastly 被跳过
    expect(r.source, 'gcore.jsdelivr.net');
  });
}
