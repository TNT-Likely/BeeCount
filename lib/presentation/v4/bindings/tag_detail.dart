import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart' as db;
import '../../../providers.dart';
import '../../../utils/month_range.dart';
import 'transaction_search.dart';

enum TagDetailPeriod { month, year, all }

typedef TagDetailScope = ({
  int tagId,
  int? ledgerId,
  DateTime? start,
  DateTime? end
});
typedef TagDetailStats = ({int count, double expense, double income});

/// Keep the existing all-history default and the ledger's custom month boundary.
DateRange? tagDetailRange(
        TagDetailPeriod period, int startDay, DateTime anchor) =>
    switch (period) {
      TagDetailPeriod.month =>
        periodForLabel(anchor.year, anchor.month, startDay),
      TagDetailPeriod.year => yearRangeFor(anchor.year, startDay),
      TagDetailPeriod.all => null,
    };

final tagDetailTagProvider = StreamProvider.autoDispose.family<db.Tag?, int>(
    (ref, id) => ref.watch(repositoryProvider).watchTag(id));

final tagDetailStatsProvider = FutureProvider.autoDispose
    .family<TagDetailStats, TagDetailScope>((ref, scope) {
  ref.watch(tagListRefreshProvider);
  ref.watch(statsRefreshProvider);
  ref.watch(syncGenerationProvider);
  ref.watch(tagDetailTransactionsProvider(scope));
  return ref.watch(repositoryProvider).getTagStats(scope.tagId,
      ledgerId: scope.ledgerId, start: scope.start, end: scope.end);
});

final tagDetailTransactionsProvider = StreamProvider.autoDispose
    .family<List<db.Transaction>, TagDetailScope>((ref, scope) => ref
        .watch(repositoryProvider)
        .watchTransactionsByTag(scope.tagId,
            ledgerId: scope.ledgerId, start: scope.start, end: scope.end));

class TagDetailRows {
  const TagDetailRows(this.rows, this.tags, this.attachments, this.ledgers);
  final List<SearchTransaction> rows;
  final Map<int, List<db.Tag>> tags;
  final Map<int, int> attachments;
  final Map<int, db.Ledger> ledgers;
}

/// Hydrate in batches, outside business-ui. Original transaction snapshots stay
/// intact; no conversion using current quotes and no per-row requests.
final tagDetailRowsProvider = FutureProvider.autoDispose
    .family<TagDetailRows, List<db.Transaction>>((ref, transactions) async {
  ref.watch(syncGenerationProvider);
  ref.watch(statsRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  final categories = await repo.getAllCategoriesIncludingShared();
  final accounts = await repo.getAllAccounts();
  final ledgers = await repo.getAllLedgers();
  final ids = transactions.map((t) => t.id).toList();
  final tags = await repo.getTagsForTransactions(ids);
  final attachments = await repo.getAttachmentCountsForTransactions(ids);
  // Shared rows point at sync IDs, not the local account table. Reuse the
  // repository's hydrated projection once per affected ledger.
  final shared = <int, SearchTransaction>{};
  final sharedLedgers = transactions
      .where((t) =>
          t.accountSyncIdOverride?.isNotEmpty == true ||
          t.toAccountSyncIdOverride?.isNotEmpty == true)
      .map((t) => t.ledgerId)
      .toSet();
  for (final ledgerId in sharedLedgers) {
    for (final row in await repo.getTransactionsWithCategoryByIds(
        ledgerId: ledgerId,
        transactionIds: transactions
            .where((t) => t.ledgerId == ledgerId)
            .map((t) => t.id)
            .toList())) {
      shared[row.t.id] = row;
    }
  }
  return TagDetailRows(
      transactions.map((t) {
        final category = categories
            .where((c) => t.categorySyncIdOverride?.isNotEmpty == true
                ? c.syncId == t.categorySyncIdOverride
                : c.id == t.categoryId)
            .firstOrNull;
        db.Account? account(int? id, String? syncId) => accounts
            .where((a) =>
                syncId?.isNotEmpty == true ? a.syncId == syncId : a.id == id)
            .firstOrNull;
        return (
          t: t,
          category: category,
          account: shared[t.id]?.account ??
              account(t.accountId, t.accountSyncIdOverride),
          toAccount: shared[t.id]?.toAccount ??
              account(t.toAccountId, t.toAccountSyncIdOverride)
        );
      }).toList(),
      tags,
      attachments,
      {for (final ledger in ledgers) ledger.id: ledger});
});

Color tagDetailColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  final clean = hex.replaceFirst('#', '');
  final value = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
  return value == null ? fallback : Color(value);
}
