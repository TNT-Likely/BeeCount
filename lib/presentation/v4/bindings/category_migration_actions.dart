import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart' as db;
import '../../../l10n/app_localizations.dart';
import '../../../providers/database_providers.dart';
import '../../../utils/category_utils.dart';
import '../../../widgets/biz/category_selector_dialog.dart';

mixin CategoryMigrationActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  db.Category? migrationFrom, migrationTo;
  String? migrationType = 'expense';
  bool migrationWorking = false;
  void initializeCategoryMigration(db.Category? from) {
    migrationFrom = from;
    migrationType = from?.kind ?? 'expense';
  }

  void changeMigrationType(String type) => setState(() {
        migrationType = type;
        migrationFrom = null;
        migrationTo = null;
      });
  bool canMigrateCategories() =>
      migrationFrom != null &&
      migrationTo != null &&
      migrationFrom!.id != migrationTo!.id;
  Future<void> selectMigrationFrom() async {
    if (migrationWorking || migrationType == null) return;
    final picked = await showCategorySelector(context,
        type: migrationType!,
        currentCategoryId: migrationFrom?.id,
        includeParentCategories: false,
        showTransactionCount: true,
        ledgerId: ref.read(currentLedgerIdProvider));
    if (!mounted || picked == null) return;
    setState(() {
      migrationFrom = picked;
      if (migrationTo?.id == picked.id) migrationTo = null;
    });
  }

  Future<void> selectMigrationTo() async {
    if (migrationWorking || migrationFrom == null) return;
    final picked = await showCategorySelector(context,
        type: migrationFrom!.kind,
        currentCategoryId: migrationTo?.id,
        includeParentCategories: true,
        excludeIds: [migrationFrom!.id],
        showTransactionCount: true,
        ledgerId: ref.read(currentLedgerIdProvider));
    if (mounted && picked != null) setState(() => migrationTo = picked);
  }

  Future<void> migrationMessage(String title, String message) =>
      showBeeDialog<void>(context,
          title: title,
          child: Text(message),
          actions: [
            BeeButton(
                label: AppLocalizations.of(context).commonOk,
                onPressed: () => Navigator.pop(context))
          ]);

  Future<void> performCategoryMigration() async {
    if (migrationWorking || !canMigrateCategories()) return;
    final from = migrationFrom!,
        to = migrationTo!,
        l = AppLocalizations.of(context),
        repo = ref.read(repositoryProvider);
    setState(() => migrationWorking = true);
    try {
      final info = await repo.getCategoryMigrationInfo(
          fromCategoryId: from.id, toCategoryId: to.id);
      if (!mounted) return;
      if (!info.canMigrate) {
        await migrationMessage(
            l.categoryMigrationCannotTitle, l.categoryMigrationCannotMessage);
        return;
      }
      final confirmed = await showBeeConfirm(context,
          title: l.categoryMigrationConfirmTitle,
          message: l.categoryMigrationConfirmMessage(
              info.transactionCount.toString(),
              CategoryUtils.getDisplayName(from.name, context),
              CategoryUtils.getDisplayName(to.name, context)),
          confirmLabel: l.categoryMigrationConfirmOk,
          cancelLabel: l.commonCancel);
      if (!confirmed || !mounted) return;
      final count = await repo.migrateCategory(
          fromCategoryId: from.id, toCategoryId: to.id);
      if (!mounted) return;
      await migrationMessage(
          l.categoryMigrationCompleteTitle,
          l.categoryMigrationCompleteMessage(
              count.toString(),
              CategoryUtils.getDisplayName(from.name, context),
              CategoryUtils.getDisplayName(to.name, context)));
      if (!mounted) return;
      ref.invalidate(categoriesWithCountProvider);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        await migrationMessage(l.categoryMigrationFailedTitle,
            l.categoryMigrationFailedMessage(error.toString()));
      }
    } finally {
      if (mounted) setState(() => migrationWorking = false);
    }
  }
}
