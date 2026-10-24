import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart' as db;
import '../../../providers.dart';

/// 分页交易状态
class AccountTransactionsPaginationState {
  final List<db.Transaction> transactions;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  const AccountTransactionsPaginationState({
    this.transactions = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  AccountTransactionsPaginationState copyWith({
    List<db.Transaction>? transactions,
    bool? isLoading,
    bool? hasMore,
    Object? error,
  }) {
    return AccountTransactionsPaginationState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class AccountTransactionsPaginationNotifier
    extends StateNotifier<AccountTransactionsPaginationState> {
  final Ref ref;
  final int accountId;

  /// 资金流向过滤:'expense'=支出+转出,'income'=收入+转入,null=全部
  final String? flow;
  static const _pageSize = 50;

  AccountTransactionsPaginationNotifier(this.ref, this.accountId, this.flow)
      : super(const AccountTransactionsPaginationState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(repositoryProvider);
      final transactions = await repo.getAccountTransactions(accountId,
          limit: _pageSize, offset: 0, flow: flow);
      if (!mounted) return;
      state = AccountTransactionsPaginationState(
        transactions: transactions,
        isLoading: false,
        hasMore: transactions.length >= _pageSize,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(repositoryProvider);
      final transactions = await repo.getAccountTransactions(
        accountId,
        limit: _pageSize,
        offset: state.transactions.length,
        flow: flow,
      );
      if (!mounted) return;
      state = state.copyWith(
        transactions: [...state.transactions, ...transactions],
        isLoading: false,
        hasMore: transactions.length >= _pageSize,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> refresh() async {
    state = const AccountTransactionsPaginationState(isLoading: true);
    try {
      final repo = ref.read(repositoryProvider);
      final transactions = await repo.getAccountTransactions(accountId,
          limit: _pageSize, offset: 0, flow: flow);
      if (!mounted) return;
      state = AccountTransactionsPaginationState(
        transactions: transactions,
        isLoading: false,
        hasMore: transactions.length >= _pageSize,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false, error: e);
    }
  }
}

final accountTransactionsPaginatedProvider = StateNotifierProvider.family
    .autoDispose<AccountTransactionsPaginationNotifier,
        AccountTransactionsPaginationState, ({int accountId, String? flow})>(
  (ref, params) =>
      AccountTransactionsPaginationNotifier(ref, params.accountId, params.flow),
);

/// 分类统计 Provider
final accountCategoryStatsProvider = FutureProvider.family.autoDispose<
    List<({int? id, String name, String? icon, double total})>,
    ({int accountId, String type})>((ref, params) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getAccountCategoryStats(params.accountId, type: params.type);
});

/// Keep the existing repayment-day calculation independent of UI layout.
int? daysUntilAccountPayment(int? dueDay, DateTime now) {
  if (dueDay == null) return null;
  if (now.day <= dueDay) return dueDay - now.day;
  return DateTime(now.year, now.month + 1, 0).day - now.day + dueDay;
}

class AccountDetailReferences {
  const AccountDetailReferences(this.categories, this.accounts, this.ledgers);
  final List<db.Category> categories;
  final Map<int, db.Account> accounts;
  final Map<int, db.Ledger> ledgers;
  db.Category? categoryFor(db.Transaction transaction) => categories
      .where((c) => transaction.categoryId != null
          ? c.id == transaction.categoryId
          : transaction.categorySyncIdOverride != null &&
              c.syncId == transaction.categorySyncIdOverride)
      .firstOrNull;
}

final accountDetailReferencesProvider = FutureProvider.autoDispose((ref) async {
  ref.watch(syncGenerationProvider);
  ref.watch(statsRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  return AccountDetailReferences(
      await repo.getAllCategoriesIncludingShared(),
      {for (final account in await repo.getAllAccounts()) account.id: account},
      {for (final ledger in await repo.getAllLedgers()) ledger.id: ledger});
});

typedef AccountRowMetadata = ({
  Map<int, List<db.Tag>> tags,
  Map<int, int> attachments
});

final accountRowMetadataProvider = FutureProvider.autoDispose
    .family<AccountRowMetadata, String>((ref, ids) async {
  ref.watch(statsRefreshProvider);
  ref.watch(syncGenerationProvider);
  final repo = ref.watch(repositoryProvider);
  final parsed = ids.isEmpty ? <int>[] : ids.split(',').map(int.parse).toList();
  return (
    tags: await repo.getTagsForTransactions(parsed),
    attachments: await repo.getAttachmentCountsForTransactions(parsed)
  );
});
