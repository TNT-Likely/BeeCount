import 'dart:async';
import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _ObservedRepository extends LocalRepository {
  _ObservedRepository(super.db);
  final tagReadSizes = <int>[], attachmentReadSizes = <int>[];
  Completer<void>? afterRows, releaseRows;

  @override
  Future<Map<int, List<Tag>>> getTagsForTransactions(List<int> ids) {
    tagReadSizes.add(ids.length);
    return super.getTagsForTransactions(ids);
  }

  @override
  Future<Map<int, int>> getAttachmentCountsForTransactions(List<int> ids) {
    attachmentReadSizes.add(ids.length);
    return super.getAttachmentCountsForTransactions(ids);
  }

  @override
  Future<
      List<
          ({
            Transaction t,
            Category? category,
            Account? account,
            Account? toAccount
          })>> getRecentTransactionsWithCategory(
      {required int ledgerId, required int limit}) async {
    final rows = await super
        .getRecentTransactionsWithCategory(ledgerId: ledgerId, limit: limit);
    afterRows?.complete();
    if (releaseRows != null) await releaseRows!.future;
    return rows;
  }
}

void main() {
  for (final background in [false, true]) {
    test(
        'complete bounded preview matches all-list prefix on ${background ? 'background' : 'memory'} SQLite',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('beecount-preview-');
      addTearDown(() => directory.delete(recursive: true));
      final db = BeeDatabase.forTesting(background
          ? NativeDatabase.createInBackground(
              File('${directory.path}/synthetic.sqlite'))
          : NativeDatabase.memory());
      final repo = _ObservedRepository(db);
      addTearDown(db.close);
      await db.customStatement(
          "INSERT INTO ledgers(id,name,currency) VALUES(1,'Synthetic pressure','CNY'),(2,'Empty','USD')");
      await db.customStatement(
          "INSERT INTO categories(id,name,kind) VALUES(1,'Synthetic category','expense')");
      await db.customStatement(
          "INSERT INTO accounts(id,ledger_id,name,type,currency,initial_balance) VALUES(1,1,'Synthetic USD','cash','USD',0)");
      await db.customStatement(
          "INSERT INTO tags(id,name) VALUES(1,'Synthetic tag')");
      final now = DateTime(2026, 10, 26, 12);
      await db.batch((batch) {
        for (var i = 1; i <= 15000; i++) {
          // Same-time groups exercise the existing SQLite tie order, without
          // introducing an ID tie-breaker that would change product ordering.
          batch.customStatement(
              'INSERT INTO transactions(id,ledger_id,type,amount,native_amount,currency_code,category_id,account_id,happened_at,exclude_from_stats,exclude_from_budget) VALUES(?,1,?,2,14,\'USD\',1,1,?,?,?)',
              [
                i,
                i % 3 == 0 ? 'income' : 'expense',
                now
                        .subtract(Duration(minutes: i ~/ 30))
                        .millisecondsSinceEpoch ~/
                    1000,
                i % 2,
                i % 2
              ]);
          batch.customStatement(
              'INSERT INTO transaction_tags(transaction_id,tag_id) VALUES(?,1)',
              [i]);
          if (i <= 50) {
            batch.customStatement(
                "INSERT INTO transaction_attachments(transaction_id,file_name,sort_order) VALUES(?,'synthetic.png',0)",
                [i]);
          }
        }
      });
      final before =
          (await db.customSelect('SELECT total_changes() AS c').getSingle())
              .read<int>('c');
      final preview = await repo.getHomeTransactionPreview(ledgerId: 1);
      expect(preview.totalCount, 15000);
      expect(preview.rows, hasLength(20));
      expect(repo.tagReadSizes, [20]);
      expect(repo.attachmentReadSizes, [20]);
      expect(
          preview.rows.every((r) =>
              r.tags.single.name == 'Synthetic tag' &&
              r.attachmentCount == 1 &&
              r.account?.currency == 'USD' &&
              r.t.nativeAmount == 14 &&
              r.t.currencyCode == 'USD'),
          isTrue);
      final full = await repo.transactionsWithCategoryAll(ledgerId: 1).first;
      expect(preview.rows.map((r) => r.t.id), full.take(20).map((r) => r.t.id));
      final fullDay = full.where((r) => r.t.happenedAt.toLocal().day == 26);
      final income = fullDay
          .where((r) => r.t.type == 'income')
          .fold<double>(0, (n, r) => n + (r.t.nativeAmount ?? r.t.amount));
      final expense = fullDay
          .where((r) => r.t.type == 'expense')
          .fold<double>(0, (n, r) => n + (r.t.nativeAmount ?? r.t.amount));
      expect(
          preview.dayTotals['2026-10-26'], (income: income, expense: expense));
      expect(expense, greaterThan(20 * 14),
          reason:
              'Full day includes records outside the preview and retains excluded flags in journal totals');
      expect(
          (await db.customSelect('SELECT total_changes() AS c').getSingle())
              .read<int>('c'),
          before,
          reason:
              'Neither preview nor full hydration may change a historical FX snapshot');
      final empty = await repo.getHomeTransactionPreview(ledgerId: 2);
      expect(empty.totalCount, 0);
      expect(empty.rows, isEmpty);
      expect(empty.dayTotals, isEmpty);
    });
  }

  test(
      'rows, labels and daily totals share one read snapshot; later manual snapshot update is fresh',
      () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final repo = _ObservedRepository(db);
    addTearDown(db.close);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'Snapshot','CNY')");
    final id = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 2,
        currencyCode: 'USD',
        nativeAmount: 14,
        happenedAt: DateTime(2026, 10, 26, 12));
    final tag = await repo.createTag(name: 'Before');
    await repo.updateTransactionTags(transactionId: id, tagIds: [tag]);
    repo.afterRows = Completer<void>();
    repo.releaseRows = Completer<void>();
    final pending = repo.getHomeTransactionPreview(ledgerId: 1);
    await repo.afterRows!.future;
    final writer = db.transaction(() async {
      await db.customStatement(
          'UPDATE transactions SET native_amount=16 WHERE id=?', [id]);
      await db
          .customStatement("UPDATE tags SET name='After' WHERE id=?", [tag]);
    });
    repo.releaseRows!.complete();
    final old = await pending;
    expect(old.rows.single.t.nativeAmount, 14);
    expect(old.rows.single.tags.single.name, 'Before');
    expect(old.dayTotals.values.single.expense, 14);
    await writer;
    repo.afterRows = null;
    repo.releaseRows = null;
    final fresh = await repo.getHomeTransactionPreview(ledgerId: 1);
    expect(fresh.rows.single.t.nativeAmount, 16);
    expect(fresh.rows.single.tags.single.name, 'After');
    expect(fresh.dayTotals.values.single.expense, 16);
  });

  test(
      'journal day totals preserve refunds, NULL fallback and excluded flags, without transfer contribution',
      () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final repo = LocalRepository(db);
    addTearDown(db.close);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'Day totals','CNY')");
    for (final values in [
      ['income', 5, null, 1],
      ['expense', -2, -14, 1],
      ['transfer', 100, 700, 0],
    ]) {
      await db.customStatement(
          'INSERT INTO transactions(ledger_id,type,amount,native_amount,happened_at,exclude_from_stats,exclude_from_budget) VALUES(1,?,?,?,?,?,?)',
          [
            values[0],
            values[1],
            values[2],
            DateTime(2026, 10, 26, 12).millisecondsSinceEpoch ~/ 1000,
            values[3],
            values[3]
          ]);
    }
    final preview = await repo.getHomeTransactionPreview(ledgerId: 1, limit: 1);
    expect(preview.rows, hasLength(1));
    expect(preview.totalCount, 3);
    expect(preview.dayTotals.values.single, (income: 5.0, expense: -14.0));
    expect(() => repo.getHomeTransactionPreview(ledgerId: 1, limit: 15000),
        throwsArgumentError);
  });
}
