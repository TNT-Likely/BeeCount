import '../db.dart';

/// 分类Repository接口
/// 定义分类相关的所有数据操作
abstract class CategoryRepository {
  /// 创建分类。撞同名抛 [DuplicateNameException]((name,kind) 联合唯一:同 kind
  /// 内不重名、跨 kind 可同名,如收入「红包」+ 支出「红包」)—— UI 主动建应已先过
  /// [isCategoryNameDuplicate];import / 自动记账等静默路径要 get-or-create 语义
  /// 请用 [upsertCategory]。
  ///
  /// 可选 [syncId] / [level] / [parentId]:给 seed 这种需要显式塞确定性
  /// syncId / 指定层级和父级的路径用;UI 主动建一般不传(走默认 L1 + auto v4 id)。
  Future<int> createCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
    int level = 1,
    int? parentId,
    String? syncId,
  });

  /// 创建二级分类。撞同名同样抛 [DuplicateNameException]。
  /// [syncId] 同 [createCategory]:可选,seed 显式传,UI 不传走 auto v4。
  Future<int> createSubCategory({
    required int parentId,
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
    String? syncId,
  });

  /// 更新分类
  /// [parentId] 传入具体值表示设置父分类，传入 -1 表示清空父分类（变为一级分类）
  /// [level] 传入 1 或 2 表示修改分类层级
  Future<void> updateCategory(
    int id, {
    String? name,
    String? icon,
    int? parentId,
    int? level,
  });

  /// 删除分类
  Future<void> deleteCategory(int id);

  /// 批量删除分类
  Future<void> deleteCategoriesByIds(List<int> ids);

  /// 按 (name,kind) 取分类(同 kind 内唯一,跨 kind 可同名);不存在则按给定
  /// kind/icon/sortOrder 建一条。命中已存在时,icon/sortOrder 参数被忽略 —— 保留
  /// 已有那条的元数据((name,kind) 唯一模型下,同 kind 的 "X" 是同一个分类,不该
  /// 被外部 import 覆盖图标/排序)。
  Future<int> upsertCategory({
    required String name,
    required String kind,
    String? icon,
    int? sortOrder,
  });

  /// 根据ID获取分类
  Future<Category?> getCategoryById(int categoryId);

  /// 获取所有分类
  Future<List<Category>> getAllCategories();

  /// 获取所有分类(本地 + 共享账本的 synthetic 分类)，用于跨账本列表按 id 映射分类
  Future<List<Category>> getAllCategoriesIncludingShared();

  /// 获取所有一级分类
  Future<List<Category>> getTopLevelCategories(String kind);

  /// 获取指定一级分类下的所有二级分类
  Future<List<Category>> getSubCategories(int parentId);

  /// 获取可用于记账的分类（叶子分类）
  Future<List<Category>> getUsableCategories(String kind);

  /// 检查分类名称是否重复(同 kind 内判重,跨 kind 允许同名)
  Future<bool> isCategoryNameDuplicate({
    required String name,
    required String kind,
    int? excludeId,
  });

  /// 检查分类是否有子分类
  Future<bool> hasSubCategories(int categoryId);

  /// 获取分类的子分类数量
  Future<int> getSubCategoryCount(int categoryId);

  /// 获取分类下的交易数量
  Future<int> getTransactionCountByCategory(int categoryId);

  /// 批量获取所有分类的交易数量
  Future<Map<int, int>> getAllCategoryTransactionCounts();

  /// 获取分类汇总信息（总笔数、总金额、平均金额）
  Future<({int totalCount, double totalAmount, double averageAmount})> getCategorySummary(
      int categoryId);

  /// 获取分类下的所有交易记录
  Future<List<Transaction>> getTransactionsByCategory(int categoryId);

  /// 获取分类下的所有交易记录（支持自定义排序）
  Future<List<Transaction>> getTransactionsByCategoryWithSort(
    int categoryId, {
    String sortBy = 'time',
    bool ascending = false,
  });

  /// 分类迁移（将fromCategoryId的所有交易迁移到toCategoryId）
  Future<int> migrateCategory({
    required int fromCategoryId,
    required int toCategoryId,
  });

  /// 迁移分类下的所有交易和子分类
  Future<({int migratedTransactions, int migratedSubCategories})> migrateCategoryTransactions({
    required int fromCategoryId,
    required int toCategoryId,
  });

  /// 获取分类迁移信息
  Future<({int transactionCount, bool canMigrate})> getCategoryMigrationInfo({
    required int fromCategoryId,
    required int toCategoryId,
  });

  /// 批量更新分类排序
  Future<void> updateCategorySortOrders(List<({int id, int sortOrder})> updates);

  /// 获取分类的完整路径名称（一级/二级）
  Future<String> getCategoryFullName(int categoryId);

  /// 响应式监听分类信息变化
  Stream<Category?> watchCategory(int categoryId);

  /// 响应式监听分类下的交易变化
  Stream<List<Transaction>> watchTransactionsByCategory(int categoryId, {int? ledgerId});

  /// 响应式监听分类及其子分类的变化
  Stream<List<Category>> watchCategoryWithSubs(int categoryId);

  /// 响应式监听所有分类及其交易数量变化
  Stream<List<({Category category, int transactionCount})>> watchCategoriesWithCount();

  /// 批量插入分类
  Future<void> batchInsertCategories(List<CategoriesCompanion> categories);

  /// 插入单个分类（返回新ID）
  Future<int> insertCategory(CategoriesCompanion category);

  /// 更新分类图标
  /// [iconType] 图标类型：'material' / 'custom' / 'community'
  /// [icon] Material图标名称（iconType='material'时使用）
  /// [customIconPath] 自定义图标路径（iconType='custom'时使用）
  /// [communityIconId] 社区图标ID（iconType='community'时使用）
  Future<void> updateCategoryIcon(
    int id, {
    required String iconType,
    String? icon,
    String? customIconPath,
    String? communityIconId,
  });

  /// 清除自定义图标，恢复为 Material 图标
  Future<void> clearCategoryCustomIcon(int id, {String? materialIcon});

  /// 获取所有使用自定义图标的分类路径列表
  Future<List<String>> getCustomIconPaths();

  /// 获取虚拟转账分类
  /// 如果不存在则创建
  Future<Category> getTransferCategory();
}
