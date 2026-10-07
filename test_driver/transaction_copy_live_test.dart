import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory =
      Directory(Platform.environment['QA_EVIDENCE_DIR']!).absolute;
  if (!directory.path.contains('beecount-qa-') || !directory.existsSync()) {
    throw StateError('A private QA evidence directory is required');
  }
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name)) return false;
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      if (data == null ||
          data['run_id'] !=
              File('${directory.parent.path}/.qa-owner').readAsStringSync()) {
        throw StateError('Acceptance data does not belong to this QA run');
      }
      final report = Map<String, dynamic>.from(data)..remove('screenshots');
      await File('${directory.path}/acceptance.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    },
  );
}
