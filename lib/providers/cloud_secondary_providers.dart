/// BeeCount-Cloud 二次开发 REST 服务的 Riverpod 接入。
/// 依赖 beecountCloudProviderInstance(已登录的 BeeCountCloudProvider)。
library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/secondary/cloud_secondary_service.dart';
import 'sync_providers.dart';

/// 二次开发 REST 服务实例。非 BeeCount Cloud 模式 / 未登录 → null,
/// UI 自己降级(隐藏相关入口)。
final cloudSecondaryServiceProvider =
    FutureProvider<CloudSecondaryService?>((ref) async {
  final cloud = await ref.watch(beecountCloudProviderInstance.future);
  if (cloud == null) return null;
  return CloudSecondaryService(cloud);
});

/// 二次开发数据刷新 tick：增删改联系人/借款/储蓄罐等后 ++，
/// 列表页 watch 它即可 reactive 重拉(这些实体不走 sync change)。
final cloudSecondaryRefreshProvider = StateProvider<int>((ref) => 0);

/// 锁账配置 provider(展示层)。watch refresh tick / sync 后刷新。
final cloudLockSettingsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(cloudSecondaryRefreshProvider);
  final service = await ref.watch(cloudSecondaryServiceProvider.future);
  if (service == null) return null;
  try {
    return await service.lockSettings();
  } on CloudSecondaryApiException catch (e) {
    if (e.statusCode == 404) return null; // 老服务端无锁账端点
    rethrow;
  }
});
