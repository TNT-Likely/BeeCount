import 'dart:convert';

import '../data/db.dart';
import '../data/repository.dart';

abstract class SyncService {
  Future<void> uploadCurrentLedger({required int ledgerId});
  Future<int> downloadAndRestoreToCurrentLedger({required int ledgerId});
  Future<SyncStatus> getStatus({required int ledgerId});
}

class LocalOnlySyncService implements SyncService {
  @override
  Future<int> downloadAndRestoreToCurrentLedger({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<SyncStatus> getStatus({required int ledgerId}) async {
    return const SyncStatus(
      diff: SyncDiff.notConfigured,
      localCount: 0,
      localFingerprint: '',
      message: '未配置云端',
    );
  }
}

// --- Simple serialization of transactions for a single ledger ---

Future<String> exportTransactionsJson(BeeDatabase db, int ledgerId) async {
  final txs = await (db.select(db.transactions)
        ..where((t) => t.ledgerId.equals(ledgerId)))
      .get();
  // 稳定排序，避免不同平台/查询导致顺序差异
  txs.sort((a, b) {
    final c = a.happenedAt.compareTo(b.happenedAt);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  });
  // Map categoryId -> name/kind for used categories
  final usedCatIds = txs.map((t) => t.categoryId).whereType<int>().toSet();
  final cats = <int, Map<String, dynamic>>{};
  for (final cid in usedCatIds) {
    final c = await (db.select(db.categories)..where((c) => c.id.equals(cid)))
        .getSingleOrNull();
    if (c != null) cats[cid] = {"name": c.name, "kind": c.kind};
  }
  final items = txs
      .map((t) => {
            'type': t.type,
            'amount': t.amount,
            'categoryName':
                t.categoryId != null ? cats[t.categoryId]!['name'] : null,
            'categoryKind':
                t.categoryId != null ? cats[t.categoryId]!['kind'] : null,
            'happenedAt': t.happenedAt.toUtc().toIso8601String(),
            'note': t.note,
          })
      .toList();
  final payload = {
    'version': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'ledgerId': ledgerId,
    'count': items.length,
    'items': items,
  };
  return jsonEncode(payload);
}

Future<int> importTransactionsJson(
    BeeRepository repo, int ledgerId, String jsonStr) async {
  final data = jsonDecode(jsonStr) as Map<String, dynamic>;
  final items = (data['items'] as List).cast<Map<String, dynamic>>();
  int inserted = 0;
  for (final it in items) {
    final type = it['type'] as String;
    final amount = (it['amount'] as num).toDouble();
    final categoryName = it['categoryName'] as String?;
    final categoryKind = it['categoryKind'] as String?;
    final happenedAt = DateTime.parse(it['happenedAt'] as String).toLocal();
    final note = it['note'] as String?;

    int? categoryId;
    if (categoryName != null && categoryKind != null) {
      categoryId =
          await repo.upsertCategory(name: categoryName, kind: categoryKind);
    }
    await repo.addTransaction(
      ledgerId: ledgerId,
      type: type,
      amount: amount,
      categoryId: categoryId,
      accountId: null,
      toAccountId: null,
      happenedAt: happenedAt,
      note: note,
    );
    inserted++;
  }
  return inserted;
}

// ---- 状态模型 ----

enum SyncDiff {
  notConfigured,
  notLoggedIn,
  noRemote,
  inSync,
  localNewer,
  cloudNewer,
  different,
  error,
}

class SyncStatus {
  final SyncDiff diff;
  final int localCount;
  final int? cloudCount;
  final String localFingerprint;
  final String? cloudFingerprint;
  final DateTime? cloudExportedAt;
  final String? message; // 错误或说明

  const SyncStatus({
    required this.diff,
    required this.localCount,
    required this.localFingerprint,
    this.cloudCount,
    this.cloudFingerprint,
    this.cloudExportedAt,
    this.message,
  });
}
