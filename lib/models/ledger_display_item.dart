/// 账本展示项模型
///
/// 纯数据模型，不包含同步状态（同步状态通过 syncStatusProvider 单独获取）
library;

/// 账本展示项（纯数据，不含同步状态）
class LedgerDisplayItem {
  /// 账本ID（本地或远程）
  final int id;

  /// 账本名称
  final String name;

  /// 货币代码
  final String currency;

  /// 账单数量
  final int transactionCount;

  /// 账本余额（总收入 - 总支出）
  final double balance;

  /// 最后更新时间
  final DateTime lastUpdated;

  /// 是否为仅远程账本（本地不存在）
  final bool isRemoteOnly;

  /// 仅远程账本独有：server 端 external_id（= syncId）。本地账本此字段为 null。
  /// 下载回本地时必须用这个字段去 server 精准拉取，而不是用 `id`，因为
  /// remote-only 项的 `id` 是仅用于 UI 唯一化的占位 hashCode。
  final String? remoteSyncId;

  /// v24 共享账本字段:>1 时显示 🤝 角标。
  final bool isShared;

  /// v24 共享账本字段:含 Owner 在内的成员数,UI 显示 "🤝 N人"。
  final int memberCount;

  /// v24 共享账本字段:当前用户在该账本的角色 (owner/editor)。
  final String myRole;

  const LedgerDisplayItem({
    required this.id,
    required this.name,
    required this.currency,
    required this.transactionCount,
    required this.balance,
    required this.lastUpdated,
    this.isRemoteOnly = false,
    this.remoteSyncId,
    this.isShared = false,
    this.memberCount = 1,
    this.myRole = 'owner',
  });

  /// 从本地账本创建
  factory LedgerDisplayItem.fromLocal({
    required int id,
    required String name,
    required String currency,
    required DateTime createdAt,
    required int transactionCount,
    required double balance,
    bool isShared = false,
    int memberCount = 1,
    String myRole = 'owner',
  }) {
    return LedgerDisplayItem(
      id: id,
      name: name,
      currency: currency,
      transactionCount: transactionCount,
      balance: balance,
      lastUpdated: createdAt,
      isRemoteOnly: false,
      isShared: isShared,
      memberCount: memberCount,
      myRole: myRole,
    );
  }

  /// 从远程索引创建
  factory LedgerDisplayItem.fromRemote({
    required String remoteSyncId,
    required String name,
    required String currency,
    required DateTime updatedAt,
    required int transactionCount,
    required double balance,
  }) {
    return LedgerDisplayItem(
      // id 是 remoteSyncId 的 hashCode，只为 UI 列表唯一性；真正用于
      // 下载/映射的 server 标识在 `remoteSyncId` 字段里。
      id: remoteSyncId.hashCode,
      name: name,
      currency: currency,
      transactionCount: transactionCount,
      balance: balance,
      lastUpdated: updatedAt,
      isRemoteOnly: true,
      remoteSyncId: remoteSyncId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LedgerDisplayItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isRemoteOnly == other.isRemoteOnly;

  @override
  int get hashCode => id.hashCode ^ isRemoteOnly.hashCode;

  @override
  String toString() =>
      'LedgerDisplayItem(id: $id, name: $name, isRemoteOnly: $isRemoteOnly)';
}
