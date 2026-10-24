import '../../../data/db.dart';
import '../../../data/repositories/base_repository.dart';
import '../../../data/repositories/local/local_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/data/tag_seed_service.dart';
import '../../../services/export/config_export_service.dart';

/// Tag operations must not inherit ExportOptions' ledger/AI defaults.
const tagLibraryOptions = ExportOptions(
    ledgers: false,
    categories: false,
    accounts: false,
    tags: true,
    recurringTransactions: false,
    budgets: false,
    appSettings: false,
    ai: false);

class TagLibraryData {
  const TagLibraryData(this.repository);
  final BaseRepository repository;

  Future<T> _atomic<T>(Future<T> Function() action) {
    final repo = repository;
    if (repo is! LocalRepository) {
      throw UnsupportedError(
          'Atomic tag operations require the local repository');
    }
    return repo.db.transaction(action);
  }

  Future<List<Tag>> unused() async {
    final tags = await repository.getAllTags();
    final counts = await repository.getAllTagTransactionCounts();
    return tags.where((tag) => (counts[tag.id] ?? 0) == 0).toList();
  }

  /// Recheck within the write transaction: a tag may have acquired a reference
  /// while the confirmation dialog was open.
  Future<int> clearUnused(Iterable<int> candidates) => _atomic(() async {
        final counts = await repository.getAllTagTransactionCounts();
        var removed = 0;
        for (final id in candidates.toSet()) {
          if (id < 0 || (counts[id] ?? 0) > 0) continue;
          if (await repository.getTagById(id) == null) continue;
          await repository.deleteTag(id);
          removed++;
        }
        return removed;
      });

  Future<void> importYaml(String yaml,
          {required int ledgerId, required bool overwrite}) =>
      _atomic(() async {
        if (overwrite) {
          final candidates = await unused();
          await clearUnused(candidates.map((tag) => tag.id));
        }
        await ConfigExportService.importFromYaml(yaml,
            repository: repository,
            ledgerId: ledgerId,
            options: tagLibraryOptions,
            throwOnTagError: true);
      });

  Future<String> export(int ledgerId) => ConfigExportService.exportToYaml(
      repository: repository, ledgerId: ledgerId, options: tagLibraryOptions);

  Future<int> generate(AppLocalizations l) =>
      _atomic(() => TagSeedService.seedDefaultTags(repository, l));
}
