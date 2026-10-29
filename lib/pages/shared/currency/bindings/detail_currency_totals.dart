import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/db.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../providers.dart';
import '../../../../utils/currencies.dart' show kCurrencyCodes;
import '../../../../services/currency/rate_math.dart';

/// Read-only query context. Rates keep the global convention: 1 quote = rate
/// target/base. Transaction fields and historical snapshots are never written.
class DetailCurrencyContext {
  const DetailCurrencyContext(
      {required this.targetLedgerId,
      required this.targetCurrency,
      required this.ledgers,
      required this.rates});
  final int? targetLedgerId;
  final String? targetCurrency;
  final Map<int, Ledger> ledgers;
  final Map<String, EffectiveRate> rates;
}

Future<Map<String, EffectiveRate>> _effective(
    BaseRepository repo, String base) async {
  final autos = await repo.getLatestAutoRates(base),
      overrides = await repo.getOverrides(base);
  return mergeEffectiveRates(autoRates: [
    for (final row in autos)
      (quote: row.quoteCurrency, rate: row.rate, rateDate: row.rateDate)
  ], overrides: [
    for (final row in overrides) (quote: row.quoteCurrency, rate: row.rate)
  ]);
}

Future<DetailCurrencyContext> loadDetailCurrencyContext(
    BaseRepository repository,
    {required int? targetLedgerId,
    List<Ledger>? sourceLedgers}) async {
  final books = sourceLedgers ?? await repository.getAllLedgers();
  final byId = {for (final book in books) book.id: book};
  final target = targetLedgerId == null
      ? (books.isEmpty ? null : books.first)
      : byId[targetLedgerId];
  final targetCurrency = target?.currency.trim().toUpperCase();
  if (targetCurrency == null || !kCurrencyCodes.contains(targetCurrency)) {
    return DetailCurrencyContext(
        targetLedgerId: targetLedgerId,
        targetCurrency: null,
        ledgers: byId,
        rates: const {});
  }
  final rates = await _effective(repository, targetCurrency);
  final sources = books
      .map((book) => book.currency.trim().toUpperCase())
      .where((code) => code.isNotEmpty && code != targetCurrency)
      .toSet();
  for (final source in sources) {
    // A direct quote (including an invalid manual override) retains priority.
    if (rates.containsKey(source)) continue;
    final reverse = (await _effective(repository, source))[targetCurrency];
    final raw = reverse == null ? null : double.tryParse(reverse.rate);
    if (raw != null && raw.isFinite && raw > 0) {
      rates[source] = EffectiveRate(
          rate: invertRate(raw),
          manual: reverse!.manual,
          rateDate: reverse.rateDate);
    }
  }
  // Global rate helpers accept decimal strings; explicitly reject non-finite
  // legacy values before invoking them so NaN/Infinity cannot become a total.
  rates.removeWhere((_, rate) {
    final value = double.tryParse(rate.rate);
    return value == null || !value.isFinite || value <= 0;
  });
  return DetailCurrencyContext(
      targetLedgerId: target?.id,
      targetCurrency: targetCurrency,
      ledgers: byId,
      rates: Map.unmodifiable(rates));
}

final detailCurrencyContextProvider =
    FutureProvider.autoDispose<DetailCurrencyContext>((ref) {
  final targetId = ref.watch(currentLedgerIdProvider);
  ref.watch(currentLedgerProvider);
  ref.watch(rateRefreshTickProvider);
  ref.watch(statsRefreshProvider);
  ref.watch(syncGenerationProvider);
  return loadDetailCurrencyContext(ref.watch(repositoryProvider),
      targetLedgerId: targetId);
});

class DetailCurrencyProjection {
  const DetailCurrencyProjection(
      {required this.context,
      required this.amounts,
      required this.missingIds,
      required this.missingCurrencies,
      required this.oldestRateDate,
      required this.hasForeignSources});
  final DetailCurrencyContext context;
  final Map<int, double> amounts;
  final Set<int> missingIds;

  /// '?' means that the source ledger/currency is unavailable. A -> B denotes a
  /// missing historical native snapshot for a foreign transaction in ledger B.
  final List<String> missingCurrencies;
  final String? oldestRateDate;
  final bool hasForeignSources;
  String? get targetCurrency => context.targetCurrency;
  int get missingCount => missingIds.length;
  bool get complete => missingIds.isEmpty && targetCurrency != null;
  bool isStaleAt(DateTime now) {
    final date = DateTime.tryParse(oldestRateDate ?? '');
    return date != null && now.difference(date) > const Duration(days: 7);
  }

  double? total(Iterable<Transaction> transactions) {
    var sum = 0.0;
    for (final transaction in transactions) {
      final value = amounts[transaction.id];
      if (value == null) return null;
      sum += value;
      if (!sum.isFinite) return null;
    }
    return sum;
  }
}

DetailCurrencyProjection projectDetailCurrencyTransactions(
    DetailCurrencyContext context, Iterable<Transaction> transactions) {
  final values = <int, double>{},
      missingIds = <int>{},
      missingCurrencies = <String>{};
  String? oldest;
  var foreign = false;
  for (final transaction in transactions) {
    final source =
        context.ledgers[transaction.ledgerId]?.currency.trim().toUpperCase();
    final target = context.targetCurrency;
    void missing(String code) {
      missingIds.add(transaction.id);
      missingCurrencies.add(code);
    }

    if (source == null || !kCurrencyCodes.contains(source) || target == null) {
      missing('?');
      continue;
    }
    if (source != target) foreign = true;
    final original = transaction.currencyCode?.trim().toUpperCase();
    if (original != null &&
        original.isNotEmpty &&
        !kCurrencyCodes.contains(original)) {
      missing(original);
      continue;
    }
    var native = transaction.nativeAmount;
    if (native == null) {
      // Null/empty original currency is the database's legacy implicit ledger
      // currency. Explicit foreign currency always requires its native snapshot.
      if (original != null && original.isNotEmpty && original != source) {
        missing('$original→$source');
        continue;
      }
      native = transaction.amount;
    }
    if (!native.isFinite) {
      missing(source);
      continue;
    }
    final result = convertAmountsToBase(
        amounts: {source: native}, rates: context.rates, base: target);
    if (result.missingCurrencies.isNotEmpty || !result.total.isFinite) {
      missing(source);
      continue;
    }
    values[transaction.id] = result.total;
    if (source != target) {
      final date = context.rates[source]?.rateDate;
      if (date != null &&
          DateTime.tryParse(date) != null &&
          (oldest == null || date.compareTo(oldest) < 0)) {
        oldest = date;
      }
    }
  }
  final codes = missingCurrencies.toList()..sort();
  return DetailCurrencyProjection(
      context: context,
      amounts: Map.unmodifiable(values),
      missingIds: Set.unmodifiable(missingIds),
      missingCurrencies: List.unmodifiable(codes),
      oldestRateDate: oldest,
      hasForeignSources: foreign);
}
