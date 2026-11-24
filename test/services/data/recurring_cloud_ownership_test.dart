import 'package:beecount/cloud/recurring/cloud_recurring_rules.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data/recurring_transaction_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PreviewBook extends CloudRuleBook {
  _PreviewBook(Ledger ledger)
      : super(BeeCountCloudProvider(), ledger, 'test', {'time_zone': 'UTC'},
            false);

  @override
  Future<void> ensureActive() async {}

  @override
  Future<RuleJson> change(RuleJson payload) async => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'handoff keeps a long memo and lets the linked account set the posting currency',
      () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalRepository(db);
    final ledger = await repo.createLedger(name: 'QA', currency: 'CNY');
    final account = await repo.createAccount(
        ledgerId: ledger, name: 'USD account', currency: 'USD', syncId: 'usd');
    final memo = '  ${List.filled(260, '🐝').join()}  ';
    await repo.addRecurringTransaction(
        ledgerId: ledger,
        type: 'expense',
        amount: 25,
        accountId: account,
        note: memo,
        frequency: 'monthly',
        interval: 1,
        startDate: DateTime(2030),
        currencyCode: 'JPY');
    final rule = (await repo.getAllRecurringTransactions()).single;
    final payload = await legacyRuleConfig(repo, rule, 'UTC');
    expect(payload['name'], List.filled(255, '🐝').join());
    expect(payload['transaction']['note'], memo);
    expect(payload['transaction']['account_id'], 'usd');
    expect(payload['transaction']['currency'], isNull);
  });

  test('a first occurrence cutoff is not a previous payment on handoff',
      () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LocalRepository(db);
    final ledger = await repo.createLedger(name: 'QA', currency: 'CNY');
    final book = _PreviewBook((await repo.getLedgerById(ledger))!);
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final id = await repo.addRecurringTransaction(
        ledgerId: ledger,
        type: 'expense',
        amount: 10,
        frequency: 'daily',
        interval: 1,
        startDate: yesterday);
    Future<RuleJson> preview() async {
      final rule = (await repo.getAllRecurringTransactions()).single;
      return (await RecurringHandoff.prepare(db, repo, book, rule)).request;
    }

    final before = await preview();
    expect(before['consumed_through'], ruleDate(yesterday));
    expect(before.containsKey('last_generated_date'), isFalse);
    await repo.generateRecurringOccurrence(
        recurringId: id, scheduledDate: today);
    final after = await preview();
    expect(after['last_generated_date'], ruleDate(today));
    expect(after['consumed_through'], ruleDate(today));
  });

  test(
      'a confirmed older Cloud keeps local rules, while a capable Cloud owns them',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = CloudServiceStore();
    await store.saveAndActivate(const CloudServiceConfig(
      type: CloudBackendType.beecountCloud,
      name: 'Legacy',
      beecountCloudBaseUrl: 'https://legacy-recurring.example/',
      beecountCloudApiPrefix: '/custom/',
    ));
    await http.runWithClient(() async {
      final db = BeeDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LocalRepository(db);
      final ledger = await repo.createLedger(name: 'QA', currency: 'CNY');
      final today = DateTime.now();
      await repo.addRecurringTransaction(
          ledgerId: ledger,
          type: 'expense',
          amount: 10,
          frequency: 'daily',
          interval: 1,
          startDate: today);
      final service = RecurringTransactionService(repo);
      expect(
          await service.generatePendingTransactions(now: today), hasLength(1));
      await store.saveAndActivate(const CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'Current',
        beecountCloudBaseUrl: 'https://current-recurring.example',
      ));
      expect(
          await service.generatePendingTransactions(
              now: today.add(const Duration(days: 1))),
          isEmpty);
    },
        () => MockClient((request) async {
              final legacy = request.url.host == 'legacy-recurring.example';
              expect(request.url.path,
                  legacy ? '/custom/version' : '/api/v1/version');
              return http.Response(
                  legacy
                      ? '{"version":"1.10.1"}'
                      : '{"version":"1.10.1","capabilities":["recurring_rules_v1"]}',
                  200);
            }));
    await http.runWithClient(
      () async => expect(await store.usesCloudRecurringRules(), isTrue),
      () =>
          MockClient((_) async => throw StateError('unexpected version probe')),
    );
  });

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
