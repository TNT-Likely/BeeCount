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
      '住房',
      '医疗',
      '教育',
      '宠物',
      '运动',
      '数码',
      '旅行',
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
      // 将话费/宽带/流量聚合为"通讯"一类
      '物业',
      '停车',
      '捐赠',
      '饮料',
      '服装',
      '零食',
      '红包',
      '水果',
      '游戏',
      '书',
      '爱人',
      '装修',
      '日用品'
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
      '退款',
      '投资',
      '二手转卖'
    ];

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
    String getDefaultIcon(String name, String kind) {
      if (kind == expense) {
        switch (name) {
          case '饮料': return 'local_cafe';
          case '服装': return 'checkroom';
          case '零食': return 'fastfood';
          case '服饰': return 'checkroom';
          case '红包': return 'card_giftcard';
          case '水果': return 'local_grocery_store';
          case '游戏': return 'sports_esports';
          case '书': return 'menu_book';
          case '爱人': return 'favorite';
          case '装修': return 'build';
          case '旅游': return 'flight';
          case '日用品': return 'local_laundry_service';
          case '餐饮': return 'restaurant';
          case '交通': return 'directions_car';
          case '购物': return 'shopping_cart';
          case '娱乐': return 'movie';
          case '居家': return 'home';
          case '通讯': return 'phone';
          case '水电': return 'flash_on';
          case '住房': return 'home_work';
          case '医疗': return 'local_hospital';
          case '教育': return 'school';
          case '宠物': return 'pets';
          case '运动': return 'fitness_center';
          case '数码': return 'smartphone';
          case '旅行': return 'flight';
          case '网购': return 'shopping_cart';
          case '烟酒': return 'local_bar';
          case '母婴': return 'child_care';
          case '美容': return 'face';
          case '维修': return 'build';
          case '社交': return 'group';
          case '学习': return 'school';
          case '汽车': return 'directions_car';
          case '打车': return 'local_taxi';
          case '地铁': return 'directions_subway';
          case '外卖': return 'delivery_dining';
          case '奶茶水果': return 'local_cafe';
          case '物业': return 'apartment';
          case '停车': return 'local_parking';
          case '捐赠': return 'volunteer_activism';
          default: return 'category';
        }
      } else {
        switch (name) {
          case '投资': return 'trending_up';
          case '二手转卖': return 'sell';
          case '工资': return 'work';
          case '理财': return 'account_balance';
          case '红包': return 'card_giftcard';
          case '奖金': return 'emoji_events';
          case '报销': return 'receipt';
          case '兼职': return 'work_outline';
          case '礼金': return 'card_giftcard';
          case '利息': return 'monetization_on';
          case '退款': return 'keyboard_return';
          default: return 'attach_money';
        }
      }
    }

    for (final name in defaultExpense) {
      final existingCategories = await (select(categories)
            ..where((c) => c.name.equals(name) & c.kind.equals(expense)))
          .get();
      if (existingCategories.isEmpty) {
        await into(categories).insert(CategoriesCompanion.insert(
            name: name, kind: expense, icon: Value(getDefaultIcon(name, expense))));
      }
    }
    for (final name in defaultIncome) {
      final existingCategories = await (select(categories)
            ..where((c) => c.name.equals(name) & c.kind.equals(income)))
          .get();
      if (existingCategories.isEmpty) {
        await into(categories).insert(CategoriesCompanion.insert(
            name: name, kind: income, icon: Value(getDefaultIcon(name, income))));
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
