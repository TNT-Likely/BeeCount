import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db.dart';
import '../pages/transaction/transaction_editor_page.dart';
import '../data/repositories/local/local_repository.dart';
import '../providers/database_providers.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ui/toast.dart';
import 'shared_ledger_picker_filter.dart' show syntheticIdForSyncId;

class TransactionEditUtils {
  static Future<void> copyTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) =>
      _openTransaction(context, ref, transaction, asCopy: true);

  static Future<void> editTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    Category? category,
  ) async {
    await _openTransaction(context, ref, transaction, asCopy: false);
  }

  static Future<void> _openTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction, {
    required bool asCopy,
  }) async {
    // 获取交易关联的标签ID(主表 + §7 override 表)
    final repo = ref.read(repositoryProvider);
    final source =
        asCopy ? await repo.getTransactionById(transaction.id) : transaction;
    transaction = source ?? transaction;
    final ledger = await repo.getLedgerById(transaction.ledgerId);
    if (!context.mounted) return;
    if (asCopy &&
        (source == null ||
            ledger == null ||
            !const {'expense', 'income', 'transfer'}
                .contains(transaction.type) ||
            (ledger.isShared &&
                !const {'owner', 'editor'}.contains(ledger.myRole)))) {
      showToast(
          context, AppLocalizations.of(context).transactionCopyUnavailable);
      return;
    }
    // Use the latest source after an asynchronous menu selection.
    if (asCopy) {
      final category = transaction.categoryId == null
          ? null
          : await repo.getCategoryById(transaction.categoryId!);
      final account = transaction.accountId == null
          ? null
          : await repo.getAccount(transaction.accountId!);
      final toAccount = transaction.toAccountId == null
          ? null
          : await repo.getAccount(transaction.toAccountId!);
      if (!context.mounted) return;
      if ((transaction.categoryId != null && category == null) ||
          (transaction.accountId != null && account == null) ||
          (transaction.toAccountId != null && toAccount == null)) {
        showToast(
            context, AppLocalizations.of(context).transactionCopyUnavailable);
        return;
      }
    }
    final tags = await repo.getTagsForTransaction(transaction.id);
    final tagIds = <int>[for (final t in tags) t.id];

    // §7 共享账本:加 TransactionTagOverrides → synthetic id 加进列表,
    // picker 显示选中
    if (repo is LocalRepository && transaction.syncId != null) {
      final overrides = await (repo.db.select(repo.db.transactionTagOverrides)
            ..where((t) => t.transactionSyncId.equals(transaction.syncId!)))
          .get();
      for (final ov in overrides) {
        final synthetic = syntheticIdForSyncId(ov.tagSyncId);
        if (!tagIds.contains(synthetic)) tagIds.add(synthetic);
      }
      if (asCopy && ledger != null) {
        final categories = await (repo.db.select(repo.db.sharedLedgerCategories)
              ..where((t) => t.ledgerSyncId.equals(ledger.syncId ?? '')))
            .get();
        final accounts = await (repo.db.select(repo.db.sharedLedgerAccounts)
              ..where((t) => t.ledgerSyncId.equals(ledger.syncId ?? '')))
            .get();
        final tags = await (repo.db.select(repo.db.sharedLedgerTags)
              ..where((t) => t.ledgerSyncId.equals(ledger.syncId ?? '')))
            .get();
        bool missing(String? syncId, Iterable<String> available) =>
            syncId != null && !available.contains(syncId);
        final invalid = missing(transaction.categorySyncIdOverride,
                categories.map((c) => c.syncId)) ||
            missing(transaction.accountSyncIdOverride,
                accounts.map((a) => a.syncId)) ||
            missing(transaction.toAccountSyncIdOverride,
                accounts.map((a) => a.syncId)) ||
            overrides
                .any((ov) => !tags.any((tag) => tag.syncId == ov.tagSyncId));
        if (!context.mounted) return;
        if (invalid) {
          showToast(
              context, AppLocalizations.of(context).transactionCopyUnavailable);
          return;
        }
      }
    }

    // §7 v25 共享账本:Editor 视角下记的 tx,categoryId/accountId 为 null,
    // 真实引用在 *SyncIdOverride。编辑时用 syntheticIdForSyncId 转成 picker
    // 列表里的 synthetic id,让 editor 反查时能命中"已选"。
    final int? initialCategoryId = transaction.categorySyncIdOverride != null
        ? syntheticIdForSyncId(transaction.categorySyncIdOverride!)
        : transaction.categoryId;
    final int? initialAccountId = transaction.accountSyncIdOverride != null
        ? syntheticIdForSyncId(transaction.accountSyncIdOverride!)
        : transaction.accountId;
    final int? initialToAccountId = transaction.toAccountSyncIdOverride != null
        ? syntheticIdForSyncId(transaction.toAccountSyncIdOverride!)
        : transaction.toAccountId;

    if (!context.mounted) return;
    // The copy entry belongs to the current homepage ledger. Recheck after
    // loading references so an asynchronously changed selection cannot redirect
    // this new transaction to another ledger.
    if (asCopy && ref.read(currentLedgerIdProvider) != transaction.ledgerId) {
      showToast(
          context, AppLocalizations.of(context).transactionCopyUnavailable);
      return;
    }

    // 所有类型（收入/支出/转账）都使用交易编辑器页面
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          final editor = asCopy
              ? TransactionEditorPage.copy(source: transaction, tagIds: tagIds)
              : TransactionEditorPage(
                  initialKind:
                      transaction.type, // 'expense', 'income', 或 'transfer'
                  quickAdd: true,
                  initialCategoryId: initialCategoryId,
                  initialAmount: transaction.amount,
                  initialDate: transaction.happenedAt,
                  initialNote: transaction.note,
                  editingTransactionId: transaction.id,
                  initialAccountId: initialAccountId,
                  // 转账特有的参数
                  initialToAccountId: initialToAccountId,
                  // 标签
                  initialTagIds: tagIds,
                  // 账单标记（不计入收支/预算）回显
                  initialExcludeFromStats: transaction.excludeFromStats,
                  initialExcludeFromBudget: transaction.excludeFromBudget,
                  // v30 多币种:编辑外币交易时汇率行按隐含汇率回显
                  initialCurrencyCode: transaction.currencyCode,
                  initialNativeAmount: transaction.nativeAmount,
                );
          return editor;
        },
      ),
    );
  }
}
