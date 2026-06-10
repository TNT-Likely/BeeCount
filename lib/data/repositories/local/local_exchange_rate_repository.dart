import 'package:drift/drift.dart' as d;
import 'package:uuid/uuid.dart';

import '../../../cloud/sync/change_tracker.dart';
import '../../db.dart';
import '../exchange_rate_repository.dart';

/// Drift 实现。tracker 用 getter 闭包注入:LocalRepository.changeTracker 是
/// 可变字段(构造后才赋值),直接传引用会捕获 null —— 2026-04 的 orphan-change
/// 坑就是这类时序问题,闭包取值规避。
class LocalExchangeRateRepository implements ExchangeRateRepository {
  static const _uuid = Uuid();
  final BeeDatabase db;
  final ChangeTracker? Function() trackerGetter;

  LocalExchangeRateRepository(this.db, {required this.trackerGetter});

  @override
  Future<void> upsertAutoRates({
    required String base,
    required String rateDate,
    required Map<String, String> rates,
    required String source,
    required DateTime fetchedAt,
  }) async {
    final baseUp = base.toUpperCase();
    await db.batch((b) {
      for (final e in rates.entries) {
        b.insert(
          db.exchangeRates,
          ExchangeRatesCompanion.insert(
            baseCurrency: baseUp,
            quoteCurrency: e.key.toUpperCase(),
            rateDate: rateDate,
            rate: e.value,
            source: source,
            fetchedAt: fetchedAt,
          ),
          onConflict: d.DoUpdate((_) => ExchangeRatesCompanion(
            rate: d.Value(e.value),
            source: d.Value(source),
            fetchedAt: d.Value(fetchedAt),
          )),
        );
      }
    });
    // 注意:自动汇率绝不记 change(README D2),测试有红线断言。
  }

  @override
  Future<List<ExchangeRate>> getLatestAutoRates(String base) async {
    final rows = await (db.select(db.exchangeRates)
          ..where((t) => t.baseCurrency.equals(base.toUpperCase()))
          ..orderBy([
            (t) => d.OrderingTerm.asc(t.quoteCurrency),
            (t) => d.OrderingTerm.desc(t.rateDate),
          ]))
        .get();
    final latest = <String, ExchangeRate>{};
    for (final r in rows) {
      latest.putIfAbsent(r.quoteCurrency, () => r); // 排序后每 quote 第一行即最新
    }
    return latest.values.toList();
  }

  @override
  Future<DateTime?> getLastFetchedAt(String base) async {
    final row = await (db.select(db.exchangeRates)
          ..where((t) => t.baseCurrency.equals(base.toUpperCase()))
          ..orderBy([(t) => d.OrderingTerm.desc(t.fetchedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row?.fetchedAt;
  }

  @override
  Future<List<ExchangeRateOverride>> getOverrides(String base) {
    return (db.select(db.exchangeRateOverrides)
          ..where((t) => t.baseCurrency.equals(base.toUpperCase()))
          ..orderBy([(t) => d.OrderingTerm.asc(t.quoteCurrency)]))
        .get();
  }

  @override
  Stream<List<ExchangeRateOverride>> watchOverrides(String base) {
    return (db.select(db.exchangeRateOverrides)
          ..where((t) => t.baseCurrency.equals(base.toUpperCase()))
          ..orderBy([(t) => d.OrderingTerm.asc(t.quoteCurrency)]))
        .watch();
  }

  @override
  Future<void> setOverride({
    required String base,
    required String quote,
    required String rate,
  }) async {
    final baseUp = base.toUpperCase();
    final quoteUp = quote.toUpperCase();
    final existing = await (db.select(db.exchangeRateOverrides)
          ..where((t) =>
              t.baseCurrency.equals(baseUp) & t.quoteCurrency.equals(quoteUp)))
        .getSingleOrNull();
    final now = DateTime.now().toUtc();
    if (existing == null) {
      final syncId = _uuid.v4();
      final id = await db.into(db.exchangeRateOverrides).insert(
            ExchangeRateOverridesCompanion.insert(
              baseCurrency: baseUp,
              quoteCurrency: quoteUp,
              rate: rate,
              syncId: d.Value(syncId),
              updatedAt: d.Value(now),
            ),
          );
      await trackerGetter()?.recordUserGlobalChange(
        entityType: 'exchange_rate_override',
        entityId: id,
        entitySyncId: syncId,
        action: 'create',
      );
    } else {
      final syncId = existing.syncId ?? _uuid.v4();
      await (db.update(db.exchangeRateOverrides)
            ..where((t) => t.id.equals(existing.id)))
          .write(ExchangeRateOverridesCompanion(
        rate: d.Value(rate),
        syncId: d.Value(syncId),
        updatedAt: d.Value(now),
      ));
      await trackerGetter()?.recordUserGlobalChange(
        entityType: 'exchange_rate_override',
        entityId: existing.id,
        entitySyncId: syncId,
        action: 'update',
      );
    }
  }

  @override
  Future<void> removeOverride({required String base, required String quote}) async {
    final existing = await (db.select(db.exchangeRateOverrides)
          ..where((t) =>
              t.baseCurrency.equals(base.toUpperCase()) &
              t.quoteCurrency.equals(quote.toUpperCase())))
        .getSingleOrNull();
    if (existing == null) return;
    await (db.delete(db.exchangeRateOverrides)
          ..where((t) => t.id.equals(existing.id)))
        .go();
    final syncId = existing.syncId;
    if (syncId != null) {
      await trackerGetter()?.recordUserGlobalChange(
        entityType: 'exchange_rate_override',
        entityId: existing.id,
        entitySyncId: syncId,
        action: 'delete',
      );
    }
  }
}
