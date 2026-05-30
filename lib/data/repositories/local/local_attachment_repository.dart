import 'package:drift/drift.dart' as d;

import '../../db.dart';
import '../attachment_repository.dart';

/// 本地附件Repository实现
/// 基于 Drift 数据库实现
class LocalAttachmentRepository implements AttachmentRepository {
  final BeeDatabase db;

  LocalAttachmentRepository(this.db);

  // ============================================
  // 基础 CRUD 操作
  // ============================================

  @override
  Future<int> createAttachment({
    required int transactionId,
    required String fileName,
    String? originalName,
    int? fileSize,
    int? width,
    int? height,
    int sortOrder = 0,
    String? cloudFileId,
    String? cloudSha256,
  }) async {
    return await db.into(db.transactionAttachments).insert(
      TransactionAttachmentsCompanion.insert(
        transactionId: transactionId,
        fileName: fileName,
        originalName: d.Value(originalName),
        fileSize: d.Value(fileSize),
        width: d.Value(width),
        height: d.Value(height),
        sortOrder: d.Value(sortOrder),
        cloudFileId: d.Value(cloudFileId),
        cloudSha256: d.Value(cloudSha256),
      ),
    );
  }

  @override
  Future<TransactionAttachment?> getAttachmentById(int id) async {
    return await (db.select(db.transactionAttachments)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  @override
  Future<List<TransactionAttachment>> getAttachmentsByTransaction(int transactionId) async {
    return await (db.select(db.transactionAttachments)
      ..where((t) => t.transactionId.equals(transactionId))
      ..orderBy([(t) => d.OrderingTerm(expression: t.sortOrder)])).get();
  }

  @override
  Future<void> deleteAttachment(int id) async {
    await (db.delete(db.transactionAttachments)
      ..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> deleteAttachmentsByTransaction(int transactionId) async {
    await (db.delete(db.transactionAttachments)
      ..where((t) => t.transactionId.equals(transactionId))).go();
  }

  @override
  Future<void> updateAttachmentSortOrder(int id, int sortOrder) async {
    await (db.update(db.transactionAttachments)
      ..where((t) => t.id.equals(id))).write(
      TransactionAttachmentsCompanion(sortOrder: d.Value(sortOrder)),
    );
  }

  @override
  Future<void> updateAttachmentCloudRef(int id, {String? cloudFileId, String? cloudSha256}) async {
    await (db.update(db.transactionAttachments)
      ..where((t) => t.id.equals(id))).write(
      TransactionAttachmentsCompanion(
        cloudFileId: d.Value(cloudFileId),
        cloudSha256: d.Value(cloudSha256),
      ),
    );
  }

  @override
  Future<void> updateAttachmentSortOrders(List<({int id, int sortOrder})> updates) async {
    await db.transaction(() async {
      for (final update in updates) {
        await updateAttachmentSortOrder(update.id, update.sortOrder);
      }
    });
  }

  // ============================================
  // 查询操作
  // ============================================

  @override
  Future<bool> attachmentExistsByFileName(String fileName) async {
    final result = await (db.select(db.transactionAttachments)
      ..where((t) => t.fileName.equals(fileName))).getSingleOrNull();
    return result != null;
  }

  @override
  Future<int> countAttachmentsByFileName(String fileName) async {
    final result = await db.customSelect(
      'SELECT COUNT(*) AS count FROM transaction_attachments WHERE file_name = ?',
      variables: [d.Variable.withString(fileName)],
      readsFrom: {db.transactionAttachments},
    ).getSingle();
    final count = result.data['count'];
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    if (count is num) return count.toInt();
    return 0;
  }

  @override
  Future<List<String>> getAttachmentFileNamesByLedger(int ledgerId) async {
    final rows = await db.customSelect(
      '''
      SELECT DISTINCT ta.file_name AS file_name
      FROM transaction_attachments ta
      INNER JOIN transactions t ON ta.transaction_id = t.id
      WHERE t.ledger_id = ?
      ''',
      variables: [d.Variable.withInt(ledgerId)],
      readsFrom: {db.transactionAttachments, db.transactions},
    ).get();
    return rows.map((r) => r.data['file_name'] as String).toList();
  }

  @override
  Future<int> getAttachmentCountByTransaction(int transactionId) async {
    final result = await db.customSelect(
      'SELECT COUNT(*) AS count FROM transaction_attachments WHERE transaction_id = ?',
      variables: [d.Variable.withInt(transactionId)],
      readsFrom: {db.transactionAttachments},
    ).getSingle();

    final count = result.data['count'];
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    if (count is num) return count.toInt();
    return 0;
  }

  @override
  Future<Map<int, int>> getAttachmentCountsForTransactions(List<int> transactionIds) async {
    if (transactionIds.isEmpty) return {};

    final placeholders = transactionIds.map((_) => '?').join(',');
    final result = await db.customSelect(
      '''
      SELECT transaction_id, COUNT(*) AS count
      FROM transaction_attachments
      WHERE transaction_id IN ($placeholders)
      GROUP BY transaction_id
      ''',
      variables: transactionIds.map((id) => d.Variable.withInt(id)).toList(),
      readsFrom: {db.transactionAttachments},
    ).get();

    final Map<int, int> counts = {};
    for (final row in result) {
      final transactionId = row.data['transaction_id'];
      final count = row.data['count'];

      if (transactionId is int) {
        int countInt = 0;
        if (count is int) {
          countInt = count;
        } else if (count is BigInt) {
          countInt = count.toInt();
        } else if (count is num) {
          countInt = count.toInt();
        }
        counts[transactionId] = countInt;
      }
    }

    return counts;
  }

  @override
  Future<Map<int, List<TransactionAttachment>>> getAttachmentsForTransactions(List<int> transactionIds) async {
    if (transactionIds.isEmpty) return {};

    final attachments = await (db.select(db.transactionAttachments)
      ..where((t) => t.transactionId.isIn(transactionIds))
      ..orderBy([(t) => d.OrderingTerm(expression: t.sortOrder)])).get();

    final Map<int, List<TransactionAttachment>> result = {};
    for (final attachment in attachments) {
      result.putIfAbsent(attachment.transactionId, () => []).add(attachment);
    }

    return result;
  }

  @override
  Future<List<int>> getTransactionIdsWithAttachments() async {
    final result = await db.customSelect(
      'SELECT DISTINCT transaction_id FROM transaction_attachments',
      readsFrom: {db.transactionAttachments},
    ).get();

    return result.map((row) {
      final id = row.data['transaction_id'];
      if (id is int) return id;
      if (id is BigInt) return id.toInt();
      return 0;
    }).where((id) => id > 0).toList();
  }

  @override
  Future<List<TransactionAttachment>> getAllAttachments() async {
    return await (db.select(db.transactionAttachments)
      ..orderBy([(t) => d.OrderingTerm(expression: t.createdAt, mode: d.OrderingMode.desc)])).get();
  }

  @override
  Future<void> deleteAttachmentByFileName(String fileName) async {
    await (db.delete(db.transactionAttachments)
      ..where((t) => t.fileName.equals(fileName))).go();
  }

  // ============================================
  // 响应式监听
  // ============================================

  @override
  Stream<List<TransactionAttachment>> watchAttachmentsByTransaction(int transactionId) {
    return (db.select(db.transactionAttachments)
      ..where((t) => t.transactionId.equals(transactionId))
      ..orderBy([(t) => d.OrderingTerm(expression: t.sortOrder)])).watch();
  }

  @override
  Stream<int> watchAttachmentCountByTransaction(int transactionId) {
    return db.customSelect(
      'SELECT COUNT(*) AS count FROM transaction_attachments WHERE transaction_id = ?',
      variables: [d.Variable.withInt(transactionId)],
      readsFrom: {db.transactionAttachments},
    ).watch().map((rows) {
      if (rows.isEmpty) return 0;
      final count = rows.first.data['count'];
      if (count is int) return count;
      if (count is BigInt) return count.toInt();
      if (count is num) return count.toInt();
      return 0;
    });
  }
}
