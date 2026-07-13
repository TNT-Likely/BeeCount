import '../../data/repositories/base_repository.dart';
import '../../data/repositories/transaction_repository.dart';

/// 历史备注的查询范围。
enum NoteHistoryScope {
  /// 查询当前账本全部分类。
  allCategories,

  /// 仅查询当前选中的具体分类。
  currentCategory,
}

/// 备注历史记录服务
/// 从交易记录聚合备注，提供可按范围和排序规则筛选的历史列表。
class NoteHistoryService {
  /// 获取历史备注列表。
  ///
  /// [repository] 仓库实例
  /// [ledgerId] 账本ID
  /// [scope] 查询范围
  /// [sort] 排序规则
  /// [categoryId] 当前本地分类ID
  /// [categorySyncId] 当前共享账本分类的同步ID
  /// [limit] 限制返回数量
  static Future<List<NoteHistoryEntry>> getHistoryNotes({
    required BaseRepository repository,
    required int ledgerId,
    required NoteHistoryScope scope,
    required NoteHistorySort sort,
    int? categoryId,
    String? categorySyncId,
    int limit = 20,
  }) async {
    // 当前分类模式没有有效分类时退回全部分类，避免转账等场景得到空结果。
    final shouldFilterByCategory = scope == NoteHistoryScope.currentCategory &&
        (categoryId != null || (categorySyncId?.isNotEmpty ?? false));
    return repository.getNoteHistory(
      ledgerId: ledgerId,
      categoryId: shouldFilterByCategory ? categoryId : null,
      categorySyncId: shouldFilterByCategory ? categorySyncId : null,
      sort: sort,
      limit: limit,
    );
  }

  /// 保存备注到历史记录（兼容旧代码，实际不再需要）
  @Deprecated('备注已从数据库交易记录中统计，无需单独保存')
  static Future<void> saveNote(String note) async {
    // 空实现，保留接口兼容性
  }
}
