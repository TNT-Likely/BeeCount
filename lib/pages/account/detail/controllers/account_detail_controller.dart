import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../data/db.dart';
import '../../../../data/repositories/base_repository.dart';

/// Route state only. All monetary totals and historical balances are read from
/// the existing repository; paging never defines the balance chart's history.
class AccountDetailController extends ChangeNotifier {
  AccountDetailController(
      {required this.repository, required this.account, DateTime? now})
      : anchor = now ?? DateTime.now();
  final BaseRepository repository;
  Account account;
  DateTime anchor;
  String period = 'month', query = '', sort = 'timeDesc';
  String? flow;
  List<Transaction> rows = [];
  List<({DateTime date, double balance})> history = [];
  Map<int, int> usage = {};
  List<Ledger> ledgers = [];
  ({int count, double income, double expense, DateTime? firstDate}) totals =
      (count: 0, income: 0, expense: 0, firstDate: null);
  ({double balance, double income, double expense}) stats =
      (balance: 0, income: 0, expense: 0);
  bool loading = true, loadingMore = false, hasMore = true, _disposed = false;
  Object? error;
  int _generation = 0;
  static const pageSize = 50;
  DateTime? get start => period == 'month'
      ? DateTime(anchor.year, anchor.month)
      : period == 'year'
          ? DateTime(anchor.year)
          : null;
  DateTime? get endExclusive => period == 'month'
      ? DateTime(anchor.year, anchor.month + 1)
      : period == 'year'
          ? DateTime(anchor.year + 1)
          : null;

  Future<void> refresh() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    if (!_disposed) notifyListeners();
    try {
      final loaded = await repository.getAccount(account.id);
      if (loaded == null) throw StateError('Account no longer exists');
      final nextStats = await repository.getAccountStats(account.id);
      final nextUsage = await repository.getAccountUsageInLedgers(account.id);
      final nextLedgers = await repository.getAllLedgers();
      final nextTotals = await repository.getAccountPeriodTotals(account.id,
          startDate: start, endExclusive: endExclusive);
      final nextRows = await _readRows(0);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final from = start ?? nextTotals.firstDate;
      final last = endExclusive == null
          ? today
          : DateTime(
              endExclusive!.year, endExclusive!.month, endExclusive!.day - 1);
      final through = last.isAfter(today) ? today : last;
      final points = from == null || from.isAfter(through)
          ? <({DateTime date, double balance})>[]
          : await repository.getAccountDailyBalances(account.id,
              startDate: DateTime(from.year, from.month, from.day),
              endDate: through);
      if (_disposed || generation != _generation) return;
      account = loaded;
      stats = nextStats;
      usage = nextUsage;
      ledgers = nextLedgers;
      totals = nextTotals;
      rows = nextRows;
      if (period == 'month') {
        history = points;
      } else {
        // Month-end snapshots, never income/expense or sampled list rows.
        final months = <(int, int), ({DateTime date, double balance})>{};
        for (final point in points) {
          months[(point.date.year, point.date.month)] = point;
        }
        history = months.values.toList();
      }
      loading = false;
      loadingMore = false;
      hasMore = nextRows.length == pageSize;
      notifyListeners();
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e;
        loading = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<List<Transaction>> _readRows(int offset) =>
      repository.getAccountTransactions(account.id,
          limit: pageSize,
          offset: offset,
          flow: flow,
          startDate: start,
          endExclusive: endExclusive,
          query: query,
          ascending: sort.endsWith('Asc'),
          orderByAmount: sort.startsWith('amount'));
  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore || _disposed) return;
    final generation = _generation;
    loadingMore = true;
    error = null;
    notifyListeners();
    try {
      final page = await _readRows(rows.length);
      if (_disposed || generation != _generation) return;
      rows = [...rows, ...page];
      hasMore = page.length == pageSize;
      loadingMore = false;
      notifyListeners();
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = e;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> choosePeriod(String value, {DateTime? date}) {
    period = value;
    if (date != null) anchor = date;
    return refresh();
  }

  Future<void> filter(
      {required String? direction,
      required String text,
      required String order}) {
    flow = direction;
    query = text;
    sort = order;
    return refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
