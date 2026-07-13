/// 历史备注的查询范围。
enum NoteHistoryScope {
  /// 查询当前账本全部分类。
  allCategories,

  /// 仅查询当前选中的具体分类。
  currentCategory,
}

/// 历史备注的排序规则。
enum NoteHistorySort {
  /// 按累计使用次数排序。
  frequency,

  /// 按最近一次使用时间排序。
  recent,
}

/// 历史备注聚合结果。
class NoteHistoryEntry {
  /// 去除首尾空白后的备注文本。
  final String note;

  /// 当前查询范围内的累计使用次数。
  final int usageCount;

  const NoteHistoryEntry({
    required this.note,
    required this.usageCount,
  });
}
