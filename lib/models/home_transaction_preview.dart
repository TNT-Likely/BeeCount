import '../data/db.dart';

typedef TransactionRowData = ({
  Transaction t,
  Category? category,
  Account? account,
  Account? toAccount,
});

/// A row is publishable only after all of its relationships have been read.
typedef TransactionDisplayItem = ({
  Transaction t,
  Category? category,
  Account? account,
  Account? toAccount,
  List<Tag> tags,
  int attachmentCount,
  String? accountName,
  String? toAccountName,
});

typedef TransactionDayTotals = ({double income, double expense});

/// Limited rows, but complete ledger count and complete totals for their days.
/// This is explicitly a preview, never a replacement for the full collection.
class HomeTransactionPreview {
  const HomeTransactionPreview({
    required this.ledgerId,
    required this.rows,
    required this.dayTotals,
    required this.totalCount,
  });

  final int ledgerId;
  final List<TransactionDisplayItem> rows;
  final Map<String, TransactionDayTotals> dayTotals;
  final int totalCount;
}
