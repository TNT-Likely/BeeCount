import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db.dart';
import '../../../data/repositories/base_repository.dart';
import '../../../providers.dart';
import '../../../providers/shared_ledger_providers.dart';
import '../../../services/attachment_service.dart';
import 'transaction_search.dart';

/// Stable entry arguments: no stale transaction objects are needed on reopening.
@immutable
class TransactionDetailRequest {
  const TransactionDetailRequest(this.transactionId, {this.ledgerId});
  final int transactionId;
  final int? ledgerId;
  @override
  bool operator ==(Object other) =>
      other is TransactionDetailRequest &&
      other.transactionId == transactionId &&
      other.ledgerId == ledgerId;
  @override
  int get hashCode => Object.hash(transactionId, ledgerId);
}

class TransactionDetailData {
  const TransactionDetailData(
      {required this.row,
      required this.ledger,
      required this.tags,
      required this.attachments,
      this.parentCategory});
  final SearchTransaction row;
  final Ledger ledger;
  final Category? parentCategory;
  final List<Tag> tags;
  final List<TransactionAttachment> attachments;
  static String? _code(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim().toUpperCase();
  String get baseCurrency => _code(ledger.currency) ?? 'CNY';
  String get currency =>
      _code(row.t.currencyCode) ?? _code(row.account?.currency) ?? baseCurrency;
  bool get foreign => currency != baseCurrency;
  double? get historicalAmount =>
      foreign && row.t.nativeAmount?.isFinite == true
          ? row.t.nativeAmount
          : null;
  double? get historicalRate {
    final native = historicalAmount, original = row.t.amount;
    if (native == null || !original.isFinite || original == 0) return null;
    final rate = (native / original).abs();
    return rate.isFinite ? rate : null;
  }

  bool get canWrite =>
      const {'expense', 'income', 'transfer'}.contains(row.t.type) &&
      (!ledger.isShared || const {'owner', 'editor'}.contains(ledger.myRole));
}

/// Reuses the production shared-reference hydration. Synthetic IDs are matched
/// against its combined category projection; never queried as local entity IDs.
Future<TransactionDetailData?> loadTransactionDetail(
    BaseRepository repo, TransactionDetailRequest request) async {
  if (request.transactionId <= 0) return null;
  final tx = await repo.getTransactionById(request.transactionId);
  if (tx == null ||
      request.ledgerId != null && request.ledgerId != tx.ledgerId) {
    return null;
  }
  final ledger = await repo.getLedgerById(tx.ledgerId);
  if (ledger == null) return null;
  final rows = await repo.getTransactionsWithCategoryByIds(
      ledgerId: tx.ledgerId, transactionIds: [tx.id]);
  final row = rows.where((r) => r.t.id == tx.id).firstOrNull;
  if (row == null) return null;
  final categories = await repo.getAllCategoriesIncludingShared();
  final category =
      categories.where((c) => c.id == row.category?.id).firstOrNull ??
          row.category;
  final parent = category?.parentId == null
      ? null
      : categories.where((c) => c.id == category!.parentId).firstOrNull;
  final tags = await repo.getTagsForTransaction(tx.id);
  final attachments = await repo.getAttachmentsByTransaction(tx.id);
  return TransactionDetailData(
      row: (
        t: row.t,
        category: category,
        account: row.account,
        toAccount: row.toAccount
      ),
      ledger: ledger,
      parentCategory: parent,
      tags: tags,
      attachments: attachments);
}

final transactionDetailDataProvider = FutureProvider.autoDispose
    .family<TransactionDetailData?, TransactionDetailRequest>((ref, request) {
  ref.watch(statsRefreshProvider);
  ref.watch(tagListRefreshProvider);
  ref.watch(syncGenerationProvider);
  ref.watch(sharedResourceRefreshProvider);
  ref.watch(attachmentListRefreshProvider);
  return loadTransactionDetail(ref.watch(repositoryProvider), request);
});

final transactionDetailDirectoryProvider = FutureProvider.autoDispose<String>(
    (ref) async =>
        (await ref.watch(attachmentServiceProvider).getAttachmentDirectory())
            .path);
