import '../../../../data/db.dart';
import '../../../../data/repositories/base_repository.dart';
import '../../../../data/repositories/local/local_repository.dart';
import '../../../../utils/shared_ledger_picker_filter.dart';

class CategorySelectorData {
  const CategorySelectorData(this.categories, this.counts, this.eligible);
  final List<Category> categories;
  final Map<int, int> counts;
  final Map<int, bool> eligible;
}

/// Scope, real counts and asynchronous eligibility belong to the App adapter.
Future<CategorySelectorData> loadCategorySelectorData(
  BaseRepository repository, {
  required int? ledgerId,
  required bool onlyTopLevel,
  required bool showTransactionCount,
  Future<bool> Function(Category)? categoryFilter,
}) async {
  final all = await repository.getAllCategories();
  var categories = [
    ...all.where((c) => c.kind == 'income'),
    ...all.where((c) => c.kind == 'expense'),
  ];
  if (repository is LocalRepository) {
    final scope = await repository.db.loadLedgerPickerContext(ledgerId);
    categories = await repository.db.filterCategoriesForLedger(
        categories, scope,
        topLevelOnly: onlyTopLevel);
  }
  if (onlyTopLevel) {
    categories = categories.where((c) => c.parentId == null).toList();
  }
  final eligible = <int, bool>{};
  if (categoryFilter != null) {
    for (final category in categories) {
      eligible[category.id] = await categoryFilter(category);
    }
  }
  final counts = <int, int>{};
  if (showTransactionCount) {
    try {
      if (repository is LocalRepository) {
        final query = repository.db.select(repository.db.transactions);
        if (ledgerId != null) {
          query.where((t) => t.ledgerId.equals(ledgerId));
        }
        final primaryIds = all.map((c) => c.id).toSet();
        final bySyncId = {
          for (final c in categories)
            if (c.syncId != null && c.syncId!.isNotEmpty) c.syncId!: c.id
        };
        for (final row in await query.get()) {
          final id = primaryIds.contains(row.categoryId)
              ? row.categoryId
              : bySyncId[row.categorySyncIdOverride];
          if (id != null) counts[id] = (counts[id] ?? 0) + 1;
        }
      } else {
        final rows = await repository
            .transactionsWithCategoryAll(ledgerId: ledgerId)
            .first;
        for (final row in rows) {
          final id = row.category?.id;
          if (id != null) counts[id] = (counts[id] ?? 0) + 1;
        }
      }
    } catch (_) {
      // Counts are optional metadata; retain the original selectable fallback.
    }
  }
  return CategorySelectorData(categories, counts, eligible);
}
