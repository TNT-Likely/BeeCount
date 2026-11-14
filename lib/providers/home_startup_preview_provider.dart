import 'dart:async';

import 'package:drift/drift.dart' as d;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../data/repositories/base_repository.dart';
import '../models/home_transaction_preview.dart';

/// One complete, transactional snapshot prepared immediately before startup
/// releases the application. It is not a reusable transaction-list cache.
class HomeStartupPreview {
  const HomeStartupPreview({required this.repository, required this.preview});

  final BaseRepository repository;
  final HomeTransactionPreview preview;

  bool matches(BaseRepository repository, int ledgerId) =>
      identical(this.repository, repository) && preview.ledgerId == ledgerId;
}

class HomeStartupPreviewHandoff {
  HomeStartupPreview? _pending;
  BeeDatabase? _database;
  StreamSubscription? _updates;
  int _revision = 0, _request = 0;

  void publish(BaseRepository repository, HomeTransactionPreview preview) {
    _pending = HomeStartupPreview(repository: repository, preview: preview);
  }

  void clear() => _pending = null;

  HomeStartupPreview? peek(BaseRepository repository, int ledgerId) =>
      _pending?.matches(repository, ledgerId) == true ? _pending : null;

  /// Watch only while a startup snapshot is waiting to be consumed. This does
  /// not subscribe to or decode the full transaction collection.
  void _track(BeeDatabase database) {
    if (identical(_database, database) && _updates != null) return;
    unawaited(_updates?.cancel());
    _database = database;
    _updates = database
        .tableUpdates(d.TableUpdateQuery.onAllTables({
      database.transactions,
      database.ledgers,
      database.categories,
      database.accounts,
      database.tags,
      database.transactionTags,
      database.transactionAttachments,
      database.sharedLedgerCategories,
      database.sharedLedgerAccounts,
      database.sharedLedgerTags,
      database.transactionTagOverrides,
    }))
        .listen((_) {
      _revision++;
      clear();
    });
  }

  Future<HomeTransactionPreview> prepare(
      BaseRepository repository, int ledgerId, BeeDatabase database) async {
    _track(database);
    final request = ++_request;
    while (true) {
      final revision = _revision;
      final preview =
          await repository.getHomeTransactionPreview(ledgerId: ledgerId);
      // Drift commit notifications are asynchronous. Do not publish a snapshot
      // whose transaction/relationship data changed while it was being read.
      await Future<void>.delayed(Duration.zero);
      if (request != _request) return preview;
      if (revision != _revision) continue;
      publish(repository, preview);
      return preview;
    }
  }

  /// Consume even a mismatched snapshot: returning to its ledger later must
  /// read current data, never replay a pre-navigation snapshot.
  HomeStartupPreview? take(BaseRepository repository, int ledgerId) {
    final pending = _pending;
    _pending = null;
    _request++;
    unawaited(_updates?.cancel());
    _updates = null;
    _database = null;
    return pending?.matches(repository, ledgerId) == true ? pending : null;
  }

  void dispose() {
    clear();
    _request++;
    unawaited(_updates?.cancel());
  }
}

/// A one-shot handoff has no UI notifications or writes during widget build.
final homeStartupPreviewHandoffProvider =
    Provider<HomeStartupPreviewHandoff>((ref) {
  final handoff = HomeStartupPreviewHandoff();
  ref.onDispose(handoff.dispose);
  return handoff;
});
