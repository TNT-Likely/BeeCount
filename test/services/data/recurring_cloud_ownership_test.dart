import 'package:beecount/cloud/recurring/cloud_recurring_rules.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data/recurring_transaction_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('local executes alone; selecting Cloud is durable even while signed out',
      () async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalRepository(db);
    final ledger = await repo.createLedger(name: 'QA', currency: 'CNY');
    final today = DateTime.now();
    final sid = await repo.addRecurringTransaction(
        ledgerId: ledger,
        type: 'expense',
        amount: 10,
        frequency: 'daily',
        interval: 1,
        startDate: today.subtract(const Duration(days: 2)));
    final service = RecurringTransactionService(repo);
    expect(await service.generatePendingTransactions(now: today), hasLength(1));
    expect(await service.generatePendingTransactions(now: today), isEmpty);
    final store = CloudServiceStore();
    await store.saveAndActivate(const CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'unreachable',
        beecountCloudBaseUrl: 'http://127.0.0.1:1'));
    final next = today.add(const Duration(days: 1));
    expect(await service.generatePendingTransactions(now: next), isEmpty);
    expect(
        await repo.generateRecurringOccurrence(
            recurringId: sid, scheduledDate: next),
        isNull);
    final frozen = await freezeRecurring(db, sid, 'scopeA');
    expect((await freezeRecurring(db, sid, 'scopeA')).cloudHandoffKey,
        frozen.cloudHandoffKey);
    await expectLater(freezeRecurring(db, sid, 'scopeB'), throwsStateError);
    await store.saveAndActivate(CloudServiceConfig.localStorage());
    expect(
        await LocalRepository(db)
            .generateRecurringOccurrence(recurringId: sid, scheduledDate: next),
        isNull);
    expect((await db.select(db.transactions).get()), hasLength(1));
    expect(await repo.getAllRecurringTransactions(), isEmpty);
    await applyHandoffReceipt(
        db,
        frozen,
        {'id': 'cloud-id', 'local_transactions': {}, 'handoff_confirmed': true},
        'review');
    final row = (await db.select(db.recurringTransactions).get()).single;
    expect(row.cloudRuleId, 'cloud-id');
    expect(row.enabled, isFalse);
    await repo.addRecurringTransaction(
        ledgerId: ledger,
        type: 'income',
        amount: 2,
        frequency: 'daily',
        interval: 1,
        startDate: next);
    expect(await service.generatePendingTransactions(now: next), hasLength(1));
  });
}
