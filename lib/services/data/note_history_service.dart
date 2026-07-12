import '../../data/repositories/base_repository.dart';

/// 备注频率数据
typedef NoteFrequency = ({String note, int count});

/// 备注历史记录服务
/// 从交易记录中统计备注使用频率，提供高频备注列表
class NoteHistoryService {
  /// 获取高频备注列表（按使用次数从高到低排序）
  /// [repository] 仓库实例
  /// [ledgerId] 账本ID
  /// [limit] 限制返回数量，默认10条
  static Future<List<NoteFrequency>> getFrequentNotes(
    BaseRepository repository,
    int ledgerId, {
    int limit = 10,
  }) async {
    // 查询当前账本的所有交易
    final transactionsWithCategory =
        await repository.transactionsWithCategoryAll(ledgerId: ledgerId).first;
    final transactions = transactionsWithCategory.map((e) => e.t).toList();

    // 统计备注使用频率
    final Map<String, int> noteFrequency = {};
    for (final transaction in transactions) {
      final note = transaction.note?.trim();
      if (note != null && note.isNotEmpty) {
        noteFrequency[note] = (noteFrequency[note] ?? 0) + 1;
      }
    }

    // 按频率排序（从高到低）
    final sortedNotes = noteFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 返回前N个备注及其使用次数
    return sortedNotes
        .take(limit)
        .map((e) => (note: e.key, count: e.value))
        .toList();
  }

  /// 保存备注到历史记录（兼容旧代码，实际不再需要）
  @Deprecated('备注已从数据库交易记录中统计，无需单独保存')
  static Future<void> saveNote(String note) async {
    // 空实现，保留接口兼容性
  }
}
