import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../../../data/db.dart';
import '../../../data/repositories/base_repository.dart';
import 'transaction_search.dart' show SearchTransaction;
import 'detail_currency_totals.dart';

enum CategoryDetailSort { timeAsc, timeDesc, amountAsc, amountDesc }

enum CategoryDetailPeriod { month, year, all, custom }

/// The same repository supplies historical snapshots and hydrated shared IDs.
/// Historical native snapshots are retained; query-time cross-ledger display
/// conversion never changes a transaction.
class CategoryDetailController extends ChangeNotifier {
  CategoryDetailController(
      {required this.repository,
      required this.categoryId,
      required this.ledgerId,
      int? summaryLedgerId,
      this.initialStart,
      this.initialEnd,
      DateTime? now})
      : summaryLedgerId = summaryLedgerId ?? ledgerId,
        anchor = initialStart ?? now ?? DateTime.now(),
        period = initialStart != null && initialEnd != null
            ? CategoryDetailPeriod.custom
            : CategoryDetailPeriod.all {
    if (initialStart != null && initialEnd != null) {
      final start = initialStart!, end = initialEnd!;
      if (start == DateTime(start.year) && end == DateTime(start.year + 1)) {
        period = CategoryDetailPeriod.year;
      } else if (start == DateTime(start.year, start.month) &&
          end == DateTime(start.year, start.month + 1)) {
        period = CategoryDetailPeriod.month;
      }
    }
  }
  final BaseRepository repository;
  final int categoryId;
  final int? ledgerId;
  int? summaryLedgerId;
  DetailCurrencyContext? _currencyContext;
  DetailCurrencyProjection? currencyProjection;
  bool shareComplete = true;
  bool get summaryComplete => currencyProjection?.complete ?? false;
  String? get summaryCurrency => currencyProjection?.targetCurrency;
  final DateTime? initialStart, initialEnd;
  DateTime anchor;
  CategoryDetailPeriod period;
  CategoryDetailSort sort = CategoryDetailSort.timeDesc;
  Category? category, parent;
  List<Category> children = [];
  List<SearchTransaction> rows = [], _all = [];
  Map<int, List<Tag>> tags = {};
  Map<int, int> attachments = {};
  Map<int, Ledger> ledgers = {};
  Map<int, double> childAmounts = {};
  List<double> trend = [];
  List<DateTime> trendDates = [];
  int count = 0;
  double amount = 0, average = 0, share = 0;
  bool loading = true,
      _disposed = false,
      _rowsReady = false,
      _categoryReady = false;
  Object? error;
  int _generation = 0, _resourceGeneration = 0;
  StreamSubscription<List<SearchTransaction>>? _transactions;
  StreamSubscription<Category?>? _category;
  Set<String> get currencies =>
      rows.map((row) => ledgers[row.t.ledgerId]?.currency ?? 'CNY').toSet();

  Future<void> start() async {
    try {
      category = await repository.getCategoryById(categoryId);
      await _resources(++_resourceGeneration);
      if (_disposed) return;
      _category = repository.watchCategory(categoryId).listen((value) {
        category = value;
        unawaited(refreshResources());
      }, onError: _fail);
      _transactions = repository
          .transactionsWithCategoryAll(ledgerId: ledgerId)
          .listen((values) {
        _all = values;
        _rowsReady = true;
        unawaited(_refresh());
      }, onError: _fail);
    } catch (e) {
      _fail(e);
    }
  }

  Future<bool> _resources(int generation) async {
    final categories = await repository.getAllCategoriesIncludingShared();
    final books = await repository.getAllLedgers();
    final currencyContext = await loadDetailCurrencyContext(repository,
        targetLedgerId: summaryLedgerId, sourceLedgers: books);
    if (_disposed || generation != _resourceGeneration) return false;
    parent = categories.where((c) => c.id == category?.parentId).firstOrNull;
    children = categories
        .where((c) => c.parentId == categoryId && c.kind == category?.kind)
        .toList();
    ledgers = {for (final book in books) book.id: book};
    _currencyContext = currencyContext;
    return true;
  }

  Future<void> setSummaryLedger(int ledgerId) async {
    if (summaryLedgerId == ledgerId) return;
    summaryLedgerId = ledgerId;
    loading = true;
    await refreshResources();
  }

  Future<void> refreshResources() async {
    final resourceGeneration = ++_resourceGeneration;
    try {
      ++_generation;
      _categoryReady = false;
      final loaded = await _resources(resourceGeneration);
      if (!_disposed && loaded) {
        _categoryReady = true;
        await _refresh();
      }
    } catch (e) {
      if (resourceGeneration == _resourceGeneration) _fail(e);
    }
  }

  ({DateTime? start, DateTime? end}) get range => switch (period) {
        CategoryDetailPeriod.all => (start: null, end: null),
        CategoryDetailPeriod.custom => (start: initialStart, end: initialEnd),
        CategoryDetailPeriod.month => (
            start: DateTime(anchor.year, anchor.month),
            end: DateTime(anchor.year, anchor.month + 1)
          ),
        CategoryDetailPeriod.year => (
            start: DateTime(anchor.year),
            end: DateTime(anchor.year + 1)
          ),
      };
  void choosePeriod(CategoryDetailPeriod value) {
    period = value;
    unawaited(_refresh());
  }

  void chooseSort(CategoryDetailSort value) {
    sort = value;
    unawaited(_refresh());
  }

  void chooseAnchor(DateTime value) {
    anchor = DateTime(value.year, value.month);
    unawaited(_refresh());
  }

  Future<void> refreshRows() => _refresh();
  Future<void> _refresh() async {
    if (!_rowsReady ||
        !_categoryReady ||
        _disposed ||
        _currencyContext == null) {
      return;
    }
    final generation = ++_generation;
    try {
      final scope = range;
      final inRange = _all
          .where((r) =>
              (scope.start == null || !r.t.happenedAt.isBefore(scope.start!)) &&
              (scope.end == null || r.t.happenedAt.isBefore(scope.end!)))
          .toList();
      final family = {categoryId, ...children.map((c) => c.id)};
      final selected =
          inRange.where((r) => family.contains(r.category?.id)).toList();
      final ids = selected.map((r) => r.t.id).toList();
      final rowTags = await repository.getTagsForTransactions(ids);
      final counts = await repository.getAttachmentCountsForTransactions(ids);
      if (_disposed || generation != _generation) return;
      selected.sort((a, b) => switch (sort) {
            CategoryDetailSort.timeAsc =>
              a.t.happenedAt.compareTo(b.t.happenedAt),
            CategoryDetailSort.timeDesc =>
              b.t.happenedAt.compareTo(a.t.happenedAt),
            CategoryDetailSort.amountAsc => a.t.amount.compareTo(b.t.amount),
            CategoryDetailSort.amountDesc => b.t.amount.compareTo(a.t.amount),
          });
      rows = selected;
      tags = rowTags;
      attachments = counts;
      count = selected.length;
      final currency = _currencyContext!;
      final converted = projectDetailCurrencyTransactions(
          currency, selected.map((row) => row.t));
      currencyProjection = converted;
      amount = converted.total(selected.map((row) => row.t)) ?? 0;
      average = count == 0 ? 0 : amount / count;
      final denominator = parent == null
          ? inRange.where((row) => row.t.type == category?.kind)
          : inRange.where((row) =>
              row.category?.id == parent!.id ||
              row.category?.parentId == parent!.id);
      final denominatorRows = denominator.toList();
      final denominatorProjection = projectDetailCurrencyTransactions(
          currency, denominatorRows.map((row) => row.t));
      final base =
          denominatorProjection.total(denominatorRows.map((row) => row.t));
      shareComplete =
          converted.complete && denominatorProjection.complete && base != null;
      share = shareComplete && base != 0 ? amount / base! : 0;
      childAmounts = {
        for (final child in children)
          child.id: converted.total(selected
                  .where((row) => row.category?.id == child.id)
                  .map((row) => row.t)) ??
              0
      };
      final buckets = <DateTime, double>{};
      for (final row in selected) {
        final date = row.t.happenedAt;
        final key = period == CategoryDetailPeriod.month
            ? DateTime(date.year, date.month, date.day)
            : DateTime(date.year, date.month);
        buckets[key] = (buckets[key] ?? 0) + (converted.amounts[row.t.id] ?? 0);
      }
      final dates = buckets.keys.toList()..sort();
      trendDates = dates;
      var running = 0.0;
      trend = converted.complete
          ? dates.map((date) => running += buckets[date]!).toList()
          : [];
      loading = false;
      error = null;
      notifyListeners();
    } catch (e) {
      if (generation == _generation) _fail(e);
    }
  }

  void _fail(Object e) {
    if (_disposed) return;
    loading = false;
    error = e;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_transactions?.cancel());
    unawaited(_category?.cancel());
    super.dispose();
  }
}
