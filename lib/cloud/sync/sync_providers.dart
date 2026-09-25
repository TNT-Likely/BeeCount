import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/database_providers.dart';
import 'change_tracker.dart';
import 'sync_engine.dart';

/// ChangeTracker provider
final changeTrackerProvider = Provider<ChangeTracker>((ref) {
  final db = ref.watch(databaseProvider);
  return ChangeTracker(db);
});

/// 同步引擎状态（区别于 sync_service.dart 中的 SyncStatus）
final syncEngineStatusProvider =
    StateProvider<SyncEngineStatus>((ref) => SyncEngineStatus.idle);

/// 未推送变更数量
final unpushedChangeCountProvider = FutureProvider<int>((ref) async {
  final tracker = ref.watch(changeTrackerProvider);
  return tracker.getUnpushedCount();
});
