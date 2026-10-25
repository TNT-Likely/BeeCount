import 'package:flutter/material.dart';
import '../../presentation/v4/bindings/transaction_detail_controls.dart';

/// Reopening resolves the latest local record from stable transaction/ledger IDs.
class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage(
      {super.key,
      required this.transactionId,
      this.ledgerId,
      this.allLedgers = false});
  final int transactionId;
  final int? ledgerId;
  final bool allLedgers;
  @override
  Widget build(BuildContext context) => TransactionDetailControls(
      transactionId: transactionId, ledgerId: ledgerId, allLedgers: allLedgers);
}
