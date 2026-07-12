import '../../services/system/logger_service.dart';

/// LWW (Last-Writer-Wins) 冲突解决器
/// 服务端以 server_received_at 为准，客户端无需决策
/// 此类仅处理 pull 时本地与远程的冲突检测和日志记录
class SyncConflictResolver {
  /// 判断远程变更是否应覆盖本地数据
  /// 在 LWW 策略下，远程变更（已被服务端接受）始终生效
  static bool shouldApplyRemote({
    required String entityType,
    required String entitySyncId,
    required String action,
    required DateTime? remoteUpdatedAt,
  }) {
    // LWW: 服务端已决定优先级，客户端直接应用
    return true;
  }

  /// 记录冲突（仅用于日志/调试）
  static void logConflict({
    required String entityType,
    required String entitySyncId,
    required String remoteAction,
    required String localStatus,
  }) {
    logger.warning(
      'SyncConflict',
      '冲突: $entityType($entitySyncId) '
          'remote=$remoteAction local=$localStatus — 使用远程版本(LWW)',
    );
  }
}
