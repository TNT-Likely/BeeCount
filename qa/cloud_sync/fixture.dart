import 'dart:convert';
import 'dart:math';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:uuid/uuid.dart';

part 'fixture_local.dart';
part 'fixture_remote.dart';

typedef FixtureRow = Map<String, dynamic>;
typedef FixtureRows = Map<String, FixtureRow>;

/// Expected business records. Nothing in this model calls a production serializer.
/// Each independent QA account gets its own namespace for globally unique ledger IDs.
class RichLedgerFixture {
  RichLedgerFixture._(this.namespace, this.seed);

  final String namespace;
  final int seed;
  final FixtureRows ledgers = {},
      categories = {},
      tags = {},
      accounts = {},
      budgets = {},
      transactions = {};
  final aliases = <String, String>{};

  String id(String alias) {
    final key = const Uuid()
        .v5('15c89673-878b-4bb2-b5bd-713335ca2a1b', '$namespace/$alias');
    aliases[key] = alias;
    return key;
  }

  static RichLedgerFixture generate(
      {String namespace = 'standalone',
      int seed = 20261126,
      int transactionCount = 1200}) {
    if (transactionCount < 1) {
      throw ArgumentError.value(transactionCount, 'transactionCount');
    }
    final f = RichLedgerFixture._(namespace, seed);
    f._defineResources();
    final random = Random(seed);
    for (var i = 0; i < transactionCount; i++) {
      final r = i < _examples.length
          ? _examples[i]
          : (
              'generated-${i + 1}',
              random.nextInt(18),
              1 + random.nextInt(45000),
              _spendingAccounts[random.nextInt(_spendingAccounts.length)],
            );
      final (alias, categoryIndex, minor, source) = r;
      final transfer = categoryIndex >= 16;
      final account = transfer ? (i.isEven ? 'cash' : 'bank') : source;
      final txTags = switch (i % 6) {
        0 => [0, 1],
        1 => <int>[],
        2 => [3],
        3 => [1, 5, 7],
        4 => [i % 12],
        _ => [0, 8],
      };
      // Both ledgers have CNY base. The primary also has foreign-currency accounts.
      final book = f.id(
          i % 4 == 3 && !['usd', 'jpy'].contains(account) ? 'travel' : 'main');
      final accountId = f.id(account);
      final currency = f.accounts[accountId]!['currency'] as String;
      final cents = switch (currency) {
        'USD' => (minor * 72 + 5) ~/ 10, // 1 USD = 7.20 CNY
        'JPY' => minor * 5, // 1 JPY = 0.05 CNY
        _ => minor,
      };
      final date = DateTime.utc(2026, 10, 28, 12)
          .add(Duration(days: i % 40, minutes: (i * 7) % 540, seconds: i % 61));
      final rowId = f.id(alias);
      final rowTags = txTags.map((n) => f.id(_tagAliases[n])).toSet().toList()
        ..sort();
      f.transactions[rowId] = {
        'syncId': rowId,
        'ledgerId': book,
        'type':
            transfer ? 'transfer' : (categoryIndex < 12 ? 'expense' : 'income'),
        'amount': currency == 'JPY' ? minor.toDouble() : minor / 100,
        'currencyCode': currency,
        'nativeAmount': cents / 100,
        'accountId': accountId,
        'toAccountId':
            transfer ? f.id(account == 'cash' ? 'bank' : 'cash') : null,
        'categoryId': transfer
            ? null
            : f.id(_children[categoryIndex == 11 ? 10 : categoryIndex].$1),
        'note': i % 9 == 1 ? null : 'QA $alias',
        'happenedAt': date.toIso8601String(),
        'excludeFromStats': i % 11 == 4,
        'excludeFromBudget': i % 13 == 6,
        'tagIds': rowTags,
      };
    }
    return f;
  }

  void _defineResources() {
    void put(FixtureRows table, String alias, FixtureRow fields) {
      final key = id(alias);
      table[key] = {'syncId': key, ...fields};
    }

    put(ledgers, 'main',
        {'name': 'QA 日常', 'currency': 'CNY', 'monthStartDay': 1});
    put(ledgers, 'travel',
        {'name': 'QA 差旅', 'currency': 'CNY', 'monthStartDay': 12});
    for (var n = 0; n < _parents.length; n++) {
      final (alias, name) = _parents[n];
      put(categories, alias, {
        'name': name,
        'kind': n < 6 ? 'expense' : 'income',
        'level': 1,
        'parentId': null,
        'sortOrder': (8 - n) * 3
      });
    }
    for (var n = 0; n < _children.length; n++) {
      final (alias, name, parent) = _children[n];
      put(categories, alias, {
        'name': name,
        'kind': n < 12 ? 'expense' : 'income',
        'level': 2,
        'parentId': id(parent),
        'sortOrder': n.isEven ? 9 : 3
      });
    }
    for (var n = 0; n < _tagAliases.length; n++) {
      put(tags, _tagAliases[n], {
        'name': _tagNames[n],
        'color': '#${(0x229944 + n * 7003).toRadixString(16).padLeft(6, '0')}',
        'sortOrder': 0
      });
    }
    for (final (alias, name, type, currency, balance) in const [
      ('cash', '现金', 'cash', 'CNY', 1200.50),
      ('bank', '银行卡', 'bank_card', 'CNY', 24000.75),
      ('usd', '美元卡', 'bank_card', 'USD', 400.25),
      ('jpy', '日元现金', 'cash', 'JPY', 35000.0),
      ('credit', '信用账户', 'credit_card', 'CNY', -150.0),
      ('property', '房产估值', 'real_estate', 'CNY', 822000.0)
    ]) {
      put(accounts, alias, {
        'name': name,
        'type': type,
        'currency': currency,
        'initialBalance': balance
      });
    }
    for (final book in ['main', 'travel']) {
      for (final (alias, category, amount) in [
        ('total', null, 6000.0),
        ('food', 'food', 1200.50),
        ('metro', 'metro', 280.0)
      ]) {
        put(budgets, '$book-budget-$alias', {
          'ledgerId': id(book),
          'type': category == null ? 'total' : 'category',
          'categoryId': category == null ? null : id(category),
          'amount': amount,
          'period': 'monthly',
          'startDay': 1,
          'enabled': true
        });
      }
    }
  }

  Future<void> seedLocal(BeeDatabase db) => _seedFixture(this, db);

  Future<void> assertLocal(BeeDatabase db,
          {Set<String>? ledgerIds, bool checkResources = true}) =>
      _checkLocal(this, db, ledgerIds ?? ledgers.keys.toSet(), checkResources);

  Future<void> assertRemote(Future<dynamic> Function(String path) get,
          {Set<String>? ledgerIds}) =>
      _checkRemote(this, get, ledgerIds ?? ledgers.keys.toSet());

  FixtureRows forLedger(FixtureRows rows, String ledger) =>
      Map.fromEntries(rows.entries.where((e) => e.value['ledgerId'] == ledger));

  void assertEvents(String source, Map<String, String> expected,
      Iterable<Map<String, dynamic>> events) {
    final seen = <String>{};
    for (final event in events) {
      final id = event['entity_sync_id'] as String,
          kind = event['entity_type'] as String;
      final key = '$kind/$id', label = aliases[id] ?? id;
      if (!seen.add(key)) {
        throw StateError('$source: duplicate event $kind/$label');
      }
      if (!expected.containsKey(key)) {
        throw StateError('$source: unexpected event $kind/$label');
      }
      if (event['action'] != expected[key]) {
        throw StateError(
            '$source: $kind/$label expected ${expected[key]}, observed ${event['action']}');
      }
    }
    for (final key in expected.keys) {
      if (!seen.contains(key)) throw StateError('$source: missing event $key');
    }
  }

  void compare(
      String source, FixtureRows expected, Iterable<FixtureRow> actual) {
    final seen = <String>{};
    for (final row in actual) {
      final key = row['syncId'] as String?;
      if (key == null || !seen.add(key) || !expected.containsKey(key)) {
        throw StateError(
            '$source: unexpected or duplicate syncId ${aliases[key] ?? key}');
      }
      for (final entry in expected[key]!.entries) {
        final v = row[entry.key], want = entry.value;
        final matches = want is List
            ? v is List && listEquals(v, want)
            : (want is num && v is num)
                ? (v - want).abs() < 0.00001
                : v == want;
        if (!row.containsKey(entry.key) || !matches) {
          throw StateError(
              '$source ${aliases[key] ?? key} ($key).${entry.key}: expected $want, observed $v');
        }
      }
    }
    final missing = expected.keys.where((s) => !seen.contains(s)).firstOrNull;
    if (missing != null) {
      throw StateError(
          '$source: missing ${aliases[missing] ?? missing} ($missing)');
    }
  }
}

const _spendingAccounts = ['cash', 'bank', 'usd', 'jpy', 'credit'];
const _parents = [
  ('food', '餐饮'),
  ('transport', '交通'),
  ('home', '居家'),
  ('health', '健康'),
  ('learning', '学习'),
  ('other-out', '其他'),
  ('work', '工作'),
  ('other-in', '其他')
];
const _children = [
  ('breakfast', '早餐', 'food'),
  ('dinner', '正餐', 'food'),
  ('metro', '地铁', 'transport'),
  ('train', '高铁', 'transport'),
  ('groceries', '日用品', 'home'),
  ('rent', '房租', 'home'),
  ('medicine', '药品', 'health'),
  ('sport', '运动', 'health'),
  ('books', '书籍', 'learning'),
  ('course', '课程', 'learning'),
  ('gifts', '礼物', 'other-out'),
  ('unused', '预留', 'other-out'),
  ('salary', '工资', 'work'),
  ('bonus', '奖金', 'work'),
  ('refund', '退款', 'other-in'),
  ('award', '奖励', 'other-in'),
];
const _tagAliases = [
  'tag-trip',
  'tag-reimbursable',
  'tag-family',
  'tag-weekend',
  'tag-work',
  'tag-group',
  'tag-budget',
  'tag-invoice',
  'tag-online',
  'tag-cash',
  'tag-personal',
  'tag-another'
];
const _tagNames = [
  '出差',
  '可报销',
  '家庭',
  '周末',
  '工作',
  '聚会',
  '预算',
  '发票',
  '线上',
  '现金',
  '自用',
  '复核'
];
// Fixed representative operations come before the deterministic volume sample.
// Category indexes 16/17 are opposite transfer directions, amount is original minor units.
const _examples = [
  ('breakfast-01', 0, 2850, 'cash'),
  ('dinner-no-note', 1, 4780, 'bank'),
  ('single-tag', 2, 450, 'cash'),
  ('train-travel', 3, 18900, 'credit'),
  ('household', 4, 3780, 'bank'),
  ('rent-month-end', 5, 350000, 'bank'),
  ('pharmacy', 6, 2475, 'cash'),
  ('pool-pass', 7, 5500, 'credit'),
  ('book-usd', 8, 1599, 'usd'),
  ('course-jpy', 9, 1280, 'jpy'),
  ('gift', 10, 6600, 'bank'),
  ('coffee-trip', 0, 950, 'cash'),
  ('salary-month-end', 12, 932450, 'bank'),
  ('bonus-usd', 13, 40000, 'usd'),
  ('refund-jpy', 14, 450, 'jpy'),
  ('award-cny', 15, 1850, 'cash'),
  ('transfer-to-bank', 16, 100000, 'cash'),
  ('transfer-to-cash', 17, 15000, 'bank'),
  ('work-lunch', 1, 3200, 'credit'),
  ('snack', 0, 538, 'cash'),
  ('overseas-metro', 2, 240, 'jpy'),
  ('airport-train', 3, 1150, 'usd'),
  ('grocer-small', 4, 1, 'cash'),
  ('rental', 5, 88000, 'bank'),
  ('medication-usd', 6, 699, 'usd'),
  ('yoga', 7, 2100, 'credit'),
  ('children-books', 8, 9900, 'cash'),
  ('enrolment', 9, 76000, 'bank'),
  ('gift-overseas', 10, 2230, 'jpy'),
  ('hotel-meal', 1, 1210, 'usd'),
  ('breakfast-cash', 0, 875, 'cash'),
  ('evening-meal', 1, 7495, 'credit'),
  ('salary-second', 12, 780050, 'bank'),
  ('annual-bonus', 13, 180000, 'bank'),
  ('book-refund', 14, 999, 'usd'),
  ('small-reward', 15, 100, 'cash'),
  ('wallet-topup', 16, 50000, 'cash'),
  ('cash-refill', 17, 10000, 'bank'),
  ('underground', 2, 675, 'cash'),
  ('rail-return', 3, 7800, 'credit'),
  ('supplies-foreign', 4, 625, 'usd'),
  ('flat-rent', 5, 280000, 'bank'),
  ('sports-kit', 7, 14500, 'cash'),
  ('specialist', 6, 3240, 'jpy'),
  ('reading', 8, 7240, 'bank'),
  ('language-course', 9, 8900, 'usd'),
  ('souvenir', 10, 149, 'jpy'),
  ('small-income', 15, 5, 'cash'),
];
