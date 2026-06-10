import '../db.dart';

/// 汇率数据访问(多币种 MVP)。
/// 方向约定全链统一:rate 字符串 = 「1 quote = rate base」。
/// 自动汇率(exchange_rates)是本地缓存,不进同步;手动覆盖
/// (exchange_rate_overrides)是 user-global 同步实体(README D2/D9)。
abstract class ExchangeRateRepository {
  /// 落一批自动汇率(同 base 同 rateDate),内部 upsert,同日重拉覆盖。
  Future<void> upsertAutoRates({
    required String base,
    required String rateDate,
    required Map<String, String> rates, // quote(大写) -> decimal 字符串
    required String source,
    required DateTime fetchedAt,
  });

  /// 每个 quote 取 rateDate 最新一行。
  Future<List<ExchangeRate>> getLatestAutoRates(String base);

  /// 该 base 最近一次成功拉取时间(节流用),无记录返回 null。
  Future<DateTime?> getLastFetchedAt(String base);

  Future<List<ExchangeRateOverride>> getOverrides(String base);
  Stream<List<ExchangeRateOverride>> watchOverrides(String base);

  /// 币对 upsert:已存在则更新并复用 syncId;记 user-global change。
  Future<void> setOverride({required String base, required String quote, required String rate});

  /// 删除并记 delete change;不存在则 no-op。
  Future<void> removeOverride({required String base, required String quote});
}
