import 'dart:collection';
import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart'
    show syntheticIdForSyncId;
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReadMetrics extends d.QueryInterceptor {
  int calls = 0, rows = 0, cells = 0, stringCharacters = 0, maxBindings = 0;
  void reset() => calls = rows = cells = stringCharacters = maxBindings = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
      d.QueryExecutor executor, String statement, List<Object?> args) async {
    final out = await executor.runSelect(statement, args);
    calls++;
    if (args.length > maxBindings) maxBindings = args.length;
    rows += out.length;
    for (final row in out) {
      cells += row.length;
      for (final value in row.values) {
        if (value is String) stringCharacters += value.length;
      }
    }
    return out;
  }
}

Future<void> _seed(BeeDatabase db, int count, {int noteLength = 0}) async {
  await db.customStatement(
      "INSERT INTO ledgers(id,name,currency) VALUES(1,'QA tags','CNY')");
  await db.customStatement('''
WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x<32)
INSERT INTO tags(id,name,color,sort_order,sync_id)
SELECT x,'QA tag ' || x,CASE WHEN x%2=0 THEN '#1256AB' ELSE '#AB5612' END,
       33-x,'tag-' || x FROM n
''');
  await db.customStatement('''
WITH RECURSIVE n(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM n WHERE x<?)
INSERT INTO transactions(id,ledger_id,type,amount,happened_at,note,sync_id)
SELECT x,1,'expense',1.25,1792022400,?,'tx-' || x FROM n
''', [count, '备' * noteLength]);
  await db.customStatement('''
INSERT INTO transaction_tags(transaction_id,tag_id)
SELECT id,1+(id%32) FROM transactions
UNION ALL SELECT id,1+((id+7)%32) FROM transactions
UNION ALL SELECT id,1+((id+15)%32) FROM transactions
''');
}

Future<void> _shared(BeeDatabase db) async {
  await db.customStatement('''
INSERT INTO shared_ledger_tags(ledger_sync_id,sync_id,name,color,updated_at)
VALUES('book-shared','owner-z','QA shared Z','#654321',1792022400),
      ('book-shared','owner-a','QA shared A','#123456',1792022400)
''');
  await db.customStatement('''
INSERT INTO transaction_tag_overrides(transaction_sync_id,tag_sync_id,created_at)
SELECT 'tx-' || id,'owner-z',1792022400 FROM transactions WHERE id%10=0
UNION ALL
SELECT 'tx-' || id,'owner-a',1792022400 FROM transactions WHERE id%10=0
''');
}

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late _ReadMetrics metrics;
  setUp(() {
    metrics = _ReadMetrics();
    db = BeeDatabase.forTesting(NativeDatabase.memory().interceptWith(metrics));
    repo = LocalRepository(db);
  });
  tearDown(() async => db.close());

  test('关系插入顺序保留，主标签后追加共享标签且颜色和synthetic ID准确', () async {
    await _seed(db, 2);
    await _shared(db);
    await db.customStatement('''
INSERT INTO transaction_tag_overrides VALUES('tx-1','owner-z',1792022400),
                                           ('tx-1','owner-a',1792022400)
''');
    final result = await repo.getTagsForTransactions([2, 1, 1]);
    expect(result.keys.toSet(), {1, 2});
    expect(result[1]!.take(3).map((t) => t.id), [2, 9, 17]);
    expect(result[1]!.skip(3).map((t) => t.syncId), ['owner-a', 'owner-z']);
    final shared = result[1]!.firstWhere((t) => t.syncId == 'owner-a');
    expect(shared.id, syntheticIdForSyncId('owner-a'));
    expect(shared.color, '#123456');
    expect(result[1]!.first.sortOrder, 31);
    expect(result[1]!.first.color, '#1256AB');
    expect(testerlessTagData(result[1]!.first),
        testerlessTagData((await repo.getTagById(2))!));
  });

  test('空输入、无标签、缺失主标签及共享资源均不伪造数据', () async {
    await _seed(db, 2);
    expect(await repo.getTagsForTransactions([]), isEmpty);
    await db.customStatement('DELETE FROM transaction_tags');
    await db.customStatement(
        'INSERT INTO transaction_tags(transaction_id,tag_id) VALUES(1,99999)');
    await db.customStatement("INSERT INTO transaction_tag_overrides VALUES"
        "('tx-1','absent-owner',1792022400)");
    expect(await repo.getTagsForTransactions([1, 2, 99999]), isEmpty);
  });

  test('重复关系与NULL/重复交易syncId保持原有集合语义', () async {
    await _seed(db, 3);
    await _shared(db);
    await db.customStatement(
        'INSERT INTO transaction_tags(transaction_id,tag_id) VALUES(1,2)');
    await db.customStatement("UPDATE transactions SET sync_id=NULL WHERE id=2");
    await db
        .customStatement("UPDATE transactions SET sync_id='tx-1' WHERE id=3");
    await db.customStatement("INSERT INTO transaction_tag_overrides VALUES"
        "('tx-1','owner-a',1792022400)");
    final result = await repo.getTagsForTransactions([3, 1, 2, 1]);
    expect(result[1]!.map((t) => t.id), [2, 9, 17, 2]);
    expect(result[2], hasLength(3));
    expect(result[3]!.last.syncId, 'owner-a');
  });

  test('跨400边界与15000ID完整返回，长备注不影响标签且单次绑定有界', () async {
    await _seed(db, 15000, noteLength: 2048);
    await _shared(db);
    final ids = List.generate(15000, (i) => 15000 - i);
    metrics.reset();
    final result = await repo.getTagsForTransactions(ids);
    expect(result, hasLength(15000));
    expect(result.values.fold<int>(0, (n, tags) => n + tags.length), 48000);
    for (final id in [1, 399, 400, 401, 800, 14999, 15000]) {
      expect(result[id]!.take(3).map((t) => t.id),
          [1 + id % 32, 1 + (id + 7) % 32, 1 + (id + 15) % 32]);
      if (id % 10 == 0) {
        expect(
            result[id]!.skip(3).map((t) => t.syncId), ['owner-a', 'owner-z']);
      }
    }
    expect(metrics.maxBindings, lessThanOrEqualTo(400));
    expect(metrics.stringCharacters, lessThan(200000));
    final identities = HashSet<Tag>.identity()
      ..addAll(result.values.expand((tags) => tags));
    expect(identities, hasLength(34));
  });

  test('超过400个唯一标签仍完整返回，重复syncId跨分块沿用原映射', () async {
    await _seed(db, 401);
    await _shared(db);
    await db
        .customStatement("UPDATE transactions SET sync_id='tx-1' WHERE id=401");
    await db.customStatement("INSERT INTO transaction_tag_overrides VALUES"
        "('tx-1','owner-a',1792022400)");
    await db.customStatement('''
WITH RECURSIVE n(x) AS (SELECT 33 UNION ALL SELECT x+1 FROM n WHERE x<900)
INSERT INTO tags(id,name,color,sort_order,sync_id)
SELECT x,'QA extra tag ' || x,'#010203',x,'extra-' || x FROM n
''');
    await db.customStatement('''
INSERT INTO transaction_tags(transaction_id,tag_id)
SELECT 1,id FROM tags WHERE id>=33
''');
    metrics.reset();
    final result =
        await repo.getTagsForTransactions(List.generate(401, (i) => 401 - i));
    expect(result[1], hasLength(871));
    expect(result[1]!.any((tag) => tag.id < 0), false);
    expect(result[401]!.last.syncId, 'owner-a');
    expect(metrics.maxBindings, lessThanOrEqualTo(400));
  });

  test('每次重读看到改名颜色与关系变更，不跨调用复用旧Tag', () async {
    await _seed(db, 3);
    await _shared(db);
    final before = await repo.getTagsForTransactions([1, 2, 3]);
    await repo.updateTag(2, name: 'QA renamed', color: '#112233');
    await repo.updateTransactionTags(transactionId: 2, tagIds: [2]);
    final after = await repo.getTagsForTransactions([1, 2, 3]);
    expect(before[1]!.first.name, 'QA tag 2');
    expect(after[1]!.first.name, 'QA renamed');
    expect(after[1]!.first.color, '#112233');
    expect(after[2]!.map((t) => t.id), [2]);
    expect(identical(before[1]!.first, after[1]!.first), false);
  });

  test('嵌套事务内可读取，所有持久表在批量读取前后完全相同', () async {
    await _seed(db, 401, noteLength: 2048);
    await _shared(db);
    Future<Map<String, List<String>>> snapshot() async {
      final tables = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
          .get();
      final out = <String, List<String>>{};
      for (final table in tables) {
        final name = table.read<String>('name');
        // FTS config tables may be WITHOUT ROWID; canonicalize all cells,
        // including blobs, instead of assuming a hidden rowid exists.
        final rows = (await db.customSelect('SELECT * FROM "$name"').get())
            .map((row) => jsonEncode(row.data))
            .toList()
          ..sort();
        out[name] = rows;
      }
      return out;
    }

    final before = await snapshot();
    await db.transaction(() async {
      final result =
          await repo.getTagsForTransactions(List.generate(401, (i) => i + 1));
      expect(result, hasLength(401));
      expect(result[400]!.last.syncId, 'owner-z');
    });
    expect(await snapshot(), before);
  });

  test('共享资源跨调用改色、删除可见，未解析关系不伪造新标签', () async {
    await _seed(db, 10);
    await _shared(db);
    final before = await repo.getTagsForTransactions([10]);
    await db.customStatement(
        "UPDATE shared_ledger_tags SET color='#ABCDEF' WHERE sync_id='owner-a'");
    await db.customStatement(
        "DELETE FROM shared_ledger_tags WHERE sync_id='owner-z'");
    final after = await repo.getTagsForTransactions([10]);
    expect(before[10]!.last.syncId, 'owner-z');
    expect(after[10]!.last.syncId, 'owner-a');
    expect(after[10]!.last.color, '#ABCDEF');
    expect(after[10], hasLength(4));
  });

  test('并发标签删除后下一次读取不残留旧对象', () async {
    await _seed(db, 801);
    final expectedLinks = (await db
            .customSelect(
                'SELECT COUNT(*) AS n FROM transaction_tags WHERE tag_id=2')
            .getSingle())
        .read<int>('n');
    final reading =
        repo.getTagsForTransactions(List.generate(801, (i) => i + 1));
    final deleting = repo.deleteTag(2);
    final during = await reading;
    final seen =
        during.values.expand((tags) => tags).where((tag) => tag.id == 2).length;
    expect(seen, anyOf(0, expectedLinks));
    await deleting;
    final after =
        await repo.getTagsForTransactions(List.generate(801, (i) => i + 1));
    expect(
        after.values.expand((tags) => tags).any((tag) => tag.id == 2), false);
  });
}

List<Object?> testerlessTagData(Tag tag) =>
    [tag.id, tag.name, tag.color, tag.sortOrder, tag.createdAt, tag.syncId];
