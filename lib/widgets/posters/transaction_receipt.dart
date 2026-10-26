import 'package:beecount_business_ui/share_posters.dart';
import 'package:beecount_ui/paper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/category_utils.dart';
import '../../utils/currencies.dart';
import 'poster_projection.dart';

/// A read-only snapshot. Receipt options never write back to the transaction.
class TransactionReceiptData {
  const TransactionReceiptData(
      {required this.transaction,
      required this.ledger,
      this.category,
      this.account,
      this.toAccount,
      this.tags = const []});
  final Transaction transaction;
  final Ledger ledger;
  final Category? category;
  final Account? account, toAccount;
  final List<Tag> tags;
}

class TransactionReceipt extends StatelessWidget {
  const TransactionReceipt(
      {super.key,
      required this.data,
      this.showNote = true,
      this.showTags = true,
      this.showAccount = false,
      this.showLedger = false});
  final TransactionReceiptData data;
  final bool showNote, showTags, showAccount, showLedger;
  static const ink = BeePaper.ink,
      muted = BeePaper.muted,
      paper = Color(0xfffffefa);
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), tx = data.transaction;
    final locale = Localizations.localeOf(context).toString();
    final currency =
        tx.currencyCode ?? data.account?.currency ?? data.ledger.currency;
    final amount =
        NumberFormat.currency(locale: locale, name: currency, symbol: '')
            .format(tx.amount.abs())
            .trim();
    final kind = switch (tx.type) {
      'income' => l.homeIncome,
      'transfer' => l.transferTitle,
      _ => l.homeExpense
    };
    BeeReceiptRow row(String label, String value) =>
        BeeReceiptRow(label, Text(value));
    return MediaQuery.withNoTextScaling(
        child: BeeReceiptPoster(
            brand: posterBrand(l, Theme.of(context).colorScheme.primary,
                size: 31, centered: true, nameSize: 15, captionSize: 7),
            amount:
                '${tx.type == 'expense' ? '−' : tx.type == 'income' ? '+' : ''}${getCurrencySymbol(currency)}$amount',
            currency: currency,
            kind: kind,
            rows: [
              if (tx.type != 'transfer')
                row(
                    l.importFieldCategory,
                    CategoryUtils.getDisplayName(data.category?.name, context,
                        kind: tx.type)),
              row(
                  l.importFieldDate,
                  DateFormat('yyyy.MM.dd  HH:mm', locale)
                      .format(tx.happenedAt)),
              if (showAccount && tx.type == 'transfer') ...[
                if (data.account != null)
                  row(l.transferFromAccount, data.account!.name),
                if (data.toAccount != null)
                  row(l.transferToAccount, data.toAccount!.name),
              ] else if (showAccount && data.account != null)
                row(l.importFieldAccount, data.account!.name),
              if (showLedger) row(l.transactionReceiptLedger, data.ledger.name),
              if (showTags && data.tags.isNotEmpty)
                BeeReceiptRow(
                    l.transactionReceiptTags,
                    Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final tag in data.tags)
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: const Color(0xfffff6d9),
                                    borderRadius: BorderRadius.circular(99)),
                                child: Text('#${tag.name}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xff8c741a))))
                        ]))
            ],
            noteLabel: l.importFieldNote,
            note: showNote && (tx.note?.trim().isNotEmpty ?? false)
                ? Text(tx.note!,
                    key: const ValueKey('receipt-note'),
                    style: const TextStyle(fontSize: 12, height: 1.7))
                : null,
            footer: l.transactionReceiptFooter));
  }
}
