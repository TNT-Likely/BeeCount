import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/db.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../attachment/attachment_preview_page.dart';
import '../../../tag/tag_detail_page.dart';
import '../../../transaction/category_detail_page.dart';
import '../../../transaction/transaction_detail_page.dart';
import '../../../../utils/category_utils.dart';
import '../../../../utils/transaction_edit_utils.dart';
import '../transaction_list_item.dart';
import '../../resources/category_icon_adapter.dart';
import '../../../transaction/search/bindings/transaction_search.dart';

class TransactionTileBinding extends ConsumerWidget {
  const TransactionTileBinding(
      {super.key,
      required this.row,
      required this.tags,
      required this.attachmentCount,
      this.batch = false,
      this.selected = false,
      this.onSelect,
      this.fullDate = false,
      this.allLedgers = false,
      this.ledgerName,
      this.baseCurrency,
      this.transferDirection,
      this.onDelete,
      this.allowCategoryNavigation = true,
      this.accountsEnabled = true,
      required this.onReturned});
  final SearchTransaction row;
  final List<Tag> tags;
  final int attachmentCount;
  final bool batch,
      selected,
      accountsEnabled,
      fullDate,
      allLedgers,
      allowCategoryNavigation;
  final String? ledgerName, baseCurrency;
  final int? transferDirection;
  final Future<void> Function()? onDelete;
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
        ledgerName: ledgerName,
        baseCurrencyCode: baseCurrency,
        alwaysShowCurrency: allLedgers,
        onDelete: onDelete,
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
        transferDirection: transferDirection,
        excludeFromStats: t.excludeFromStats,
        excludeFromBudget: t.excludeFromBudget,
        happenedAt: t.happenedAt,
        showFullDate: fullDate,
        tags: tags
            .map((tag) => (id: tag.id, name: tag.name, color: tag.color))
            .toList(),
        attachmentCount: attachmentCount,
        onAttachmentTap: () => open(AttachmentPreviewPage.fromTransaction(
            transactionId: t.id, allowDelete: false)),
        onTagTap: (id, name) => open(
            TagDetailPage(tagId: id, tagName: name, allLedgers: allLedgers)),
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
        onLongPressStart: batch
            ? null
            : (details) async {
                final action = await showBeeContextMenu<String>(context,
                    anchor: details.globalPosition,
                    items: [
                      BeeMenuAction(
                          value: 'detail',
                          label: l.v4TransactionDetailTitle,
                          icon: const BeeLineIcon('FileText', size: 18))
                    ]);
                if (action == 'detail' && context.mounted) {
                  await open(TransactionDetailPage(
                      transactionId: t.id,
                      ledgerId: t.ledgerId,
                      allLedgers: allLedgers));
                }
              },
        onCategoryTap: !allowCategoryNavigation ||
                batch ||
                transfer ||
                row.category == null
            ? null
            : () => open(CategoryDetailPage(
                categoryId: row.category!.id,
                categoryName: name,
                allLedgers: allLedgers)));
  }
}
