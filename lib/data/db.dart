import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'db.g.dart';

// --- Tables ---

class Ledgers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('cash'))();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get kind => text()(); // expense / income
  TextColumn get icon => text().nullable()();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ledgerId => integer()();
  TextColumn get type => text()(); // expense / income / transfer
  RealColumn get amount => real()();
  IntColumn get categoryId => integer().nullable()();
  IntColumn get accountId => integer().nullable()();
  IntColumn get toAccountId => integer().nullable()();
  DateTimeColumn get happenedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
}

@DriftDatabase(tables: [Ledgers, Accounts, Categories, Transactions])
class BeeDatabase extends _$BeeDatabase {
  BeeDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Seed minimal data
  Future<void> ensureSeed() async {
    final count = await (select(ledgers).get()).then((v) => v.length);
    if (count == 0) {
      final ledgerId =
          await into(ledgers).insert(LedgersCompanion.insert(name: '默认账本'));
      await into(accounts)
          .insert(AccountsCompanion.insert(ledgerId: ledgerId, name: '现金'));
    }
    // 总是确保默认分类存在
    const expense = 'expense';
    const income = 'income';
    final defaultExpense = <String>[
      '餐饮',
      '交通',
      '购物',
      '娱乐',
      '居家',
      '通讯',
      '水电',
      '房租',
      '医疗',
      '教育',
      '宠物',
      '运动',
      '数码',
      '旅行',
      '网购',
      '烟酒',
      '母婴',
      '美容',
      '维修',
      '社交',
      '学习',
      '汽车',
      '打车',
      '地铁',
      '外卖',
      '奶茶水果',
      '话费',
      '宽带',
      '物业',
      '停车',
      '捐赠'
    ];
    final defaultIncome = <String>[
      '工资',
      '理财',
      '红包',
      '奖金',
      '报销',
      '兼职',
      '礼金',
      '利息',
      '退款'
    ];

    for (final name in defaultExpense) {
      final exists = await (select(categories)
            ..where((c) => c.name.equals(name) & c.kind.equals(expense)))
          .getSingleOrNull();
      if (exists == null) {
        await into(categories).insert(CategoriesCompanion.insert(
            name: name, kind: expense, icon: const Value(null)));
      }
    }
    for (final name in defaultIncome) {
      final exists = await (select(categories)
            ..where((c) => c.name.equals(name) & c.kind.equals(income)))
          .getSingleOrNull();
      if (exists == null) {
        await into(categories).insert(CategoriesCompanion.insert(
            name: name, kind: income, icon: const Value(null)));
      }
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'beecount.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
