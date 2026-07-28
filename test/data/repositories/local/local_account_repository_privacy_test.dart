import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    logger.clear();
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.into(db.ledgers).insert(LedgersCompanion.insert(name: 'L'));
  });

  tearDown(() async {
    logger.clear();
    await db.close();
  });

  test('createAccount success log does not contain the account name', () async {
    const canary = 'CANARY_ACCOUNT_SUCCESS_DO_NOT_LOG_6C2E';

    await repo.createAccount(ledgerId: 1, name: canary);

    final accountLogs =
        logger.logs.where((entry) => entry.tag == 'AccountCreate');
    expect(accountLogs.map((entry) => entry.toFormattedString()).join('\n'),
        isNot(contains(canary)));
  });

  test('createAccount failure log does not contain the account name', () async {
    await db.customStatement('''
      CREATE TRIGGER fail_account_insert_for_privacy_test
      BEFORE INSERT ON accounts
      BEGIN
        SELECT RAISE(ABORT, 'forced account insert failure');
      END
    ''');
    const canary = 'CANARY_ACCOUNT_FAILURE_DO_NOT_LOG_6C2E';

    await expectLater(
      repo.createAccount(
        ledgerId: 1,
        name: canary,
        syncId: 'duplicate-account-sync-id',
      ),
      throwsA(anything),
    );

    final accountLogs =
        logger.logs.where((entry) => entry.tag == 'AccountCreate');
    expect(accountLogs.map((entry) => entry.toFormattedString()).join('\n'),
        isNot(contains(canary)));
  });
}
