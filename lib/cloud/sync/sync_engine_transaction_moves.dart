part of 'sync_engine.dart';

enum TransactionMoveFailure { changed, unsynced, awaitingConfirmation }

extension SyncEngineTransactionMoves on SyncEngine {
  Future<T> _withTransactionMoveLock<T>(Future<T> Function() action) {
    final work = _transactionMoveTail.then((_) => action());
    _transactionMoveTail =
        work.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return work;
  }

  String? _transactionMoveScope() {
    final auth = provider.auth;
    if (auth is! BeeCountCloudAuthService ||
        auth.currentUserId == null ||
        auth.currentDeviceId == null) {
      return null;
    }
    return jsonEncode([
      provider.baseUrl,
      provider.apiPrefix,
      auth.currentUserId,
      auth.currentDeviceId,
    ]);
  }

  Future<int> moveTransactionsInCloud({
    required int sourceLedgerId,
    required int targetLedgerId,
    required Set<int> transactionIds,
  }) =>
      _withTransactionMoveLock(() async {
        if (transactionIds.isEmpty) return 0;
        final scope = _transactionMoveScope();
        if (scope == null) throw TransactionMoveFailure.unsynced;
        await _recoverMovesForScope(scope);
        // Finish any writes that were already queued before this move acquired the lock.
        for (final id in [sourceLedgerId, targetLedgerId]) {
          await _pushInFlight[id.toString()]?.future;
          await _fullPushInFlight[id]?.future;
        }

        final source = await repo.getLedgerById(sourceLedgerId);
        final target = await repo.getLedgerById(targetLedgerId);
        if (source == null ||
            target == null ||
            !canMoveTransactionsBetween(source, target)) {
          throw TransactionMoveFailure.changed;
        }
        final sourceSyncId = source.syncId;
        final targetSyncId = target.syncId;
        if (sourceSyncId == null || targetSyncId == null) {
          throw TransactionMoveFailure.unsynced;
        }

        final selection = <String, int>{};
        for (final id in transactionIds) {
          final tx = await repo.getTransactionById(id);
          if (tx == null || tx.ledgerId != sourceLedgerId) {
            throw TransactionMoveFailure.changed;
          }
          final syncId = tx.syncId;
          if (syncId == null ||
              syncId.isEmpty ||
              selection.containsKey(syncId)) {
            throw TransactionMoveFailure.unsynced;
          }
          selection[syncId] = id;
        }

        final prepared = await provider.prepareTransactionMove(
          sourceLedger: sourceSyncId,
          targetLedger: targetSyncId,
          transactionIds: selection.keys.toList(),
        );
        if (prepared.length != selection.length) {
          throw TransactionMoveFailure.changed;
        }
        final operationId = _uuid.v4();
        final items = <Map<String, dynamic>>[];

        // Compare the selected rows with the authoritative, versioned cloud data.
        // The regular sync endpoint can acknowledge a batch containing rejected rows.
        await db.transaction(() async {
          final pending =
              await changeTracker.getUnpushedChangesForLedger(sourceLedgerId);
          if (pending.any((change) =>
              change.entityType == 'transaction' &&
              transactionIds.contains(change.entityId))) {
            throw TransactionMoveFailure.unsynced;
          }
          for (final item in prepared) {
            final syncId = item['sync_id'] as String;
            final id = selection[syncId];
            final tx = id == null ? null : await repo.getTransactionById(id);
            if (tx == null ||
                tx.ledgerId != sourceLedgerId ||
                tx.syncId != syncId) {
              throw TransactionMoveFailure.changed;
            }
            final local = await _serializeEntityForPush(
                entityType: 'transaction',
                entityId: tx.id,
                ledgerId: sourceLedgerId);
            final remote = item['transaction'] as Map<String, dynamic>;
            if (!listEquals(_comparableMoveFields(local, source.currency),
                _comparableMoveFields(remote, source.currency))) {
              throw TransactionMoveFailure.unsynced;
            }
            items.add({'sync_id': syncId, 'revision': item['revision']});
          }
          if (_transactionMoveScope() != scope) {
            throw TransactionMoveFailure.changed;
          }
          await db.into(db.pendingTransactionMoves).insert(
                PendingTransactionMovesCompanion.insert(
                  operationId: operationId,
                  scope: scope,
                  payload: jsonEncode({
                    'source': sourceSyncId,
                    'target': targetSyncId,
                    'sourceId': sourceLedgerId,
                    'targetId': targetLedgerId,
                    'items': items,
                    'selection': selection,
                  }),
                ),
              );
        });

        final entry = await (db.select(db.pendingTransactionMoves)
              ..where((row) => row.operationId.equals(operationId)))
            .getSingle();
        await _submitTransactionMove(entry);
        return selection.length;
      });

  Future<void> _recoverTransactionMoves() => _withTransactionMoveLock(() async {
        final hasMoves =
            await (db.select(db.pendingTransactionMoves)..limit(1)).get();
        if (hasMoves.isEmpty) return;
        final scope = _transactionMoveScope();
        if (scope != null) await _recoverMovesForScope(scope);
      });

  Future<void> _recoverMovesForScope(String scope) async {
    final moves = await (db.select(db.pendingTransactionMoves)
          ..where((entry) => entry.scope.equals(scope)))
        .get();
    for (final move in moves) {
      try {
        await _submitTransactionMove(move);
      } on BeeCountCloudTransactionMoveException catch (error) {
        // A definite rejection never changed either Cloud ledger.
        if (!error.isFinal) rethrow;
        logger.warning('SyncEngine',
            'Pending transaction move rejected (${error.statusCode})');
      }
    }
  }

  Future<void> _submitTransactionMove(PendingTransactionMove move) async {
    if (_transactionMoveScope() != move.scope) {
      throw TransactionMoveFailure.awaitingConfirmation;
    }
    final payload = jsonDecode(move.payload) as Map<String, dynamic>;
    final sourceId = payload['sourceId'] as int;
    final targetId = payload['targetId'] as int;
    final items = (payload['items'] as List).cast<Map<String, dynamic>>();
    final selection = (payload['selection'] as Map).cast<String, int>();
    final Map<String, dynamic> receipt;
    try {
      receipt = await provider.commitTransactionMove(
        sourceLedger: payload['source'] as String,
        targetLedger: payload['target'] as String,
        operationId: move.operationId,
        items: items,
      );
    } on BeeCountCloudTransactionMoveException catch (error) {
      if (!error.isFinal) throw TransactionMoveFailure.awaitingConfirmation;
      await _removePendingMove(move.operationId);
      rethrow;
    } catch (_) {
      throw TransactionMoveFailure.awaitingConfirmation;
    }

    if (receipt['operation_id'] != move.operationId ||
        _transactionMoveScope() != move.scope) {
      throw TransactionMoveFailure.awaitingConfirmation;
    }
    final moved = <String, String>{
      for (final item
          in (receipt['items'] as List).cast<Map<String, dynamic>>())
        item['source_sync_id'] as String: item['target_sync_id'] as String,
    };
    if (moved.length != selection.length ||
        !selection.keys.every(moved.containsKey) ||
        moved.values.toSet().length != moved.length) {
      throw TransactionMoveFailure.awaitingConfirmation;
    }
    final attachments =
        (receipt['attachment_ids'] as Map).cast<String, String>();
    final serverTime = DateTime.parse(receipt['server_timestamp'] as String);
    // Drift stores whole seconds. Rebased edits must sort after the server upsert.
    final afterMove = DateTime.fromMillisecondsSinceEpoch(
        (serverTime.millisecondsSinceEpoch ~/ 1000 + 1) * 1000,
        isUtc: true);

    await db.transaction(() async {
      final target = await repo.getLedgerById(targetId);
      if (target?.syncId != payload['target']) {
        throw TransactionMoveFailure.awaitingConfirmation;
      }
      for (final entry in selection.entries) {
        final id = entry.value;
        final oldSyncId = entry.key;
        final newSyncId = moved[oldSyncId]!;
        final tx = await repo.getTransactionById(id);
        if (tx != null && (tx.ledgerId != sourceId || tx.syncId != oldSyncId)) {
          throw TransactionMoveFailure.awaitingConfirmation;
        }
        if (tx != null) {
          await (db.update(db.transactions)..where((row) => row.id.equals(id)))
              .write(TransactionsCompanion(
                  ledgerId: d.Value(targetId), syncId: d.Value(newSyncId)));
          final files = await repo.getAttachmentsByTransaction(id);
          for (final file in files) {
            final newFileId = attachments[file.cloudFileId];
            await (db.update(db.transactionAttachments)
                  ..where((row) => row.id.equals(file.id)))
                .write(TransactionAttachmentsCompanion(
                    cloudFileId: d.Value(newFileId),
                    cloudSha256: newFileId == null
                        ? const d.Value(null)
                        : const d.Value.absent()));
          }
          await (db.update(db.transactionTagOverrides)
                ..where((row) => row.transactionSyncId.equals(oldSyncId)))
              .write(TransactionTagOverridesCompanion(
                  transactionSyncId: d.Value(newSyncId)));
        }
        // Any user edit made while the receipt was pending belongs to the same bill.
        final staleChanges = await (db.delete(db.localChanges)
              ..where((row) =>
                  row.pushedAt.isNull() &
                  row.ledgerId.equals(sourceId) &
                  row.entityType.equals('transaction') &
                  row.entitySyncId.equals(oldSyncId)))
            .go();
        if (staleChanges > 0) {
          await db.into(db.localChanges).insert(LocalChangesCompanion.insert(
                entityType: 'transaction',
                entityId: id,
                entitySyncId: newSyncId,
                ledgerId: targetId,
                action: tx == null ? 'delete' : 'update',
                createdAt: d.Value(afterMove),
              ));
        }
      }
      await _removePendingMove(move.operationId);
    });
    clearStatusCache(ledgerId: sourceId);
    clearStatusCache(ledgerId: targetId);
    _emit(PullCompleted(
        ledgerId: payload['source'] as String, applied: selection.length));
    _emit(PullCompleted(
        ledgerId: payload['target'] as String, applied: selection.length));
  }

  Future<void> _removePendingMove(String operationId) =>
      (db.delete(db.pendingTransactionMoves)
            ..where((row) => row.operationId.equals(operationId)))
          .go();

  List<Object?> _comparableMoveFields(
      Map<String, dynamic> item, String baseCurrency) {
    final tags = ((item['tagIds'] as List?) ?? const [])
        .whereType<String>()
        .toList()
      ..sort();
    final attachments = ((item['attachments'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((file) => jsonEncode([
              file['fileName'],
              file['originalName'],
              file['cloudFileId'],
              file['sortOrder'] ?? 0,
            ]))
        .toList()
      ..sort();
    if (attachments.any((file) => (jsonDecode(file) as List)[2] == null)) {
      throw TransactionMoveFailure.unsynced;
    }
    final happenedAt = DateTime.tryParse(item['happenedAt'] as String? ?? '');
    return [
      item['syncId'],
      item['type'],
      item['amount'],
      happenedAt == null ? null : happenedAt.millisecondsSinceEpoch ~/ 1000,
      item['note'],
      for (final key in [
        'categoryId',
        'accountId',
        'fromAccountId',
        'toAccountId'
      ])
        (item[key] == '' ? null : item[key]),
      item['currencyCode'] ?? baseCurrency,
      item['nativeAmount'] ?? item['amount'],
      item['excludeFromStats'] ?? false,
      item['excludeFromBudget'] ?? false,
      jsonEncode(tags),
      jsonEncode(attachments),
    ];
  }
}
