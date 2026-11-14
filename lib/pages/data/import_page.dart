import 'package:flutter/material.dart';
import 'import/bindings/import_controls.dart';

export 'import/bindings/import_source.dart' show BillSourceType;

class ImportPage extends StatelessWidget {
  const ImportPage({super.key});
  @override
  Widget build(BuildContext context) => const ImportControls();
}
