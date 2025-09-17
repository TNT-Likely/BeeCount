import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db.dart';
import '../pages/category_picker.dart';

class TransactionEditUtils {
  static Future<void> editTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    Category? category,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryPickerPage(
          initialKind: transaction.type,
          quickAdd: true,
          initialCategoryId: transaction.categoryId,
          initialAmount: transaction.amount,
          initialDate: transaction.happenedAt,
          initialNote: transaction.note,
          editingTransactionId: transaction.id,
        ),
      ),
    );
  }
}