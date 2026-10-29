import '../../../pages/shared/transactions/bindings/transaction_row_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import '../../../data/db.dart';
import '../../../data/repositories/local/local_repository.dart';
import '../../../providers.dart';
import '../../../providers/shared_ledger_providers.dart';
import '../../../utils/account_type_utils.dart';
import '../../../utils/currencies.dart';
import '../../../utils/shared_ledger_picker_filter.dart';
import '../../../pages/transaction/transaction_editor_page.dart';
import '../../../pages/transaction/category_detail_page.dart';
import '../../../pages/attachment/attachment_preview_page.dart';
import '../../../pages/tag/tag_detail_page.dart';
import '../../../pages/shared/selectors/category_selector_dialog.dart';
import '../../../pages/transaction/recording/bindings/recording_category_section.dart';
import '../../../pages/shared/resources/bindings/recording_category_icon.dart';

typedef GalleryTransaction = ({
  Transaction t,
  Category? category,
  Account? account,
  Account? toAccount
});

class GalleryLedgerData {
  const GalleryLedgerData(
      {required this.ledger,
      required this.categories,
      required this.accounts,
      required this.balances,
      required this.rows,
      required this.tags,
      required this.attachments,
      required this.balance,
      required this.income,
      required this.expense,
      required this.dayCount,
      required this.txCount});
  final Ledger ledger;
  final List<Category> categories;
  final List<Account> accounts;
  final Map<int, double> balances;
  final List<GalleryTransaction> rows;
  final Map<int, List<Tag>> tags;
  final Map<int, int> attachments;
  final double balance, income, expense;
  final int dayCount, txCount;
}

/// Uses the same repository, shared-ledger filters and historical amount snapshots.
final galleryLedgerDataProvider =
    FutureProvider.autoDispose.family<GalleryLedgerData, int>((ref, id) async {
  ref.watch(statsRefreshProvider);
  ref.watch(tagListRefreshProvider);
  ref.watch(syncGenerationProvider);
  ref.watch(sharedResourceRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  final ledger = await repo.getLedgerById(id);
  if (ledger == null) throw StateError('账本不存在');
  final categories = await ref.watch(
      recordingCategoriesProvider((ledgerId: id, kind: 'expense')).future);
  var accounts = await repo.getAllAccounts();
  if (repo is LocalRepository) {
    final ctx = await repo.db.loadLedgerPickerContext(id);
    accounts = await repo.db.filterAccountsForLedger(accounts, ctx);
  }
  accounts =
      accounts.where((a) => !a.hidden && isTradableType(a.type)).toList();
  final balances = <int, double>{};
  for (final a in accounts) {
    // Synthetic shared accounts are not rows in the personal account repository.
    if (a.id >= 0) balances[a.id] = (await repo.getAccountStats(a.id)).balance;
  }
  final rows =
      await repo.getRecentTransactionsWithCategory(ledgerId: id, limit: 12);
  final ids = rows.map((r) => r.t.id).toList();
  final tags = await repo.getTagsForTransactions(ids);
  final attachments = await repo.getAttachmentCountsForTransactions(ids);
  final feature = await ref.watch(accountFeatureEnabledProvider.future);
  final stats =
      await repo.getLedgerStats(ledgerId: id, accountFeatureEnabled: feature);
  final totals = await repo.monthlyTotals(
      ledgerId: id, month: DateTime(DateTime.now().year, DateTime.now().month));
  final counts = await repo.getCountsForLedger(ledgerId: id);
  return GalleryLedgerData(
      ledger: ledger,
      categories: categories,
      accounts: accounts,
      balances: balances,
      rows: rows,
      tags: tags,
      attachments: attachments,
      balance: stats.balance,
      income: totals.$1,
      expense: totals.$2,
      dayCount: counts.dayCount,
      txCount: counts.txCount);
});

/// Real data is read here, never inside either presentation package.
class LiveBusinessPreview extends ConsumerStatefulWidget {
  const LiveBusinessPreview({super.key});
  @override
  ConsumerState<LiveBusinessPreview> createState() =>
      _LiveBusinessPreviewState();
}

class _LiveBusinessPreviewState extends ConsumerState<LiveBusinessPreview> {
  String? categoryId, accountId;
  int? selectionLedger;
  Future<void> record(int id) async {
    await Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => TransactionEditorPage(
                initialKind: 'expense',
                initialCategoryId: int.tryParse(categoryId ?? ''),
                initialAccountId: int.tryParse(accountId ?? ''))));
    if (mounted) ref.invalidate(galleryLedgerDataProvider(id));
  }

  @override
  Widget build(BuildContext context) {
    if (!TickerMode.of(context)) return const SizedBox.shrink();
    final id = ref.watch(currentLedgerIdProvider),
        hidden = ref.watch(hideAmountsProvider);
    final ledgers = ref.watch(ledgersStreamProvider).valueOrNull ?? <Ledger>[];
    final noteMode = ref.watch(noteDisplayModeProvider);
    final showTime = ref.watch(showTransactionTimeProvider);
    if (selectionLedger != id) {
      selectionLedger = id;
      categoryId = null;
      accountId = null;
    }
    return ref.watch(galleryLedgerDataProvider(id)).when(
        loading: () => const BeeSkeleton(label: '读取当前账本', rows: 3),
        error: (_, __) => BeeStatus(
            label: '读取账本失败',
            tone: BeeTone.error,
            action: BeeButton(
                label: '重新读取',
                onPressed: () =>
                    ref.invalidate(galleryLedgerDataProvider(id)))),
        data: (d) {
          final symbol = getCurrencySymbol(d.ledger.currency),
              categories = d.categories;
          final ids = categories.map((c) => c.id).toSet();
          final roots = categories
              .where((c) => c.parentId == null || !ids.contains(c.parentId));
          Widget icon(Category c) =>
              RecordingCategoryIcon(category: c, size: 20);
          final choices = roots
              .map((c) => BeeCategoryChoice(
                  id: '${c.id}',
                  label: c.name,
                  icon: icon(c),
                  children: categories
                      .where((child) => child.parentId == c.id)
                      .map((child) => BeeCategoryChoice(
                          id: '${child.id}',
                          label: child.name,
                          icon: icon(child)))
                      .toList()))
              .toList();
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('真实数据 · ${d.ledger.name}',
                    key: const ValueKey('live-ledger-title'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('读取当前 App 的本地账本；选择器只修改记账草稿，保存仍走原记账流程。',
                    style: TextStyle(fontSize: 11)),
                const SizedBox(height: 12),
                BeeLedgerBalance(
                    ledger: d.ledger.name,
                    stats: '${d.dayCount} 天 · ${d.txCount} 笔',
                    privacyLabel: hidden ? '显示金额' : '隐藏金额',
                    balanceLabel: '当前余额',
                    amount: d.balance.toStringAsFixed(2),
                    prefix: symbol,
                    days: '${d.dayCount}',
                    daysLabel: '记账天数',
                    count: '${d.txCount}',
                    countLabel: '账单笔数',
                    hidden: hidden,
                    onPrivacyTap: () =>
                        ref.read(hideAmountsProvider.notifier).state = !hidden,
                    onLedgerTap: () => showBeeSheet<void>(context,
                        title: '切换真实账本',
                        child: SizedBox(
                            height: 350,
                            child: BeeLedgerPicker(
                                ledgers: ledgers
                                    .map((l) => BeeLedgerChoice(
                                        id: '${l.id}',
                                        name: l.name,
                                        currency: l.currency,
                                        detail: l.isShared ? '共享账本' : '个人账本'))
                                    .toList(),
                                currentId: '$id',
                                searchLabel: '搜索账本',
                                emptyLabel: '没有可用账本',
                                currentLabel: '当前账本',
                                onSelected: (v) {
                                  ref
                                      .read(currentLedgerIdProvider.notifier)
                                      .state = int.parse(v);
                                  Navigator.pop(context);
                                })))),
                const SizedBox(height: 12),
                BeeSurface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      BeeButton(
                          label: '当前账本分类 · ${categories.length} 项',
                          onPressed: () => showBeeSheet<void>(context,
                              title: '真实分类 · ${d.ledger.name}',
                              child: SizedBox(
                                  height: 430,
                                  child: BeeCategoryPicker(
                                      items: choices,
                                      selected: categoryId,
                                      searchLabel: '搜索分类',
                                      emptyLabel: '当前账本暂无分类',
                                      confirmLabel: '使用分类',
                                      cancelLabel: '取消',
                                      onConfirm: (v) {
                                        setState(() => categoryId = v);
                                        Navigator.pop(context);
                                      },
                                      onCancel: () =>
                                          Navigator.pop(context))))),
                      const SizedBox(height: 8),
                      BeeButton(
                          label: '分类即时选择与笔数',
                          kind: BeeButtonKind.secondary,
                          onPressed: () async {
                            final selected = await showCategorySelector(context,
                                type: 'expense',
                                currentCategoryId:
                                    int.tryParse(categoryId ?? ''),
                                ledgerId: id,
                                showTransactionCount: true);
                            if (mounted &&
                                selected != null &&
                                ref.read(currentLedgerIdProvider) == id) {
                              setState(() => categoryId = '${selected.id}');
                            }
                          }),
                      const SizedBox(height: 8),
                      BeeButton(
                          label:
                              '当前币种账户 · ${d.accounts.where((a) => a.currency == d.ledger.currency).length} 项',
                          kind: BeeButtonKind.secondary,
                          onPressed: () => showBeeSheet<void>(context,
                              title: '真实账户 · ${d.ledger.currency}',
                              child: SizedBox(
                                  height: 340,
                                  child: BeeAccountPicker(
                                      currency: d.ledger.currency,
                                      accounts: d.accounts
                                          .map((a) => BeeAccountChoice(
                                              id: '${a.id}',
                                              name: a.name,
                                              currency: a.currency,
                                              balance: d.balances
                                                      .containsKey(a.id)
                                                  ? '${getCurrencySymbol(a.currency)}${d.balances[a.id]!.toStringAsFixed(2)}'
                                                  : '余额暂不可用',
                                              icon: AccountTypeIcon(
                                                  type: a.type, size: 24)))
                                          .toList(),
                                      selected: accountId,
                                      searchLabel: '搜索账户',
                                      emptyLabel: '暂无同币种账户',
                                      unsetLabel: '暂不设置账户',
                                      onSelected: (v) {
                                        setState(() => accountId = v);
                                        Navigator.pop(context);
                                      })))),
                      const SizedBox(height: 8),
                      BeeButton(
                          label: '带所选分类和账户记一笔', onPressed: () => record(id)),
                    ])),
                const SizedBox(height: 12),
                Text('真实交易 · 最近 ${d.rows.length} 笔',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (d.rows.isEmpty) const BeeEmptyState(title: '当前账本暂无交易'),
                ...d.rows.map((r) {
                  final tx = r.t,
                      code = tx.currencyCode ??
                          r.account?.currency ??
                          d.ledger.currency;
                  final composed = composeTransactionRowTitle(
                      mode: noteMode,
                      categoryName: tx.type == 'transfer'
                          ? null
                          : r.category?.name ?? '未分类',
                      title: tx.note ?? (tx.type == 'transfer' ? '账户转账' : ''));
                  final accountName = tx.type == 'transfer'
                      ? [r.account?.name, r.toAccount?.name]
                          .whereType<String>()
                          .join(' → ')
                      : r.account?.name;
                  final sign = tx.type == 'income'
                      ? '+'
                      : tx.type == 'transfer'
                          ? ''
                          : '−';
                  return BeeSurface(
                      padding: EdgeInsets.zero,
                      child: BeeTransactionRow(
                        key: ValueKey('live-tx-${tx.id}'),
                        title: composed.primary,
                        note: composed.parenNote,
                        detailsNote: tx.note,
                        categoryLabel: r.category?.name,
                        labels: transactionRowLabels(context),
                        amount:
                            '$sign${getCurrencySymbol(code)}${tx.amount.toStringAsFixed(2)}',
                        converted: code != d.ledger.currency &&
                                tx.nativeAmount != null &&
                                tx.nativeAmount != tx.amount
                            ? '≈ $symbol${tx.nativeAmount!.toStringAsFixed(2)}'
                            : null,
                        kind: BeeTransactionKind.values.byName(tx.type),
                        happenedAt: tx.happenedAt,
                        showTime: showTime,
                        accountName: accountName,
                        onAttachmentTap: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    AttachmentPreviewPage.fromTransaction(
                                        transactionId: tx.id))),
                        onTagTap: (tag) => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => TagDetailPage(
                                    tagId: int.parse(tag.id),
                                    tagName: tag.label))),
                        onMoreTagsTap: () => showBeeSheet<void>(context,
                            title: '全部标签',
                            child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (d.tags[tx.id] ?? [])
                                    .map((t) => BeeChoiceChip(
                                        label: t.name,
                                        selected: true,
                                        onSelected: (_) {
                                          Navigator.pop(context);
                                          Navigator.push<void>(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => TagDetailPage(
                                                      tagId: t.id,
                                                      tagName: t.name)));
                                        }))
                                    .toList())),
                        icon: r.category == null
                            ? const BeeCategoryIcon()
                            : Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                    color: BeeCardTheme.of(context).soft,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Center(child: icon(r.category!))),
                        hidden: hidden,
                        tags: (d.tags[tx.id] ?? [])
                            .map((t) => BeeTagData(
                                '${t.id}',
                                t.name,
                                Color(int.tryParse(
                                        (t.color ?? '#9C9C9C')
                                            .replaceFirst('#', 'ff'),
                                        radix: 16) ??
                                    0xff9c9c9c)))
                            .toList(),
                        attachmentCount: d.attachments[tx.id] ?? 0,
                        statusLabels: [
                          if (tx.excludeFromStats) '不计收支',
                          if (tx.excludeFromBudget) '不计预算'
                        ],
                        onCategoryTap: () {
                          if (r.category != null) {
                            Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => CategoryDetailPage(
                                        categoryId: r.category!.id,
                                        categoryName: r.category!.name)));
                          }
                        },
                        onTap: () => showBeeDialog<void>(context,
                            title: '真实账单',
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('备注：${tx.note ?? '无'}'),
                                  Text('币种：$code'),
                                  Text(
                                      '金额：${hidden ? '••••' : tx.amount.toStringAsFixed(2)}'),
                                  Text('账户：${r.account?.name ?? '未设置'}'),
                                  Text('日期：${tx.happenedAt}')
                                ])),
                      ));
                }),
                const SizedBox(height: 12),
                BeeButton(
                    label: '刷新真实数据',
                    kind: BeeButtonKind.secondary,
                    onPressed: () =>
                        ref.invalidate(galleryLedgerDataProvider(id))),
              ]);
        });
  }
}
