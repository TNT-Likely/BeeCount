import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('package source stays independent from Flutter and BeeCount business',
      () {
    final candidates = [
      Directory('packages/agentcore/lib'),
      Directory('lib'),
    ];
    final lib = candidates.firstWhere((directory) => directory.existsSync());
    final forbidden = RegExp(
      r'''package:flutter|package:drift|package:dio|package:beecount|\bBeeCount\b|record_transaction_from_text|query_transactions|get_spending_summary|get_budget_status''',
    );
    final violations = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (forbidden.hasMatch(source)) violations.add(entity.path);
    }
    expect(violations, isEmpty);
  });
}
