import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cloud/recurring/cloud_recurring_rules.dart';
import 'recurring/cloud_recurring_page.dart';
import '../../data/db.dart';
import 'recurring/bindings/recurring_editor_controls.dart';

class RecurringTransactionEditPage extends ConsumerWidget {
  const RecurringTransactionEditPage({super.key, this.recurring});
  final RecurringTransaction? recurring;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(cloudRecurringModeProvider).when(
            data: (cloud) => cloud
                ? const CloudRecurringPage()
                : RecurringEditorControls(recurring: recurring),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
          );
}
