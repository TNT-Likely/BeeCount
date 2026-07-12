/// 云同步服务接口和状态模型

// ---- 同步服务接口 ----

abstract class SyncService {
  Future<void> uploadCurrentLedger({required int ledgerId});

  /// 下载并导入到当前账本
  /// 返回 (inserted, deletedDup) 二元组：
  /// - inserted: 新增条数
  /// - deletedDup: 保留字段（目前始终为0）
  Future<({int inserted, int deletedDup})> downloadAndRestoreToCurrentLedger(
      {required int ledgerId});

  Future<SyncStatus> getStatus({required int ledgerId});

  /// 主动刷新云端指纹：强制下载云端对象并计算指纹，返回 (fingerprint, count, exportedAt)。
  /// 实现可在内部根据对比结果适度更新缓存，便于 UI 立即反映状态。
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId});

  /// 当本地数据发生变更（增删改）时调用，以便使缓存状态失效
  void markLocalChanged({required int ledgerId});

  /// 删除云端备份（若存在）。应忽略 404。
  Future<void> deleteRemoteBackup({required int ledgerId});

  /// 清除指定账本的状态缓存，下次 getStatus 会重新从云端获取
  void clearStatusCache({int? ledgerId});
}

// ---- 本地存储实现（无云同步） ----

class LocalOnlySyncService implements SyncService {
  @override
  Future<({int inserted, int deletedDup})> downloadAndRestoreToCurrentLedger(
      {required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<SyncStatus> getStatus({required int ledgerId}) async {
    return const SyncStatus(
      diff: SyncDiff.notConfigured,
      localCount: 0,
      localFingerprint: '',
      message: '__SYNC_NOT_CONFIGURED__', // 特殊标记，在UI层处理本地化
    );
  }

  @override
  void markLocalChanged({required int ledgerId}) {}

  @override
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  Future<void> deleteRemoteBackup({required int ledgerId}) async {
    throw UnsupportedError('Cloud sync not configured');
  }

  @override
  void clearStatusCache({int? ledgerId}) {}
}

// ---- 状态模型 ----

enum SyncDiff {
  notConfigured,
  notLoggedIn,
  noRemote,
  inSync,
  localNewer,
  cloudNewer,
  different,
  error,
}

class SyncStatus {
  final SyncDiff diff;
  final int localCount;
  final int? cloudCount;
  final String localFingerprint;
  final String? cloudFingerprint;
  final DateTime? cloudExportedAt;
  final String? message; // 错误或说明

  const SyncStatus({
    required this.diff,
    required this.localCount,
    required this.localFingerprint,
    this.cloudCount,
    this.cloudFingerprint,
    this.cloudExportedAt,
    this.message,
  });
}
