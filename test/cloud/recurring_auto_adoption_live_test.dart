import 'dart:convert';
import 'dart:io';

import 'package:beecount/cloud/recurring/recurring_handoff.dart';
import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data/recurring_transaction_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/support/recurring_cloud_case.dart';

/// Drop only this installation's rule traffic; the shared QA server stays online.
class UnreliableRuleConnection extends BeeCountCloudProvider {
  bool unavailable = false;
  bool loseReceipt = false;

  @override
  Future<RuleJson> recurringRules(String ledgerId, {RuleJson? change}) async {
    if (unavailable) throw const SocketException('QA connection unavailable');
    final result = await super.recurringRules(ledgerId, change: change);
    if (loseReceipt &&
        change?['confirm'] == true &&
        result['handoff_confirmed'] == true) {
      loseReceipt = false;
      throw const SocketException('QA dropped the committed response');
    }
    return result;
  }
}

typedef TestInstall = ({
  LocalRepository repo,
  SyncEngine engine,
  BeeDatabase db,
  int ledger
});

Future<Map<String, dynamic>> verifyConcurrentFirstPayment(
    List<TestInstall> installs,
    DateTime today,
    Future<List<dynamic>> Function() remote,
    Future<List<dynamic>> Function() posted) async {
  // Two real sessions see separate pre-Cloud templates for today's installment
  // before either has posted it. Only one server rule and one payment may result.
  const dueName = 'QA 到期接管';
  final dueIds = await Future.wait(
      installs.map((device) => device.repo.addRecurringTransaction(
            ledgerId: device.ledger,
            type: 'expense',
            amount: 23,
            note: dueName,
            frequency: 'daily',
            interval: 1,
            startDate: today.subtract(const Duration(days: 1)),
            endDate: today,
          )));
  await Future.wait(
      installs.map((device) => device.engine.push(device.ledger.toString())));
  for (final device in installs) {
    await device.engine.push(device.ledger.toString());
    expect(
        await RecurringTransactionService(device.repo)
            .generatePendingTransactions(),
        isEmpty);
  }
  final localDue = await Future.wait([
    for (final (index, device) in installs.indexed)
      (device.db.select(device.db.recurringTransactions)
            ..where((r) => r.id.equals(dueIds[index])))
          .getSingle()
  ]);
  expect(localDue.where((r) => r.cloudRuleId != null), hasLength(1));
  expect(localDue.where((r) => r.cloudHandoffIssue == 'similar'), hasLength(1));
  final dueId = localDue.singleWhere((r) => r.cloudRuleId != null).cloudRuleId;
  int executionCount = 0;
  for (int attempt = 0; attempt < 46; attempt++) {
    final rules = (await remote())
        .map((r) => CloudRule(r))
        .where((r) => r.config['name'] == dueName);
    final due = rules.single;
    expect(due.id, dueId);
    executionCount = due.data['executed_count'] as int;
    if (executionCount > 0) break;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  expect(executionCount, 1);
  final generated =
      (await posted()).where((tx) => tx['note'] == dueName).single;
  expect(generated['amount'], 23);
  for (final device in installs) {
    await device.engine.pull(device.ledger.toString());
    await device.engine.pull(device.ledger.toString(), sinceOverride: 0);
    final localRows = await (device.db.select(device.db.transactions)
          ..where((t) => t.note.equals(dueName)))
        .get();
    expect(localRows.single.syncId, generated['syncId']);
    expect(localRows.single.amount, 23);
  }
  return {
    'due_sync_id': generated['syncId'],
    'due_amount': generated['amount'],
    'due_execution_count': executionCount,
    'due_rule_id': dueId,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'sync automatically adopts safe rules and holds only ambiguous local occurrences',
      () async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    final address = email.replaceFirst(
        '@', '+auto-${DateTime.now().microsecondsSinceEpoch}@');
    await registerQa(address);
    final store = CloudServiceStore();
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tracker = ChangeTracker(db);
    final repo = LocalRepository(db,
        changeTracker: tracker,
        cloudExecutesRecurring: store.usesBeeCountCloud);
    final ledger = await repo.createLedger(name: 'QA 自动接管', currency: 'CNY');
    final key = (await repo.getLedgerById(ledger))!.syncId!;
    final today = DateTime.now();
    final id = await repo.addRecurringTransaction(
        ledgerId: ledger,
        type: 'expense',
        amount: 81,
        note: 'QA 房租',
        frequency: 'daily',
        interval: 1,
        startDate: today.subtract(const Duration(days: 1)));
    final service = RecurringTransactionService(repo);
    final local = (await service.generatePendingTransactions()).single;
    // Also exercise recovery of rules in an inactive ledger, preserving paused state.
    final other = await repo.createLedger(name: 'QA 第二个账本', currency: 'CNY');
    final otherId = await repo.addRecurringTransaction(
        ledgerId: other,
        type: 'income',
        amount: 400,
        note: 'QA 工资',
        frequency: 'monthly',
        interval: 1,
        startDate: today,
        enabled: false);
    final config = CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'QA',
        beecountCloudBaseUrl: origin,
        beecountCloudEmail: address,
        beecountCloudPassword: password);
    await store.saveAndActivate(config);
    final api = UnreliableRuleConnection();
    addTearDown(api.dispose);
    await api.initialize(
        {'baseUrl': origin, 'email': address, 'password': password});
    await api.auth.signInWithEmail(email: address, password: password);
    final engine =
        SyncEngine(db: db, provider: api, changeTracker: tracker, repo: repo);
    addTearDown(engine.dispose);
    Future<RecurringTransaction> rule(int id) =>
        (db.select(db.recurringTransactions)..where((r) => r.id.equals(id)))
            .getSingle();
    Future<List<dynamic>> remote() async =>
        (await api.recurringRules(key))['items'] as List;
    final login = await qaRequest('POST', '/api/v1/auth/login', data: {
      'email': address,
      'password': password,
      'client_type': 'web',
      'device_name': 'QA web'
    });
    Future<List<dynamic>> posted() async {
      final full = await qaRequest('GET', '/api/v1/sync/full?ledger_id=$key',
          token: login['access_token'] as String);
      final snapshot = full['snapshot'];
      if (snapshot == null) return [];
      return jsonDecode(snapshot['payload']['content'] as String)['items']
          as List;
    }

    api.unavailable = true;
    await engine.fullPush(ledgerId: ledger);
    expect((await rule(id)).cloudRuleId, isNull);
    expect(
        await service.generatePendingTransactions(
            now: today.add(const Duration(days: 1))),
        isEmpty);
    expect(await posted(),
        isEmpty); // No unconfirmed local occurrence leaked via the bootstrap snapshot.

    api.unavailable = false;
    final originalRule = await rule(id);
    final user = (await api.auth.currentUser)!;
    final book = CloudRuleBook(api, (await repo.getLedgerById(ledger))!,
        ruleScope(api, user.id, key), await api.recurringRules(key), false);
    await RecurringHandoff.prepare(db, repo, book, originalRule);
    // Closing a preview has made no commitment on either device or Cloud.
    expect((await rule(id)).cloudHandoffKey, isNull);
    expect(await remote(), isEmpty);
    api.loseReceipt = true;
    await engine.push(ledger.toString());
    expect(await remote(), hasLength(1));
    expect((await rule(id)).cloudRuleId, isNull);
    await Future.wait(
        [engine.push(ledger.toString()), engine.push(ledger.toString())]);
    expect((await rule(id)).cloudRuleId, (await remote()).single['id']);
    expect((await posted()).single['syncId'], local.syncId);
    await engine.retryPendingRecurring(except: ledger);
    final otherKey = (await repo.getLedgerById(other))!.syncId!;
    final paused =
        ((await api.recurringRules(otherKey))['items'] as List).single;
    expect(paused['id'], (await rule(otherId)).cloudRuleId);
    expect(paused['status'], 'paused');

    final second = await repo.addRecurringTransaction(
        ledgerId: ledger,
        type: 'expense',
        amount: 81,
        note: 'QA 房租',
        frequency: 'daily',
        interval: 1,
        startDate: today);
    final duplicate = await repo.addTransaction(
        ledgerId: ledger,
        type: 'expense',
        amount: 81,
        happenedAt: local.happenedAt,
        recurringId: second);
    await repo.addTransaction(
        ledgerId: ledger,
        type: 'expense',
        amount: 12,
        happenedAt: today,
        note: 'QA 手记');
    await engine.push(ledger.toString());
    expect((await rule(second)).cloudHandoffIssue, 'similar');
    expect((await rule(second)).cloudRuleId, isNull);
    expect(
        await (db.select(db.transactions)..where((r) => r.id.equals(duplicate)))
            .getSingleOrNull(),
        isNotNull);
    expect(await remote(), hasLength(1));
    expect((await posted()).map((v) => v['amount']), unorderedEquals([81, 12]));
    await engine.fullPush(ledgerId: ledger);
    expect((await posted()).map((v) => v['amount']), unorderedEquals([81, 12]));

    final token = login['access_token'] as String;
    final full = await qaRequest('GET', '/api/v1/sync/full?ledger_id=$key',
        token: token);
    await qaRequest(
        'PATCH', '/api/v1/write/ledgers/$key/transactions/${local.syncId}',
        token: token,
        data: {'base_change_id': full['latest_cursor'], 'amount': 86});
    final webRule = CloudRule((await remote()).single);
    await qaRequest('POST', '/api/v1/ledgers/$key/recurring-rules',
        token: token,
        data: {
          'action': 'update',
          'record_id': webRule.id,
          'expected_revision': webRule.revision,
          'data': {
            ...webRule.config,
            'name': 'QA 已编辑房租',
            'transaction': {
              ...webRule.config['transaction'] as Map,
              'amount': 93
            },
          },
          'confirm': true,
        });
    final deviceIds = {(api.auth as BeeCountCloudAuthService).currentDeviceId!};
    final installs = <TestInstall>[
      (repo: repo, engine: engine, db: db, ledger: ledger),
    ];
    for (final fullUpload in [false, true]) {
      // Each restored app has fresh device credentials, a new local handoff key
      // and the original transaction ID. Both upload paths must preserve web edits.
      SharedPreferences.setMockInitialValues({});
      await store.saveAndActivate(config);
      final copyApi = BeeCountCloudProvider();
      addTearDown(copyApi.dispose);
      await copyApi.initialize(
          {'baseUrl': origin, 'email': address, 'password': password});
      await copyApi.auth.signInWithEmail(email: address, password: password);
      final device =
          (copyApi.auth as BeeCountCloudAuthService).currentDeviceId!;
      expect(deviceIds.add(device), isTrue);
      final copyDb = BeeDatabase.forTesting(NativeDatabase.memory());
      addTearDown(copyDb.close);
      final copyTracker = ChangeTracker(copyDb);
      final copyRepo = LocalRepository(copyDb,
          changeTracker: copyTracker,
          cloudExecutesRecurring: store.usesBeeCountCloud);
      final copyLedger =
          await copyRepo.createLedger(name: 'QA 自动接管', currency: 'CNY');
      await (copyDb.update(copyDb.ledgers)
            ..where((l) => l.id.equals(copyLedger)))
          .write(LedgersCompanion(syncId: Value(key)));
      final copyTemplate = await copyRepo.addRecurringTransaction(
          ledgerId: copyLedger,
          type: 'expense',
          amount: 81,
          note: 'QA 房租',
          frequency: 'daily',
          interval: 1,
          startDate: today.subtract(const Duration(days: 1)));
      await copyRepo.addTransaction(
          ledgerId: copyLedger,
          type: 'expense',
          amount: 81,
          happenedAt: local.happenedAt,
          recurringId: copyTemplate,
          syncId: local.syncId);
      await copyRepo.updateLastGeneratedDate(copyTemplate, local.happenedAt);
      final copyEngine = SyncEngine(
          db: copyDb,
          provider: copyApi,
          changeTracker: copyTracker,
          repo: copyRepo);
      addTearDown(copyEngine.dispose);
      if (!fullUpload) {
        installs.add((
          repo: copyRepo,
          engine: copyEngine,
          db: copyDb,
          ledger: copyLedger
        ));
      }
      if (fullUpload) {
        await copyEngine.fullPush(ledgerId: copyLedger);
        expect(
            (await posted()).map((v) => v['amount']), unorderedEquals([86, 12]),
            reason:
                'Restored app full upload must retain all current cloud entries');
      }
      final result = await copyEngine.sync(ledgerId: copyLedger.toString());
      expect(result.error, isNull);
      final linked =
          (await copyDb.select(copyDb.recurringTransactions).get()).single;
      expect(linked.cloudRuleId, webRule.id);
      final updated = CloudRule((await remote()).single);
      expect(updated.config['name'], 'QA 已编辑房租');
      expect(updated.config['transaction']['amount'], 93);
      final history =
          (await posted()).singleWhere((v) => v['syncId'] == local.syncId);
      expect(history['amount'], 86);
      expect(
          (await posted()).map((v) => v['amount']), unorderedEquals([86, 12]));
      final pulled = await (copyDb.select(copyDb.transactions)
            ..where((r) => r.ledgerId.equals(copyLedger)))
          .get();
      expect(pulled.map((v) => v.amount), unorderedEquals([86, 12]));
    }
    final entries = await posted();
    final adoptedRule = CloudRule((await remote()).single);
    final dueResult =
        await verifyConcurrentFirstPayment(installs, today, remote, posted);
    stdout.writeln('QA_RECURRING_AUTO_RESULT ${jsonEncode({
          'ledger_id': key,
          'prior_rule_id': adoptedRule.id,
          'rule_count_with_due_rule': (await remote()).length,
          ...dueResult,
          'prior_entry_count': entries.length,
          'history_count':
              entries.where((v) => v['syncId'] == local.syncId).length,
          'history_amount':
              entries.singleWhere((v) => v['syncId'] == local.syncId)['amount'],
          'independent_expense_amount': 12,
          'future_rule_amount': adoptedRule.tx['amount'],
          'cancelled_preview_kept_local_rule': true,
          'distinct_app_devices': deviceIds.length,
          'inactive_rule_status': paused['status'],
          'ambiguous_issue': (await rule(second)).cloudHandoffIssue,
        })}');
  }, skip: runId.isEmpty, timeout: const Timeout(Duration(minutes: 3)));
}
