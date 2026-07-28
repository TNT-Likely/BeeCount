import 'package:beecount/cloud/transactions_json.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    logger.clear();
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    logger.clear();
    await db.close();
  });

  test('dangling category warning does not log financial payload fields',
      () async {
    final ledgerId = await db.into(db.ledgers).insert(
          LedgersCompanion.insert(
            name: 'L',
            syncId: const Value('ledger-log-privacy'),
          ),
        );
    final txId = await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            ledgerId: ledgerId,
            type: 'expense',
            amount: 987654.321,
            categoryId: const Value(999999),
            happenedAt: Value(DateTime.utc(2042, 3, 4, 5, 6, 7)),
            note: const Value('SENSITIVE_NOTE_SENTINEL_7f42'),
            syncId: const Value('tx-log-privacy'),
          ),
        );

    await exportTransactionsJson(db, ledgerId);

    final warnings = logger.logs
        .where((entry) =>
            entry.tag == 'TransactionsJson' && entry.level == LogLevel.warning)
        .map((entry) => entry.message)
        .toList();
    expect(warnings, hasLength(1));
    expect(warnings.single, contains('交易 $txId'));
    expect(warnings.single, contains('分类 999999'));
    expect(warnings.single, isNot(contains('987654.321')));
    expect(warnings.single, isNot(contains('SENSITIVE_NOTE_SENTINEL_7f42')));
    expect(warnings.single, isNot(contains('2042-03-04')));
  });
}
