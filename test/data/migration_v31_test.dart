// v31 迁移(专项预算,冻结合同见
// local-artifacts/special-budget/plans/2026-07-23-app-phase3-contract.md):
// - budgets 加 5 列:name / start_at / end_at / exclude_from_monthly_total / status;
// - transactions 加 1 列:project_budget_sync_id;
// - idx_transactions_project_budget_sync_id 索引;
// - 不做行重写:老 total/category 行的新列自动 null/默认;老 transactions 的
//   project_budget_sync_id 自动 null。
//
// in-memory db 由 create_all 建出 v31 全 schema,这里用「PRAGMA table_info /
// PRAGMA index_list + 幂等再跑 migration 语句」验证语义。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';

Future<void> _expectProjectLinkTriggers(BeeDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='trigger' "
        "AND name LIKE 'trg_%project%'",
      )
      .get();
  expect(rows.map((row) => row.read<String>('name')).toSet(), hasLength(4));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('v31 schema:budgets 带 5 个专项列 + 期望默认值', () async {
    final cols = await db.customSelect('PRAGMA table_info(budgets)').get();
    final byName = {for (final r in cols) r.read<String>('name'): r};

    // 5 个新列都存在,可空/非空/默认值一致。
    expect(byName['name'], isNotNull);
    expect(byName['name']!.read<int>('notnull'), 0); // nullable

    expect(byName['start_at'], isNotNull);
    expect(byName['start_at']!.read<int>('notnull'), 0);

    expect(byName['end_at'], isNotNull);
    expect(byName['end_at']!.read<int>('notnull'), 0);

    expect(byName['exclude_from_monthly_total'], isNotNull);
    expect(byName['exclude_from_monthly_total']!.read<int>('notnull'), 1);
    // Drift 生成的 default:INTEGER 0 或 'false'。两种都接受,只关心"非空 + 默认存在"。
    final excludeDflt = byName['exclude_from_monthly_total']!
        .readNullable<String>('dflt_value');
    expect(excludeDflt, isNotNull);

    expect(byName['status'], isNotNull);
    expect(byName['status']!.read<int>('notnull'), 1);
    final statusDflt = byName['status']!.readNullable<String>('dflt_value');
    // Drift emits string default with quotes, e.g. `'active'`.
    expect(statusDflt, contains('active'));
  });

  test('v31 schema:transactions 带 project_budget_sync_id(可空)', () async {
    final cols = await db.customSelect('PRAGMA table_info(transactions)').get();
    final byName = {for (final r in cols) r.read<String>('name'): r};
    expect(byName['project_budget_sync_id'], isNotNull);
    expect(byName['project_budget_sync_id']!.read<int>('notnull'), 0);
  });

  test('v31 schema:idx_transactions_project_budget_sync_id 索引存在', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='transactions'",
        )
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('idx_transactions_project_budget_sync_id'));
  });

  test('v31 迁移语句幂等:重复执行不报错', () async {
    // 模拟 partial upgrade 后重启:同一段 ALTER + CREATE INDEX 再跑一遍应无
    // "duplicate column / index"。直接调 customStatement 用 IF NOT EXISTS 的
    // ALTER 走不通(SQLite 语法不支持),这里用 PRAGMA 判断的 helper 才是正解;
    // 该 helper 已在 db.dart 中封装为 _addColumnIfMissing。这里通过重复运行索
    // 引 CREATE INDEX IF NOT EXISTS 以及重复的 create_all(在 fresh setup 里
    // 自动跑过一次)间接验证。
    await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_project_budget_sync_id '
        'ON transactions(project_budget_sync_id);');
    await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_project_budget_sync_id '
        'ON transactions(project_budget_sync_id);');
    // 到这里没抛异常即通过。
  });

  test('v31 默认值:直接 INSERT 老式 total 行,新列自动填 null / 默认', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
      "INSERT INTO budgets (ledger_id, type, amount, period, start_day, "
      "enabled, created_at, updated_at, sync_id) "
      "VALUES (1, 'total', 5000.0, 'monthly', 1, 1, 0, 0, 'total-1')",
    );
    final rows = await db
        .customSelect(
          "SELECT name, start_at, end_at, exclude_from_monthly_total, status "
          "FROM budgets WHERE sync_id = 'total-1'",
        )
        .get();
    expect(rows, hasLength(1));
    final r = rows.single;
    expect(r.readNullable<String>('name'), isNull);
    expect(r.readNullable<int>('start_at'), isNull);
    expect(r.readNullable<int>('end_at'), isNull);
    expect(r.read<int>('exclude_from_monthly_total'), 0);
    expect(r.read<String>('status'), 'active');
  });

  test('完整生产 v30 fixture → v31:全 schema、旧数据、新默认值和重开均保真', () async {
    await db.close();
    SharedPreferences.setMockInitialValues({});
    final fixture = File('test/fixtures/beecount_schema_v30.sqlite');
    expect(fixture.existsSync(), isTrue,
        reason: 'fixture 必须由 34ff551e 的 schemaVersion=30 BeeDatabase 生成');

    final tempDir = await Directory.systemTemp.createTemp('beecount-v30-v31-');
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final upgradedFile = File('${tempDir.path}/upgraded.sqlite');
    await fixture.copy(upgradedFile.path);

    var upgraded = BeeDatabase.forTesting(NativeDatabase(upgradedFile));
    var version =
        await upgraded.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 32);
    await _expectProjectLinkTriggers(upgraded);

    final tables = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
        )
        .get();
    final tableNames = tables.map((r) => r.read<String>('name')).toSet();
    expect(tableNames, hasLength(22));
    expect(
      tableNames,
      containsAll(<String>{
        'accounts',
        'budgets',
        'categories',
        'exchange_rate_overrides',
        'exchange_rates',
        'ledger_members',
        'ledgers',
        'local_changes',
        'recurring_transactions',
        'shared_ledger_accounts',
        'shared_ledger_categories',
        'shared_ledger_tags',
        'sync_pull_errors',
        'sync_state',
        'tags',
        'transaction_attachments',
        'transaction_tag_overrides',
        'transaction_tags',
        'transactions',
      }),
    );

    final indexes = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name",
        )
        .get();
    final indexNames = indexes.map((r) => r.read<String>('name')).toSet();
    expect(indexNames, hasLength(10),
        reason: '完整 v30 的 8 个索引 + transaction project link + budget sync 索引');
    expect(indexNames, contains('idx_rate_override_pair'));
    expect(indexNames, contains('sqlite_autoindex_sync_pull_errors_1'));
    expect(indexNames, contains('idx_transactions_project_budget_sync_id'));

    final ledger = await upgraded
        .customSelect(
          "SELECT name, currency, sync_id FROM ledgers WHERE sync_id='ledger-v30'",
        )
        .getSingle();
    expect(ledger.read<String>('name'), 'Synthetic v30 ledger');
    expect(ledger.read<String>('currency'), 'CNY');

    final budget = await upgraded
        .customSelect(
          "SELECT type, amount, name, start_at, end_at, "
          "exclude_from_monthly_total, status FROM budgets "
          "WHERE sync_id='budget-v30'",
        )
        .getSingle();
    expect(budget.read<String>('type'), 'total');
    expect(budget.read<double>('amount'), 5000);
    expect(budget.readNullable<String>('name'), isNull);
    expect(budget.readNullable<int>('start_at'), isNull);
    expect(budget.readNullable<int>('end_at'), isNull);
    expect(budget.read<int>('exclude_from_monthly_total'), 0);
    expect(budget.read<String>('status'), 'active');

    final tx = await upgraded
        .customSelect(
          "SELECT type, amount, currency_code, native_amount, "
          "project_budget_sync_id FROM transactions WHERE sync_id='tx-v30'",
        )
        .getSingle();
    expect(tx.read<String>('type'), 'expense');
    expect(tx.read<double>('amount'), 88);
    expect(tx.read<String>('currency_code'), 'CNY');
    expect(tx.read<double>('native_amount'), 88);
    expect(tx.readNullable<String>('project_budget_sync_id'), isNull);

    await upgraded.close();

    // 真实文件关闭后重开，必须保持 v32 且数据不丢。
    upgraded = BeeDatabase.forTesting(NativeDatabase(upgradedFile));
    addTearDown(upgraded.close);
    version = await upgraded.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 32);
    expect(
      await upgraded
          .customSelect(
            "SELECT count(*) AS n FROM transactions WHERE sync_id='tx-v30'",
          )
          .getSingle()
          .then((r) => r.read<int>('n')),
      1,
    );
  });

  test('partial v31 DDL + user_version 30 → 可幂等续跑并保留数据', () async {
    await db.close();
    SharedPreferences.setMockInitialValues({});
    final fixture =
        File('test/fixtures/beecount_schema_v30_partial_v31.sqlite');
    expect(fixture.existsSync(), isTrue);

    final tempDir =
        await Directory.systemTemp.createTemp('beecount-v31-partial-');
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final upgradedFile = File('${tempDir.path}/upgraded.sqlite');
    await fixture.copy(upgradedFile.path);

    final upgraded = BeeDatabase.forTesting(NativeDatabase(upgradedFile));
    addTearDown(upgraded.close);
    final version =
        await upgraded.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 32);
    await _expectProjectLinkTriggers(upgraded);

    final budgetColumns =
        await upgraded.customSelect('PRAGMA table_info(budgets)').get();
    final budgetColumnNames =
        budgetColumns.map((r) => r.read<String>('name')).toList();
    for (final name in <String>[
      'name',
      'start_at',
      'end_at',
      'exclude_from_monthly_total',
      'status',
    ]) {
      expect(budgetColumnNames.where((n) => n == name), hasLength(1));
    }
    final txColumns =
        await upgraded.customSelect('PRAGMA table_info(transactions)').get();
    expect(
      txColumns
          .map((r) => r.read<String>('name'))
          .where((n) => n == 'project_budget_sync_id'),
      hasLength(1),
    );
    expect(
      await upgraded
          .customSelect(
            "SELECT count(*) AS n FROM budgets WHERE sync_id='budget-v30'",
          )
          .getSingle()
          .then((r) => r.read<int>('n')),
      1,
    );
  });

  test('最小 v30 fixture → v32:upgrade 保留旧行并补齐双方字段', () async {
    final oldExecutor = NativeDatabase.memory(setup: (raw) {
      // 这是针对受影响表的最小合成 fixture，不冒充完整生产 schema。
      // accounts 是真实 v30 的核心表，也是 current-main v31 hidden migration
      // 的前置条件；漏建它会让测试构造出不可能的历史数据库。
      raw.execute('''CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL
      )''');
      raw.execute('''CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT, sync_id TEXT, ledger_id INTEGER NOT NULL,
        type TEXT NOT NULL, amount REAL NOT NULL, period TEXT NOT NULL,
        start_day INTEGER NOT NULL, enabled INTEGER NOT NULL,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
      )''');
      raw.execute('''CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT, ledger_id INTEGER NOT NULL,
        type TEXT NOT NULL, amount REAL NOT NULL, happened_at INTEGER NOT NULL
      )''');
      raw.execute(
          "INSERT INTO budgets (sync_id, ledger_id, type, amount, period, start_day, enabled, created_at, updated_at) VALUES ('old-total', 1, 'total', 5000, 'monthly', 1, 1, 11, 12)");
      raw.execute("INSERT INTO accounts (name) VALUES ('legacy-account')");
      raw.execute(
          "INSERT INTO transactions (ledger_id, type, amount, happened_at) VALUES (1, 'expense', 88, 13)");
      raw.execute('PRAGMA user_version = 30');
    });
    final upgraded = BeeDatabase.forTesting(oldExecutor);
    addTearDown(upgraded.close);

    final budget = await upgraded
        .customSelect(
            "SELECT sync_id, amount, name, exclude_from_monthly_total, status FROM budgets WHERE sync_id = 'old-total'")
        .getSingle();
    expect(budget.read<String>('sync_id'), 'old-total');
    expect(budget.read<double>('amount'), 5000);
    expect(budget.readNullable<String>('name'), isNull);
    expect(budget.read<int>('exclude_from_monthly_total'), 0);
    expect(budget.read<String>('status'), 'active');
    final tx = await upgraded
        .customSelect('SELECT project_budget_sync_id FROM transactions')
        .getSingle();
    expect(tx.readNullable<String>('project_budget_sync_id'), isNull);
    final account = await upgraded
        .customSelect("SELECT name, hidden FROM accounts WHERE id = 1")
        .getSingle();
    expect(account.read<String>('name'), 'legacy-account');
    expect(account.read<int>('hidden'), 0);
    final indexes = await upgraded
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_transactions_project_budget_sync_id'")
        .get();
    expect(indexes, hasLength(1));
    await _expectProjectLinkTriggers(upgraded);
  });
}
