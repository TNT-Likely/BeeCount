import 'package:flutter/material.dart';
import '../../presentation/v4/bindings/import_controls.dart';

export '../../presentation/v4/bindings/import_source.dart' show BillSourceType;

class ImportPage extends StatelessWidget {
  const ImportPage({super.key});
  @override
  Widget build(BuildContext context) => const ImportControls();
}
