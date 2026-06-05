// SyncEngine 对外广播的事件总线类型。
//
// 设计目标:让 UI 跟 SyncEngine 解耦 —— SyncEngine 只往 `events` stream 写,
// UI 自己 `ref.listen(syncEventStreamProvider, ...)` 订阅,SyncEngine 完全不
// 知道 Riverpod / widget 存在。
//
// 当前阶段(过渡期):callback 字段仍保留,每个 fire 点同时 emit 等价事件,
// UI 可以选择走老 callback 或新 stream。等所有 UI caller 迁完之后 callback
// 字段会被删除(详见 PR 2/3 路线图)。

/// 所有 SyncEngine 对外广播事件的基类。sealed 让 UI 用 switch 处理时编译器
/// 能 exhaustiveness check。
sealed class SyncEvent {
  const SyncEvent();
}

/// pull 完成(包括空 pull / 有变更 / 自动触发)。**老 `onAutoPullCompleted`
/// 等价物**。订阅者用 `ledgerId` 决定是否要刷新自己的 widget。
class PullCompleted extends SyncEvent {
  const PullCompleted({required this.ledgerId, this.applied = 0});

  /// server 推过来的 ledgerId(external_id / syncId)。WS sync_change 事件
  /// 带的 ledgerId,可能为空(用户级 change 或者 bootstrap 时)。
  final String ledgerId;

  /// 本次 pull 累计 apply 的 change 数。0 = 空 pull / 仅触发 UI 刷新。
  final int applied;
}

/// 共享账本资源(分类 / 账户 / 标签)变化。比 PullCompleted 精确 — 只在
/// 真有 SharedLedger* 镜像表更新时 fire,避免 HomePage 全局刷新。
class SharedResourceChanged extends SyncEvent {
  const SharedResourceChanged({required this.ledgerId});
  final String ledgerId;
}

/// 头像**实际下载完成**(remoteVersion > localVersion + 文件写盘成功)。
/// 避免每次 pull 都刷头像 widget 产生闪一下的体感。
class AvatarChanged extends SyncEvent {
  const AvatarChanged();
}

/// `/profile/me` 拉到的字段应用到本地。订阅者按 [field] 类型决定如何处理。
class ProfileFieldApplied extends SyncEvent {
  const ProfileFieldApplied._({required this.field, required this.value});

  const ProfileFieldApplied.themeColor(String hex)
      : this._(field: ProfileField.themeColor, value: hex);

  const ProfileFieldApplied.incomeColor(bool incomeIsRed)
      : this._(field: ProfileField.incomeColor, value: incomeIsRed);

  const ProfileFieldApplied.appearance(Map<String, dynamic> appearance)
      : this._(field: ProfileField.appearance, value: appearance);

  const ProfileFieldApplied.aiConfig(Map<String, dynamic> aiConfig)
      : this._(field: ProfileField.aiConfig, value: aiConfig);

  const ProfileFieldApplied.displayName(String name)
      : this._(field: ProfileField.displayName, value: name);

  final ProfileField field;
  /// 类型由 [field] 决定:
  /// - `themeColor` → `String`(hex)
  /// - `incomeColor` → `bool`
  /// - `appearance` → `Map<String, dynamic>`
  /// - `aiConfig` → `Map<String, dynamic>`
  /// - `displayName` → `String`
  final Object value;
}

enum ProfileField { themeColor, incomeColor, appearance, aiConfig, displayName }
