import 'package:flutter/material.dart';
import 'import/bindings/import_confirm_controls.dart';
import 'import_page.dart' show BillSourceType;

class ImportConfirmPage extends StatelessWidget {
  const ImportConfirmPage(
      {super.key,
      required this.csvText,
      required this.hasHeader,
      required this.billType});
  final String csvText;
  final bool hasHeader;
  final BillSourceType billType;
  @override
  Widget build(BuildContext context) => ImportConfirmControls(
      csvText: csvText, hasHeader: hasHeader, billType: billType);
}
