import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../system/logger_service.dart';

/// 公网汇率源链(.docs/multi-currency/04-exchange-rate-sources.md §④A;server 源由
/// currency_providers 的协调层在链前尝试,本服务只管公网):
/// fastly → gcore → testingcf → cdn.jsdelivr → pages.dev → frankfurter v1。
/// 每源 4s 超时;成功后记住源 index,下次从它起跳(自适应国内/海外网络)。
/// 返回方向:1 base = x quote(落库前由调用方 invertRate 取倒数)。
///
/// 成功源会被记住并优先重试 —— frankfurter(末位,~30 币)成功后会粘住直到它失败
/// 才回落 fawaz 族(200+ 币);这是"自适应收敛"的有意取舍,覆盖面换稳定性。
class RateFetchResult {
  final String rateDate;
  final String source;
  final Map<String, String> ratesBaseToQuote; // quote 大写 -> 字符串
  const RateFetchResult({
    required this.rateDate,
    required this.source,
    required this.ratesBaseToQuote,
  });
}

class RateFetchException implements Exception {
  final String message;
  RateFetchException(this.message);
  @override
  String toString() => 'RateFetchException: $message';
}

class RateSource {
  final String id;
  final bool isFrankfurter;
  final String Function(String base) url;
  const RateSource(this.id, this.url, {this.isFrankfurter = false});
}

String _fawazPath(String host, String base) =>
    'https://$host/npm/@fawazahmed0/currency-api@latest/v1/currencies/${base.toLowerCase()}.min.json';

class ExchangeRateService {
  static const _prefKeyLastSource = 'rateSourceIndex';
  static const _timeout = Duration(seconds: 4);

  /// 源列表顺序即优先级;成功源会被 SharedPreferences 记住并优先重试(见 fetch)。
  /// frankfurter 为末位兜底:~30 币覆盖面窄,但稳定;fawaz 族 200+ 币但 CDN 可能抖动。
  static final List<RateSource> sources = [
    RateSource(
        'fastly.jsdelivr.net', (b) => _fawazPath('fastly.jsdelivr.net', b)),
    RateSource(
        'gcore.jsdelivr.net', (b) => _fawazPath('gcore.jsdelivr.net', b)),
    RateSource(
        'testingcf.jsdelivr.net', (b) => _fawazPath('testingcf.jsdelivr.net', b)),
    RateSource('cdn.jsdelivr.net', (b) => _fawazPath('cdn.jsdelivr.net', b)),
    RateSource(
        'currency-api.pages.dev',
        (b) =>
            'https://latest.currency-api.pages.dev/v1/currencies/${b.toLowerCase()}.min.json'),
    RateSource(
        'api.frankfurter.dev',
        (b) =>
            'https://api.frankfurter.dev/v1/latest?base=${b.toUpperCase()}',
        isFrankfurter: true),
  ];

  final Dio _dio;

  /// 并发去抖表:key = base 大写。不同 base 各自独立,互不复用。
  final Map<String, Future<RateFetchResult>> _inflight = {};

  ExchangeRateService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.connectTimeout = _timeout;
    _dio.options.receiveTimeout = _timeout;
  }

  /// 并发去抖:同 base 进行中的请求直接复用(不同 base 各自独立)。
  ///
  /// 调用方须为后台静默刷新场景;6 源 × 4s 串行最坏 ~24s,勿在 UI 同步路径 await。
  Future<RateFetchResult> fetch(String base) {
    final key = base.toUpperCase();
    final inflight = _inflight[key];
    if (inflight != null) return inflight;
    final f = _fetchChain(base).whenComplete(() {
      _inflight.remove(key); // 丢弃返回值;Map.remove 返回 Future<V?>,若作为 whenComplete 返回值会造成循环等待。
    });
    _inflight[key] = f;
    return f;
  }

  Future<RateFetchResult> _fetchChain(String base) async {
    final prefs = await SharedPreferences.getInstance();
    final start =
        (prefs.getInt(_prefKeyLastSource) ?? 0).clamp(0, sources.length - 1);
    final errors = <String>[];
    for (var i = 0; i < sources.length; i++) {
      final idx = (start + i) % sources.length;
      final src = sources[idx];
      try {
        final resp = await _dio.get<Map<String, dynamic>>(src.url(base));
        final data = resp.data;
        if (data == null) throw RateFetchException('empty body');
        final result = src.isFrankfurter
            ? parseFrankfurter(base, data)
            : parseFawaz(base, data, source: src.id);
        await prefs.setInt(_prefKeyLastSource, idx);
        logger.info(
            'ExchangeRate',
            '汇率获取成功 source=${src.id} date=${result.rateDate} '
                'quotes=${result.ratesBaseToQuote.length}');
        return result;
      } catch (e) {
        errors.add('${src.id}: $e');
        logger.warning('ExchangeRate', '源失败,下滑: ${src.id}: $e');
      }
    }
    throw RateFetchException('全部源失败: ${errors.join('; ')}');
  }

  /// fawazahmed0:{"date":"2026-06-10","cny":{"usd":0.1477,...}} —— 键小写。
  static RateFetchResult parseFawaz(String base, Map<String, dynamic> data,
      {String source = 'fawazahmed0'}) {
    final date = data['date']?.toString() ?? '';
    final table = data[base.toLowerCase()];
    if (date.isEmpty || table is! Map) {
      throw RateFetchException('fawazahmed0 payload 结构异常');
    }
    final rates = <String, String>{
      for (final e in table.entries)
        if (e.value is num && (e.value as num) > 0)
          e.key.toString().toUpperCase(): e.value.toString(),
    };
    return RateFetchResult(rateDate: date, source: source, ratesBaseToQuote: rates);
  }

  /// frankfurter v1:{"base":"USD","date":"...","rates":{"CNY":6.77,...}} —— 键大写。
  static RateFetchResult parseFrankfurter(
      String base, Map<String, dynamic> data) {
    final date = data['date']?.toString() ?? '';
    final table = data['rates'];
    if (date.isEmpty || table is! Map) {
      throw RateFetchException('frankfurter payload 结构异常');
    }
    final rates = <String, String>{
      for (final e in table.entries)
        if (e.value is num && (e.value as num) > 0)
          e.key.toString().toUpperCase(): e.value.toString(),
    };
    return RateFetchResult(
        rateDate: date,
        source: 'api.frankfurter.dev',
        ratesBaseToQuote: rates);
  }
}
