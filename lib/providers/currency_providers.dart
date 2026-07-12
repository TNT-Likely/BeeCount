import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/base_repository.dart';
import '../services/system/logger_service.dart';
import '../services/currency/rate_math.dart';
import '../services/currency/exchange_rate_service.dart';
import 'database_providers.dart';
import 'statistics_providers.dart';
import 'sync_providers.dart';

/// 多币种 MVP 的 provider 层(.docs/multi-currency/02-tech-design-app.md §五/§六)。
/// 主币种链照 displayName(theme_providers.dart:275-312)同款。

/// 用户主币种(大写 ISO code)。本地真值存 prefs 'baseCurrency';BeeCount Cloud
/// 模式下改动会推到 server,其余云模式 / 纯本地只存本地。
final baseCurrencyProvider = StateProvider<String>((ref) => 'CNY');

/// 汇率数据变更信号:拉取成功 / 手动编辑后 bump,触发 effectiveRates 重算。
final rateRefreshTickProvider = StateProvider<int>((ref) => 0);

final exchangeRateServiceProvider =
    Provider<ExchangeRateService>((ref) => ExchangeRateService());

/// 启动初始化:读 prefs;主币种未设置时按
/// ① Welcome 选币(selected_currency) → ② 当前账本币种 → ③ CNY 初始化。
final baseCurrencyInitProvider = FutureProvider<void>((ref) async {
  // WS profile 回流可能先于本 init 执行(写 provider+prefs):两种交错最终都收敛到
  // server 值,仅存在毫秒级 UI 闪烁窗口,自愈;详见 Task5+6 评审 I1。
  final prefs = await SharedPreferences.getInstance();
  var saved = prefs.getString('baseCurrency');
  if (saved == null || saved.isEmpty) {
    saved = prefs.getString('selected_currency');
    if (saved == null || saved.isEmpty) {
      saved = ref.read(currentLedgerProvider).valueOrNull?.currency;
    }
    if (saved == null || saved.isEmpty) saved = 'CNY';
    await prefs.setString('baseCurrency', saved);
  }
  ref.read(baseCurrencyProvider.notifier).state = saved.toUpperCase();

  ref.listen<String>(baseCurrencyProvider, (prev, next) async {
    await prefs.setString('baseCurrency', next);
    _pushBaseCurrencyToCloud(ref, next);
  });
});

/// 把主币种推给 server 的 /profile/me(仅 BeeCount Cloud 模式)。非 cloud 模式
/// provider 返回 null 直接跳过。fire-and-forget,失败只打 warning。照
/// _pushDisplayNameToCloud(theme_providers.dart)的写法。
void _pushBaseCurrencyToCloud(Ref ref, String code) {
  final normalized = code.trim().toUpperCase();
  if (normalized.isEmpty) return;
  unawaited(() async {
    try {
      final cloudProvider =
          await ref.read(beecountCloudProviderInstance.future);
      if (cloudProvider == null) return;
      await cloudProvider.updateMyProfileBaseCurrency(
          primaryCurrency: normalized);
      logger.info(
          'currency_providers', 'primary currency pushed to server: $normalized');
    } catch (e, st) {
      logger.warning('currency_providers',
          'push primary currency failed (non-blocking): $e', st);
    }
  }());
}

/// 使用中币种 ∪ {主币种}(大写)。watch statsRefresh 跟随账户增删改。
final usedCurrenciesProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(statsRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  final used = await repo.getUsedCurrencies();
  used.add(ref.watch(baseCurrencyProvider).toUpperCase());
  return used;
});

/// 多币种态总闸(README D6):使用中币种 ≥2 即恒为折算态,与 Web 端对齐。
/// 原「按主币种折算」开关已下线(默认折算),不再有「非折算多币种」态。
final multiCurrencyActiveProvider = Provider<bool>((ref) {
  final used = ref.watch(usedCurrenciesProvider).valueOrNull;
  return used != null && used.length >= 2;
});

/// 有效汇率:手动 > 最新自动;缺失显式缺失(D5)。
final effectiveRatesProvider =
    FutureProvider<Map<String, EffectiveRate>>((ref) async {
  ref.watch(rateRefreshTickProvider);
  ref.watch(statsRefreshProvider); // 同步 pull 应用 override 后随全局刷新信号重算
  final base = ref.watch(baseCurrencyProvider).toUpperCase();
  final repo = ref.watch(repositoryProvider);
  final autos = await repo.getLatestAutoRates(base);
  final overrides = await repo.getOverrides(base);
  return mergeEffectiveRates(
    autoRates: [
      for (final r in autos)
        (quote: r.quoteCurrency, rate: r.rate, rateDate: r.rateDate)
    ],
    overrides: [
      for (final o in overrides) (quote: o.quoteCurrency, rate: o.rate)
    ],
  );
});

/// 币种选择弹窗的展示汇率:1 该币种 ≈ ? base。拉一次全量(fawaz base→quote
/// 全量返回),手动 override 优先。仅展示用,不落库。family key = base(大写)。
/// 值 = 「1 quote 币种 = value base」(便于 UI 显示 1 JPY ≈ 0.048 CNY)。
final currencyPickerRatesProvider =
    FutureProvider.family<Map<String, double>, String>((ref, base) async {
  ref.watch(rateRefreshTickProvider);
  final baseUp = base.toUpperCase();
  final repo = ref.watch(repositoryProvider);
  final out = <String, double>{};
  // 先公网/服务端全量(1 base = y quote → 1 quote = 1/y base)
  try {
    final result = await ref.read(exchangeRateServiceProvider).fetch(baseUp);
    for (final e in result.ratesBaseToQuote.entries) {
      final y = double.tryParse(e.value);
      if (y != null && y > 0) out[e.key.toUpperCase()] = 1 / y;
    }
  } catch (_) {/* 拉不到就只用本地 override,下方覆盖 */}
  // 手动 override 覆盖(1 quote = rate base,直接用)
  try {
    for (final o in await repo.getOverrides(baseUp)) {
      final r = double.tryParse(o.rate);
      if (r != null && r > 0) out[o.quoteCurrency.toUpperCase()] = r;
    }
  } catch (_) {}
  return out;
});

/// 当前账本本位币(ISO 大写)。`ledger.currency` 的语义化别名——交易级多币种后
/// 它的语义是「账本统计折算的目标币种」(.docs/multi-currency-ledger L1)。
final currentLedgerCurrencyProvider = Provider<String>((ref) {
  final ledger = ref.watch(currentLedgerProvider).valueOrNull;
  final c = ledger?.currency;
  return (c == null || c.isEmpty) ? 'CNY' : c.toUpperCase();
});

/// 以**账本本位币**为 base 的有效汇率(账户/交易币种 → 账本本位币)。
/// 结构同 [effectiveRatesProvider],仅 base 从用户主币种换成账本本位币;
/// 两者默认相同(新账本本位币默认=主币种),不同账本切换时自动重算。
/// 记账折算(computeNativeAmount)用这组。
final effectiveRatesForLedgerProvider =
    FutureProvider<Map<String, EffectiveRate>>((ref) async {
  ref.watch(rateRefreshTickProvider);
  ref.watch(statsRefreshProvider);
  final base = ref.watch(currentLedgerCurrencyProvider);
  final repo = ref.watch(repositoryProvider);
  final autos = await repo.getLatestAutoRates(base);
  final overrides = await repo.getOverrides(base);
  return mergeEffectiveRates(
    autoRates: [
      for (final r in autos)
        (quote: r.quoteCurrency, rate: r.rate, rateDate: r.rateDate)
    ],
    overrides: [
      for (final o in overrides) (quote: o.quoteCurrency, rate: o.rate)
    ],
  );
});

/// 当前账本「未折算外币交易」条数(L11 检测):>0 时统计页显示补折算横幅。
/// watch statsRefresh(重算完成/交易变动后重查)。
final ledgerUnconvertedForeignTxCountProvider = FutureProvider<int>((ref) async {
  ref.watch(statsRefreshProvider);
  ref.watch(rateRefreshTickProvider);
  final ledger = ref.watch(currentLedgerProvider).valueOrNull;
  if (ledger == null) return 0;
  final repo = ref.watch(repositoryProvider);
  return repo.countUnconvertedForeignTx(ledger.id);
});

/// 当前账本外币交易条数(含已折算):>0 时账本统计页显示折算脚注(01 §五)。
final ledgerForeignTxCountProvider = FutureProvider<int>((ref) async {
  ref.watch(statsRefreshProvider);
  final ledger = ref.watch(currentLedgerProvider).valueOrNull;
  if (ledger == null) return 0;
  final repo = ref.watch(repositoryProvider);
  return repo.countForeignCurrencyTx(ledger.id);
});

/// 资产页折算结果。
final convertedNetWorthProvider =
    FutureProvider<ConvertedNetWorth>((ref) async {
  final breakdown = await ref.watch(netWorthBreakdownByCurrencyProvider.future);
  final rates = await ref.watch(effectiveRatesProvider.future);
  final base = ref.watch(baseCurrencyProvider).toUpperCase();
  return computeConvertedNetWorth(breakdown: breakdown, rates: rates, base: base);
});

/// 折算后的资产构成:每 (type, currency) 原币余额 × 汇率 → 按 type 聚合(主币种值)。
/// 缺汇率的币种整条剔除(绝不按 1.0,与净资产/分组小计一致,README D5)。
/// 多币种折算态喂给 [AssetCompositionChart](入参类型与 [assetCompositionProvider] 相同)。
final convertedAssetCompositionProvider =
    FutureProvider<List<({String type, double totalBalance})>>((ref) async {
  final rates = await ref.watch(effectiveRatesProvider.future);
  final base = ref.watch(baseCurrencyProvider).toUpperCase();
  ref.watch(statsRefreshProvider);
  ref.watch(rateRefreshTickProvider);
  final repo = ref.watch(repositoryProvider);
  final rows = await repo.getAssetCompositionByTypeAndCurrency();

  final byType = <String, double>{};
  for (final r in rows) {
    final code = r.currency.toUpperCase();
    double? rate;
    if (code == base) {
      rate = 1.0;
    } else {
      final eff = rates[code];
      if (eff != null) rate = double.tryParse(eff.rate);
    }
    if (rate == null || rate <= 0) continue; // 缺汇率剔除
    byType.update(r.type, (v) => v + r.totalBalance * rate!,
        ifAbsent: () => r.totalBalance * rate!);
  }
  return byType.entries
      .map((e) => (type: e.key, totalBalance: e.value))
      .toList();
});

/// 拉取协调:server 源(云模式)→ 公网链;倒数后只落「使用中币种」;成功 bump tick。
/// force=false 时 24h 节流 + 多币种总闸(D6/D7)。失败返回 false(资产页静默、汇率页 Toast)。
///
/// Ref 版入口当前无调用方,保留给后台/provider 语境的未来调用
/// (如周期刷新、启动预拉);UI 层用 [refreshExchangeRatesFromUi]。
Future<bool> refreshExchangeRates(Ref ref,
        {bool force = false, Set<String>? extraQuotes}) =>
    _refreshExchangeRatesImpl(
      read: ref.read,
      readFuture: <T>(p) => ref.read(p.future),
      force: force,
      extraQuotes: extraQuotes,
    );

/// UI 层薄封装:`WidgetRef` 与 `Ref` 的 read 能力等价,直接转发到同一实现。
/// ConsumerState 里只有 `WidgetRef`,无法 cast 成 `Ref`,故单开此入口。
Future<bool> refreshExchangeRatesFromUi(WidgetRef ref,
        {bool force = false, Set<String>? extraQuotes}) =>
    _refreshExchangeRatesImpl(
      read: ref.read,
      readFuture: <T>(p) => ref.read(p.future),
      force: force,
      extraQuotes: extraQuotes,
    );

/// 真正的实现:只依赖 read / readFuture 两个能力,与 Ref / WidgetRef 解耦。
///
/// 交易级多币种(Q1):base 集合 = {用户主币种} ∪ {各账本本位币}——账本本位币
/// ≠ 主币种时(如「美漂生活」账本用 USD),记账折算需要以该本位币为 base 的
/// 汇率组。默认所有账本本位币 == 主币种 → 集合仅一个,行为与 MVP 完全一致。
/// [extraQuotes]:额外要拉的币种(v30 记账页手选币种,L12)——手选币种不在
/// usedCurrencies(账户币种∪主币种)里,不带上它拉回来的组里永远没有它。
Future<bool> _refreshExchangeRatesImpl({
  required T Function<T>(ProviderListenable<T>) read,
  required Future<T> Function<T>(FutureProvider<T>) readFuture,
  required bool force,
  Set<String>? extraQuotes,
}) async {
  try {
    final repo = read(repositoryProvider);

    // base 集合:主币种 ∪ 各账本本位币(大写)
    final bases = <String>{read(baseCurrencyProvider).toUpperCase()};
    try {
      final ledgers = await repo.getAllLedgers();
      bases.addAll(ledgers
          .map((l) => l.currency.toUpperCase())
          .where((c) => c.isNotEmpty));
    } catch (e) {
      logger.warning('currency_providers', '读取账本本位币集合失败(仅拉主币种): $e');
    }

    // 需要折算的币种全集:使用中币种 ∪ 各 base(外币本位币账本即使还没有
    // 外币账户,也要能把使用中币种折过去)。
    final usedAll = (await readFuture(usedCurrenciesProvider)).toSet()
      ..addAll(bases)
      ..addAll((extraQuotes ?? const {}).map((c) => c.toUpperCase()));
    // 总闸(D6 扩展):全集 <2 说明纯单币种(账本本位币也全一致),无需汇率。
    if (!force && usedAll.length < 2) return false;

    var anySuccess = false;
    for (final base in bases) {
      final quotes = usedAll.toSet()..remove(base);
      if (quotes.isEmpty) continue;
      if (!force) {
        final last = await repo.getLastFetchedAt(base);
        if (last != null &&
            DateTime.now().toUtc().difference(last) <
                const Duration(hours: 24)) {
          anySuccess = true; // 未过期视作成功,无需拉取
          continue;
        }
      }
      if (await _fetchAndStoreRatesForBase(
          read: read,
          readFuture: readFuture,
          repo: repo,
          base: base,
          quotes: quotes)) {
        anySuccess = true;
      }
    }
    if (anySuccess) read(rateRefreshTickProvider.notifier).state++;
    return anySuccess;
  } catch (e, st) {
    logger.warning('currency_providers', '汇率刷新失败: $e', st);
    return false;
  }
}

/// 拉取并落库单个 base 的汇率(原单 base 实现拆出,循环体复用)。
Future<bool> _fetchAndStoreRatesForBase({
  required T Function<T>(ProviderListenable<T>) read,
  required Future<T> Function<T>(FutureProvider<T>) readFuture,
  required BaseRepository repo,
  required String base,
  required Set<String> quotes,
}) async {
  try {
    String rateDate, source;
    Map<String, String> baseToQuote;
    Map<String, dynamic>? serverBody;
    try {
      final cloudProvider = await readFuture(beecountCloudProviderInstance);
      serverBody = cloudProvider == null
          ? null
          : await cloudProvider.fetchExchangeRates(base: base);
    } catch (e) {
      logger.warning('currency_providers', 'server 汇率源失败,下滑公网: $e');
      serverBody = null;
    }
    // serverBody['stale'] 有意不消费:rateDate 如实落库(UI 日期不撒谎),代价是
    // stale 数据会被 24h 节流当新鲜缓存一天;有 force 刷新兜底,MVP 接受。
    final rawRateDate = serverBody?['rate_date']?.toString() ?? '';
    if (serverBody != null &&
        serverBody['rates'] is Map &&
        rawRateDate.isNotEmpty) {
      rateDate = rawRateDate;
      source = 'server';
      baseToQuote = {
        for (final e in (serverBody['rates'] as Map).entries)
          e.key.toString().toUpperCase(): e.value.toString(),
      };
    } else {
      final result = await read(exchangeRateServiceProvider).fetch(base);
      rateDate = result.rateDate;
      source = result.source;
      baseToQuote = result.ratesBaseToQuote;
    }

    // 倒数成「1 quote = x base」,只保留需要的币种
    final inverted = <String, String>{};
    for (final code in quotes) {
      final raw = double.tryParse(baseToQuote[code] ?? '');
      if (raw != null && raw > 0) inverted[code] = invertRate(raw);
    }
    if (inverted.isEmpty) return false;
    await repo.upsertAutoRates(
      base: base,
      rateDate: rateDate,
      rates: inverted,
      source: source,
      fetchedAt: DateTime.now().toUtc(),
    );
    return true;
  } catch (e, st) {
    logger.warning('currency_providers', 'base=$base 汇率拉取失败: $e', st);
    return false;
  }
}
