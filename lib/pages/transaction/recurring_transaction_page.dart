import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cloud/recurring/cloud_recurring_rules.dart';
import 'recurring/bindings/recurring_bill_controls.dart';
import 'recurring/cloud_recurring_page.dart';

class RecurringTransactionPage extends ConsumerWidget {
  const RecurringTransactionPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(cloudRecurringModeProvider)
      .when(
        data: (cloud) =>
            cloud ? const CloudRecurringPage() : const RecurringBillsControls(),
        error: (error, _) => Scaffold(
            appBar: AppBar(), body: Center(child: Text(error.toString()))),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
}
