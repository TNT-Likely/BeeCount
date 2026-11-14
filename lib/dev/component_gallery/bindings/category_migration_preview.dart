import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/category/category_migration_page.dart';
import '../../../providers/database_providers.dart';
import '../../../utils/category_utils.dart';
import '../../../pages/category/migration/bindings/category_migration_actions.dart';
import '../../../pages/shared/resources/bindings/recording_category_icon.dart';

final categoryMigrationInfoProvider = FutureProvider.autoDispose
    .family<({int transactionCount, bool canMigrate}), ({int from, int to})>(
        (ref, ids) {
  ref.watch(categoriesWithCountProvider);
  return ref
      .watch(repositoryProvider)
      .getCategoryMigrationInfo(fromCategoryId: ids.from, toCategoryId: ids.to);
});

/// Actual picker and migration-info reads; writes require the production route.
class LiveCategoryMigrationPreview extends ConsumerStatefulWidget {
  const LiveCategoryMigrationPreview({super.key});
  @override
  ConsumerState<LiveCategoryMigrationPreview> createState() =>
      _LiveCategoryMigrationPreviewState();
}

class _LiveCategoryMigrationPreviewState
    extends ConsumerState<LiveCategoryMigrationPreview>
    with CategoryMigrationActions<LiveCategoryMigrationPreview> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        categories = ref.watch(categoriesWithCountProvider);
    final info = canMigrateCategories()
        ? ref.watch(categoryMigrationInfoProvider(
            (from: migrationFrom!.id, to: migrationTo!.id)))
        : null;
    return categories.when(
        loading: () => const SizedBox(
            height: 120, child: Center(child: CircularProgressIndicator())),
        error: (error, stack) => BeeStatus(
            label: '读取分类失败',
            tone: BeeTone.error,
            action: TextButton(
                onPressed: () => ref.invalidate(categoriesWithCountProvider),
                child: const Text('重试'))),
        data: (rows) =>
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('真实分类迁移预览 · ${rows.length} 个分类'),
              const SizedBox(height: 8),
              BeeSegmented<String>(
                  items: [
                    BeeSegment('expense', l.categoryExpense),
                    BeeSegment('income', l.categoryIncome)
                  ],
                  value: migrationType ?? 'expense',
                  onChanged: changeMigrationType),
              const SizedBox(height: 12),
              BeeCategoryMigrationPair(
                  fromLabel: l.categoryMigrationFromLabel,
                  toLabel: l.categoryMigrationToLabel,
                  fromHint: l.categoryMigrationFromHint,
                  toHint: migrationFrom == null
                      ? l.categoryMigrationToHintFirst
                      : l.categoryMigrationToHint,
                  fromName: migrationFrom == null
                      ? null
                      : CategoryUtils.getDisplayName(
                          migrationFrom!.name, context),
                  toName: migrationTo == null
                      ? null
                      : CategoryUtils.getDisplayName(
                          migrationTo!.name, context),
                  fromIcon: migrationFrom == null
                      ? null
                      : RecordingCategoryIcon(
                          category: migrationFrom!, size: 24),
                  toIcon: migrationTo == null
                      ? null
                      : RecordingCategoryIcon(category: migrationTo!, size: 24),
                  onFrom: selectMigrationFrom,
                  onTo: migrationFrom == null ? null : selectMigrationTo),
              if (info != null) ...[
                const SizedBox(height: 12),
                info.when(
                    loading: () => const Text('正在读取真实迁移信息'),
                    error: (error, stack) => const Text('读取迁移信息失败'),
                    data: (value) => Text(
                        '${l.categoryMigrationTransactionLabel(value.transactionCount)} · ${value.canMigrate ? '可迁移' : '当前不可迁移'}'))
              ],
              const SizedBox(height: 12),
              const Text('这里只查询真实分类与迁移信息；确认和写入在正式页面完成。',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              BeeButton(
                  label: '打开分类迁移',
                  onPressed: () => Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CategoryMigrationPage(
                              preselectedFromCategory: migrationFrom)))),
            ]));
  }
}
