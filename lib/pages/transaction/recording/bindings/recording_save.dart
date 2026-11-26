import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/db.dart';
import '../../../../data/repositories/local/local_repository.dart';
import '../../../../providers.dart';
import '../../../../providers/budget_providers.dart';
import '../../../../services/attachment_service.dart';
import '../../../../services/billing/post_processor.dart';
import '../../../../services/data/tx_author_service.dart';
import '../../../../utils/shared_ledger_picker_filter.dart';
import 'amount_editor_sheet.dart';
import 'recording_category_section.dart';
import 'transfer_inline_accounts.dart';

/// Persist an editor draft through the original repository and sync services.
/// The page retains the created identity so a later metadata failure can retry
/// without creating a second transaction.
Future<void> persistRecordingDraft(
  WidgetRef ref, {
  required int ledgerId,
  required Category category,
  required String kind,
  required AmountEditorResult result,
  required int? editingId,
  required ValueChanged<int> onCreated,
}) async {
  final c = category;
  final res = result;
  if (ledgerId != ref.read(currentLedgerIdProvider)) {
    throw StateError('Ledger context changed during recording');
  }
  final available = await ref.read(
      recordingCategoriesProvider((ledgerId: ledgerId, kind: kind)).future);
  if (!available.any((entry) => entry.id == c.id)) {
    throw StateError('Selected category is no longer available');
  }
  final repo = ref.read(repositoryProvider);
  int transactionId;
  // §7 v25:Category 是来自 SharedLedger* 的 synthetic (id<0)时,
  // categoryId 留 null,override 走 syncId。同理对 account/toAccount。
  // res.accountId 可能也是 synthetic(Account picker 用同一规则)。
  final isSyntheticCategory = c.id < 0;
  final isSyntheticAccount = res.accountId != null && res.accountId! < 0;
  final categoryIdForWrite = isSyntheticCategory ? null : c.id;
  // synthetic / picker 返 null 时账户 id 写 null。
  // addTransaction 的 accountId 是 int?(直接传 null 即写 null);
  // updateTransaction 的 accountId 是 dynamic,dart null 被解释成
  // Value.absent(=不更新该字段) → 用户选"不选择账户"无效;必须显式
  // 传 d.Value<int?>(null) 才会真清空旧 accountId。
  final accountIdForAdd = isSyntheticAccount ? null : res.accountId;
  final accountIdForUpdate = d.Value<int?>(accountIdForAdd);
  final categoryOverride = isSyntheticCategory ? c.syncId : null;
  final accountOverride = isSyntheticAccount
      ? await _resolveSyncIdByAccountId(ref, res.accountId!, ledgerId)
      : null;
  if (editingId != null) {
    transactionId = editingId;
    await _editExisting(ref, ledgerId, editingId, () async {
      await repo.updateTransaction(
        id: editingId,
        type: kind,
        amount: res.amount,
        categoryId: categoryIdForWrite,
        note: res.note,
        happenedAt: res.date,
        accountId: accountIdForUpdate,
        categorySyncIdOverride: categoryOverride,
        accountSyncIdOverride: accountOverride,
        excludeFromStats: res.excludeFromStats,
        excludeFromBudget: res.excludeFromBudget,
        currencyCode: res.currencyCode,
        nativeAmount: res.nativeAmount,
      );
      // 共享账本:本地 lastEditedByUserId 立即回填,UI 头像组直接展示
      // 当前 user 为编辑人(否则要等 server 下次 pull 才回来)
      await TxAuthorService.markEdited(ref, transactionId);
      await _persistRecordingMetadata(ref,
          transactionId: editingId, result: res, editing: true);
    });
  } else {
    transactionId = await repo.addTransaction(
      ledgerId: ledgerId,
      type: kind,
      amount: res.amount,
      categoryId: categoryIdForWrite,
      happenedAt: res.date,
      note: res.note,
      accountId: accountIdForAdd,
      categorySyncIdOverride: categoryOverride,
      accountSyncIdOverride: accountOverride,
      excludeFromStats: res.excludeFromStats,
      excludeFromBudget: res.excludeFromBudget,
      currencyCode: res.currencyCode,
      nativeAmount: res.nativeAmount,
    );
    onCreated(transactionId);
    // 共享账本:新建本地 tx 也回填创建人 + 编辑人(同一个 user)
    await TxAuthorService.markCreated(ref, transactionId);
    await _persistRecordingMetadata(ref,
        transactionId: transactionId, result: res, editing: false);
  }
  // 统一处理：自动/手动同步与状态刷新（后台静默）
  PostProcessor.sync(ref, ledgerId: ledgerId);
  // 刷新：账本笔数与全局统计
  ref.invalidate(countsForLedgerProvider(ledgerId));
  ref.read(statsRefreshProvider.notifier).state++;
  // 刷新：预算数据
  ref.read(budgetRefreshProvider.notifier).state++;
}

/// App-owned transfer persistence; the caller retains a created identity on
/// metadata failure so retry updates that row instead of creating another.
Future<void> persistTransferDraft(
  WidgetRef ref, {
  required int ledgerId,
  required int fromAccountId,
  required int toAccountId,
  required AmountEditorResult result,
  required int? editingId,
  required ValueChanged<int> onCreated,
  Set<int> pinnedAccountIds = const {},
}) async {
  if (ledgerId != ref.read(currentLedgerIdProvider)) {
    throw StateError('Ledger context changed during transfer');
  }
  await validateTransferInlineWrite(ref,
      ledgerId: ledgerId,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: result.amount,
      currencyCode: result.currencyCode,
      nativeAmount: result.nativeAmount,
      editingId: editingId,
      pinnedAccountIds: pinnedAccountIds);
  final repo = ref.read(repositoryProvider);
  final category = await ref.read(transferCategoryProvider.future);
  final fromOverride = fromAccountId < 0
      ? await _resolveSyncIdByAccountId(ref, fromAccountId, ledgerId)
      : null;
  final toOverride = toAccountId < 0
      ? await _resolveSyncIdByAccountId(ref, toAccountId, ledgerId)
      : null;
  final fromId = fromAccountId < 0 ? null : fromAccountId;
  final toId = toAccountId < 0 ? null : toAccountId;
  late final int transactionId;
  if (editingId == null) {
    transactionId = await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'transfer',
      amount: result.amount,
      categoryId: category.id,
      accountId: fromId,
      toAccountId: toId,
      accountSyncIdOverride: fromOverride,
      toAccountSyncIdOverride: toOverride,
      happenedAt: result.date,
      note: result.note,
      excludeFromStats: result.excludeFromStats,
      excludeFromBudget: result.excludeFromBudget,
      currencyCode: result.currencyCode,
      nativeAmount: result.nativeAmount,
    );
    onCreated(transactionId);
    await TxAuthorService.markCreated(ref, transactionId);
    await _persistRecordingMetadata(ref,
        transactionId: transactionId, result: result, editing: false);
  } else {
    transactionId = editingId;
    await _editExisting(ref, ledgerId, transactionId, () async {
      await repo.updateTransaction(
        id: transactionId,
        type: 'transfer',
        amount: result.amount,
        categoryId: category.id,
        accountId: d.Value<int?>(fromId),
        accountSyncIdOverride: fromOverride,
        happenedAt: result.date,
        note: result.note,
        excludeFromStats: result.excludeFromStats,
        excludeFromBudget: result.excludeFromBudget,
        currencyCode: result.currencyCode,
        nativeAmount: result.nativeAmount,
      );
      await repo.updateTransactionFields(
        id: transactionId,
        toAccountId: d.Value<int?>(toId),
        toAccountSyncIdOverride: toOverride,
        writeToAccountSyncIdOverride: true,
      );
      await TxAuthorService.markEdited(ref, transactionId);
      await _persistRecordingMetadata(ref,
          transactionId: transactionId, result: result, editing: true);
    });
  }
  await PostProcessor.sync(ref, ledgerId: ledgerId);
  ref.invalidate(countsForLedgerProvider(ledgerId));
  ref.read(statsRefreshProvider.notifier).state++;
}

/// A synced move can land while the editor is open. Keep the identity check,
/// financial update and its tags/attachments within the same SQLite transaction.
Future<void> _editExisting(
    WidgetRef ref, int ledgerId, int id, Future<void> Function() update) {
  final repo = ref.read(repositoryProvider);
  Future<void> checkedUpdate() async {
    final live = await repo.getTransactionById(id);
    if (live == null || live.ledgerId != ledgerId) {
      throw StateError('The entry is no longer in this ledger');
    }
    await update();
  }

  return repo is LocalRepository
      ? repo.db.transaction(checkedUpdate)
      : checkedUpdate();
}

Future<void> _persistRecordingMetadata(
  WidgetRef ref, {
  required int transactionId,
  required AmountEditorResult result,
  required bool editing,
}) async {
  final repo = ref.read(repositoryProvider);
  final res = result;
  if (editing || res.tagIds.isNotEmpty) {
    await repo.updateTransactionTags(
      transactionId: transactionId,
      tagIds: repo is LocalRepository
          ? res.tagIds
          : res.tagIds.where((id) => id >= 0).toList(),
    );
    ref.read(tagListRefreshProvider.notifier).state++;
  }
  // Save files after tag writes, so a failed tag retry cannot duplicate them.
  if (res.pendingAttachments.isNotEmpty) {
    final attachmentService = ref.read(attachmentServiceProvider);
    await attachmentService.saveAttachments(
      transactionId: transactionId,
      sourceFiles: res.pendingAttachments,
      startIndex: 0,
    );
    // 刷新附件列表缓存
    ref.read(attachmentListRefreshProvider.notifier).state++;
  }
}

/// 获取默认账户ID（验证币种匹配）
Future<int?> defaultRecordingAccount(
    WidgetRef ref, String kind, int ledgerId) async {
  try {
    // 1. 根据类型获取默认账户ID
    final defaultAccountId = kind == 'income'
        ? await ref.read(defaultIncomeAccountIdProvider.future)
        : await ref.read(defaultExpenseAccountIdProvider.future);

    if (defaultAccountId == null) return null;

    // 2. 获取账本币种
    final ledger = await ref.read(ledgerByIdProvider(ledgerId).future);
    if (ledger == null) return null;

    // 3. 获取默认账户信息
    final account =
        await ref.read(accountByIdProvider(defaultAccountId).future);
    if (account == null) return null;

    // 账户隐藏 #240 E3:默认账户已被隐藏时按「无默认」处理(defensive 兜底,
    // 正常路径下隐藏时已清 pref,这里防同步竞态等边缘情况)
    if (account.hidden) return null;

    // 4. 验证币种匹配
    if (account.currency != ledger.currency) return null;

    return defaultAccountId;
  } catch (e) {
    return null;
  }
}

/// §7 v25:account picker 返 synthetic Account(id<0)时,把 id 反查
/// SharedLedgerAccounts 拿 syncId,写到 tx.accountSyncIdOverride。
/// 失败返 null,调用方应回到 accountId int 路径(synthetic 不一致时的兜底)。
Future<String?> _resolveSyncIdByAccountId(
    WidgetRef ref, int accountId, int ledgerId) async {
  if (accountId >= 0) return null;
  final repo = ref.read(repositoryProvider);
  if (repo is! LocalRepository) return null;
  // 反查:本地 ledger.syncId → SharedLedgerAccounts ledgerSyncId 范围
  final ledger = await (repo.db.select(repo.db.ledgers)
        ..where((l) => l.id.equals(ledgerId)))
      .getSingleOrNull();
  if (ledger?.syncId == null) return null;
  final rows = await (repo.db.select(repo.db.sharedLedgerAccounts)
        ..where((t) => t.ledgerSyncId.equals(ledger!.syncId!)))
      .get();
  for (final r in rows) {
    if (syntheticIdForSyncId(r.syncId) == accountId) return r.syncId;
  }
  return null;
}
