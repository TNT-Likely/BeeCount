import 'dart:convert';

import '../data/db.dart';
import 'package:drift/drift.dart' as d;
import '../data/repository.dart';

abstract class SyncService {
  Future<void> uploadCurrentLedger({required int ledgerId});

  /// 下载并导入到当前账本，带去重。
  /// 返回 (inserted, skipped, deletedDup) 三元组：
  /// - inserted: 新增条数
  /// - skipped: 因重复而跳过的条数
  /// - deletedDup: 导入后执行本地二次去重所删除的条数
  Future<({int inserted, int skipped, int deletedDup})>
      downloadAndRestoreToCurrentLedger({required int ledgerId});
  Future<SyncStatus> getStatus({required int ledgerId});

  /// 主动刷新云端指纹：强制下载云端对象并计算指纹，返回 (fingerprint, count, exportedAt)。
  /// 实现可在内部根据对比结果适度更新缓存，便于 UI 立即反映状态。
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId});

  /// 当本地数据发生变更（增删改）时调用，以便使缓存状态失效
  void markLocalChanged({required int ledgerId});

  /// 删除云端备份（若存在）。应忽略 404。
  Future<void> deleteRemoteBackup({required int ledgerId});
}

class LocalOnlySyncService implements SyncService {
  @override
  Future<({int inserted, int skipped, int deletedDup})>
      downloadAndRestoreToCurrentLedger({required int ledgerId}) async {
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

  @override
  void markLocalChanged({required int ledgerId}) {}

  @override
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<void> deleteRemoteBackup({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
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
  // ledger meta
  final ledger = await (db.select(db.ledgers)
        ..where((l) => l.id.equals(ledgerId)))
      .getSingleOrNull();
  final payload = {
    'version': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'ledgerId': ledgerId,
    'ledgerName': ledger?.name,
    'currency': ledger?.currency,
    'count': items.length,
    'items': items,
  };
  return jsonEncode(payload);
}

/// 解析 JSON 并增量导入，使用签名去重（与本地现有数据合并）。
/// 返回 (inserted, skipped)
Future<({int inserted, int skipped})> importTransactionsJson(
    BeeRepository repo, int ledgerId, String jsonStr,
    {void Function(int done, int total)? onProgress}) async {
  final data = jsonDecode(jsonStr) as Map<String, dynamic>;
  final items = (data['items'] as List).cast<Map<String, dynamic>>();
  // optional: update local ledger name & currency if present
  final ledgerName = data['ledgerName'] as String?;
  final currency = data['currency'] as String?;
  if (ledgerName != null || currency != null) {
    try {
      await repo.updateLedger(
          id: ledgerId, name: ledgerName, currency: currency);
    } catch (_) {}
  }
  int inserted = 0;
  int skipped = 0;
  int processed = 0;
  final total = items.length;
  // 先构建现有签名集合，避免 N^2
  final existing = await repo.signatureSetForLedger(ledgerId);
  // 构建批量待插入列表，分批写入
  final toInsert = <TransactionsCompanion>[];
  const batchSize = 500;
  // 预热：用于减少 upsertCategory 的重复查询
  final categoryCache = <String, int>{}; // key: kind|name -> id
  for (final it in items) {
    final type = it['type'] as String;
    final amount = (it['amount'] as num).toDouble();
    final categoryName = it['categoryName'] as String?;
    final categoryKind = it['categoryKind'] as String?;
    final happenedAt = DateTime.parse(it['happenedAt'] as String).toLocal();
    final note = it['note'] as String?;

    int? categoryId;
    if (categoryName != null && categoryKind != null) {
      final key = '$categoryKind|$categoryName';
      final cached = categoryCache[key];
      if (cached != null) {
        categoryId = cached;
      } else {
        categoryId =
            await repo.upsertCategory(name: categoryName, kind: categoryKind);
        categoryCache[key] = categoryId;
      }
    }
    final sig = repo.txSignature(
        type: type,
        amount: amount,
        categoryId: categoryId,
        happenedAt: happenedAt,
        note: note);
    if (existing.contains(sig)) {
      skipped++;
      processed++;
      // 节流触发进度（每 200 条或最后）
      if (onProgress != null && (processed % 200 == 0)) {
        onProgress(processed, total);
      }
      continue;
    }
    toInsert.add(TransactionsCompanion.insert(
      ledgerId: ledgerId,
      type: type,
      amount: amount,
      categoryId: d.Value(categoryId),
      accountId: const d.Value(null),
      toAccountId: const d.Value(null),
      happenedAt: d.Value(happenedAt),
      note: d.Value(note),
    ));
    existing.add(sig);
    // 批量写入达到阈值时落盘并更新进度
    if (toInsert.length >= batchSize) {
      final n = await repo.insertTransactionsBatch(List.of(toInsert));
      toInsert.clear();
      inserted += n;
      processed += n;
      if (onProgress != null) onProgress(processed, total);
    }
  }
  if (toInsert.isNotEmpty) {
    final n = await repo.insertTransactionsBatch(toInsert);
    inserted += n;
    processed += n;
  }
  if (onProgress != null) onProgress(processed, total);
  return (inserted: inserted, skipped: skipped);
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
