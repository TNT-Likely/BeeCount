import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import '../cloud/sync/_fakes/fake_beecount_cloud_provider.dart';

class LoanCloud extends FakeBeeCountCloudProvider {
  int capability = 1;
  @override
  Future<BeeCountCloudServerVersion> fetchServerVersion() async =>
      BeeCountCloudServerVersion(
          name: 'QA', version: 'fixture', loanAccountingVersion: capability);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late ChangeTracker tracker;
  late LocalRepository repo;
  late LoanCloud cloud;
  late SyncEngine engine;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    tracker = ChangeTracker(db);
    repo = LocalRepository(db, changeTracker: tracker);
    cloud = LoanCloud();
    engine =
        SyncEngine(db: db, provider: cloud, changeTracker: tracker, repo: repo);
  });
  tearDown(() => db.close());
  test('贷款部分更新缺键保留版本和起算日期', () async {
    final ledger = await repo.createLedger(name: 'QA');
    final loan = await repo.createAccount(
        ledgerId: ledger,
        name: '贷款',
        type: 'loan',
        initialBalance: -50000,
        syncId: 'loan');
    final before = (await repo.getAccount(loan))!;
    cloud.pushFakeChange(
        entityType: 'account',
        entitySyncId: 'loan',
        ledgerId: '$ledger',
        payload: {
          'syncId': 'loan',
          'name': '贷款改名',
          'type': 'loan',
          'currency': 'CNY',
          'initialBalance': -50000,
        });
    await engine.pull('');
    final after = (await repo.getAccount(loan))!;
    expect(after.loanBalanceVersion, 1);
    expect(after.loanBalanceSince, before.loanBalanceSince);
    expect(after.name, '贷款改名');
  });
  test('旧 Cloud 不支持本金版本时先拒绝推送，账户不丢失', () async {
    final ledger = await repo.createLedger(name: 'QA');
    final loan = await repo.createAccount(
        ledgerId: ledger, name: '贷款', type: 'loan', initialBalance: -50000);
    cloud.capability = 0;
    await expectLater(engine.pushUserGlobalEntities(), throwsStateError);
    expect(await repo.getAccountBalance(loan), -50000);
    expect((await tracker.getUnpushedChangesForLedger(0)).isNotEmpty, true);
  });
}
