import 'package:flutter/material.dart';
import '../../data/db.dart';
import '../../presentation/v4/bindings/recurring_editor_controls.dart';

class RecurringTransactionEditPage extends StatelessWidget {
  const RecurringTransactionEditPage({super.key, this.recurring});
  final RecurringTransaction? recurring;
  @override
  Widget build(BuildContext context) =>
      RecurringEditorControls(recurring: recurring);
}
