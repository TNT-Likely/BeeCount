import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart'
    hide SyncStatus;

import '../../providers/database_providers.dart';
import 'change_tracker.dart';
import 'sync_engine.dart';

/// ChangeTracker provider
final changeTrackerProvider = Provider<ChangeTracker>((ref) {
  final db = ref.watch(databaseProvider);
  return ChangeTracker(db);
});

/// SyncEngine provider（需要已认证的 BeeCountCloudProvider）。
///
/// 全 app 唯一来源。`providers/sync_providers.dart::syncServiceProvider`、
/// `shared_ledger_providers.dart`、`join_shared_ledger_page.dart` 都通过这个
/// family 拿同一个 engine 实例(family key=cloudProvider 命中相同缓存)。
/// 否则两个独立 engine 各跑各的 sync,同一 ledger 1 秒内可能 2-3 次 sync。
///
/// 注:disposal 责任归 family — engine.startListeningRealtime 在 syncService
/// 装配 callback 后才启动,但 dispose 由 Riverpod GC family entry 时统一触发。
final syncEngineProvider = Provider.family<SyncEngine, BeeCountCloudProvider>(
  (ref, provider) {
    final db = ref.watch(databaseProvider);
    final tracker = ref.watch(changeTrackerProvider);
    final repo = ref.watch(repositoryProvider);
    final engine = SyncEngine(
      db: db,
      provider: provider,
      changeTracker: tracker,
      repo: repo,
    );
    ref.onDispose(() => engine.dispose());
    return engine;
  },
);

/// 同步引擎状态（区别于 sync_service.dart 中的 SyncStatus）
final syncEngineStatusProvider =
    StateProvider<SyncEngineStatus>((ref) => SyncEngineStatus.idle);

/// 未推送变更数量
final unpushedChangeCountProvider = FutureProvider<int>((ref) async {
  final tracker = ref.watch(changeTrackerProvider);
  return tracker.getUnpushedCount();
});
