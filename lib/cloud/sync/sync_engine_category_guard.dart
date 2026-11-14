part of 'sync_engine.dart';

class _PendingCategoryChange implements Exception {
  const _PendingCategoryChange(this.syncId);

  final String syncId;
}

extension SyncEngineCategoryGuardExt on SyncEngine {
  /// Check inside the page transaction, before any writes or icon cleanup.
  /// A deferred page must be retried after push, not skipped past its cursor.
  Future<void> _ensureNoPendingCategoryChanges(
      List<BeeCountCloudSyncChange> changes) async {
    final categoryChanges = changes
        .where((c) =>
            c.entityType == 'category' &&
            (c.action == 'delete' || c.payload != null))
        .toList();
    if (categoryChanges.isEmpty) return;

    final deviceId = await _getDeviceId();
    final applicable =
        categoryChanges.where((c) => c.updatedByDeviceId != deviceId).toList();
    if (applicable.isEmpty) return;

    final affectedSyncIds = applicable.map((c) => c.entitySyncId).toSet();
    final deletedSyncIds = applicable
        .where((c) => c.action == 'delete')
        .map((c) => c.entitySyncId)
        .toSet();
    if (deletedSyncIds.isNotEmpty) {
      final parents = await (db.select(db.categories)
            ..where((c) => c.syncId.isIn(deletedSyncIds)))
          .get();
      if (parents.isNotEmpty) {
        // Category deletion also removes direct children. Their unpushed
        // edits must be protected even without a child event in this page.
        final children = await (db.select(db.categories)
              ..where((c) => c.parentId.isIn(parents.map((p) => p.id))))
            .get();
        affectedSyncIds
            .addAll(children.map((c) => c.syncId).whereType<String>());
      }
    }

    final pending = await (db.select(db.localChanges)
          ..where((c) =>
              c.entityType.equals('category') &
              c.entitySyncId.isIn(affectedSyncIds) &
              c.pushedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (pending != null) throw _PendingCategoryChange(pending.entitySyncId);
  }
}
