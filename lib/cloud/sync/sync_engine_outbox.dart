part of 'sync_engine.dart';

class _PushTally {
  const _PushTally({this.accepted = 0, this.conflicts = 0, this.rejected = 0});
  final int accepted;
  final int conflicts;
  final int rejected;

  _PushTally operator +(_PushTally other) => _PushTally(
      accepted: accepted + other.accepted,
      conflicts: conflicts + other.conflicts,
      rejected: rejected + other.rejected);

  String? get error {
    if (rejected == 0 && conflicts == 0) return null;
    final l10n = resolveAppLocalizations(null);
    return [
      if (conflicts != 0) l10n.cloudSyncPushConflicts(conflicts),
      if (rejected != 0) l10n.cloudSyncPushUnconfirmed(rejected),
    ].join(' ');
  }

  int requireSuccess() {
    final problem = error;
    if (problem != null) throw CloudStorageException(problem);
    return accepted;
  }

  SyncResult syncResult(int pulled) => SyncResult(
      pushed: accepted, pulled: pulled, conflicts: conflicts, error: error);
}

extension _SyncEngineOutbox on SyncEngine {
  String get _receiptScope => _transactionMoveScope() ?? '';

  /// A successful response can already be behind a concurrently fetched page.
  /// Keep the later remote event until the last pending operation has settled.
  Future<bool> _deferOrSkipRemote(BeeCountCloudSyncChange change) async {
    final confirmed = await (db.selectOnly(db.localChanges)
          ..addColumns([db.localChanges.id])
          ..where(db.localChanges.entityType.equals(change.entityType) &
              db.localChanges.entitySyncId.equals(change.entitySyncId) &
              db.localChanges.receiptScope.equals(_receiptScope) &
              db.localChanges.confirmedChangeId
                  .isBiggerOrEqualValue(change.changeId))
          ..limit(1))
        .getSingleOrNull();
    if (confirmed != null) return true;
    // Ledger metadata merges unmodified fields in its own apply handler.
    if (change.entityType == 'ledger') return false;
    final pending = await changeTracker.pendingEntity(
        change.entityType, change.entitySyncId);
    if (pending == null) return false;
    await _rememberRemote(pending, change);
    return true;
  }

  BeeCountCloudSyncChange? _deferred(LocalChange row) {
    if (row.deferredJson == null) return null;
    final envelope = jsonDecode(row.deferredJson!) as Map<String, dynamic>;
    if (envelope['scope'] != _receiptScope) return null;
    return BeeCountCloudSyncChange.fromJson(
        envelope['change'] as Map<String, dynamic>);
  }

  Future<void> _rememberRemote(
      LocalChange row, BeeCountCloudSyncChange remote) async {
    if ((_deferred(row)?.changeId ?? -1) >= remote.changeId) return;
    await (db.update(db.localChanges)..where((c) => c.id.equals(row.id))).write(
        LocalChangesCompanion(
            deferredJson: d.Value(jsonEncode(
                {'scope': _receiptScope, 'change': remote.toJson()}))));
  }

  /// Freeze wire values, identity and version before the request leaves this
  /// device. Retrying a lost acknowledgement must send the original operation.
  Future<Map<String, dynamic>> _outgoing(
      LocalChange row, String? ledger) async {
    if (row.wireJson != null) {
      final cached = jsonDecode(row.wireJson!) as Map<String, dynamic>;
      if (cached['scope'] == _receiptScope) {
        return cached['change'] as Map<String, dynamic>;
      }
    }
    final patch = row.payloadJson == null
        ? null
        : jsonDecode(row.payloadJson!) as Map<String, dynamic>;
    final payload = row.action == 'delete'
        ? <String, dynamic>{}
        : await _serializeEntityForPush(
            entityType: row.entityType,
            entityId: row.entityId,
            ledgerId: row.ledgerId);
    // Version pre-v37 edits in journal order within their original second.
    // This also distinguishes consecutive old edits on an unupgraded server.
    final micros = row.writeMicros ?? await _legacyWriteMicros(row);
    final deferred = _deferred(row);
    final operation = row.operationId ?? _uuid.v4();
    final outgoing = <String, dynamic>{
      'operation_id': operation,
      'ledger_id': ledger,
      'scope': ledger == null ? 'user' : 'ledger',
      'entity_type': row.entityType,
      'entity_sync_id': row.entitySyncId,
      'action': row.action == 'delete' ? 'delete' : 'upsert',
      'payload': patch == null
          ? payload
          : {
              ...payload,
              if (deferred?.action == 'upsert') ...?deferred!.payload,
              ...patch,
            },
      if (patch != null) 'changed_fields': patch.keys.toList(),
      'updated_at': DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true)
          .toIso8601String(),
    };
    await (db.update(db.localChanges)..where((c) => c.id.equals(row.id))).write(
        LocalChangesCompanion(
            operationId: d.Value(operation),
            writeMicros: d.Value(micros),
            wireJson: d.Value(
                jsonEncode({'scope': _receiptScope, 'change': outgoing}))));
    return outgoing;
  }

  Future<int> _legacyWriteMicros(LocalChange row) async {
    final table = db.localChanges;
    final count = table.id.count();
    final earlier = await (db.selectOnly(table)
          ..addColumns([count])
          ..where(table.entityType.equals(row.entityType) &
              table.entitySyncId.equals(row.entitySyncId) &
              table.createdAt.equals(row.createdAt) &
              table.id.isSmallerThanValue(row.id)))
        .getSingle();
    return row.createdAt.microsecondsSinceEpoch +
        (earlier.read(count) ?? 0).clamp(0, Duration.microsecondsPerSecond - 1);
  }

  DateTime? _remoteTime(String? value) {
    if (value == null) return null;
    final time = DateTime.tryParse(value);
    if (time == null || time.isUtc) return time;
    // SQLite timestamps from older Cloud releases contain UTC without an offset.
    return DateTime.tryParse('${value}Z');
  }

  Future<_PushTally> _sendTracked(
      List<LocalChange> rows, String? ledger) async {
    var outcome = const _PushTally();
    final scope = _receiptScope;
    const size = 500;
    for (var start = 0; start < rows.length; start += size) {
      final batch =
          rows.sublist(start, (start + size).clamp(start, rows.length));
      final outgoing = <Map<String, dynamic>>[];
      for (final row in batch) {
        outgoing.add(await _outgoing(row, ledger));
      }
      _requireReceiptScope(scope);
      final response = await provider.pushChanges(changes: outgoing);
      outcome += await _settleBatch(scope, outgoing, response, [
        for (final row in batch) [row.id]
      ]);
    }
    return outcome;
  }

  void _requireReceiptScope(String scope) {
    if (scope != _receiptScope) {
      throw CloudStorageException('Sync session changed during upload');
    }
  }

  Future<_PushTally> _settleBatch(
      String scope,
      List<Map<String, dynamic>> outgoing,
      BeeCountCloudPushResult response,
      List<List<int>> journalIds) async {
    final applied = <String, Set<(String, String)>>{};
    final result = await _applyWithAttachmentCleanup((removedFiles) async {
      _requireReceiptScope(scope);
      var accepted = 0, conflicts = 0, rejected = 0;
      for (var i = 0; i < outgoing.length; i++) {
        final item = response.items[i];
        if (item.status == 'accepted') {
          accepted++;
        } else if (item.status == 'conflict') {
          conflicts++;
        }
        if (item.status != 'accepted' && item.winner == null) {
          rejected++;
          continue;
        }
        var changed = false;
        for (final id in journalIds[i]) {
          if (await _settle(id, outgoing[i], item, removedFiles)) {
            changed = true;
          }
        }
        final winner = item.winner;
        if (journalIds[i].isEmpty &&
            winner != null &&
            !await _deferOrSkipRemote(winner)) {
          changed = await _applyRemoteChange(winner, removedFiles,
              authoritative: true);
        }
        if (changed) {
          final change = outgoing[i];
          final ledger = change['ledger_id'] as String? ?? '__user_global__';
          (applied[ledger] ??= {}).add((
            change['entity_type'] as String,
            change['entity_sync_id'] as String
          ));
        }
      }
      _requireReceiptScope(scope);
      return _PushTally(
          accepted: accepted, conflicts: conflicts, rejected: rejected);
    });
    for (final entry in applied.entries) {
      _emit(PullCompleted(ledgerId: entry.key, applied: entry.value.length));
    }
    return result;
  }

  Future<bool> _settle(int id, Map<String, dynamic> sent,
      BeeCountCloudPushItem receipt, Set<String> removedFiles) async {
    final row = await (db.select(db.localChanges)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (row == null || row.pushedAt != null) return false;
    var winner = receipt.winner;
    if (winner != null &&
        (winner.entityType != row.entityType ||
            winner.entitySyncId != row.entitySyncId ||
            winner.ledgerId != (sent['ledger_id'] ?? '__user_global__'))) {
      throw CloudStorageException(
          'Sync acknowledgement identifies another entity');
    }
    final deferred = _deferred(row);
    final remoteId = winner?.changeId ?? receipt.changeId;
    if (deferred != null &&
        (remoteId != null
            ? deferred.changeId > remoteId
            : (_remoteTime(deferred.updatedAt)
                    ?.isAfter(DateTime.parse(sent['updated_at'] as String)) ??
                false))) {
      winner = deferred;
    } else if (deferred != null &&
        receipt.status == 'accepted' &&
        remoteId == null &&
        sent['changed_fields'] != null &&
        sent['action'] != 'delete') {
      // The aggregate-only server accepted this full row. Apply exactly those
      // wire values, including independent remote fields merged before sending.
      winner = BeeCountCloudSyncChange(
          changeId: deferred.changeId,
          ledgerId: deferred.ledgerId,
          entityType: row.entityType,
          entitySyncId: row.entitySyncId,
          action: 'upsert',
          payload: sent['payload'] as Map<String, dynamic>);
    }
    await (db.update(db.localChanges)..where((c) => c.id.equals(row.id)))
        .write(LocalChangesCompanion(
            pushedAt: d.Value(DateTime.now()),
            confirmedChangeId: d.Value(winner?.changeId ?? receipt.changeId),
            receiptScope: d.Value(_receiptScope),
            deferredJson: const d.Value(null),
            // Keep the submitted value and the reason for a rejected local edit.
            wireJson: receipt.status == 'conflict'
                ? d.Value(jsonEncode({
                    'scope': _receiptScope,
                    'change': sent,
                    'conflict': receipt.reason,
                  }))
                : const d.Value(null)));
    if (winner == null) return false;
    final next =
        await changeTracker.pendingEntity(row.entityType, row.entitySyncId);
    if (next != null) {
      await _rememberRemote(next, winner);
      return false;
    }
    return _applyRemoteChange(winner, removedFiles, authoritative: true);
  }
}
