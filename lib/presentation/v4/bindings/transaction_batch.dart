import '../../../data/db.dart';
import '../../../data/repositories/base_repository.dart';
import '../../../data/repositories/local/local_repository.dart';
import '../../../utils/shared_ledger_picker_filter.dart';

/// Financial values and relationships are deliberately absent from these writes.
/// The UI owns confirmation and selection; the binding rechecks scope at commit.
class TransactionBatchBinding {
  const TransactionBatchBinding(this.repository);
  final BaseRepository repository;

  Future<int> replaceNotes({
    required int ledgerId,
    required Iterable<int> transactionIds,
    required String note,
  }) =>
      _edit(
          ledgerId: ledgerId,
          transactionIds: transactionIds,
          update: (transaction) => repository.updateTransactionFields(
              id: transaction.id,
              writeNote: true,
              note: note.trim().isEmpty ? null : note.trim()));

  Future<int> changeCategory({
    required int ledgerId,
    required Iterable<int> transactionIds,
    required Category category,
  }) =>
      _edit(
          ledgerId: ledgerId,
          transactionIds: transactionIds,
          category: category,
          update: (transaction) => repository.updateTransactionFields(
              id: transaction.id,
              writeCategory: true,
              categoryId: category.id < 0 ? null : category.id,
              categorySyncIdOverride:
                  category.id < 0 ? category.syncId : null));

  Future<int> _edit({
    required int ledgerId,
    required Iterable<int> transactionIds,
    required Future<void> Function(Transaction) update,
    Category? category,
  }) async {
    final ids = transactionIds.toSet();
    if (ids.isEmpty) return 0;
    Future<int> run() async {
      final transactions = <Transaction>[];
      for (final id in ids) {
        final transaction = await repository.getTransactionById(id);
        if (transaction == null || transaction.ledgerId != ledgerId) {
          throw StateError('Batch selection changed or crossed ledger scope');
        }
        transactions.add(transaction);
      }
      if (category != null) {
        if (transactions
            .any((t) => t.type == 'transfer' || t.type != category.kind)) {
          throw StateError(
              'The selected transaction types cannot use this category');
        }
        var available = (await repository.getAllCategories())
            .where((c) => c.kind == category.kind)
            .toList();
        final repo = repository;
        if (repo is LocalRepository) {
          final scope = await repo.db.loadLedgerPickerContext(ledgerId);
          available = await repo.db.filterCategoriesForLedger(available, scope,
              kind: category.kind, topLevelOnly: false);
        }
        if (!available
            .any((c) => c.id == category.id && c.syncId == category.syncId)) {
          throw StateError('The selected category is no longer available');
        }
      }
      for (final transaction in transactions) {
        await update(transaction);
      }
      return transactions.length;
    }

    final repo = repository;
    return repo is LocalRepository ? repo.db.transaction(run) : run();
  }
}
