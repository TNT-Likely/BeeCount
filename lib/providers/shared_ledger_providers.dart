// 共享账本数据刷新 tick:Owner 改 user-global / WS shared_resource_change /
// member_change 触发后 ++。picker 等 widget watch 它强制 rebuild,确保跨设备
// 改动立即反映到 Editor 的 picker UI。
//
/// Shared-ledger Riverpod 层。
///
/// 把 BeeCountCloudProvider 的 invites / members API 封装成可缓存的
/// FutureProvider,UI 直接 ref.watch。失效刷新走 family.refresh 或 invalidate。
///
/// 设计:
/// - 所有 provider autoDispose,避免后台残留 — 共享账本是低频功能,
///   UI 关掉就该释放。
/// - cloud provider 缺失 / 用户未登录时,所有 provider 返回 null 或空集合,
///   UI 自己降级提示。
library;

import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/sync/sync_providers.dart' as cloud_sync;
import 'database_providers.dart';
import 'sync_providers.dart';

/// 共享账本资源刷新 tick:Owner 改 / WS 收 / accept 接受 → ++,picker / 反查
/// widget watch 它即可 reactive 刷新。
final sharedResourceRefreshProvider = StateProvider<int>((ref) => 0);

/// 列出某账本的成员(任何 member 可读)。
/// Sprint 5.1 边界:watch sharedResourceRefreshProvider 让 WS 重连后(server
/// 不持久化离线 member_change 事件)自动重拉,避免被踢 / 新成员加入但本地
/// 列表 stale 的窗口。
final ledgerMembersProvider = FutureProvider.autoDispose
    .family<List<BeeCountCloudLedgerMember>, String>((ref, ledgerId) async {
  ref.watch(sharedResourceRefreshProvider);
  final cloud = await ref.watch(beecountCloudProviderInstance.future);
  if (cloud == null) return const [];
  return cloud.listMembers(ledgerId: ledgerId);
});

/// 共享账本成员收支统计 query key — (ledgerId, scope)。
/// scope 限 'month' / 'year' / 'all',period 暂用默认(当月/当年/全部)。
class MemberStatsKey {
  const MemberStatsKey({required this.ledgerId, this.scope = 'month'});

  final String ledgerId;
  final String scope;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemberStatsKey &&
          other.ledgerId == ledgerId &&
          other.scope == scope);

  @override
  int get hashCode => Object.hash(ledgerId, scope);
}

/// 共享账本成员收支统计 provider。watch sharedResourceRefreshProvider 实现
/// 实时跟随:当 WS sync_change / member_change 来时,bump tick → refetch。
///
/// 错误处理:cloud 不可用时返 null(单人 / 非 Cloud 后端场景),让 UI
/// 自动隐藏。**其它异常一律向上抛**,让 AsyncValue.when error 分支展示
/// 真实错误,而不是把 401/403/500/网络 等全部 swallow 成"无数据"。
final memberStatsProvider = FutureProvider.autoDispose
    .family<BeeCountCloudMemberStats?, MemberStatsKey>((ref, key) async {
  ref.watch(sharedResourceRefreshProvider);
  final cloud = await ref.watch(beecountCloudProviderInstance.future);
  if (cloud == null) return null;
  return cloud.fetchMemberStats(
    ledgerId: key.ledgerId,
    scope: key.scope,
    tzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
  );
});

/// 列出某账本"当前 active"邀请(仅 owner)。
final ledgerInvitesProvider = FutureProvider.autoDispose
    .family<List<BeeCountCloudInvite>, String>((ref, ledgerId) async {
  final cloud = await ref.watch(beecountCloudProviderInstance.future);
  if (cloud == null) return const [];
  try {
    return await cloud.listInvites(ledgerId: ledgerId);
  } catch (_) {
    // 非 owner 拉这个会 404 — 降级返空,UI 不显示邀请列表区
    return const [];
  }
});

/// 一次性触发函数:创建邀请 → 自动失效列表 cache。
Future<BeeCountCloudInvite> createInviteAndRefresh(
  WidgetRef ref, {
  required String ledgerId,
  required String role,
  required int expiresInHours,
}) async {
  final cloud = await ref.read(beecountCloudProviderInstance.future);
  if (cloud == null) {
    throw StateError('BeeCount Cloud not configured');
  }
  final invite = await cloud.createInvite(
    ledgerId: ledgerId,
    role: role,
    expiresInHours: expiresInHours,
  );
  ref.invalidate(ledgerInvitesProvider(ledgerId));
  return invite;
}

/// 一次性触发函数:撤销邀请 → 失效列表。
Future<void> revokeInviteAndRefresh(
  WidgetRef ref, {
  required String ledgerId,
  required String code,
}) async {
  final cloud = await ref.read(beecountCloudProviderInstance.future);
  if (cloud == null) return;
  await cloud.revokeInvite(ledgerId: ledgerId, code: code);
  ref.invalidate(ledgerInvitesProvider(ledgerId));
}

/// 接受邀请 — 不绑特定 ledger family(此时还不知道是哪个 ledger)。
Future<BeeCountCloudInviteAcceptResult> acceptInvite(
  WidgetRef ref, {
  required String code,
}) async {
  final cloud = await ref.read(beecountCloudProviderInstance.future);
  if (cloud == null) {
    throw StateError('BeeCount Cloud not configured');
  }
  final result = await cloud.acceptInvite(code: code);
  // 接受后整个账本列表(本地 ledger / remote ledgers)都可能变,失效兜底
  // 由 sync engine 的 pull 路径 + cloud 同步刷新。
  return result;
}

/// preview(不写)
Future<BeeCountCloudInvitePreview> previewInvite(
  WidgetRef ref, {
  required String code,
}) async {
  final cloud = await ref.read(beecountCloudProviderInstance.future);
  if (cloud == null) {
    throw StateError('BeeCount Cloud not configured');
  }
  return cloud.previewInvite(code: code);
}

/// 删成员(踢人 / 退出)。caller 给 ledgerId 用于 cache 失效。
Future<void> removeMemberAndRefresh(
  WidgetRef ref, {
  required String ledgerId,
  required String userId,
}) async {
  final cloud = await ref.read(beecountCloudProviderInstance.future);
  if (cloud == null) return;
  await cloud.removeMember(ledgerId: ledgerId, userId: userId);
  ref.invalidate(ledgerMembersProvider(ledgerId));

  // §7 共享账本:Owner 踢成员后,本地 Ledgers 表的 memberCount / isShared
  // 需要更新(server 端 LedgerMember 行已删,/read/ledgers 会返新数据,但
  // 本地数据 stale → 首页 header / 账本列表 🤝 显示还是 2 人)。手动调
  // syncLedgersFromServer 让本地 ledger 字段对齐,然后 bump 所有相关 tick。
  try {
    final engine = ref.read(cloud_sync.syncEngineProvider(cloud));
    await engine.syncLedgersFromServer();
  } catch (_) {}
  ref.invalidate(localLedgersProvider);
  ref.read(ledgerListRefreshProvider.notifier).state++;
  // currentLedgerProvider 也得 invalidate — 首页 header 看的是它
  ref.invalidate(currentLedgerProvider);
}

// MVP 阶段不实现 transfer ownership(roadmap 推到 Phase 3);
// 当前 cloud provider 上不暴露这个方法,UI 也不展示按钮。
