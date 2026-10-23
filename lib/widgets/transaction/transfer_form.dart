import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../providers.dart';
import '../../providers/shared_ledger_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';
import '../../services/billing/post_processor.dart';
import '../../services/attachment_service.dart';
import '../../services/data/tx_author_service.dart';
import '../biz/amount_editor_sheet.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/shared_ledger_picker_filter.dart';
import '../ui/ui.dart';

/// 转账表单组件
/// 用于创建或编辑转账记录
class TransferForm extends ConsumerStatefulWidget {
  final bool initialExcludeFromStats;
  final bool initialExcludeFromBudget;
  final String? initialCurrencyCode;
  final double? initialNativeAmount;

  /// 转账完成回调
  final VoidCallback onTransferComplete;

  /// 初始转出账户ID（可选）
  final int? initialFromAccountId;

  /// 初始转入账户ID（可选）
  final int? initialToAccountId;

  /// 正在编辑的交易ID（编辑模式）
  final int? editingTransactionId;

  /// 初始金额（可选）
  final double? initialAmount;

  /// 初始备注（可选）
  final String? initialNote;

  /// 初始日期（可选）
  final DateTime? initialDate;

  /// 初始标签ID列表（可选）
  final List<int>? initialTagIds;

  const TransferForm({
    super.key,
    this.initialExcludeFromStats = false,
    this.initialExcludeFromBudget = false,
    this.initialCurrencyCode,
    this.initialNativeAmount,
    required this.onTransferComplete,
    this.initialFromAccountId,
    this.initialToAccountId,
    this.editingTransactionId,
    this.initialAmount,
    this.initialNote,
    this.initialDate,
    this.initialTagIds,
  });

  @override
  ConsumerState<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends ConsumerState<TransferForm> {
  int? _fromAccountId;
  int? _toAccountId;
  bool _autoOpened = false;
  final _amountEditorKey = GlobalKey<AmountEditorSheetState>();

  @override
  void initState() {
    super.initState();
    // 初始化账户ID（用于编辑模式）
    _fromAccountId = widget.initialFromAccountId;
    _toAccountId = widget.initialToAccountId;

    // 如果是编辑模式且两个账户都已选择，自动打开金额编辑弹窗
    if (_fromAccountId != null && _toAccountId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted && !_autoOpened) {
          _autoOpened = true;
          await _openAmountSheet();
        }
      });
    }
  }

  // 检查两个账户是否是相同币种
  Future<bool> _checkSameCurrency() async {
    if (_fromAccountId == null || _toAccountId == null) return false;

    final fromAccount = await _lookupAccount(_fromAccountId!);
    final toAccount = await _lookupAccount(_toAccountId!);
    return fromAccount?.currency == toAccount?.currency;
  }

  /// 反查账户:正数 id → 主表 accounts;负数 synthetic id → 扫
  /// SharedLedgerAccounts 找 syntheticIdForSyncId 命中(共享账本 Editor
  /// 视角下 picker 给出的是 Owner 的 synthetic 账户)。
  Future<Account?> _lookupAccount(int accountId) async {
    final repo = ref.read(repositoryProvider);
    if (accountId >= 0) return repo.getAccount(accountId);
    if (repo is! LocalRepository) return null;
    return repo.db.findAccountBySyntheticId(accountId);
  }

  /// 把 synthetic accountId(负数)反查回 Owner 的 syncId(正数 id 时返 null)。
  /// 用 ledger.syncId 限定 SharedLedgerAccounts 的查询范围。
  Future<String?> _resolveSyncIdByAccountId(int accountId, int ledgerId) async {
    if (accountId >= 0) return null;
    final repo = ref.read(repositoryProvider);
    if (repo is! LocalRepository) return null;
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

  // 当两个账户都选择后，自动弹出金额输入弹窗
  Future<void> _openAmountSheet() async {
    final l10n = AppLocalizations.of(context);

    // 检查币种是否一致(跨币种转账守卫,.docs/multi-currency-ledger 01 §4.4)
    final sameCurrency = await _checkSameCurrency();
    if (!sameCurrency) {
      // 存量数据放行(2026-07-12 细则):编辑模式且账户对未改动(老数据在
      // 守卫上线前就是跨币种)→ 放行让用户能改备注/日期等,不强迫重选账户。
      final isOriginalPair = widget.editingTransactionId != null &&
          _fromAccountId == widget.initialFromAccountId &&
          _toAccountId == widget.initialToAccountId;
      if (!isOriginalPair) {
        if (mounted) {
          showToast(context, l10n.transferDifferentCurrencyError);
          // 重置转入账户
          setState(() => _toAccountId = null);
        }
        return;
      }
    }

    final repo = ref.read(repositoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);

    final fromAccount = await _lookupAccount(_fromAccountId!);
    final toAccount = await _lookupAccount(_toAccountId!);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeeCardTheme.of(context).canvas,
      builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .88,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(17, 6, 8, 0),
                child: Row(children: [
                  Expanded(
                      child: Text(l10n.transferTitle,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600))),
                  BeeIconButton(
                      label: l10n.txFlagMoreOptions,
                      icon: const BeeLineIcon('Ellipsis', size: 21),
                      onPressed: () =>
                          _amountEditorKey.currentState?.showRecordingOptions())
                ])),
            Expanded(
                child: AmountEditorSheet(
              key: _amountEditorKey,
              cardLayout: true,
              categorySection: BeeTransferAccountPair(
                  fromLabel: l10n.transferFromAccount,
                  toLabel: l10n.transferToAccount,
                  fromName: fromAccount?.name ?? l10n.transferSelectAccount,
                  toName: toAccount?.name ?? l10n.transferSelectAccount),
              categoryName: l10n.transferTitle,
              initialDate: widget.initialDate ?? DateTime.now(),
              initialAmount: widget.initialAmount,
              initialNote: widget.initialNote,
              initialTagIds: widget.initialTagIds,
              showAccountPicker: false,
              ledgerId: ledgerId,
              editingTransactionId: widget.editingTransactionId,
              transactionKind: 'transfer',
              initialExcludeFromStats: widget.initialExcludeFromStats,
              initialExcludeFromBudget: widget.initialExcludeFromBudget,
              initialCurrencyCode: widget.initialCurrencyCode,
              initialNativeAmount: widget.initialNativeAmount,
              onSubmit: (result) async {
                final attachmentService = ref.read(attachmentServiceProvider);
                // 获取虚拟转账分类ID
                final transferCategory =
                    await ref.read(transferCategoryProvider.future);
                final transferCategoryId = transferCategory.id;

                // §7 共享账本:Editor picker 给的是 synthetic Account(负数 id)。
                // 写本地 Drift 时 accountId / toAccountId 留 null,override 字段
                // 走 Owner 的 syncId;push 序列化时按 override 输出 payload。
                final isSyntheticFrom =
                    _fromAccountId != null && _fromAccountId! < 0;
                final isSyntheticTo = _toAccountId != null && _toAccountId! < 0;
                final fromAccountForAdd =
                    isSyntheticFrom ? null : _fromAccountId;
                final toAccountForAdd = isSyntheticTo ? null : _toAccountId;
                final fromOverride = isSyntheticFrom
                    ? await _resolveSyncIdByAccountId(_fromAccountId!, ledgerId)
                    : null;
                final toOverride = isSyntheticTo
                    ? await _resolveSyncIdByAccountId(_toAccountId!, ledgerId)
                    : null;

                try {
                  if (widget.editingTransactionId != null) {
                    // 编辑模式：更新现有转账记录
                    await repo.updateTransaction(
                      id: widget.editingTransactionId!,
                      type: 'transfer',
                      amount: result.amount,
                      categoryId: transferCategoryId, // 使用虚拟转账分类ID
                      note: result.note,
                      happenedAt: result.date,
                      excludeFromStats: result.excludeFromStats,
                      excludeFromBudget: result.excludeFromBudget,
                      currencyCode: result.currencyCode,
                      nativeAmount: result.nativeAmount,
                      accountId: d.Value<int?>(fromAccountForAdd),
                      accountSyncIdOverride: fromOverride,
                    );
                    // 更新 toAccountId(同时写 toAccountSyncIdOverride,共享账本场景)
                    await repo.updateTransactionFields(
                      id: widget.editingTransactionId!,
                      toAccountId: d.Value<int?>(toAccountForAdd),
                      toAccountSyncIdOverride: toOverride,
                      writeToAccountSyncIdOverride: true,
                    );
                    // 共享账本:回填编辑人,UI 头像组立即展示
                    await TxAuthorService.markEdited(
                        ref, widget.editingTransactionId!);
                    // 更新标签
                    if (result.tagIds.isNotEmpty) {
                      await repo.updateTransactionTags(
                        transactionId: widget.editingTransactionId!,
                        tagIds: result.tagIds,
                      );
                      // 刷新标签列表缓存
                      ref.read(tagListRefreshProvider.notifier).state++;
                    } else {
                      // 编辑模式：如果没有选择标签，清除原有标签
                      await repo.removeAllTagsFromTransaction(
                          widget.editingTransactionId!);
                      ref.read(tagListRefreshProvider.notifier).state++;
                    }

                    // 保存待上传的附件
                    if (result.pendingAttachments.isNotEmpty) {
                      await attachmentService.saveAttachments(
                        transactionId: widget.editingTransactionId!,
                        sourceFiles: result.pendingAttachments,
                        startIndex: 0,
                      );
                      // 刷新附件列表缓存
                      ref.read(attachmentListRefreshProvider.notifier).state++;
                    }

                    // 统一处理：自动/手动同步与状态刷新
                    await PostProcessor.sync(ref, ledgerId: ledgerId);
                    // 刷新统计
                    ref.invalidate(countsForLedgerProvider(ledgerId));
                    ref.read(statsRefreshProvider.notifier).state++;

                    if (!context.mounted) return;
                    Navigator.of(context).pop(); // 关闭金额输入弹窗
                    showToast(context, l10n.transferUpdateSuccess);
                    widget.onTransferComplete();
                  } else {
                    // 创建模式：新建转账记录
                    final txId = await repo.addTransaction(
                      ledgerId: ledgerId,
                      type: 'transfer',
                      amount: result.amount,
                      categoryId: transferCategoryId, // 使用虚拟转账分类ID
                      accountId: fromAccountForAdd,
                      toAccountId: toAccountForAdd,
                      accountSyncIdOverride: fromOverride,
                      toAccountSyncIdOverride: toOverride,
                      note: result.note,
                      happenedAt: result.date,
                      excludeFromStats: result.excludeFromStats,
                      excludeFromBudget: result.excludeFromBudget,
                      currencyCode: result.currencyCode,
                      nativeAmount: result.nativeAmount,
                    );
                    // 共享账本:本地立即标记创建人 + 编辑人
                    await TxAuthorService.markCreated(ref, txId);

                    // 关联标签
                    if (result.tagIds.isNotEmpty) {
                      await repo.updateTransactionTags(
                        transactionId: txId,
                        tagIds: result.tagIds,
                      );
                      // 刷新标签列表缓存
                      ref.read(tagListRefreshProvider.notifier).state++;
                    }

                    // 保存待上传的附件
                    if (result.pendingAttachments.isNotEmpty) {
                      await attachmentService.saveAttachments(
                        transactionId: txId,
                        sourceFiles: result.pendingAttachments,
                        startIndex: 0,
                      );
                      // 刷新附件列表缓存
                      ref.read(attachmentListRefreshProvider.notifier).state++;
                    }

                    // 统一处理：自动/手动同步与状态刷新
                    await PostProcessor.sync(ref, ledgerId: ledgerId);
                    // 刷新统计
                    ref.invalidate(countsForLedgerProvider(ledgerId));
                    ref.read(statsRefreshProvider.notifier).state++;

                    if (!context.mounted) return;
                    Navigator.of(context).pop(); // 关闭金额输入弹窗
                    showToast(context, l10n.transferCreateSuccess);

                    // 重置状态
                    setState(() {
                      _fromAccountId = null;
                      _toAccountId = null;
                    });

                    widget.onTransferComplete();
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    showToast(context, '${l10n.commonError}: $e');
                  }
                }
              },
            )),
          ])),
    );
  }

  /// §7 共享账本:Editor 在共享账本下转账要选 Owner 的账户(SharedLedger
  /// Accounts 镜像),而非自己的 user-global。跟 AccountPicker / category_selector
  /// 一致用 filterAccountsForLedger 转 synthetic Account。
  ///
  /// 账户隐藏(#240)E1 钉住:编辑历史转账(editingTransactionId != null)时,
  /// 若转出/转入账户当前已被隐藏(因而被上面 filterAccountsForLedger 排
  /// 除),补回候选(hidden=true,build() 渲染网格时打「已隐藏」灰标),让用
  /// 户能原样保存;其余隐藏账户仍不出现。新建转账场景不钉住。跟
  /// AccountSelector.pinnedAccountId 同一范式(见 account_selector.dart)。
  Future<List<Account>> _loadFilteredAccounts() async {
    final repo = ref.read(repositoryProvider);
    final allAccounts = await repo.getAllAccounts();
    var accounts = allAccounts;
    if (repo is LocalRepository) {
      final currentLedgerId = ref.read(currentLedgerIdProvider);
      final ctx = await repo.db.loadLedgerPickerContext(currentLedgerId);
      accounts = await repo.db.filterAccountsForLedger(allAccounts, ctx);
    }

    if (widget.editingTransactionId != null ||
        widget.initialFromAccountId != null ||
        widget.initialToAccountId != null) {
      for (final pinnedId in {
        widget.initialFromAccountId,
        widget.initialToAccountId,
      }) {
        if (pinnedId == null) continue;
        if (accounts.any((a) => a.id == pinnedId)) continue;
        final pinned = await _lookupAccount(pinnedId);
        if (pinned != null && pinned.hidden) {
          accounts = [...accounts, pinned];
        }
      }
    }

    return accounts;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLedgerAsync = ref.watch(currentLedgerProvider);
    final currentCurrency = currentLedgerAsync.asData?.value?.currency ?? 'CNY';
    // WS shared_resource_change 推 Owner 账户更新后 rebuild,重查 SharedLedger
    // Accounts。
    ref.watch(sharedResourceRefreshProvider);

    return FutureBuilder<List<Account>>(
      future: _loadFilteredAccounts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${l10n.commonError}: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        final allAccounts = snapshot.data ?? const <Account>[];
        // 只显示与当前账本同币种的可交易账户;E1 钉住的隐藏账户(hidden==true,
        // 见 _loadFilteredAccounts)直接放行,不重复校验币种/类型,避免刚补回
        // 又被这里的过滤吃掉(跟 AccountSelector 的钉住语义一致)。
        final accounts = allAccounts
            .where((account) =>
                account.hidden ||
                (account.currency == currentCurrency &&
                    isTradableType(account.type)))
            .toList();

        if (accounts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l10n.transferSelectAccount,
                style: TextStyle(color: BeeTokens.textSecondary(context)),
              ),
            ),
          );
        }

        Account? account(int? id) {
          for (final value in accounts) {
            if (value.id == id) return value;
          }
          return null;
        }

        Future<void> select(bool from) async {
          final candidates = from
              ? accounts
              : accounts.where((a) => a.id != _fromAccountId).toList();
          final selected = await showBeeSheet<String>(context,
              title: from ? l10n.transferFromAccount : l10n.transferToAccount,
              child: BeeAccountPicker(
                  currency: currentCurrency,
                  filterByCurrency: false,
                  allowUnset: false,
                  unsetLabel: l10n.transferSelectAccount,
                  accounts: candidates
                      .map((a) => BeeAccountChoice(
                          id: '${a.id}',
                          name: a.name,
                          currency: a.currency,
                          balance: '',
                          icon: AccountTypeIcon(type: a.type, size: 24)))
                      .toList(),
                  selected: '${from ? _fromAccountId : _toAccountId}',
                  searchLabel: l10n.transferSelectAccount,
                  emptyLabel: l10n.accountsEmptyMessage,
                  onSelected: (id) => Navigator.pop(context, id)));
          if (selected == null || !mounted) return;
          setState(() {
            if (from) {
              _fromAccountId = int.parse(selected);
              if (_toAccountId == _fromAccountId) _toAccountId = null;
            } else {
              _toAccountId = int.parse(selected);
            }
          });
          if (_fromAccountId != null && _toAccountId != null) {
            await _openAmountSheet();
          }
        }

        final from = account(_fromAccountId), to = account(_toAccountId);
        return ListView(padding: const EdgeInsets.all(17), children: [
          BeeTransferAccountPair(
              fromLabel: l10n.transferFromAccount,
              toLabel: l10n.transferToAccount,
              fromName: from?.name ?? l10n.transferSelectAccount,
              toName: to?.name ?? l10n.transferSelectAccount,
              fromIcon: from == null
                  ? null
                  : AccountTypeIcon(type: from.type, size: 24),
              toIcon:
                  to == null ? null : AccountTypeIcon(type: to.type, size: 24),
              onFrom: () => select(true),
              onTo: () => select(false)),
          const SizedBox(height: 16),
          BeeButton(
              label: l10n.commonNext,
              onPressed: _fromAccountId != null && _toAccountId != null
                  ? _openAmountSheet
                  : null),
        ]);
      },
    );
  }
}
