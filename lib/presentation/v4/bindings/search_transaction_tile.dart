import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/attachment/attachment_preview_page.dart';
import '../../../pages/tag/tag_detail_page.dart';
import '../../../pages/transaction/category_detail_page.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/transaction_edit_utils.dart';
import '../../../widgets/biz/transaction_list_item.dart';
import '../../../widgets/category_icon.dart';
import 'transaction_search.dart';

class SearchTransactionTile extends ConsumerWidget {
  const SearchTransactionTile(
      {super.key,
      required this.row,
      required this.tags,
      required this.attachmentCount,
      required this.batch,
      required this.selected,
      required this.onSelect,
      required this.accountsEnabled,
      required this.onReturned});
  final SearchTransaction row;
  final List<Tag> tags;
  final int attachmentCount;
  final bool batch, selected, accountsEnabled;
  final VoidCallback? onSelect;
  final VoidCallback onReturned;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = row.t, transfer = row.t.type == 'transfer';
    final l = AppLocalizations.of(context);
    final name =
        CategoryUtils.getDisplayName(row.category?.name, context, kind: t.type);
    Future<void> open(Widget page) async {
      await Navigator.push(
          context, MaterialPageRoute<void>(builder: (_) => page));
      onReturned();
    }

    return TransactionListItem(
        icon: getCategoryIconData(category: row.category, categoryName: name),
        category: row.category,
        title: transfer && (t.note?.isEmpty ?? true)
            ? l.transferTitle
            : t.note ?? '',
        categoryName: transfer ? null : name,
        accountName: !accountsEnabled
            ? null
            : transfer
                ? [row.account?.name, row.toAccount?.name]
                    .whereType<String>()
                    .join(' → ')
                : row.account?.name,
        amount: t.amount,
        currencyCode: t.currencyCode,
        nativeAmount: t.nativeAmount,
        isExpense: t.type == 'expense',
        isTransfer: transfer,
        excludeFromStats: t.excludeFromStats,
        excludeFromBudget: t.excludeFromBudget,
        happenedAt: t.happenedAt,
        showFullDate: true,
        tags: tags
            .map((tag) => (id: tag.id, name: tag.name, color: tag.color))
            .toList(),
        attachmentCount: attachmentCount,
        onAttachmentTap: batch
            ? null
            : () => open(AttachmentPreviewPage.fromTransaction(
                transactionId: t.id, allowDelete: false)),
        onTagTap: batch
            ? null
            : (id, name) => open(TagDetailPage(tagId: id, tagName: name)),
        isSelectionMode: batch,
        isSelected: selected,
        onSelectionChanged: onSelect,
        onTap: batch
            ? null
            : () async {
                await TransactionEditUtils.editTransaction(
                    context, ref, t, row.category);
                onReturned();
              },
        onCategoryTap: batch || transfer || row.category == null
            ? null
            : () => open(CategoryDetailPage(
                categoryId: row.category!.id, categoryName: name)));
  }
}
