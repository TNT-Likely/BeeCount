import '../../../../data/db.dart';

/// The values in this snapshot are complete for every requested transaction,
/// including the transactions with no labels or attachments.
class TransactionListMetadata {
  const TransactionListMetadata(
      {required this.tags, required this.attachments});
  final Map<int, List<Tag>> tags;
  final Map<int, int> attachments;
}

class TransactionListMetadataSuperseded implements Exception {
  const TransactionListMetadataSuperseded();
}

/// Bound SQLite IN lists and the number of outstanding queries. Publish only
/// after both relationships are ready, so a row never grows a new metadata line
/// merely because its two independent reads completed in a different order.
Future<TransactionListMetadata> readTransactionListMetadata({
  required List<int> transactionIds,
  required Future<Map<int, List<Tag>>> Function(List<int>) readTags,
  required Future<Map<int, int>> Function(List<int>) readAttachmentCounts,
  bool Function()? isCurrent,
  int batchSize = 400,
  int concurrency = 3,
}) async {
  if (batchSize < 1 || batchSize > 500 || concurrency < 1 || concurrency > 4) {
    throw ArgumentError('Metadata reads require small bounded batches');
  }
  final ids = transactionIds.toSet().toList(growable: false);
  final tags = <int, List<Tag>>{};
  final counts = <int, int>{};
  var cursor = 0;
  Future<void> worker() async {
    while (cursor < ids.length) {
      if (isCurrent?.call() == false) return;
      final start = cursor;
      final end = (start + batchSize).clamp(0, ids.length);
      cursor = end;
      final batch = ids.sublist(start, end);
      final values = await Future.wait<Object>([
        readTags(batch),
        readAttachmentCounts(batch),
      ]);
      if (isCurrent?.call() == false) return;
      final batchTags = values[0] as Map<int, List<Tag>>;
      final batchCounts = values[1] as Map<int, int>;
      for (final id in batch) {
        tags[id] = List<Tag>.unmodifiable(batchTags[id] ?? const <Tag>[]);
        counts[id] = batchCounts[id] ?? 0;
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < concurrency && i < ids.length; i++) worker(),
  ]);
  if (isCurrent?.call() == false) {
    throw const TransactionListMetadataSuperseded();
  }
  return TransactionListMetadata(
      tags: Map.unmodifiable(tags), attachments: Map.unmodifiable(counts));
}
