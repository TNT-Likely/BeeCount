import 'dart:convert';
import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _queryIndexes = {
  'idx_transaction_tags_transaction',
  'idx_transaction_tags_tag',
  'idx_attachments_transaction',
  'idx_transactions_sync_id',
  'idx_accounts_sync_id',
  'idx_categories_sync_id',
  'idx_tags_sync_id',
  'idx_ledgers_sync_id',
  'idx_budgets_sync_id',
  'idx_budgets_ledger',
  'idx_budgets_category',
  'idx_budgets_ledger_type',
  'idx_transactions_ledger_happened_at',
};

Future<Map<String, String>> _indexes(BeeDatabase db) async => {
      for (final row in await db
          .customSelect(
              "SELECT name, sql FROM sqlite_master WHERE type='index' "
              "AND name LIKE 'idx_%'")
          .get())
        row.read<String>('name'): row.read<String>('sql'),
    };

Future<Map<String, List<String>>> _values(BeeDatabase db) async {
  final tables = await db
      .customSelect("SELECT name FROM sqlite_master "
          "WHERE type='table' AND name NOT LIKE 'sqlite_%'")
      .get();
  return {
    for (final table in tables)
      table.read<String>('name'): (await db
              .customSelect('SELECT * FROM "${table.read<String>('name')}"')
              .get())
          .map((row) => jsonEncode(row.data))
          .toList()
        ..sort(),
  };
}

Future<void> _seed(BeeDatabase db) async {
  await db.customStatement(
      "INSERT INTO ledgers(id,name,currency) VALUES(7,'索引修复原账本','CNY')");
  await db.customStatement("INSERT INTO accounts(id,ledger_id,name,currency) "
      "VALUES(8,0,'原外币账户','USD')");
  await db.customStatement("INSERT INTO categories(id,name,kind) "
      "VALUES(9,'原分类','expense')");
  await db.customStatement("INSERT INTO tags(id,name) VALUES(10,'原标签')");
  await db.customStatement('INSERT INTO transactions '
      '(id,ledger_id,type,amount,account_id,category_id,happened_at,note,'
      'currency_code,native_amount,exclude_from_stats,exclude_from_budget) '
      "VALUES(11,7,'expense',12.345,8,9,1792972800,"
      "'原备注🧋,保留全部字段','USD',87.6495,1,1)");
  await db.customStatement('INSERT INTO transaction_tags '
      '(id,transaction_id,tag_id) VALUES(12,11,10)');
  await db.customStatement('INSERT INTO transaction_attachments '
      '(id,transaction_id,file_name,sort_order) '
      "VALUES(13,11,'owned-original.png',0)");
}

Future<void> _expectIndexedPlans(BeeDatabase db) async {
  Future<String> plan(String sql) async =>
      (await db.customSelect('EXPLAIN QUERY PLAN $sql').get())
          .map((r) => r.read<String>('detail'))
          .join('\n');
  expect(
      await plan('SELECT tt.transaction_id,t.* FROM transaction_tags tt '
          'JOIN tags t ON t.id=tt.tag_id WHERE tt.transaction_id IN (11,14)'),
      contains('idx_transaction_tags_transaction'));
  expect(
      await plan('SELECT transaction_id FROM transaction_tags WHERE tag_id=10'),
      contains('idx_transaction_tags_tag'));
  expect(
      await plan('SELECT transaction_id,COUNT(*) FROM transaction_attachments '
          'WHERE transaction_id IN (11,14) GROUP BY transaction_id'),
      contains('idx_attachments_transaction'));
  final home = await plan(
      'SELECT * FROM transactions WHERE ledger_id=7 ORDER BY happened_at DESC');
  expect(home, contains('idx_transactions_ledger_happened_at'));
  expect(home, isNot(contains('TEMP B-TREE')));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fresh v33 has query indexes and avoids relation scans and home sort',
      () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final indexes = await _indexes(db);
    expect(indexes.keys, containsAll(_queryIndexes));
    expect(
        _queryIndexes
            .every((name) => !indexes[name]!.toUpperCase().contains('UNIQUE')),
        isTrue);
    expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        33);
    await _seed(db);
    await _expectIndexedPlans(db);
  });

  test(
      'existing v33 missing indexes repairs all rows and repeated opens are '
      'idempotent', () async {
    final dir = await Directory.systemTemp.createTemp('beecount-indexes-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/owned.sqlite');
    var db = BeeDatabase.forTesting(NativeDatabase(file));
    await _seed(db);
    for (final name in _queryIndexes) {
      await db.customStatement('DROP INDEX "$name"');
    }
    final original = await _values(db);
    expect(original.length, 31);
    expect(
        (await _indexes(db)).keys.toSet().intersection(_queryIndexes), isEmpty);
    await db.close();

    Map<String, String>? firstIndexes;
    for (var open = 0; open < 3; open++) {
      db = BeeDatabase.forTesting(NativeDatabase(file));
      try {
        expect(await _values(db), original);
        expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            33);
        final indexes = await _indexes(db);
        expect(indexes.keys, containsAll(_queryIndexes));
        if (firstIndexes != null) expect(indexes, firstIndexes);
        firstIndexes = indexes;
        await _expectIndexedPlans(db);
      } finally {
        await db.close();
      }
    }
  });

  test('real v32 upgrade with historical indexes remains compatible', () async {
    final dir =
        await Directory.systemTemp.createTemp('beecount-index-upgrade-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/owned-v32.sqlite');
    var db = BeeDatabase.forTesting(NativeDatabase(file));
    await _seed(db);
    final original = await _values(db);
    final oldIndexes = await _indexes(db);
    await db.customStatement('DROP INDEX idx_transactions_ledger_happened_at');
    await db.customStatement('DROP TABLE agent_memory_fts');
    for (final table in [
      'agent_tool_calls',
      'agent_runs',
      'agent_conversation_summaries',
      'agent_memories',
    ]) {
      await db.customStatement('DROP TABLE $table');
    }
    await db.customStatement('PRAGMA user_version=32');
    await db.close();

    db = BeeDatabase.forTesting(NativeDatabase(file));
    try {
      expect(await _values(db), original);
      expect(await _indexes(db), oldIndexes);
      expect(
          (await db.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          33);
      await _expectIndexedPlans(db);
    } finally {
      await db.close();
    }
  });
}
