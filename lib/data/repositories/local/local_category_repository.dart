import 'dart:io';

import 'package:drift/drift.dart' as d;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../db.dart';
import '../../category_node.dart';
import '../../../services/system/logger_service.dart';
import '../category_repository.dart';

/// 本地分类Repository实现
/// 基于 Drift 数据库实现
class LocalCategoryRepository implements CategoryRepository {
  static const _uuid = Uuid();
  final BeeDatabase db;

  LocalCategoryRepository(this.db);

  @override
  Future<int> createCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
  }) async {
    return await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        name: name,
        kind: kind,
        icon: d.Value(icon),
        sortOrder: d.Value(sortOrder ?? 0),
        syncId: d.Value(_uuid.v4()),
      ),
    );
  }

  @override
  Future<int> createSubCategory({
    required int parentId,
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
  }) async {
    return await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        name: name,
        kind: kind,
        icon: d.Value(icon),
        parentId: d.Value(parentId),
        level: d.Value(2),
        sortOrder: d.Value(sortOrder ?? 0),
        syncId: d.Value(_uuid.v4()),
      ),
    );
  }

  @override
  Future<void> updateCategory(
    int id, {
    String? name,
    String? icon,
    int? parentId,
    int? level,
  }) async {
    await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name != null ? d.Value(name) : const d.Value.absent(),
        icon: icon != null ? d.Value(icon) : const d.Value.absent(),
        // parentId: -1 表示清空父分类，其他值表示设置父分类
        parentId: parentId != null
            ? (parentId == -1 ? const d.Value(null) : d.Value(parentId))
            : const d.Value.absent(),
        level: level != null ? d.Value(level) : const d.Value.absent(),
      ),
    );
  }

  @override
  Future<void> deleteCategory(int id) async {
    // 先收集要删的分类(自身 + 直接子分类)的自定义图标路径,删完后清理
    // 本地磁盘文件 —— 以前 deleteCategory 只删 categories 行,
    // customIconPath 指向的本地 PNG 留在 Application Documents/custom_icons/
    // 里,长期使用会堆积孤立图标文件。云端 attachment_files 的清理由服务端
    // sync push handler 兜底(见 src/projection.py gc_orphan_attachments)。
    final iconPaths = await _collectIconPathsForIds([id], includeChildren: true);

    await (db.delete(db.categories)..where((c) => c.parentId.equals(id))).go();
    await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();

    if (iconPaths.isNotEmpty) {
      await _deleteLocalIconFiles(iconPaths);
    }
  }

  @override
  Future<void> deleteCategoriesByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final iconPaths = await _collectIconPathsForIds(ids, includeChildren: true);

    await (db.delete(db.categories)..where((c) => c.parentId.isIn(ids))).go();
    await (db.delete(db.categories)..where((c) => c.id.isIn(ids))).go();

    if (iconPaths.isNotEmpty) {
      await _deleteLocalIconFiles(iconPaths);
    }
  }

  /// 查给定分类(含其直接子分类)的 customIconPath 列表 —— 在行被 DELETE
  /// **之前**调,删后就没法查了。
  Future<List<String>> _collectIconPathsForIds(
    List<int> ids, {
    required bool includeChildren,
  }) async {
    if (ids.isEmpty) return const [];
    final paths = <String>[];
    final selfRows = await (db.select(db.categories)
          ..where((c) => c.id.isIn(ids)))
        .get();
    for (final row in selfRows) {
      final p = row.customIconPath;
      if (p != null && p.trim().isNotEmpty) paths.add(p);
    }
    if (includeChildren) {
      final childRows = await (db.select(db.categories)
            ..where((c) => c.parentId.isIn(ids)))
          .get();
      for (final row in childRows) {
        final p = row.customIconPath;
        if (p != null && p.trim().isNotEmpty) paths.add(p);
      }
    }
    return paths;
  }

  /// 清本地 custom_icons/ 目录下的图标文件。失败只 log —— 磁盘残留下次 GC
  /// 脚本能扫出来,不 block 分类删除事务。
  Future<void> _deleteLocalIconFiles(List<String> relativePaths) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final iconDir = Directory('${appDir.path}/custom_icons');
      var deleted = 0;
      for (final rel in relativePaths) {
        final fileName = p.basename(rel);
        final file = File('${iconDir.path}/$fileName');
        if (await file.exists()) {
          try {
            await file.delete();
            deleted++;
          } catch (e) {
            logger.warning(
                'LocalCategoryRepository', '删除图标失败: $fileName, error=$e');
          }
        }
      }
      if (deleted > 0) {
        logger.info('LocalCategoryRepository', '分类删除连带清理 $deleted 个自定义图标');
      }
    } catch (e, st) {
      logger.error('LocalCategoryRepository', '清理分类自定义图标异常', e, st);
    }
  }

  @override
  Future<int> upsertCategory({
    required String name,
    required String kind,
  }) async {
    final existing = await (db.select(db.categories)
          ..where((c) => c.name.equals(name) & c.kind.equals(kind)))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return db.into(db.categories).insert(CategoriesCompanion.insert(
        name: name, kind: kind, icon: const d.Value(null), syncId: d.Value(_uuid.v4())));
  }

  @override
  Future<Category?> getCategoryById(int categoryId) async {
    return await (db.select(db.categories)
          ..where((c) => c.id.equals(categoryId)))
        .getSingleOrNull();
  }

  @override
  Future<List<Category>> getTopLevelCategories(String kind) async {
    return await (db.select(db.categories)
          ..where((c) => c.kind.equals(kind) & c.level.equals(1) & c.parentId.isNull())
          ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  @override
  Future<List<Category>> getSubCategories(int parentId) async {
    return await (db.select(db.categories)
          ..where((c) => c.parentId.equals(parentId) & c.level.equals(2))
          ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  @override
  Future<List<Category>> getUsableCategories(String kind) async {
    final allCategories = await (db.select(db.categories)
          ..where((c) => c.kind.equals(kind))
          ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]))
        .get();
    return CategoryHierarchy.getUsableCategories(allCategories);
  }

  @override
  Future<bool> isCategoryNameDuplicate({
    required String name,
    int? excludeId,
  }) async {
    var expression = db.categories.name.equals(name);

    if (excludeId != null) {
      expression = expression & db.categories.id.equals(excludeId).not();
    }

    final query = db.select(db.categories)..where((c) => expression);
    final results = await query.get();
    return results.isNotEmpty;
  }

  @override
  Future<bool> hasSubCategories(int categoryId) async {
    final count = await db.customSelect(
      'SELECT COUNT(*) as count FROM categories WHERE parent_id = ?',
      variables: [d.Variable.withInt(categoryId)],
      readsFrom: {db.categories},
    ).getSingle();

    final c = count.data['count'];
    if (c is int) return c > 0;
    if (c is BigInt) return c > BigInt.zero;
    if (c is num) return c > 0;
    return false;
  }

  @override
  Future<int> getSubCategoryCount(int categoryId) async {
    final result = await db.customSelect(
      'SELECT COUNT(*) as count FROM categories WHERE parent_id = ?',
      variables: [d.Variable.withInt(categoryId)],
      readsFrom: {db.categories},
    ).getSingle();

    final count = result.data['count'];
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    if (count is num) return count.toInt();
    return 0;
  }

  @override
  Future<int> getTransactionCountByCategory(int categoryId) async {
    final result = await db.customSelect(
      'SELECT COUNT(*) AS count FROM transactions WHERE category_id = ?1',
      variables: [d.Variable.withInt(categoryId)],
      readsFrom: {db.transactions},
    ).getSingle();

    final count = result.data['count'];
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    if (count is num) return count.toInt();
    return 0;
  }

  @override
  Future<Map<int, int>> getAllCategoryTransactionCounts() async {
    final result = await db.customSelect(
      '''
      SELECT
        c.id as category_id,
        COALESCE(COUNT(t.id), 0) as transaction_count
      FROM categories c
      LEFT JOIN transactions t ON c.id = t.category_id
      GROUP BY c.id
      ''',
      readsFrom: {db.categories, db.transactions},
    ).get();

    final Map<int, int> counts = {};
    for (final row in result) {
      final categoryId = row.data['category_id'];
      final count = row.data['transaction_count'];

      if (categoryId is int) {
        int countInt = 0;
        if (count is int) {
          countInt = count;
        } else if (count is BigInt) {
          countInt = count.toInt();
        } else if (count is num) {
          countInt = count.toInt();
        }

        counts[categoryId] = countInt;
      }
    }

    return counts;
  }

  @override
  Future<({int totalCount, double totalAmount, double averageAmount})>
      getCategorySummary(int categoryId) async {
    final result = await db.customSelect(
      '''
      SELECT
        COUNT(*) as count,
        SUM(amount) as total,
        AVG(amount) as average
      FROM transactions
      WHERE category_id = ?1
      ''',
      variables: [d.Variable.withInt(categoryId)],
      readsFrom: {db.transactions},
    ).getSingle();

    int parseCount(dynamic v) {
      if (v is int) return v;
      if (v is BigInt) return v.toInt();
      if (v is num) return v.toInt();
      return 0;
    }

    double parseAmount(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is BigInt) return v.toDouble();
      if (v is num) return v.toDouble();
      return 0.0;
    }

    final count = parseCount(result.data['count']);
    final total = parseAmount(result.data['total']);
    final average = parseAmount(result.data['average']);

    return (
      totalCount: count,
      totalAmount: total,
      averageAmount: average,
    );
  }

  @override
  Future<List<Transaction>> getTransactionsByCategory(int categoryId) async {
    return await (db.select(db.transactions)
      ..where((t) => t.categoryId.equals(categoryId))
      ..orderBy([
        (t) => d.OrderingTerm(
          expression: t.happenedAt,
          mode: d.OrderingMode.desc,
        )
      ])).get();
  }

  @override
  Future<List<Transaction>> getTransactionsByCategoryWithSort(
    int categoryId, {
    String sortBy = 'time',
    bool ascending = false,
  }) async {
    final query = db.select(db.transactions)..where((t) => t.categoryId.equals(categoryId));

    if (sortBy == 'amount') {
      query.orderBy([
        (t) => d.OrderingTerm(
          expression: t.amount,
          mode: ascending ? d.OrderingMode.asc : d.OrderingMode.desc,
        )
      ]);
    } else {
      query.orderBy([
        (t) => d.OrderingTerm(
          expression: t.happenedAt,
          mode: ascending ? d.OrderingMode.asc : d.OrderingMode.desc,
        )
      ]);
    }

    return await query.get();
  }

  @override
  Future<int> migrateCategory({
    required int fromCategoryId,
    required int toCategoryId,
  }) async {
    final beforeCount = await getTransactionCountByCategory(fromCategoryId);

    await (db.update(db.transactions)
      ..where((t) => t.categoryId.equals(fromCategoryId))).write(
      TransactionsCompanion(
        categoryId: d.Value(toCategoryId),
      ),
    );

    return beforeCount;
  }

  @override
  Future<({int migratedTransactions, int migratedSubCategories})>
      migrateCategoryTransactions({
    required int fromCategoryId,
    required int toCategoryId,
  }) async {
    return await db.transaction(() async {
      final fromCategory = await (db.select(db.categories)
            ..where((c) => c.id.equals(fromCategoryId)))
          .getSingle();

      int migratedTransactions = 0;
      int migratedSubCategories = 0;

      if (fromCategory.level == 1) {
        // 一级分类：处理子分类
        final subCategories = await getSubCategories(fromCategoryId);

        if (subCategories.isNotEmpty) {
          for (final sub in subCategories) {
            // 检查目标分类是否已有同名子分类
            final existingSub = await (db.select(db.categories)
                  ..where((c) =>
                      c.parentId.equals(toCategoryId) &
                      c.name.equals(sub.name) &
                      c.kind.equals(sub.kind)))
                .getSingleOrNull();

            if (existingSub != null) {
              // 合并到已有的同名子分类
              final count = await (db.update(db.transactions)
                    ..where((t) => t.categoryId.equals(sub.id)))
                  .write(TransactionsCompanion(
                categoryId: d.Value(existingSub.id),
              ));
              migratedTransactions += count;

              // 删除源子分类
              await (db.delete(db.categories)..where((c) => c.id.equals(sub.id))).go();
            } else {
              // 将子分类移动到新的父分类下
              await (db.update(db.categories)..where((c) => c.id.equals(sub.id)))
                  .write(CategoriesCompanion(
                parentId: d.Value(toCategoryId),
              ));
              migratedSubCategories++;
            }
          }
        }

        // 迁移一级分类自身的交易
        final directCount = await (db.update(db.transactions)
              ..where((t) => t.categoryId.equals(fromCategoryId)))
            .write(TransactionsCompanion(
          categoryId: d.Value(toCategoryId),
        ));
        migratedTransactions += directCount;
      } else {
        // 二级分类：直接迁移交易
        final count = await (db.update(db.transactions)
              ..where((t) => t.categoryId.equals(fromCategoryId)))
            .write(TransactionsCompanion(
          categoryId: d.Value(toCategoryId),
        ));
        migratedTransactions = count;
      }

      return (
        migratedTransactions: migratedTransactions,
        migratedSubCategories: migratedSubCategories,
      );
    });
  }

  @override
  Future<({int transactionCount, bool canMigrate})> getCategoryMigrationInfo({
    required int fromCategoryId,
    required int toCategoryId,
  }) async {
    final transactionCount = await getTransactionCountByCategory(fromCategoryId);

    final targetCategory = await (db.select(db.categories)
      ..where((c) => c.id.equals(toCategoryId))).getSingleOrNull();

    final canMigrate = transactionCount > 0 && targetCategory != null && fromCategoryId != toCategoryId;

    return (transactionCount: transactionCount, canMigrate: canMigrate);
  }

  @override
  Future<void> updateCategorySortOrders(
      List<({int id, int sortOrder})> updates) async {
    await db.transaction(() async {
      for (final update in updates) {
        await (db.update(db.categories)..where((c) => c.id.equals(update.id)))
            .write(CategoriesCompanion(sortOrder: d.Value(update.sortOrder)));
      }
    });
  }

  @override
  Future<String> getCategoryFullName(int categoryId) async {
    final category = await (db.select(db.categories)
          ..where((c) => c.id.equals(categoryId)))
        .getSingle();

    if (category.level == 1 || category.parentId == null) {
      return category.name;
    }

    final parent = await (db.select(db.categories)
          ..where((c) => c.id.equals(category.parentId!)))
        .getSingle();

    return '${parent.name} / ${category.name}';
  }

  @override
  Stream<Category?> watchCategory(int categoryId) {
    return (db.select(db.categories)
      ..where((c) => c.id.equals(categoryId))
    ).watchSingleOrNull();
  }

  @override
  Stream<List<Transaction>> watchTransactionsByCategory(int categoryId, {int? ledgerId}) {
    final query = db.select(db.transactions)
      ..where((t) => t.categoryId.equals(categoryId));

    if (ledgerId != null) {
      query.where((t) => t.ledgerId.equals(ledgerId));
    }

    query.orderBy([
      (t) => d.OrderingTerm(
        expression: t.happenedAt,
        mode: d.OrderingMode.desc,
      )
    ]);

    return query.watch();
  }

  @override
  Stream<List<Category>> watchCategoryWithSubs(int categoryId) {
    return db.customSelect(
      '''
      SELECT * FROM categories
      WHERE id = ? OR parent_id = ?
      ORDER BY level, sort_order
      ''',
      variables: [d.Variable.withInt(categoryId), d.Variable.withInt(categoryId)],
      readsFrom: {db.categories},
    ).watch().map((rows) {
      return rows.map((row) {
        return Category(
          id: row.read<int>('id'),
          name: row.read<String>('name'),
          kind: row.read<String>('kind'),
          icon: row.read<String?>('icon'),
          sortOrder: row.read<int>('sort_order'),
          parentId: row.read<int?>('parent_id'),
          level: row.read<int>('level'),
          iconType: row.read<String?>('icon_type') ?? 'material',
          customIconPath: row.read<String?>('custom_icon_path'),
          communityIconId: row.read<String?>('community_icon_id'),
        );
      }).toList();
    });
  }

  @override
  Stream<List<({Category category, int transactionCount})>> watchCategoriesWithCount() async* {
    await for (final rows in db.customSelect(
      '''
      SELECT
        c.id as category_id,
        c.name as category_name,
        c.kind as category_kind,
        c.icon as category_icon,
        c.sort_order as category_sort_order,
        c.parent_id as category_parent_id,
        c.level as category_level,
        c.icon_type as category_icon_type,
        c.custom_icon_path as category_custom_icon_path,
        c.community_icon_id as category_community_icon_id,
        COALESCE(COUNT(t.id), 0) as transaction_count
      FROM categories c
      LEFT JOIN transactions t ON t.category_id = c.id
      WHERE c.kind != 'transfer'
      GROUP BY c.id, c.name, c.kind, c.icon, c.sort_order, c.parent_id, c.level, c.icon_type, c.custom_icon_path, c.community_icon_id
      ORDER BY c.sort_order
      ''',
      readsFrom: {db.categories, db.transactions},
    ).watch()) {
      final startTime = DateTime.now();
      final results = <({Category category, int transactionCount})>[];
      final categoryMap = <int, ({Category category, int directCount})>{};

      // 第一遍：构建分类映射，记录直接交易数
      for (final row in rows) {
        final category = Category(
          id: row.read<int>('category_id'),
          name: row.read<String>('category_name'),
          kind: row.read<String>('category_kind'),
          icon: row.read<String?>('category_icon'),
          sortOrder: row.read<int>('category_sort_order'),
          parentId: row.read<int?>('category_parent_id'),
          level: row.read<int>('category_level'),
          iconType: row.read<String?>('category_icon_type') ?? 'material',
          customIconPath: row.read<String?>('category_custom_icon_path'),
          communityIconId: row.read<String?>('category_community_icon_id'),
        );
        final directCount = row.read<int>('transaction_count');
        categoryMap[category.id] = (category: category, directCount: directCount);
      }

      // 第二遍：计算包含子分类的总交易数
      for (final entry in categoryMap.values) {
        final category = entry.category;
        var totalCount = entry.directCount;

        // 如果是父分类（level=1），累加所有子分类的交易数
        if (category.level == 1) {
          for (final child in categoryMap.values) {
            if (child.category.parentId == category.id && child.category.level == 2) {
              totalCount += child.directCount;
            }
          }
        }

        results.add((category: category, transactionCount: totalCount));
      }

      final totalTime = DateTime.now().difference(startTime);
      logger.debug('CategoryQuery', '分类数据查询完成，耗时: ${totalTime.inMilliseconds}ms, 返回${results.length}条记录');

      yield results;
    }
  }

  @override
  Future<List<Category>> getAllCategories() async {
    return await (db.select(db.categories)
          ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  @override
  Future<void> batchInsertCategories(List<CategoriesCompanion> categories) async {
    await db.batch((batch) {
      batch.insertAll(db.categories, categories);
    });
  }

  @override
  Future<int> insertCategory(CategoriesCompanion category) async {
    return await db.into(db.categories).insert(category);
  }

  @override
  Future<void> updateCategoryIcon(
    int id, {
    required String iconType,
    String? icon,
    String? customIconPath,
    String? communityIconId,
  }) async {
    await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        iconType: d.Value(iconType),
        icon: d.Value(icon),
        customIconPath: d.Value(customIconPath),
        communityIconId: d.Value(communityIconId),
      ),
    );
    logger.info('LocalCategoryRepository', '分类图标已更新: id=$id, type=$iconType');
  }

  @override
  Future<void> clearCategoryCustomIcon(int id, {String? materialIcon}) async {
    await (db.update(db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        iconType: const d.Value('material'),
        icon: d.Value(materialIcon),
        customIconPath: const d.Value(null),
        communityIconId: const d.Value(null),
      ),
    );
    logger.info('LocalCategoryRepository', '分类自定义图标已清除: id=$id');
  }

  @override
  Future<List<String>> getCustomIconPaths() async {
    final result = await (db.select(db.categories)
          ..where((c) => c.iconType.equals('custom'))
          ..where((c) => c.customIconPath.isNotNull()))
        .get();
    return result
        .where((c) => c.customIconPath != null)
        .map((c) => c.customIconPath!)
        .toList();
  }

  @override
  Future<Category> getTransferCategory() async {
    // 查找现有的转账分类
    final existing = await (db.select(db.categories)
          ..where((c) => c.kind.equals('transfer')))
        .getSingleOrNull();

    if (existing != null) {
      return existing;
    }

    // 不存在则创建（理论上seed时已创建，这里是兜底逻辑）
    logger.warning('LocalCategoryRepository', '转账分类不存在，正在创建...');
    final id = await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        name: '转账', // 使用中文默认名称
        kind: 'transfer',
        icon: const d.Value('swap_horiz'),
        sortOrder: const d.Value(-1),
        level: const d.Value(1),
      ),
    );

    final created = await getCategoryById(id);
    return created!;
  }
}
