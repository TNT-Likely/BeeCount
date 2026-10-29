import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import 'migration/bindings/category_migration_actions.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import '../shared/resources/bindings/recording_category_icon.dart';
import '../../providers/database_providers.dart';
import '../../utils/category_utils.dart';

class CategoryMigrationPage extends ConsumerStatefulWidget {
  const CategoryMigrationPage({super.key, this.preselectedFromCategory});
  final db.Category? preselectedFromCategory;
  @override
  ConsumerState<CategoryMigrationPage> createState() =>
      _CategoryMigrationPageState();
}

class _CategoryMigrationPageState extends ConsumerState<CategoryMigrationPage>
    with CategoryMigrationActions<CategoryMigrationPage> {
  @override
  void initState() {
    super.initState();
    initializeCategoryMigration(widget.preselectedFromCategory);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        categories = ref.watch(categoriesWithCountProvider);
    String? name(db.Category? c) =>
        c == null ? null : CategoryUtils.getDisplayName(c.name, context);
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.categoryMigrationTitle, leading: const BackButton()),
      Expanded(
          child: categories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => BeeEmptyState(
                  title: l.categoryLoadFailed(error.toString()),
                  icon: const BeeLineIcon('CircleAlert', size: 36),
                  action: BeeButton(
                      label: l.v4RecordingRetry,
                      onPressed: () =>
                          ref.invalidate(categoriesWithCountProvider))),
              data: (_) => BeePageBody(eager: true, children: [
                    BeeSurface(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Row(children: [
                            const BeeLineIcon('Info', size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(l.categoryMigrationDescription,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)))
                          ]),
                          const SizedBox(height: 8),
                          Text(l.categoryMigrationDescriptionContent,
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: Theme.of(context).hintColor)),
                        ])),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l.categoryMigrationTypeLabel,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor)),
                          const SizedBox(height: 8),
                          BeeSegmented<String>(
                              items: [
                                BeeSegment('expense', l.categoryExpense),
                                BeeSegment('income', l.categoryIncome)
                              ],
                              value: migrationType ?? 'expense',
                              onChanged: migrationWorking
                                  ? null
                                  : changeMigrationType),
                        ]),
                    BeeCategoryMigrationPair(
                        fromLabel: l.categoryMigrationFromLabel,
                        toLabel: l.categoryMigrationToLabel,
                        fromHint: l.categoryMigrationFromHint,
                        toHint: migrationFrom == null
                            ? l.categoryMigrationToHintFirst
                            : l.categoryMigrationToHint,
                        fromName: name(migrationFrom),
                        toName: name(migrationTo),
                        fromIcon: migrationFrom == null
                            ? null
                            : RecordingCategoryIcon(
                                category: migrationFrom!, size: 24),
                        toIcon: migrationTo == null
                            ? null
                            : RecordingCategoryIcon(
                                category: migrationTo!, size: 24),
                        onFrom: migrationWorking ? null : selectMigrationFrom,
                        onTo: migrationWorking || migrationFrom == null
                            ? null
                            : selectMigrationTo),
                  ]))),
      BeeActionBar(
          primaryLabel: l.categoryMigrationStartButton,
          loading: migrationWorking,
          onPrimary: categories.asData != null &&
                  !migrationWorking &&
                  canMigrateCategories()
              ? performCategoryMigration
              : null),
    ]));
  }
}
