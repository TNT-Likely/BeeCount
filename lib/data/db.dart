import 'dart:io';

import 'package:drift/drift.dart';
import '../services/category_service.dart';
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
    final defaultExpense = CategoryService.defaultExpenseCategories;
    final defaultIncome = CategoryService.defaultIncomeCategories;

    // 轻量迁移：将历史 "房租" 重命名为 "住房"（仅当不存在同名"住房"时）
    try {
      final old = await (select(categories)
            ..where((c) => c.name.equals('房租') & c.kind.equals(expense)))
          .getSingleOrNull();
      final hasNew = await (select(categories)
            ..where((c) => c.name.equals('住房') & c.kind.equals(expense)))
          .getSingleOrNull();
      if (old != null && hasNew == null) {
        await (update(categories)..where((c) => c.id.equals(old.id)))
            .write(CategoriesCompanion(name: const Value('住房')));
      }
    } catch (_) {}

    // 去重：合并历史相似分类到统一分类
    try {
      // 定义合并策略：目标分类 -> 需要合并的旧分类列表
      final mergeStrategies = <String, List<String>>{
        '通讯': ['话费', '宽带', '流量', '电话', '网络', '通信', '手机'],
        '旅行': ['旅游', '出行'],
        '服装': ['服饰', '衣服', '衣物'],
        '购物': ['网购', '网络购物'],
        '饮料': ['奶茶', '茶饮'],
        '水果': ['奶茶水果'], // 特殊处理：奶茶水果需要拆分
      };

      for (final targetName in mergeStrategies.keys) {
        final oldNames = mergeStrategies[targetName]!;

        // 查找是否已存在目标分类
        final targetCategory = await (select(categories)
              ..where((c) => c.name.equals(targetName) & c.kind.equals(expense)))
            .getSingleOrNull();

        if (targetCategory != null) {
          // 如果存在目标分类，将其他相关分类的交易迁移过来，然后删除重复分类
          for (final oldName in oldNames) {
            final oldCategory = await (select(categories)
                  ..where((c) => c.name.equals(oldName) & c.kind.equals(expense)))
                .getSingleOrNull();

            if (oldCategory != null) {
              // 迁移交易记录
              await (update(transactions)
                    ..where((t) => t.categoryId.equals(oldCategory.id)))
                  .write(TransactionsCompanion(
                      categoryId: Value(targetCategory.id)));

              // 删除旧分类
              await (delete(categories)..where((c) => c.id.equals(oldCategory.id))).go();
            }
          }
        }
      }

      // 特殊处理：奶茶水果 -> 分别合并到 饮料 和 水果
      final milkTeaFruitCategory = await (select(categories)
            ..where((c) => c.name.equals('奶茶水果') & c.kind.equals(expense)))
          .getSingleOrNull();

      if (milkTeaFruitCategory != null) {
        // 查找饮料分类
        final drinkCategory = await (select(categories)
              ..where((c) => c.name.equals('饮料') & c.kind.equals(expense)))
            .getSingleOrNull();

        if (drinkCategory != null) {
          // 将奶茶水果的交易迁移到饮料分类（默认策略）
          await (update(transactions)
                ..where((t) => t.categoryId.equals(milkTeaFruitCategory.id)))
              .write(TransactionsCompanion(
                  categoryId: Value(drinkCategory.id)));

          // 删除奶茶水果分类
          await (delete(categories)..where((c) => c.id.equals(milkTeaFruitCategory.id))).go();
        }
      }
    } catch (_) {}

    // 为分类名称分配默认图标

    for (final name in defaultExpense) {
      final existingCategories = await (select(categories)
            ..where((c) => c.name.equals(name) & c.kind.equals(expense)))
          .get();
      if (existingCategories.isEmpty) {
        await into(categories).insert(CategoriesCompanion.insert(
            name: name, kind: expense, icon: Value(CategoryService.getDefaultCategoryIcon(name, expense))));
      } else {
        // 更新现有分类的图标（如果图标为空或不正确）
        for (final category in existingCategories) {
          final correctIcon = CategoryService.getDefaultCategoryIcon(name, expense);
          if (category.icon != correctIcon) {
            await (update(categories)..where((c) => c.id.equals(category.id)))
                .write(CategoriesCompanion(icon: Value(correctIcon)));
          }
        }
      }
    }
    for (final name in defaultIncome) {
      final existingCategories = await (select(categories)
            ..where((c) => c.name.equals(name) & c.kind.equals(income)))
          .get();
      if (existingCategories.isEmpty) {
        await into(categories).insert(CategoriesCompanion.insert(
            name: name, kind: income, icon: Value(CategoryService.getDefaultCategoryIcon(name, income))));
      } else {
        // 更新现有分类的图标（如果图标为空或不正确）
        for (final category in existingCategories) {
          final correctIcon = CategoryService.getDefaultCategoryIcon(name, income);
          if (category.icon != correctIcon) {
            await (update(categories)..where((c) => c.id.equals(category.id)))
                .write(CategoriesCompanion(icon: Value(correctIcon)));
          }
        }
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
