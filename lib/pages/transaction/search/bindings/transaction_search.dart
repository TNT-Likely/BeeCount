import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier, immutable;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/db.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../data/repositories/local/local_repository.dart';
import '../../../../utils/shared_ledger_picker_filter.dart';

typedef SearchTransaction = ({
  Transaction t,
  Category? category,
  Account? account,
  Account? toAccount
});

enum SearchAmountBasis { original, ledger }

@immutable
class TransactionSearchFilter {
  const TransactionSearchFilter(
      {this.category,
      this.accountId,
      this.tagId,
      this.kind,
      this.minimum,
      this.maximum,
      this.start,
      this.end,
      this.basis = SearchAmountBasis.original});
  final Category? category;
  final int? accountId, tagId;
  final String? kind;
  final double? minimum, maximum;
  final DateTime? start, end;
  final SearchAmountBasis basis;
  bool get isEmpty =>
      category == null &&
      accountId == null &&
      tagId == null &&
      kind == null &&
      minimum == null &&
      maximum == null &&
      start == null &&
      end == null;
}

/// Owns the live query and selection. Widgets only render its current projection.
/// All writes remain in TransactionBatchBinding / the existing editor.
class TransactionSearchController extends ChangeNotifier {
  TransactionSearchController(
      {required this.repository,
      required this.ledgerId,
      required this.categoryLabel,
      this.initialBatch = false})
      : batch = initialBatch;
  final BaseRepository repository;
  final int ledgerId;
  final String Function(Category?) categoryLabel;
  final bool initialBatch;
  static const historyKey = 'v4.transactionSearch.history';
  StreamSubscription<List<SearchTransaction>>? _subscription;
  bool _disposed = false;
  int _generation = 0;
  bool loading = true, batch;
  Object? error;
  String query = '';
  TransactionSearchFilter filter = const TransactionSearchFilter();
  List<SearchTransaction> _all = [], results = [];
  List<Category> categories = [];
  List<Account> accounts = [];
  List<Tag> availableTags = [];
  Map<int, List<Tag>> tags = {};
  Map<int, int> attachments = {};
  List<String> history = [];
  final Set<int> _selected = {};
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasQuery => initialBatch || query.isNotEmpty || !filter.isEmpty;
  double get expense => _total(results.where((r) => r.t.type == 'expense'));
  double get income => _total(results.where((r) => r.t.type == 'income'));
  double get selectedTotal =>
      _total(results.where((r) => _selected.contains(r.t.id)));
  double _total(Iterable<SearchTransaction> rows) => rows.fold(
      0, (sum, row) => sum + (row.t.nativeAmount ?? row.t.amount).abs());

  Future<void> start() async {
    unawaited(_loadHistory());
    try {
      var cats = await repository.getAllCategories();
      var accts = await repository.getAllAccounts();
      var tagOptions = await repository.getAllTags();
      final repo = repository;
      if (repo is LocalRepository) {
        final scope = await repo.db.loadLedgerPickerContext(ledgerId);
        cats = await repo.db
            .filterCategoriesForLedger(cats, scope, topLevelOnly: false);
        accts = await repo.db.filterAccountsForLedger(accts, scope);
        tagOptions = await repo.db.filterTagsForLedger(tagOptions, scope);
      }
      if (_disposed) return;
      categories = cats;
      accounts = accts;
      availableTags = tagOptions;
      _subscription = repository
          .transactionsWithCategoryAll(ledgerId: ledgerId)
          .listen((rows) {
        _all = rows;
        unawaited(refresh());
      }, onError: _fail);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final rows = List<SearchTransaction>.of(_all);
    try {
      final ids = rows.map((r) => r.t.id).toList();
      final rowTags = await repository.getTagsForTransactions(ids);
      final counts = await repository.getAttachmentCountsForTransactions(ids);
      if (_disposed || generation != _generation) return;
      tags = rowTags;
      attachments = counts;
      loading = false;
      error = null;
      // Historical hidden accounts must remain filterable from their actual rows.
      final byId = {for (final account in accounts) account.id: account};
      for (final row in rows) {
        if (row.account != null) byId[row.account!.id] = row.account!;
        if (row.toAccount != null) byId[row.toAccount!.id] = row.toAccount!;
      }
      accounts = byId.values.toList();
      _apply();
    } catch (e) {
      if (generation == _generation) _fail(e);
    }
  }

  void _fail(Object e) {
    if (_disposed) return;
    error = e;
    loading = false;
    notifyListeners();
  }

  void search(String value) {
    query = value.trim();
    _apply();
  }

  void applyFilter(TransactionSearchFilter value) {
    filter = value;
    _apply();
  }

  void toggleBatch() {
    batch = !batch;
    if (!batch) _selected.clear();
    notifyListeners();
  }

  void toggle(int id) {
    if (!results.any((row) => row.t.id == id)) return;
    if (!_selected.add(id)) _selected.remove(id);
    notifyListeners();
  }

  void selectAll() {
    if (_selected.length == results.length) {
      _selected.clear();
    } else {
      _selected
        ..clear()
        ..addAll(results.map((r) => r.t.id));
    }
    notifyListeners();
  }

  void invert() {
    final next = results
        .map((r) => r.t.id)
        .where((id) => !_selected.contains(id))
        .toSet();
    _selected
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  void afterWrite() {
    _selected.clear();
    batch = initialBatch;
    _apply();
  }

  void _apply() {
    if (_disposed) return;
    final q = query.toLowerCase();
    final f = filter;
    results = !hasQuery
        ? []
        : _all.where((row) {
            final t = row.t, c = row.category;
            if (q.isNotEmpty &&
                ![
                  t.note ?? '',
                  categoryLabel(c),
                  t.amount.toString(),
                  row.account?.name ?? '',
                  row.toAccount?.name ?? '',
                  t.currencyCode ?? '',
                  ...?tags[t.id]?.map((tag) => tag.name),
                ].any((text) => text.toLowerCase().contains(q))) {
              return false;
            }
            if (f.category != null &&
                c?.id != f.category!.id &&
                c?.parentId != f.category!.id) {
              return false;
            }
            if (f.accountId != null &&
                row.account?.id != f.accountId &&
                row.toAccount?.id != f.accountId) {
              return false;
            }
            if (f.tagId != null &&
                !(tags[t.id]?.any((tag) => tag.id == f.tagId) ?? false)) {
              return false;
            }
            if (f.kind != null && t.type != f.kind) return false;
            final amount = (f.basis == SearchAmountBasis.ledger
                    ? t.nativeAmount ?? t.amount
                    : t.amount)
                .abs();
            if (f.minimum != null && amount < f.minimum!) return false;
            if (f.maximum != null && amount > f.maximum!) return false;
            if (f.start != null &&
                t.happenedAt.isBefore(
                    DateTime(f.start!.year, f.start!.month, f.start!.day))) {
              return false;
            }
            if (f.end != null &&
                !t.happenedAt.isBefore(
                    DateTime(f.end!.year, f.end!.month, f.end!.day + 1))) {
              return false;
            }
            return true;
          }).toList();
    _selected.retainAll(results.map((r) => r.t.id));
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    history = prefs.getStringList(historyKey) ?? [];
    notifyListeners();
  }

  Future<void> remember() async {
    if (query.isEmpty) return;
    history = [query, ...history.where((s) => s != query)].take(8).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(historyKey, history);
    if (!_disposed) notifyListeners();
  }

  Future<void> clearHistory() async {
    history = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(historyKey);
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
