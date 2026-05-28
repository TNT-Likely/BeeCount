import '../db.dart';

/// 标签Repository接口
/// 定义标签相关的所有数据操作
abstract class TagRepository {
  // ============================================
  // 基础 CRUD 操作
  // ============================================

  /// 创建标签。撞同名抛 [DuplicateNameException](name 全局唯一)。
  /// 静默路径(import / 自动记账等)请用 [upsertTag](get-or-create 语义)。
  /// [syncId] 可选:seed 类路径显式塞确定性 id,UI 不传走 auto v4。
  Future<int> createTag({
    required String name,
    String? color,
    int sortOrder = 0,
    String? syncId,
  });

  /// 按 name 取标签;不存在则建一条。给 import / 自动记账等 get-or-create
  /// 语义的静默路径用 —— 不会抛 [DuplicateNameException]。
  Future<int> upsertTag({
    required String name,
    String? color,
  });

  /// 更新标签
  Future<void> updateTag(
    int id, {
    String? name,
    String? color,
    int? sortOrder,
  });

  /// 删除标签
  Future<void> deleteTag(int id);

  /// 根据ID获取标签
  Future<Tag?> getTagById(int id);

  /// 根据名称获取标签
  Future<Tag?> getTagByName(String name);

  /// 获取所有标签
  Future<List<Tag>> getAllTags();

  /// 批量插入标签
  Future<void> batchInsertTags(List<TagsCompanion> tags);

  // ============================================
  // 交易-标签关联操作
  // ============================================

  /// 为交易添加标签
  Future<void> addTagToTransaction({
    required int transactionId,
    required int tagId,
  });

  /// 为交易添加多个标签
  Future<void> addTagsToTransaction({
    required int transactionId,
    required List<int> tagIds,
  });

  /// 从交易移除标签
  Future<void> removeTagFromTransaction({
    required int transactionId,
    required int tagId,
  });

  /// 移除交易的所有标签
  Future<void> removeAllTagsFromTransaction(int transactionId);

  /// 更新交易的标签（先删除再添加）
  Future<void> updateTransactionTags({
    required int transactionId,
    required List<int> tagIds,
  });

  /// 获取交易关联的所有标签
  Future<List<Tag>> getTagsForTransaction(int transactionId);

  /// 批量获取多个交易的标签
  Future<Map<int, List<Tag>>> getTagsForTransactions(List<int> transactionIds);

  /// 获取标签关联的交易ID列表
  Future<List<int>> getTransactionIdsByTag(int tagId);

  // ============================================
  // 统计查询
  // ============================================

  /// 获取标签的交易数量
  Future<int> getTransactionCountByTag(int tagId);

  /// 获取所有标签的交易数量
  Future<Map<int, int>> getAllTagTransactionCounts();

  /// 获取标签统计信息（总笔数、总支出、总收入）
  Future<({int count, double expense, double income})> getTagStats(int tagId);

  /// 获取标签下的所有交易
  Future<List<Transaction>> getTransactionsByTag(int tagId);

  /// 获取标签下指定时间范围的交易
  Future<List<Transaction>> getTransactionsByTagInRange({
    required int tagId,
    required DateTime start,
    required DateTime end,
  });

  // ============================================
  // 响应式监听
  // ============================================

  /// 监听所有标签
  Stream<List<Tag>> watchAllTags();

  /// 监听所有标签（带统计）
  Stream<List<({Tag tag, int transactionCount})>> watchTagsWithStats();

  /// 监听标签详情
  Stream<Tag?> watchTag(int tagId);

  /// 监听交易的标签
  Stream<List<Tag>> watchTagsForTransaction(int transactionId);

  /// 监听标签下的交易
  Stream<List<Transaction>> watchTransactionsByTag(int tagId);

  // ============================================
  // 辅助方法
  // ============================================

  /// 检查标签名是否重复
  Future<bool> isTagNameDuplicate({
    required String name,
    int? excludeId,
  });

  /// 批量更新标签排序
  Future<void> updateTagSortOrders(List<({int id, int sortOrder})> updates);

  /// 获取最近使用的标签
  Future<List<Tag>> getRecentlyUsedTags({int limit = 10});
}
