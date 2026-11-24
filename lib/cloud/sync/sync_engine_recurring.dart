part of 'sync_engine.dart';

extension RecurringHandoffSync on SyncEngine {
  Future<Set<int>> pendingRecurringLedgers() async {
    final rows = await db.customSelect(
      "SELECT DISTINCT ledger_id FROM recurring_transactions WHERE cloud_rule_id IS NULL AND (cloud_handoff_issue IS NULL OR cloud_handoff_issue='invalid')",
      readsFrom: {db.recurringTransactions},
    ).get();
    if (rows.isNotEmpty &&
        !await CloudServiceStore().usesCloudRecurringRules()) {
      return {};
    }
    return rows.map((row) => row.read<int>('ledger_id')).toSet();
  }

  /// Startup and connectivity recovery must also pick up rules in inactive ledgers.
  Future<void> retryPendingRecurring({int? except}) async {
    try {
      for (final id in await pendingRecurringLedgers()) {
        if (id != except && !_eventsController.isClosed) {
          await sync(ledgerId: id.toString());
        }
      }
    } catch (e, st) {
      logger.error('SyncEngine', '周期规则等待下次同步', e, st);
    }
  }

  bool _holdRecurringChange(LocalChange change, Set<int> held) =>
      held.isNotEmpty &&
      ((change.entityType == 'transaction' && held.contains(change.entityId)) ||
          (change.entityType == 'ledger_snapshot' &&
              change.action != 'delete'));

  Future<Set<int>> _adoptBeforeUpload(Ledger ledger) async {
    final unresolved = await (db.select(db.recurringTransactions)
          ..where((r) => r.ledgerId.equals(ledger.id) & r.cloudRuleId.isNull()))
        .get();
    if (unresolved.isEmpty ||
        !await CloudServiceStore().usesCloudRecurringRules()) {
      return {};
    }
    if (unresolved.any((r) =>
        r.cloudHandoffIssue == null || r.cloudHandoffIssue == 'invalid')) {
      final work = _recurringInFlight.putIfAbsent(
          ledger.id, () => _adoptLocalRules(ledger, unresolved));
      try {
        await work;
      } catch (e, st) {
        // An older Cloud, expired session or outage must not block unrelated manual entries.
        logger.warning('SyncEngine',
            '周期规则等待同步 ledger=${ledger.id} (${e.runtimeType})', st);
      } finally {
        if (identical(_recurringInFlight[ledger.id], work)) {
          _recurringInFlight.remove(ledger.id);
        }
      }
    }
    final held = await db.customSelect(
      'SELECT t.id FROM transactions t JOIN recurring_transactions r ON r.id=t.recurring_id '
      'WHERE t.ledger_id=? AND r.ledger_id=t.ledger_id AND r.cloud_rule_id IS NULL',
      variables: [d.Variable.withInt(ledger.id)],
      readsFrom: {db.transactions, db.recurringTransactions},
    ).get();
    return held.map((row) => row.read<int>('id')).toSet();
  }

  /// A restored device must add its missing entries without replacing Cloud's
  /// newer edits, deleted occurrences, or entries created by another device.
  /// On an ordinary ledger, null retains the existing full snapshot behavior.
  Future<Set<int>?> _recurringBulkExclusions(
      Ledger ledger, Set<int> held, List<LocalChange> changes) async {
    if (!await CloudServiceStore().usesCloudRecurringRules()) return null;
    final templates = await (db.select(db.recurringTransactions)
          ..where((r) => r.ledgerId.equals(ledger.id)))
        .get();
    if (templates.isEmpty) {
      try {
        final rules = await provider.recurringRules(ledger.syncId!);
        if ((rules['items'] as List).isEmpty) return null;
      } on RecurringRuleException catch (e) {
        if (e.status == 404 || e.status == 405) return null;
        // When rule discovery is temporarily unavailable, merge into the
        // existing ledger below; an authoritative snapshot would be unsafe.
      }
    }
    final content = await provider.storage.download(path: ledger.syncId!);
    final cloudIds = <String>{
      if (content != null)
        for (final item in (jsonDecode(content)['items'] as List? ?? const []))
          if (item['syncId'] is String) item['syncId'] as String,
    };
    final txChanges = changes.where((c) => c.entityType == 'transaction');
    final pending = txChanges.map((c) => c.entityId).toSet();
    final edits = txChanges
        .where((c) => c.action == 'update')
        .map((c) => c.entityId)
        .toSet();
    final adopted =
        templates.where((r) => r.cloudRuleId != null).map((r) => r.id).toSet();
    final rows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledger.id)))
        .get();
    return {
      ...held,
      for (final tx in rows)
        if ((cloudIds.contains(tx.syncId) && !edits.contains(tx.id)) ||
            (adopted.contains(tx.recurringId) && !pending.contains(tx.id)))
          tx.id,
    };
  }

  Future<void> _adoptLocalRules(
      Ledger ledger, List<RecurringTransaction> unresolved) async {
    final user = await provider.auth.currentUser;
    if (user == null || !await CloudServiceStore().usesBeeCountCloud()) return;
    final key = ledger.syncId ?? ledger.id.toString();
    final scope = ruleScope(provider, user.id, key);
    final pending = unresolved.where((r) =>
        (r.cloudHandoffIssue == null || r.cloudHandoffIssue == 'invalid') &&
        (r.cloudHandoffKey == null || r.cloudHandoffScope == scope));
    if (pending.isEmpty) return;
    final snapshot = await provider.recurringRules(key);
    final book = CloudRuleBook(provider, ledger, scope, snapshot, false);
    if (!book.canCreate) return;
    await book.ensureActive();
    await pushUserGlobalEntities();
    for (final local in pending) {
      try {
        final handoff = await RecurringHandoff.prepare(db, repo, book, local,
            automatic: true);
        if (handoff.overlaps.isNotEmpty) {
          await _flagRecurring(local.id, scope, 'history');
        } else {
          await handoff.finish(db);
        }
      } on RecurringRuleException catch (e) {
        if (e.message.contains('SIMILAR_RULE')) {
          await _flagRecurring(local.id, scope, 'similar');
        } else if (e.message.contains('HISTORY_CONFLICT') ||
            e.message.contains('Already synchronized copies')) {
          await _flagRecurring(local.id, scope, 'history');
        } else if (e.status == 422) {
          await _flagRecurring(local.id, scope, 'invalid');
        } else if (e.status != 409) {
          rethrow;
        }
      } on StateError catch (e) {
        if (e.message == 'HISTORY_CONFLICT') {
          await _flagRecurring(local.id, scope, 'history');
        } else if (e.message ==
            'Sync the linked categories and accounts first') {
          // A later resource sync can resolve the local stable IDs.
          continue;
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> _flagRecurring(int id, String scope, String issue) => (db
          .update(db.recurringTransactions)
        ..where((r) =>
            r.id.equals(id) &
            r.cloudRuleId.isNull() &
            (r.cloudHandoffKey.isNull() | r.cloudHandoffScope.equals(scope))))
      .write(RecurringTransactionsCompanion(cloudHandoffIssue: d.Value(issue)));
}
