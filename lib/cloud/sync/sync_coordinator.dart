import 'dart:async';

import '../../data/db.dart';
import '../../services/system/logger_service.dart';
import 'sync_engine.dart';

/// 反应式同步触发器:监听 `local_changes` 表的未推送行,debounce 后调
/// [SyncEngine.triggerAutoSync] 把变更推到云端。
///
/// 设计动机:在引入 SyncCoordinator 之前,触发同步的责任散落在 21+ 个
/// UI 调用点 (`PostProcessor.sync(...)`)。任何漏掉一处都会导致"已经写
/// 进 local_changes 但永远不推"的 bug —— CSV 导入和"清空账本"就是这
/// 类典型故障 (见 plans/beecount-cloud-app-clever-crayon.md)。
///
/// 把触发逻辑挪到数据层之后,**任何写入 local_changes 表的代码路径**
/// 都自动获得同步触发能力,UI 不需要再操心。Repository 层的 mutation
/// 只要正确写了 local_changes 行就万事大吉。
///
/// 双层 debounce 保护:
/// - 本类:250ms,合并 CSV 导入 / 批量删除 / migrate 等会高频写入
///   local_changes 的场景
/// - [SyncEngine._scheduleAutoSync]:2s,合并 WS 重连 / connectivity
///   恢复 / 反应式触发等多个上游事件
///
/// 仅在 BeeCount Cloud (SyncEngine) 模式下启用。本地 only / 旧 provider
/// (S3 / WebDAV) 走的是 snapshot 同步,不读 local_changes 表,这里没意义。
class SyncCoordinator {
  final BeeDatabase db;
  final SyncEngine engine;

  StreamSubscription<List<LocalChange>>? _subscription;
  Timer? _debounce;

  SyncCoordinator({required this.db, required this.engine});

  /// 启动监听。重复调用安全:重新建立订阅前会取消旧的。
  void start() {
    _subscription?.cancel();
    _subscription = (db.select(db.localChanges)
          ..where((c) => c.pushedAt.isNull()))
        .watch()
        .listen(_onUnpushedChanged, onError: (Object e, StackTrace st) {
      logger.warning('SyncCoordinator', 'local_changes watch 失败: $e', st);
    });
    logger.info('SyncCoordinator', '已启动: 监听 local_changes 未推送变更');
  }

  void _onUnpushedChanged(List<LocalChange> rows) {
    // 没有未推送变更:大概率是 markPushed 之后的 echo,跳过即可。
    if (rows.isEmpty) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      logger.info('SyncCoordinator', '检测到 ${rows.length} 条未推送变更,触发自动同步');
      engine.triggerAutoSync(reason: 'local_change_detected');
    });
  }

  /// 释放资源。配合 `ref.onDispose` 调用。
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _subscription?.cancel();
    _subscription = null;
  }
}
