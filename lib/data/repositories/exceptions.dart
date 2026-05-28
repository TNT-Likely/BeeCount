/// Repository 层的异常类型。
///
/// 用于让 caller 把"撞了不允许的状态"显式 handle,而不是被静默吞掉。
library;

/// 创建实体时撞了已有的同名条目。
///
/// 抛它的场景:`createCategory` / `createSubCategory` / `createTag` /
/// `createAccount` 撞到本地已有同名行(name 全局唯一)。caller 应该:
///   - **UI 主动建**:弹 toast 提示用户改名(同名 UI 警告也在挡)。
///   - **非交互路径**(import / app-link / 自动记账等):改用 `upsertX`
///     —— get-or-create 语义,按 name 匹配。
///
/// 历史的"撞同名静默复用"做法已废弃 —— 那会把收入 tx 错挂到 expense 分类,
/// 或者把 caller 传的 icon/sortOrder 静默吞掉,排查极难。fail-loud 才能让
/// 这类 bug 第一时间冒出来。
class DuplicateNameException implements Exception {
  const DuplicateNameException({
    required this.entityType,
    required this.name,
    this.existingId,
  });

  /// 'category' / 'account' / 'tag' — 给日志和上层 UI 区分。
  final String entityType;
  final String name;
  final int? existingId;

  @override
  String toString() =>
      'DuplicateNameException: $entityType "$name" already exists'
      '${existingId != null ? ' (id=$existingId)' : ''}';
}
