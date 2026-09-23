import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db.dart';
import '../pages/transaction/transaction_editor_page.dart';
import '../data/repositories/local/local_repository.dart';
import '../providers/database_providers.dart';
import '../l10n/app_localizations.dart';
import 'shared_ledger_picker_filter.dart' show syntheticIdForSyncId;
import 'transaction_type_utils.dart';

class TransactionEditUtils {
  static Future<void> editTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    Category? category,
  ) async {
    if (isBalanceAdjustmentTransaction(transaction.type)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title:
              Text(AppLocalizations.of(context).balanceAdjustmentTransaction),
          content: Text(transaction.note ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).commonOk),
            ),
          ],
        ),
      );
      return;
    }
    // 获取交易关联的标签ID(主表 + §7 override 表)
    final repo = ref.read(repositoryProvider);
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

    // 所有类型（收入/支出/转账）都使用交易编辑器页面
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionEditorPage(
          initialKind: transaction.type, // 'expense', 'income', 或 'transfer'
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
        ),
      ),
    );
  }
}
