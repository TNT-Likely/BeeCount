import 'dart:convert';

import 'package:drift/drift.dart' as d;
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import 'bookkeeping_result.dart';

/// The persisted user message is the operation identity. The financial rows,
/// the receipt, and its chat bubble commit in the same local transaction.
final class ChatReceiptStore {
  ChatReceiptStore(this.db);
  final BeeDatabase db;
  Future<({Message source, Map<String, dynamic> metadata})> source(
      int id, int ledgerId, String text) async {
    final row = await (db.select(db.messages)..where((m) => m.id.equals(id)))
        .getSingle();
    final metadata = jsonDecode(row.metadata ?? '{}') as Map<String, dynamic>;
    if (row.role != 'user' ||
        metadata['contextLedgerId'] != ledgerId ||
        row.content != text) {
      throw StateError(
          'The bookkeeping request no longer matches its source message.');
    }
    return (source: row, metadata: metadata);
  }

  Future<Map<String, Object?>> save(
      Message source,
      Map<String, dynamic> metadata,
      BookkeepingResult result,
      int ledgerId,
      AppLocalizations l) async {
    final ids = result.transactionIds;
    final bills = result.savedBills.map((b) => b.toJson()).toList();
    final receipt = <String, Object?>{
      'bills': bills,
      'txIds': ids,
      'undoneIds': <int>[],
      'contextLedgerId': ledgerId,
      'receiptSourceId': source.id,
      'failedCount': result.failedCount,
      'unconvertedCurrencies': result.unconvertedCurrencies
    };
    final note = result.failedCount > 0 ? l.agentReceiptPartlySaved : null;
    if (note != null) receipt['supplementalText'] = note;
    final replyId = await db.into(db.messages).insert(MessagesCompanion.insert(
        conversationId: source.conversationId,
        role: 'assistant',
        messageType: 'bill_card',
        content: [
          ids.length == 1
              ? l.aiChatRecordSuccessOne
              : l.aiChatRecordSuccessMany(ids.length),
          if (note != null) note
        ].join('\n'),
        transactionId: d.Value(ids.first),
        metadata: d.Value(jsonEncode(receipt))));
    final stored = {...receipt, 'replyId': replyId};
    await (db.update(db.messages)..where((m) => m.id.equals(source.id))).write(
        MessagesCompanion(
            metadata:
                d.Value(jsonEncode({...metadata, 'agentReceipt': stored}))));
    return stored;
  }

  /// Keep edits or undo actions made on the live receipt while the model was
  /// composing the second part of a mixed request.
  Future<void> finish(int replyId, int sourceId, MessagesCompanion reply) =>
      db.transaction(() async {
        final row = await (db.select(db.messages)
              ..where((m) => m.id.equals(replyId)))
            .getSingleOrNull();
        if (row == null) return;
        final current = jsonDecode(row.metadata ?? '{}') as Map;
        if (current['receiptSourceId'] != sourceId || row.role != 'assistant') {
          throw StateError('Receipt identity mismatch');
        }
        final fields = {
          ...current,
          ...jsonDecode(reply.metadata.value ?? '{}') as Map,
          for (final key in ['bills', 'txIds', 'undoneIds'])
            if (current.containsKey(key)) key: current[key]
        };
        await (db.update(db.messages)..where((m) => m.id.equals(replyId)))
            .write(MessagesCompanion(
                content: reply.content, metadata: d.Value(jsonEncode(fields))));
      });
}
