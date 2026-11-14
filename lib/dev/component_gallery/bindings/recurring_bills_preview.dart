import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../pages/transaction/recurring_transaction_page.dart';
import '../../../providers.dart';
import '../../../pages/transaction/recurring/bindings/recurring_bill_controls.dart';

/// Uses the same original all-ledger stream. Merely visiting this catalog must
/// never seed a template, enable a rule or invoke the bill generation service.
class LiveRecurringBillsPreview extends ConsumerWidget {
  const LiveRecurringBillsPreview({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('真实周期账单（只读）'),
        const SizedBox(height: 8),
        ref.watch(allRecurringTransactionsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(error.toString()),
            data: (rules) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${rules.length} 个周期账单 · 全部账本'),
                      for (final rule in rules.take(3)) ...[
                        const SizedBox(height: 12),
                        RecurringBillBinding(recurring: rule, busy: false),
                      ]
                    ])),
        const SizedBox(height: 12),
        BeeButton(
            label: '打开真实周期账单',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const RecurringTransactionPage())))
      ]);
}
