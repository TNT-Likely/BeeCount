import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as d;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../../services/custom_icon_service.dart';
import '../../services/system/logger_service.dart';
import '../../services/ui/avatar_service.dart';
import '../sync_service.dart' as app;
import '../transactions_json.dart';
import 'change_tracker.dart';
import 'entity_serializer.dart';

const _uuid = Uuid();

/// 同步结果
class SyncResult {
  final int pushed;
  final int pulled;
  final int conflicts;
  final String? error;

  const SyncResult({
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.error,
  });

  bool get hasError => error != null;

  @override
  String toString() =>
      'SyncResult(pushed=$pushed, pulled=$pulled, conflicts=$conflicts${error != null ? ', error=$error' : ''})';
}

/// 同步状态
enum SyncEngineStatus { idle, pushing, pulling, syncing, error }

/// 核心同步编排器 — 实现 SyncService 接口
/// 负责 push 本地变更到服务端、pull 远程变更到本地
class SyncEngine implements app.SyncService {
  final BeeDatabase db;
  final BeeCountCloudProvider provider;
  final ChangeTracker changeTracker;
  final BaseRepository repo;

  /// 状态缓存
  final Map<int, app.SyncStatus> _statusCache = {};
  bool _localChanged = false;

  /// WebSocket 实时监听
  StreamSubscription<BeeCountCloudRealtimeEvent>? _realtimeSubscription;
  Timer? _pullDebounce;

  /// 当前正在自动拉取的 ledgerId（防止重复触发）
  bool _autoPulling = false;

  /// 当前是否在执行 WS 重连触发的自动 sync（push+pull），防止 ws reconnect
  /// 和 connectivity 恢复几乎同时命中时重复 sync。
  bool _autoSyncing = false;
  Timer? _autoSyncDebounce;

  /// 外部回调：自动 pull 完成后通知（用于刷新 UI）
  void Function(String ledgerId)? onAutoPullCompleted;

  /// 外部注入：当前活跃 ledgerId 的解析器。WS 重连 / 网络恢复 时需要知道
  /// 往哪个 ledger 触发 sync，但 SyncEngine 内部不挂 Riverpod ref，所以让
  /// sync_providers 构造完之后塞一个函数进来。返回 0 / null 会跳过本次 sync。
  String Function()? ledgerIdResolver;

  /// 外部注入:从 /profile/me 拉到的值回写本地 SharedPreferences + Riverpod
  /// 的 setter。SyncEngine 不挂 Riverpod ref,sync_providers 构造后 hook
  /// 进来。三个字段的 null 分别对应"不同步该字段"的 fallback。
  void Function(String hex)? onThemeColorApplied;
  void Function(bool incomeIsRed)? onIncomeColorApplied;
  void Function(Map<String, dynamic> appearance)? onAppearanceApplied;
  void Function(Map<String, dynamic> aiConfig)? onAiConfigApplied;

  SyncEngine({
    required this.db,
    required this.provider,
    required this.changeTracker,
    required this.repo,
  });

  // ==================== SyncService 接口实现 ====================

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    logger.info('SyncEngine', '上传账本 ledger=$ledgerId');

    // 用户主动点"上传"永远只做增量：用 server 的 entity diff log 把本地未推
    // 送的 changes 推上去，绝不触发 fullPush。
    //
    // 原因：fullPush 会把本地当前 ledger 的 JSON 快照整体覆盖到 server 的
    // snapshot（path = ledger.syncId），一旦本地不是"完整权威版本"（比如
    // B 刚登录、bootstrap pull 还没跑完 / 跑了但漏了几条、多设备期间某条
    // 交易延迟到达），web 立刻就看到"剩几条"的残缺快照 —— 这是典型的
    // "覆盖丢数据"场景。
    //
    // 即使一次 fullPush 之后后续 pull 再回灌也不行：snapshot 是权威源，
    // sync_changes 只是 diff，web 端读的是 snapshot。
    //
    // 增量 push 只推 changeTracker 登记过的本地操作，不会把没 own 的数据
    // 误推回去，所以是安全的。本地没变更时直接返回，不需要 fallback。
    final pushed = await _push(ledgerId.toString());
    logger.info('SyncEngine', '上传账本完成：增量推送 $pushed 条变更');

    _statusCache.remove(ledgerId);
    _localChanged = false;
  }

  @override
  Future<({int inserted, int deletedDup})>
      downloadAndRestoreToCurrentLedger({required int ledgerId}) async {
    logger.info('SyncEngine', '下载并恢复账本 ledger=$ledgerId');

    // 先尝试增量拉取
    final pulled = await _pull(ledgerId.toString());
    if (pulled > 0) {
      _statusCache.remove(ledgerId);
      return (inserted: pulled, deletedDup: 0);
    }

    // 增量拉取无数据，尝试全量拉取
    final result = await _fullPull(ledgerId: ledgerId);
    _statusCache.remove(ledgerId);
    return result;
  }

  @override
  Future<app.SyncStatus> getStatus({required int ledgerId}) async {
    // 返回缓存（如果有且未标记变更）
    if (!_localChanged && _statusCache.containsKey(ledgerId)) {
      return _statusCache[ledgerId]!;
    }

    try {
      final user = await provider.auth.currentUser;
      if (user == null) {
        return const app.SyncStatus(
          diff: app.SyncDiff.notLoggedIn,
          localCount: 0,
          localFingerprint: '',
        );
      }

      // 本地交易数
      final localTxs = await (db.select(db.transactions)
            ..where((t) => t.ledgerId.equals(ledgerId)))
          .get();
      final localCount = localTxs.length;

      // 检查是否有未推送的本地变更
      final unpushedCount =
          (await changeTracker.getUnpushedChangesForLedger(ledgerId)).length;

      // 检查云端是否有数据。path 用 ledger.syncId 跟 push 侧保持一致。
      final ledgerRowStatus = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingleOrNull();
      final hasRemote = await provider.storage.exists(
        path: ledgerRowStatus?.syncId ?? ledgerId.toString(),
      );

      app.SyncDiff diff;
      if (!hasRemote && localCount == 0) {
        diff = app.SyncDiff.noRemote;
      } else if (!hasRemote) {
        diff = app.SyncDiff.localNewer; // 本地有数据，云端没有
      } else if (unpushedCount > 0) {
        diff = app.SyncDiff.localNewer;
      } else {
        diff = app.SyncDiff.inSync;
      }

      final status = app.SyncStatus(
        diff: diff,
        localCount: localCount,
        localFingerprint: unpushedCount > 0 ? 'has_changes' : 'synced',
      );
      _statusCache[ledgerId] = status;
      _localChanged = false;
      return status;
    } catch (e, st) {
      logger.error('SyncEngine', '获取同步状态失败', e, st);
      return app.SyncStatus(
        diff: app.SyncDiff.error,
        localCount: 0,
        localFingerprint: '',
        message: e.toString(),
      );
    }
  }

  @override
  void markLocalChanged({required int ledgerId}) {
    _localChanged = true;
    _statusCache.remove(ledgerId);
  }

  @override
  Future<void> deleteRemoteBackup({required int ledgerId}) async {
    // path 用 ledger.syncId，跟 push/upload 对齐。
    final ledgerRow = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final path = ledgerRow?.syncId ?? ledgerId.toString();
    try {
      await provider.storage.delete(path: path);
    } catch (e) {
      // 忽略 404
      if (!e.toString().contains('404')) rethrow;
    }
    _statusCache.remove(ledgerId);
  }

  @override
  void clearStatusCache({int? ledgerId}) {
    if (ledgerId != null) {
      _statusCache.remove(ledgerId);
    } else {
      _statusCache.clear();
    }
  }

  @override
  Future<({String? fingerprint, int? count, DateTime? exportedAt})>
      refreshCloudFingerprint({required int ledgerId}) async {
    // 对于增量同步，fingerprint 概念不太适用
    // 返回基本信息即可
    final ledgerRow = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final hasRemote = await provider.storage.exists(
      path: ledgerRow?.syncId ?? ledgerId.toString(),
    );
    if (!hasRemote) {
      return (fingerprint: null, count: null, exportedAt: null);
    }
    return (
      fingerprint: 'incremental',
      count: null,
      exportedAt: DateTime.now(),
    );
  }

  // ==================== WebSocket 实时监听 ====================

  /// 开始监听 WebSocket 实时事件，收到变更通知时自动触发 pull
  void startListeningRealtime() {
    _realtimeSubscription?.cancel();
    // 启动 WebSocket 连接，否则 realtimeEvents 流永远为空
    provider.startRealtime().catchError((e) {
      logger.warning('SyncEngine', 'WebSocket 启动失败: $e');
    });
    _realtimeSubscription = provider.realtimeEvents.listen((event) {
      if (event.type == 'sync_change' || event.type == 'backup_restore') {
        logger.info('SyncEngine',
            '收到实时事件: type=${event.type}, ledgerId=${event.ledgerId}');
        _schedulePull(event.ledgerId);
      } else if (event.type == 'profile_change') {
        // A 设备改主题色 / 收支配色 / 外观 / 头像 → server 广播。这里拉一下
        // /profile/me,把 theme_primary_color / income_is_red / appearance
        // 写回本地 SharedPreferences,让 B 无感同步。
        logger.info('SyncEngine', '收到实时事件: profile_change');
        unawaited(syncMyProfile().then((changed) {
          if (changed) {
            onAutoPullCompleted?.call(event.ledgerId ?? '');
          }
        }));
      } else if (event.type == 'connected') {
        // WS 连接建立（首次或断线重连）。离线期间累积的 local_changes 这里
        // 顺带 flush 一次，否则用户要等下一次交易写入 PostProcessor.sync()
        // 才能把东西推出去。
        logger.info('SyncEngine', 'WS connected, scheduling auto sync');
        _scheduleAutoSync(reason: 'ws_connected');
      }
    }, onError: (Object e) {
      logger.warning('SyncEngine', '实时事件流错误: $e');
    });
    logger.info('SyncEngine', '已开始监听实时事件');
  }

  /// 停止监听 WebSocket 实时事件
  void stopListeningRealtime() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _pullDebounce?.cancel();
    _pullDebounce = null;
    _autoSyncDebounce?.cancel();
    _autoSyncDebounce = null;
    logger.info('SyncEngine', '已停止监听实时事件');
  }

  /// 防抖调度一次完整 sync（push + pull）。WS 重连 / 网络恢复 都会打到这里。
  /// 2 秒防抖：WiFi ↔ 移动网络切换、或 WS reconnect 接着 connectivity 事件
  /// 这种"连续上线信号"只触发 1 次 sync。
  void _scheduleAutoSync({required String reason}) {
    _autoSyncDebounce?.cancel();
    _autoSyncDebounce = Timer(const Duration(seconds: 2), () async {
      if (_autoSyncing) {
        logger.debug('SyncEngine',
            'auto sync 跳过 (reason=$reason, 已在执行中)');
        return;
      }
      final resolver = ledgerIdResolver;
      if (resolver == null) {
        logger.debug('SyncEngine', 'auto sync 跳过 (reason=$reason, 无 resolver)');
        return;
      }
      final ledgerId = resolver();
      if (ledgerId.isEmpty || ledgerId == '0') {
        logger.debug('SyncEngine',
            'auto sync 跳过 (reason=$reason, ledgerId 为空)');
        return;
      }
      _autoSyncing = true;
      try {
        logger.info('SyncEngine',
            'auto sync 触发 (reason=$reason, ledger=$ledgerId)');
        final result = await sync(ledgerId: ledgerId);
        if (result.hasError) {
          logger.warning('SyncEngine',
              'auto sync 失败 (reason=$reason): ${result.error}');
        } else {
          logger.info('SyncEngine',
              'auto sync 完成 (reason=$reason): pushed=${result.pushed} pulled=${result.pulled}');
        }
      } catch (e, st) {
        logger.error('SyncEngine', 'auto sync 异常 (reason=$reason)', e, st);
      } finally {
        _autoSyncing = false;
      }
    });
  }

  /// 外部触发（例如 connectivity_plus 监听到网络恢复）。内部防抖、单飞。
  void triggerAutoSync({required String reason}) {
    _scheduleAutoSync(reason: reason);
  }

  /// 防抖调度 pull（1 秒内多次触发只执行一次）
  void _schedulePull(String? ledgerId) {
    _pullDebounce?.cancel();
    _pullDebounce = Timer(const Duration(seconds: 1), () async {
      if (_autoPulling) return;
      _autoPulling = true;
      try {
        final targetLedgerId = ledgerId ?? '';
        if (targetLedgerId.isEmpty) {
          logger.debug('SyncEngine', '自动 pull: 无 ledgerId，跳过');
          return;
        }
        logger.info('SyncEngine', '自动 pull 开始: ledger=$targetLedgerId');
        final pulled = await _pull(targetLedgerId);
        logger.info('SyncEngine', '自动 pull 完成: $pulled 条变更');
        // 附件二进制：metadata 已经在 _pull 里写到 Drift 了，文件本身需要额
        // 外调 downloadAttachments 才会下。之前只有 full `sync()` 调用它，
        // WS 触发的 pull 不调 → A 设备上传附件后 B 设备要重启才能看到图。
        // 这里 fire-and-forget 触发一下；失败只打日志，不阻塞 UI 刷新。
        final localLedgerIdInt =
            await _resolveLedgerIdBySyncId(targetLedgerId) ??
                int.tryParse(targetLedgerId);
        if (localLedgerIdInt != null && localLedgerIdInt > 0) {
          unawaited(() async {
            try {
              final downloaded = await downloadAttachments(
                  ledgerId: localLedgerIdInt);
              if (downloaded > 0) {
                logger.info('SyncEngine',
                    '自动 pull 后下载了 $downloaded 个附件');
                // 重新通知 UI 刷新（附件 UI 的 state 可能已经 stale）。
                onAutoPullCompleted?.call(targetLedgerId);
              }
            } catch (e, st) {
              logger.warning('SyncEngine', 'auto pull 后下载附件失败: $e', st);
            }
          }());
        }
        // 不管实际拉了几条，都通知 UI 刷新。pulled==0 可能是自我回声被过滤，
        // 但等于此刻 WS 事件产生的时候 snapshot 已经由 materialize 更新过，
        // UI 刷一下总没错；派生 Provider 重算也很便宜。
        _statusCache.remove(int.tryParse(targetLedgerId));
        onAutoPullCompleted?.call(targetLedgerId);
      } catch (e, st) {
        logger.error('SyncEngine', '自动 pull 失败', e, st);
      } finally {
        _autoPulling = false;
      }
    });
  }

  /// 释放资源
  void dispose() {
    stopListeningRealtime();
  }

  // ==================== 核心同步逻辑 ====================

  /// 执行完整同步（先 push 后 pull）
  Future<SyncResult> sync({required String ledgerId}) async {
    logger.info('SyncEngine', '开始同步 ledger=$ledgerId');
    try {
      final ledgerIdInt = int.tryParse(ledgerId) ?? -1;
      int pushed = 0;

      // 先上传附件文件，确保 cloudFileId 写入本地 DB，后续 push 的 payload 才包含 cloudFileId
      try {
        await uploadAttachments(ledgerId: ledgerIdInt);
      } catch (e, st) {
        logger.error('SyncEngine', '附件上传失败（不阻塞主同步）', e, st);
      }

      // 决策：fullPush 还是增量 push
      //
      // 原来用 SharedPreferences['sync_entity_pushed_v3_<id>'] 缓存"曾经推过"，
      // 但这个缓存会跟服务端真实状态失联（服务端重建/切换部署都会），所以我们
      // 现在直接问服务端："这个账本有没有快照？"
      //   - 有：走增量 push（只推 local_changes 里未推送的）
      //   - 没有 + 本地有交易：走 fullPush（把本地数据整体推上去）
      //   - 没有 + 本地空：跳过 push
      // 多一个 exists() 网络调用，但 O(1)、请求极小，足以省掉缓存跟真实状态
      // 失联带来的"假装同步成功"问题。
      // exists() 的 path 必须跟 fullPush / _pushAllEntities 用的 ledger_id 对齐，
      // 都走 ledger.syncId。否则：server 上数据挂在 syncId=UUID 下，本地 exists
      // 查 int id 永远 false → 误判"远端无快照" → 触发 fullPush → server 被
      // 本地残缺快照覆盖。这是之前 "web 只剩几条" 事故的主路径之一。
      final ledgerRow = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerIdInt)))
          .getSingleOrNull();
      final checkPath = ledgerRow?.syncId ?? ledgerId.toString();
      bool hasRemote = true;
      try {
        hasRemote = await provider.storage.exists(path: checkPath);
      } catch (e, st) {
        // 检查失败时保守假设远端存在，走增量 push；fullPush 的风险更大。
        logger.warning('SyncEngine', '远端存在性检查失败（按已存在处理）: $e', st);
      }

      if (!hasRemote) {
        final localTxCount = (await (db.select(db.transactions)
              ..where((t) => t.ledgerId.equals(ledgerIdInt)))
            .get()).length;
        logger.info('SyncEngine',
            '远端无快照，本地 $localTxCount 条交易，'
            '${localTxCount > 0 ? "触发 fullPush" : "跳过 push"}');
        if (localTxCount > 0) {
          // 远端重建/切换后，本地 attachments.cloudFileId 指向的文件已失效。
          // 清掉云端引用，让 uploadAttachments 重新上传并回填新 ID；否则
          // 交易 payload 里带的是旧 ID，web 那边会 404。
          await _resetAttachmentCloudRefs(ledgerIdInt);
          await fullPush(ledgerId: ledgerIdInt);
          pushed = localTxCount;
        }
      } else {
        pushed = await _push(ledgerId);
        logger.info('SyncEngine', '增量推送: $pushed 条');
      }

      final pulled = await _pull(ledgerId);

      // 下载远端附件文件（上传已在 push 前完成）
      try {
        await downloadAttachments(ledgerId: ledgerIdInt);
      } catch (e, st) {
        logger.error('SyncEngine', '附件下载失败（不阻塞主同步）', e, st);
      }

      // 顺手再拉一次 profile（多数场景 bootstrap 已经拉过，这里幂等兜底）。
      await syncMyProfile();

      final result = SyncResult(pushed: pushed, pulled: pulled);
      logger.info('SyncEngine', '同步完成: $result');
      return result;
    } catch (e, st) {
      logger.error('SyncEngine', '同步失败', e, st);
      return SyncResult(error: e.toString());
    }
  }

  /// 从服务端拉 profile，按 avatar_version 去重下载头像文件到本地。
  /// 不依赖 ledger —— profile 是 user-scoped。sync_providers bootstrap 阶段
  /// 独立调这个而不是夹在 sync() 中间（sync() 前置步骤抛错会 skip 掉这里）。
  /// 返回 true 表示有实际下载并写盘，调用方用来决定要不要 bump 刷新信号。
  /// 拉 /profile/me 并把 theme_primary_color / income_is_red / appearance /
  /// 头像都落回本地(SharedPreferences + 本地文件)。任意字段有更新都返 true,
  /// 让调用方 bump 对应 UI refresh tick。
  ///
  /// 用 [onAppearanceApplied]/[onThemeApplied]/[onIncomeColorApplied] 回调
  /// 让 sync_providers 层把值写进 Riverpod state + SharedPreferences,避免
  /// 这里直接依赖 Riverpod。回调不写就只同步头像(向后兼容)。
  Future<bool> syncMyProfile({
    void Function(String hex)? themeApplied,
    void Function(bool incomeIsRed)? incomeApplied,
    void Function(Map<String, dynamic> appearance)? appearanceApplied,
    void Function(Map<String, dynamic> aiConfig)? aiConfigApplied,
  }) async {
    // 没显式传参数时走 SyncEngine 的全局回调(sync_providers 在构造时注入)。
    // 这样 bootstrap / WS profile_change 两个内部调用点都能自动用到。
    final onThemeApplied = themeApplied ?? onThemeColorApplied;
    final onIncomeApplied = incomeApplied ?? onIncomeColorApplied;
    final onAppearanceCallback = appearanceApplied ?? onAppearanceApplied;
    final onAiConfigCallback = aiConfigApplied ?? onAiConfigApplied;
    final localVersion = await AvatarService.getStoredRemoteVersion();
    logger.info('avatar_sync',
        'syncMyProfile start, localVersion=$localVersion');
    bool anyChanged = false;
    try {
      final profile = await provider.getMyProfile();

      // === theme_primary_color ===
      final theme = profile.themePrimaryColor;
      if (theme != null && theme.isNotEmpty && onThemeApplied != null) {
        try {
          onThemeApplied(theme);
          anyChanged = true;
        } catch (e, st) {
          logger.warning('profile_sync', 'onThemeApplied 失败: $e', st);
        }
      }

      // === income_is_red ===
      final incomeIsRed = profile.incomeIsRed;
      if (incomeIsRed != null && onIncomeApplied != null) {
        try {
          onIncomeApplied(incomeIsRed);
          anyChanged = true;
        } catch (e, st) {
          logger.warning('profile_sync', 'onIncomeApplied 失败: $e', st);
        }
      }

      // === appearance (header_decoration_style / compact_amount / show_transaction_time) ===
      final appearance = profile.appearance;
      if (appearance != null && appearance.isNotEmpty && onAppearanceCallback != null) {
        try {
          onAppearanceCallback(appearance);
          anyChanged = true;
        } catch (e, st) {
          logger.warning('profile_sync', 'onAppearanceCallback 失败: $e', st);
        }
      }

      // === ai_config (providers / binding / custom_prompt / strategy …) ===
      final aiConfig = profile.aiConfig;
      if (aiConfig != null && aiConfig.isNotEmpty && onAiConfigCallback != null) {
        try {
          onAiConfigCallback(aiConfig);
          anyChanged = true;
        } catch (e, st) {
          logger.warning('profile_sync', 'onAiConfigCallback 失败: $e', st);
        }
      }

      // === avatar ===
      final url = profile.avatarUrl;
      final remoteVersion = profile.avatarVersion;
      logger.info('avatar_sync',
          'got profile url=$url remoteVersion=$remoteVersion');
      if (url == null || url.isEmpty) {
        logger.info('avatar_sync', 'server has no avatar, skip download');
        return anyChanged;
      }
      if (remoteVersion > 0 && remoteVersion == localVersion) {
        logger.info('avatar_sync',
            'avatar up-to-date (version=$remoteVersion), skip download');
        return anyChanged;
      }
      // profile 头像专用下载路径。之前这里用正则从 avatar_url 里抠
      // `attachments/(.+)` 的 fileId 然后走 downloadAttachment —— 但服务端
      // 真实 URL 是 `/profile/avatar/<user_id>?v=<v>`，和 attachment 不是
      // 同一套存储，正则永远不命中，于是"初次同步头像"永远失败。
      // 现在直接用 downloadMyAvatar(userId, version) 走对的端点。
      final bytes = await provider.downloadMyAvatar(
        userId: profile.userId,
        version: remoteVersion > 0 ? remoteVersion : null,
      );
      logger.info('avatar_sync', 'downloaded size=${bytes.length}B');
      await AvatarService.saveAvatarFromBytes(bytes);
      await AvatarService.setStoredRemoteVersion(remoteVersion);
      logger.info('avatar_sync',
          'saved to local, bumped localVersion=$remoteVersion');
      return true;
    } catch (e, st) {
      logger.warning('avatar_sync', '同步失败: $e', st);
      return anyChanged;
    }
  }

  /// 首次登录 / app 启动时从 server 拉全部账本写本地 Drift。
  ///
  /// Server 的 ledger 不走 sync_change log（只有 tx/account/cat/tag 走），
  /// 所以设备 B 首次登录时 `_pull` 拿不到 A 已有的账本。这个方法专门补这一
  /// 刀：走 `GET /sync/ledgers` 拿列表，按 `external_id` 对齐本地 `syncId`
  /// upsert 到 Drift。
  ///
  /// 新插入的 ledger 对应的 tx/account/category/tag sync_changes 历史会被
  /// `replayAllChanges`（由调用方在必要时触发）从 cursor=0 重放应用，因为
  /// 此时设备全局 cursor 可能已经前移、普通 `_pull` 再也拉不回历史。
  ///
  /// 返回新增（非已存在）的账本数，调用方可据此决定要不要 bump 刷新信号。
  Future<int> syncLedgersFromServer() async {
    logger.info('SyncEngine', 'syncLedgersFromServer start');
    try {
      final remote = await provider.readLedgers();
      int upserted = 0;
      int inserted = 0;
      for (final r in remote) {
        final syncId = r.ledgerId;
        if (syncId.isEmpty) continue;
        final existing = await (db.select(db.ledgers)
              ..where((l) => l.syncId.equals(syncId)))
            .getSingleOrNull();
        if (existing != null) {
          // update meta（name / currency 可能在 server 被改过）
          await (db.update(db.ledgers)..where((l) => l.id.equals(existing.id)))
              .write(LedgersCompanion(
            name: d.Value(r.ledgerName),
            currency: d.Value(r.currency),
          ));
          upserted++;
          continue;
        }
        // fallback：同名 + syncId 为 NULL 的 seed 行 → 收编
        final byName = await (db.select(db.ledgers)
              ..where((l) => l.name.equals(r.ledgerName))
              ..where((l) => l.syncId.isNull()))
            .getSingleOrNull();
        if (byName != null) {
          await (db.update(db.ledgers)..where((l) => l.id.equals(byName.id)))
              .write(LedgersCompanion(
            syncId: d.Value(syncId),
            currency: d.Value(r.currency),
          ));
          upserted++;
          continue;
        }
        // 全新账本：insert。id 是本地 autoIncrement，跟 server 无关。
        await db.into(db.ledgers).insert(LedgersCompanion.insert(
              name: r.ledgerName,
              currency: d.Value(r.currency),
              syncId: d.Value(syncId),
            ));
        inserted++;
      }
      logger.info(
          'SyncEngine',
          'syncLedgersFromServer done: total=${remote.length} upserted=$upserted inserted=$inserted');
      return inserted;
    } catch (e, st) {
      logger.warning('SyncEngine', 'syncLedgersFromServer failed: $e', st);
      return 0;
    }
  }

  /// 推送本地未同步的变更到服务端
  Future<int> _push(String ledgerId) async {
    final ledgerIdInt = int.tryParse(ledgerId) ?? -1;
    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerIdInt)))
        .getSingleOrNull();
    if (ledger == null) {
      logger.warning('SyncEngine', 'push: 未找到本地账本 $ledgerId');
      return 0;
    }

    // 当前账本的变更 + user-scoped（ledgerId=0：tag / category）的未推变更。
    // 后者是"账户/分类/标签属于用户而非单个账本"的对齐：LocalRepository 在
    // create/update/deleteTag/Category 时用 ledgerId=0 记录变更，getUnpushed-
    // ChangesForLedger(ledger.id) 永远查不到它们 → 移动端重命名标签/分类在
    // web 永远看不到。把 ledgerId=0 的也一起捎带。
    final ledgerChanges =
        await changeTracker.getUnpushedChangesForLedger(ledger.id);
    final globalChanges = ledger.id == 0
        ? const <LocalChange>[]
        : await changeTracker.getUnpushedChangesForLedger(0);
    final changes = [...ledgerChanges, ...globalChanges];
    if (changes.isEmpty) {
      logger.debug('SyncEngine', 'push: 无待推送变更');
      return 0;
    }

    // 构建服务端 push 格式：从 DB 读取最新数据序列化
    final syncChanges = <Map<String, dynamic>>[];

    for (final change in changes) {
      Map<String, dynamic> payload;

      if (change.action == 'delete') {
        payload = <String, dynamic>{};
      } else {
        // 从数据库读取最新实体并序列化
        payload = await _serializeEntityForPush(
          entityType: change.entityType,
          entityId: change.entityId,
          ledgerId: ledger.id,
        );
      }

      // push 侧用 ledger.syncId 作为跨设备唯一的 external_id。对 v21 以前
      // 就同步过的账本，migration 把 syncId 回填成了原 int id（如 "1"、"5"），
      // 兼容 server 已有数据；对 v21 之后新建的账本，syncId 是 UUID。
      //
      // 第二台设备看到同一账本后，syncLedgersFromServer 已把 A 的 syncId
      // 写到 B 本地 ledger 行，B push 时 `ledger.syncId` 跟 A 相同 →
      // server 不会 auto-create 新 ledger，同一账本始终单份存在。
      //
      // fallback 到 ledger.id.toString() 只覆盖 migration 前写死的极老数据
      // （理论上不会发生），不作为主路径。
      final pushLedgerId = ledger.syncId ?? ledgerId;
      syncChanges.add({
        // ledgerId=0 的 user-global 变更依附到当前账本 push 上。服务端按
        // entity_type + entity_sync_id 做 LWW / 物化，不依赖这里的 ledger_id
        // 字段，这样挂一下能让 mobile 的全局实体改动搭上任一账本的同步链。
        'ledger_id': pushLedgerId,
        'entity_type': change.entityType,
        'entity_sync_id': change.entitySyncId,
        'action': change.action == 'delete' ? 'delete' : 'upsert',
        'payload': payload,
        'updated_at': change.createdAt.toUtc().toIso8601String(),
      });
    }

    // 使用 pushChanges 直接推送个体变更
    await provider.pushChanges(changes: syncChanges);

    // 标记已推送
    await changeTracker.markPushed(changes.map((c) => c.id).toList());
    logger.info('SyncEngine',
        'push: 推送 ${changes.length} 条变更 (当前账本 ${ledgerChanges.length} + 全局 ${globalChanges.length})');
    return changes.length;
  }

  /// 从 DB 读取实体并序列化为 push payload
  Future<Map<String, dynamic>> _serializeEntityForPush({
    required String entityType,
    required int entityId,
    required int ledgerId,
  }) async {
    // 取父 ledger 的 syncId，下面 serialize 时塞进 tx payload。对端
    // apply 先用 payload.ledgerSyncId 解析本地 ledger id，跨设备的 int id
    // 不一致问题（如 A 的账本 2 = B 的账本 3）才不会把 tx 错挂到别处。
    final parentLedger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final parentLedgerSyncId = parentLedger?.syncId;

    switch (entityType) {
      case 'transaction':
        final tx = await (db.select(db.transactions)
              ..where((t) => t.id.equals(entityId)))
            .getSingleOrNull();
        if (tx == null) return <String, dynamic>{};

        // 获取关联数据
        final cat = tx.categoryId != null
            ? await (db.select(db.categories)
                  ..where((c) => c.id.equals(tx.categoryId!)))
                .getSingleOrNull()
            : null;
        final acc = tx.accountId != null
            ? await (db.select(db.accounts)
                  ..where((a) => a.id.equals(tx.accountId!)))
                .getSingleOrNull()
            : null;
        final toAcc = tx.toAccountId != null
            ? await (db.select(db.accounts)
                  ..where((a) => a.id.equals(tx.toAccountId!)))
                .getSingleOrNull()
            : null;

        // 获取标签（连同 tag.syncId，server 端按 id 反查最新名字）
        final txTags = await (db.select(db.transactionTags)
              ..where((tt) => tt.transactionId.equals(tx.id)))
            .get();
        final tagNames = <String>[];
        final tagSyncIds = <String>[];
        for (final tt in txTags) {
          final tag = await (db.select(db.tags)
                ..where((t) => t.id.equals(tt.tagId)))
              .getSingleOrNull();
          if (tag != null) {
            tagNames.add(tag.name);
            if (tag.syncId != null && tag.syncId!.isNotEmpty) {
              tagSyncIds.add(tag.syncId!);
            }
          }
        }

        // 获取附件
        final txAttachments = await (db.select(db.transactionAttachments)
              ..where((a) => a.transactionId.equals(tx.id)))
            .get();
        final attMaps = txAttachments
            .map((a) => <String, dynamic>{
                  'fileName': a.fileName,
                  'originalName': a.originalName,
                  'fileSize': a.fileSize,
                  'width': a.width,
                  'height': a.height,
                  'sortOrder': a.sortOrder,
                  if (a.cloudFileId != null) 'cloudFileId': a.cloudFileId,
                  if (a.cloudSha256 != null) 'cloudSha256': a.cloudSha256,
                })
            .toList();

        return EntitySerializer.serializeTransaction(
          tx,
          categoryName: cat?.name,
          categoryKind: cat?.kind,
          categorySyncId: cat?.syncId,
          accountName: acc?.name,
          accountSyncId: acc?.syncId,
          fromAccountName: tx.type == 'transfer' ? acc?.name : null,
          fromAccountSyncId: tx.type == 'transfer' ? acc?.syncId : null,
          toAccountName: toAcc?.name,
          toAccountSyncId: toAcc?.syncId,
          ledgerSyncId: parentLedgerSyncId,
          tagNames: tagNames.isNotEmpty ? tagNames : null,
          tagSyncIds: tagSyncIds.isNotEmpty ? tagSyncIds : null,
          attachments: attMaps,
        );

      case 'account':
        final account = await (db.select(db.accounts)
              ..where((a) => a.id.equals(entityId)))
            .getSingleOrNull();
        if (account == null) return <String, dynamic>{};
        return EntitySerializer.serializeAccount(account);

      case 'category':
        final category = await (db.select(db.categories)
              ..where((c) => c.id.equals(entityId)))
            .getSingleOrNull();
        if (category == null) return <String, dynamic>{};
        String? parentName;
        if (category.parentId != null) {
          final parent = await (db.select(db.categories)
                ..where((c) => c.id.equals(category.parentId!)))
              .getSingleOrNull();
          parentName = parent?.name;
        }
        // 如果分类是自定义图标，先把图标文件上传到云端拿到 fileId/sha256，
        // 否则增量 push 的 payload 里不会带 iconCloudFileId，web 端永远没图。
        // fullPush 的 `_uploadCategoryIcons` 是批量版本，这里对单条 category 做
        // 同样的事情 —— server 按 sha256 去重，重复上传不占额外空间。
        String? iconCloudFileId;
        String? iconCloudSha256;
        if (category.iconType == 'custom' &&
            category.customIconPath != null &&
            category.customIconPath!.isNotEmpty) {
          try {
            final iconSvc = CustomIconService();
            final abs = await iconSvc.resolveIconPath(category.customIconPath!);
            final file = File(abs);
            if (file.existsSync()) {
              final bytes = await file.readAsBytes();
              // 跟 attachment 一样用 ledger.syncId 当 server ledger_id，
              // 避免 B 本地 int id 在 server ledgers 表里找不到报 "Ledger
              // not found"。parentLedgerSyncId 在这个 switch 顶部已解析好。
              final uploaded = await provider.uploadAttachment(
                ledgerId: parentLedgerSyncId ?? ledgerId.toString(),
                bytes: bytes,
                fileName: category.customIconPath!.split('/').last,
              );
              iconCloudFileId = uploaded.fileId;
              iconCloudSha256 = uploaded.sha256;
            }
          } catch (e, st) {
            logger.warning(
                'SyncEngine', '分类图标增量上传失败: ${category.name} $e', st);
          }
        }
        return EntitySerializer.serializeCategory(
          category,
          parentName: parentName,
          iconCloudFileId: iconCloudFileId,
          iconCloudSha256: iconCloudSha256,
        );

      case 'tag':
        final tag = await (db.select(db.tags)
              ..where((t) => t.id.equals(entityId)))
            .getSingleOrNull();
        if (tag == null) return <String, dynamic>{};
        return EntitySerializer.serializeTag(tag);

      case 'budget':
        final budget = await (db.select(db.budgets)
              ..where((b) => b.id.equals(entityId)))
            .getSingleOrNull();
        if (budget == null) return <String, dynamic>{};
        // 分类预算才有 categorySyncId;总预算直接不带。ledgerSyncId 用本 tx
        // 顶上已经取到的 parentLedgerSyncId(对应 budget.ledgerId)。
        String? categorySyncId;
        if (budget.categoryId != null) {
          final cat = await (db.select(db.categories)
                ..where((c) => c.id.equals(budget.categoryId!)))
              .getSingleOrNull();
          categorySyncId = cat?.syncId;
        }
        return EntitySerializer.serializeBudget(
          budget,
          ledgerSyncId: parentLedgerSyncId,
          categorySyncId: categorySyncId,
        );

      case 'ledger':
        // 账本元数据(名字 / 币种)。entityId 是本地 int id,取出后按 syncId
        // 推送,server materialize 时更新 `ledger_snapshot.ledgerName/currency`
        // + `Ledger.name` 自身,web 下次 read 就拿到新名字。
        final ledger = await (db.select(db.ledgers)
              ..where((l) => l.id.equals(entityId)))
            .getSingleOrNull();
        if (ledger == null || ledger.syncId == null || ledger.syncId!.isEmpty) {
          return <String, dynamic>{};
        }
        return EntitySerializer.serializeLedger(ledger);

      default:
        return <String, dynamic>{};
    }
  }

  /// 拉取远程变更并应用到本地。每一页变更用 `db.transaction` 包起来，把
  /// "逐条 select + insert" 合成一个事务，初次同步几百条实体时的"感觉一条
  /// 一条蹦出来"变成一次性写入，iOS SQLite 的 fsync 代价减一大截。
  ///
  /// 默认用 provider 存在 SharedPreferences 里的全局 cursor；传 [sinceOverride]
  /// 可以强制从指定 change_id 重拉（用 0 表示从头）。BeeCount Cloud apply 是
  /// 按 entity_sync_id 做 upsert 的，所以重拉历史是幂等的，用于"cursor 推到顶
  /// 但本地状态跟实际脱节"的恢复场景。
  Future<int> _pull(String ledgerId, {int? sinceOverride}) async {
    int totalPulled = 0;

    bool hasMore = true;
    int? nextSince = sinceOverride;
    while (hasMore) {
      final result = await provider.pullChanges(since: nextSince, limit: 500);
      if (result.changes.isEmpty) break;

      // 用 transaction 把整页变更合成一次提交。Drift 内部是 SQLite 单 WAL，
      // 每条独立 commit 会触发 fsync；合成一次可以把 N 次 fsync 降到 1 次。
      // 即使某条 apply 内部抛错，transaction 会 rollback 整页 —— 比半同步
      // 的状态好，下一次 sync 会再拉一次（server cursor 只在全部成功时 advance）。
      final pageApplied = await db.transaction<int>(() async {
        int pageCount = 0;
        for (final change in result.changes) {
          final applied = await _applyRemoteChange(change);
          if (applied) pageCount++;
        }
        return pageCount;
      });
      totalPulled += pageApplied;

      hasMore = result.hasMore;
      // 下一页接着上一页的 cursor 往后翻；pullChanges 内部也会 save，这里
      // 只是显式把下一个页面的 since 对齐到 server 返回的最新 cursor。
      if (hasMore) nextSince = result.serverCursor;
    }

    if (totalPulled > 0) {
      logger.info('SyncEngine', 'pull: 应用 $totalPulled 条远程变更');
    }
    return totalPulled;
  }

  /// 从 change_id=0 起把整段 sync_changes 重拉一遍并幂等应用。
  /// 用在"账本刚从 server 拉到本地、本地 tx 为空但 cursor 已经被推到顶"
  /// 的恢复场景。跟 S3/WebDAV 的 `_fullPull` 不同，这里走的还是 BeeCount
  /// Cloud 的增量日志，只是把起点拨回 0，符合 BeeCount Cloud 的同步模型。
  Future<int> replayAllChanges() async {
    logger.info('SyncEngine', 'replayAllChanges: 从 0 开始重拉 sync_changes');
    return _pull('', sinceOverride: 0);
  }

  /// 云同步页下拉刷新时用:对比本地 Drift 和 server `/read/ledgers/<id>/stats`
  /// 返回的计数,如果有差异就返回 hasDiff=true,UI 据此决定是否触发一次
  /// auto sync。server 端计数来源跟 web 实际展示一致(从最新 snapshot 读),
  /// 所以对得上 web 就代表"对端用户眼里的真实状态"。
  Future<SyncHealthReport> checkSyncHealth({required int ledgerId}) async {
    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    if (ledger == null) {
      return SyncHealthReport.error('本地找不到 ledger=$ledgerId');
    }
    final serverLedgerId = ledger.syncId ?? ledger.id.toString();

    // ---------- 本地 per-ledger ----------
    // 只数有 syncId 的行,跟服务端口径对齐 —— 没 syncId 的行无法 push,
    // 云端不会有对应记录,统计它们会造成永久假阳性"本地比云端多"。
    final ledgerTxRows = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId))
          ..where((t) => t.syncId.isNotNull()))
        .get();
    final localLedgerTx = ledgerTxRows.length;
    final ledgerTxIds = ledgerTxRows.map((t) => t.id).toList();
    // 本地附件按"实际占盘数"算 —— transaction_attachments 每 tx 独立一行,
    // 磁盘上也是每行一个物理文件(mobile 不做 sha256 dedup)。服务端那边
    // 要对齐这个"引用条目数"口径,见 server read.py::get_ledger_stats 里
    // attachment_count 改成按 attachments_json 条目 SUM。
    int localLedgerTxAttachments = 0;
    if (ledgerTxIds.isNotEmpty) {
      localLedgerTxAttachments = (await (db.select(db.transactionAttachments)
                ..where((a) => a.transactionId.isIn(ledgerTxIds)))
              .get())
          .length;
    }
    // 分类自定义图标也占 attachment_files 一行(走 /attachments/upload 进同一张表),
    // server 的 attachment_count 把它们算进去了,所以本地也补上对齐。分类是
    // 用户级实体,每个账本 fullPush 都会把所有 custom icon 上传一份挂到那个
    // ledger 下,per-ledger 口径 = 全局 custom icon 数。
    final customIconCategoryCount = (await (db.select(db.categories)
              ..where((c) => c.iconType.equals('custom'))
              ..where((c) => c.customIconPath.isNotNull()))
            .get())
        .length;
    final localLedgerAttachments =
        localLedgerTxAttachments + customIconCategoryCount;
    final localLedgerBudgets = (await (db.select(db.budgets)
              ..where((b) => b.ledgerId.equals(ledgerId))
              ..where((b) => b.syncId.isNotNull()))
            .get())
        .length;

    // ---------- 本地 全量 ----------
    final localTotalTx = (await (db.select(db.transactions)
              ..where((t) => t.syncId.isNotNull()))
            .get())
        .length;
    // 全量附件 = 所有 tx 附件 + 每个账本各自上传一份的分类图标(ledgers 个)
    final localTotalTxAttachments =
        (await db.select(db.transactionAttachments).get()).length;
    final localLedgerCount = (await db.select(db.ledgers).get()).length;
    final localTotalAttachments =
        localTotalTxAttachments + customIconCategoryCount * localLedgerCount;
    final localTotalBudgets = (await (db.select(db.budgets)
              ..where((b) => b.syncId.isNotNull()))
            .get())
        .length;

    // ---------- 本地 用户级 ----------
    final localAccounts = (await (db.select(db.accounts)
              ..where((a) => a.syncId.isNotNull()))
            .get())
        .length;
    final localCategories = (await (db.select(db.categories)
              ..where((c) => c.syncId.isNotNull()))
            .get())
        .length;
    final localTags = (await (db.select(db.tags)
              ..where((t) => t.syncId.isNotNull()))
            .get())
        .length;

    final unpushed =
        (await changeTracker.getUnpushedChangesForLedger(ledgerId)).length;

    // ---------- 远端 /read/ledgers/<id>/stats ----------
    try {
      final stats = await provider.readLedgerStats(ledgerId: serverLedgerId);
      return SyncHealthReport(
        ledgerTx: SyncCountPair(
            local: localLedgerTx, remote: stats.transactionCount),
        ledgerAttachments: SyncCountPair(
            local: localLedgerAttachments, remote: stats.attachmentCount),
        ledgerBudgets:
            SyncCountPair(local: localLedgerBudgets, remote: stats.budgetCount),
        totalTx: SyncCountPair(
            local: localTotalTx, remote: stats.transactionTotal),
        totalAttachments: SyncCountPair(
            local: localTotalAttachments, remote: stats.attachmentTotal),
        totalBudgets:
            SyncCountPair(local: localTotalBudgets, remote: stats.budgetTotal),
        accounts: SyncCountPair(local: localAccounts, remote: stats.accountTotal),
        categories:
            SyncCountPair(local: localCategories, remote: stats.categoryTotal),
        tags: SyncCountPair(local: localTags, remote: stats.tagTotal),
        unpushedChanges: unpushed,
      );
    } catch (e, st) {
      logger.warning('SyncEngine', 'checkSyncHealth 拉 stats 失败: $e', st);
      return SyncHealthReport(
        ledgerTx: SyncCountPair(local: localLedgerTx, remote: -1),
        ledgerAttachments:
            SyncCountPair(local: localLedgerAttachments, remote: -1),
        ledgerBudgets: SyncCountPair(local: localLedgerBudgets, remote: -1),
        totalTx: SyncCountPair(local: localTotalTx, remote: -1),
        totalAttachments: SyncCountPair(local: localTotalAttachments, remote: -1),
        totalBudgets: SyncCountPair(local: localTotalBudgets, remote: -1),
        accounts: SyncCountPair(local: localAccounts, remote: -1),
        categories: SyncCountPair(local: localCategories, remote: -1),
        tags: SyncCountPair(local: localTags, remote: -1),
        unpushedChanges: unpushed,
        error: e.toString(),
      );
    }
  }

  /// 为"绕过 changeTracker 插入"的本地 tag / account / category / budget
  /// 补写 `create` 变更记录,让后续 push 能把它们推到云端。
  ///
  /// 典型场景:早期的种子代码(TagSeedService)直接 `db.into(...).insert()`,
  /// 不经 `LocalRepository.createTag` → 这批标签永远不会被 push。
  /// `checkSyncHealth` 检测到 `localTags > remoteTags` 且 `unpushed == 0` 时
  /// 调这个方法 backfill 一次,再触发 sync 就能把种子标签送上云。
  ///
  /// 幂等:只对没有对应 sync_change 记录的实体补写 create。重复调用是安全的。
  Future<int> backfillUntrackedEntities({required int ledgerId}) async {
    final allUnpushed = await changeTracker.getUnpushedChangesForLedger(ledgerId);
    final allPushedIds = <String>{};  // syncId 集合 —— unpushed 的先留着,判断"从未写过 change"用的是下面的专用查询
    for (final c in allUnpushed) {
      allPushedIds.add(c.entitySyncId);
    }
    // 用 change_tracker 的 hasAnyChangeForEntity(若有) / 直接查 local_changes 表。
    // 这里用更稳妥的方式:对每个 entity 调 recordChange,recordChange 自身会
    // 判断"同 entitySyncId + action 是否已经存在",不会造成重复(依赖
    // ChangeTracker 的 upsert 语义,若没有就是直接 insert,重复的会被 unique
    // 约束拦住 —— 重复 insert catch 住 = 无害重复)。
    int backfilled = 0;

    // Tags
    final tags = await db.select(db.tags).get();
    for (final tag in tags) {
      if (tag.syncId == null || tag.syncId!.isEmpty) continue;
      if (allPushedIds.contains(tag.syncId)) continue;
      try {
        await changeTracker.recordChange(
          entityType: 'tag',
          entityId: tag.id,
          entitySyncId: tag.syncId!,
          ledgerId: 0,
          action: 'create',
        );
        backfilled++;
      } catch (e) {
        // 已存在的 change 会撞唯一约束,忽略即可。
        logger.debug('SyncEngine', 'backfill tag ${tag.syncId} skip: $e');
      }
    }

    // Accounts
    final accounts = await db.select(db.accounts).get();
    for (final acc in accounts) {
      if (acc.syncId == null || acc.syncId!.isEmpty) continue;
      if (allPushedIds.contains(acc.syncId)) continue;
      try {
        await changeTracker.recordChange(
          entityType: 'account',
          entityId: acc.id,
          entitySyncId: acc.syncId!,
          ledgerId: 0,
          action: 'create',
        );
        backfilled++;
      } catch (e) {
        logger.debug('SyncEngine', 'backfill account ${acc.syncId} skip: $e');
      }
    }

    // Categories
    final categories = await db.select(db.categories).get();
    for (final cat in categories) {
      if (cat.syncId == null || cat.syncId!.isEmpty) continue;
      if (allPushedIds.contains(cat.syncId)) continue;
      try {
        await changeTracker.recordChange(
          entityType: 'category',
          entityId: cat.id,
          entitySyncId: cat.syncId!,
          ledgerId: 0,
          action: 'create',
        );
        backfilled++;
      } catch (e) {
        logger.debug('SyncEngine', 'backfill category ${cat.syncId} skip: $e');
      }
    }

    logger.info('SyncEngine',
        'backfillUntrackedEntities: 共补写 $backfilled 条 sync_change');
    return backfilled;
  }

  /// 应用单条远程变更到本地数据库
  /// 返回 true 表示已应用，false 表示跳过
  Future<bool> _applyRemoteChange(BeeCountCloudSyncChange change) async {
    // 跳过本设备自己的变更
    final deviceId = await _getDeviceId();
    if (change.updatedByDeviceId == deviceId) return false;

    // 如果没有 payload 且不是删除操作，跳过（无法应用）
    if (change.payload == null && change.action != 'delete') {
      logger.debug('SyncEngine',
          'pull: 跳过无 payload 的变更 ${change.entityType}/${change.entitySyncId}');
      return false;
    }

    switch (change.entityType) {
      case 'transaction':
        await _applyTransactionChange(change);
        return true;
      case 'account':
        await _applyAccountChange(change);
        return true;
      case 'category':
        await _applyCategoryChange(change);
        return true;
      case 'tag':
        await _applyTagChange(change);
        return true;
      case 'budget':
        await _applyBudgetChange(change);
        return true;
      case 'ledger':
        await _applyLedgerChange(change);
        return true;
      case 'ledger_snapshot':
        // 全量快照在 fullPull 中处理，这里跳过
        return false;
      default:
        logger.warning(
            'SyncEngine', '未知 entityType: ${change.entityType}');
        return false;
    }
  }

  // ==================== Apply 方法 ====================

  Future<void> _applyTransactionChange(
      BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;

    if (change.action == 'delete') {
      final existing = await (db.select(db.transactions)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      if (existing != null) {
        // 先清磁盘附件(原图 + 缩略图),再删 transaction_attachments 行 ——
        // 反过来就查不到 fileName 了。历史 bug:这段只做 db.delete 不清磁盘,
        // 设备 A 删交易时设备 B sync pull 下来只删表,attachments/*.jpg 永远
        // 残留。跟主动删交易路径(LocalTransactionRepository.deleteTransaction)
        // 对齐。
        await _cleanupTxAttachmentFilesOnDisk(existing.id);
        await (db.delete(db.transactionTags)
              ..where((tt) => tt.transactionId.equals(existing.id)))
            .go();
        await (db.delete(db.transactionAttachments)
              ..where((ta) => ta.transactionId.equals(existing.id)))
            .go();
        await (db.delete(db.transactions)
              ..where((t) => t.id.equals(existing.id)))
            .go();
        logger.debug('SyncEngine', 'pull: 删除交易 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    // change.ledgerId 是 server 的 external_id（string）。本地 B 设备 auto-
    // increment int id 跟 server 不一致，必须按 syncId 查本地 int id。
    // 只有没命中时才 fallback 到直接 parse（向后兼容老数据 ledger_id 就是
    // int 字符串的场景）。
    final ledgerIdInt =
        await _resolveLedgerIdBySyncId(change.ledgerId) ??
            int.tryParse(change.ledgerId) ??
            -1;

    // 解析 payload 字段
    final type = payload['type'] as String? ?? 'expense';
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    final happenedAtStr = payload['happenedAt'] as String?;
    final happenedAt = happenedAtStr != null
        ? DateTime.tryParse(happenedAtStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();
    final note = payload['note'] as String?;
    final categoryName = payload['categoryName'] as String?;
    final categoryKind = payload['categoryKind'] as String?;
    final accountName = payload['accountName'] as String?;
    final toAccountName = payload['toAccountName'] as String?;

    // 解析关联实体 ID —— 优先用 syncId 映射（跨设备稳定），fallback 到名字。
    // payload 里的 categoryId / accountId / toAccountId 是 server snapshot.items[i]
    // 存的远端实体 syncId，B 设备 pull 后 category/account 已经上 syncId 了
    // （P1 的 fallback 给 seed 补的，或 pull 新插入带的），按 syncId 查一定命中。
    // 名字 fallback 兜住旧 snapshot payload 没 syncId 的老数据。
    final rawCategoryId = payload['categoryId'] as String?;
    final categoryId =
        await _resolveCategoryIdBySyncId(rawCategoryId) ??
            await _resolveCategoryId(
              categoryName: categoryName,
              categoryKind: categoryKind,
            );
    final rawAccountId = payload['accountId'] as String?;
    final accountId =
        await _resolveAccountIdBySyncId(rawAccountId) ??
            await _resolveAccountId(
              accountName: accountName,
              ledgerId: ledgerIdInt,
            );
    final rawToAccountId = payload['toAccountId'] as String?;
    final toAccountId =
        await _resolveAccountIdBySyncId(rawToAccountId) ??
            await _resolveAccountId(
              accountName: toAccountName,
              ledgerId: ledgerIdInt,
            );

    final existing = await (db.select(db.transactions)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();

    if (existing != null) {
      // 更新
      await (db.update(db.transactions)
            ..where((t) => t.id.equals(existing.id)))
          .write(TransactionsCompanion(
        type: d.Value(type),
        amount: d.Value(amount),
        happenedAt: d.Value(happenedAt),
        note: d.Value(note),
        categoryId: d.Value(categoryId),
        accountId: d.Value(accountId),
        toAccountId: d.Value(toAccountId),
      ));
      // 更新标签和附件
      await _syncTransactionTags(existing.id, payload);
      await _syncTransactionAttachments(existing.id, payload);
      logger.debug('SyncEngine', 'pull: 更新交易 $syncId');
    } else {
      // 插入
      final id = await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              ledgerId: ledgerIdInt,
              type: type,
              amount: amount,
              happenedAt: d.Value(happenedAt),
              note: d.Value(note),
              categoryId: d.Value(categoryId),
              accountId: d.Value(accountId),
              toAccountId: d.Value(toAccountId),
              syncId: d.Value(syncId),
            ),
          );
      // 同步标签和附件
      await _syncTransactionTags(id, payload);
      await _syncTransactionAttachments(id, payload);
      logger.debug('SyncEngine', 'pull: 新增交易 $syncId');
    }
  }

  Future<void> _applyAccountChange(BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;
    // ledger_id 也按 syncId 映射到本地 int。account 表 ledgerId 是 legacy
    // 字段，但 insert 时仍需填个有效值；映射失败再 fallback 到旧格式。
    final ledgerIdInt =
        await _resolveLedgerIdBySyncId(change.ledgerId) ??
            int.tryParse(change.ledgerId) ??
            -1;

    if (change.action == 'delete') {
      final existing = await (db.select(db.accounts)
            ..where((a) => a.syncId.equals(syncId)))
          .getSingleOrNull();
      if (existing != null) {
        await (db.delete(db.accounts)
              ..where((a) => a.id.equals(existing.id)))
            .go();
        logger.debug('SyncEngine', 'pull: 删除账户 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    final name = payload['name'] as String? ?? '';
    final type = payload['type'] as String? ?? 'cash';
    final currency = payload['currency'] as String? ?? 'CNY';
    final initialBalance =
        (payload['initialBalance'] as num?)?.toDouble() ?? 0.0;
    final sortOrder = (payload['sortOrder'] as num?)?.toInt() ?? 0;

    var existing = await (db.select(db.accounts)
          ..where((a) => a.syncId.equals(syncId)))
        .getSingleOrNull();

    // Fallback：syncId 查不到 → 本地可能是 seed 默认账户（syncId 为 NULL），
    // 按 name 匹配一条 NULL syncId 的行，把 syncId 补上，后面走 update 分支。
    // 这样 device B 首次 pull 远端账户不会再插第二份同名 seed。
    if (existing == null && name.isNotEmpty) {
      final seeded = await (db.select(db.accounts)
            ..where((a) => a.name.equals(name))
            ..where((a) => a.syncId.isNull()))
          .getSingleOrNull();
      if (seeded != null) {
        await (db.update(db.accounts)..where((a) => a.id.equals(seeded.id)))
            .write(AccountsCompanion(syncId: d.Value(syncId)));
        existing = seeded;
        logger.info('SyncEngine',
            'pull: 收编本地 seed 账户 name="$name" → syncId=$syncId');
      }
    }

    if (existing != null) {
      final localId = existing.id;
      await (db.update(db.accounts)
            ..where((a) => a.id.equals(localId)))
          .write(AccountsCompanion(
        name: d.Value(name),
        type: d.Value(type),
        currency: d.Value(currency),
        initialBalance: d.Value(initialBalance),
        sortOrder: d.Value(sortOrder),
        creditLimit: d.Value((payload['creditLimit'] as num?)?.toDouble()),
        billingDay: d.Value((payload['billingDay'] as num?)?.toInt()),
        paymentDueDay:
            d.Value((payload['paymentDueDay'] as num?)?.toInt()),
        bankName: d.Value(payload['bankName'] as String?),
        cardLastFour: d.Value(payload['cardLastFour'] as String?),
        note: d.Value(payload['note'] as String?),
      ));
      logger.debug('SyncEngine', 'pull: 更新账户 $syncId');
    } else {
      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              ledgerId: ledgerIdInt,
              name: name,
              type: d.Value(type),
              currency: d.Value(currency),
              initialBalance: d.Value(initialBalance),
              sortOrder: d.Value(sortOrder),
              creditLimit:
                  d.Value((payload['creditLimit'] as num?)?.toDouble()),
              billingDay:
                  d.Value((payload['billingDay'] as num?)?.toInt()),
              paymentDueDay:
                  d.Value((payload['paymentDueDay'] as num?)?.toInt()),
              bankName: d.Value(payload['bankName'] as String?),
              cardLastFour:
                  d.Value(payload['cardLastFour'] as String?),
              note: d.Value(payload['note'] as String?),
              syncId: d.Value(syncId),
            ),
          );
      logger.debug('SyncEngine', 'pull: 新增账户 $syncId');
    }
  }

  Future<void> _applyCategoryChange(
      BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;

    if (change.action == 'delete') {
      final existing = await (db.select(db.categories)
            ..where((c) => c.syncId.equals(syncId)))
          .getSingleOrNull();
      if (existing != null) {
        // 先收集自身 + 子分类的 customIconPath 清磁盘。跟 LocalCategoryRepository
        // .deleteCategory 路径对齐,防止 sync pull 下来的分类删除留下孤立图标。
        await _cleanupCategoryIconFilesOnDisk([existing.id]);
        // 先删子分类再删自身(跟 LocalCategoryRepository 一致)
        await (db.delete(db.categories)
              ..where((c) => c.parentId.equals(existing.id)))
            .go();
        await (db.delete(db.categories)
              ..where((c) => c.id.equals(existing.id)))
            .go();
        logger.debug('SyncEngine', 'pull: 删除分类 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    final name = payload['name'] as String? ?? '';
    final kind = payload['kind'] as String? ?? 'expense';
    final level = (payload['level'] as num?)?.toInt() ?? 1;
    final sortOrder = (payload['sortOrder'] as num?)?.toInt() ?? 0;
    final icon = payload['icon'] as String?;
    final iconType = payload['iconType'] as String? ?? 'material';
    final parentName = payload['parentName'] as String?;

    // 解析 parentId
    int? parentId;
    if (parentName != null && parentName.isNotEmpty) {
      final parent = await (db.select(db.categories)
            ..where((c) => c.name.equals(parentName))
            ..where((c) => c.kind.equals(kind))
            ..where((c) => c.level.equals(1)))
          .getSingleOrNull();
      parentId = parent?.id;
    }

    var existing = await (db.select(db.categories)
          ..where((c) => c.syncId.equals(syncId)))
        .getSingleOrNull();

    // Fallback：syncId 查不到 → 本地可能是 seed 默认分类（syncId 为 NULL）。
    // 按 name + kind 匹配 NULL syncId 行，把 syncId 补上。避免 device B 首次
    // pull 远端分类插第二份同名 seed。
    if (existing == null && name.isNotEmpty) {
      final seeded = await (db.select(db.categories)
            ..where((c) => c.name.equals(name))
            ..where((c) => c.kind.equals(kind))
            ..where((c) => c.syncId.isNull()))
          .getSingleOrNull();
      if (seeded != null) {
        await (db.update(db.categories)..where((c) => c.id.equals(seeded.id)))
            .write(CategoriesCompanion(syncId: d.Value(syncId)));
        existing = seeded;
        logger.info('SyncEngine',
            'pull: 收编本地 seed 分类 name="$name" kind=$kind → syncId=$syncId');
      }
    }

    // P3 —— 自定义图标二进制下载。payload.iconCloudFileId 非空说明是 custom
    // 图标，server snapshot 里存着 attachment 引用。本地如果没这张图就下载，
    // 有就 skip（checked by customIconPath 文件是否存在）。Drift Category
    // 表不单独存 cloudFileId/sha256，A push 时是动态上传的，B 这里只需要最终
    // 的 customIconPath 指到本地文件即可。
    String? resolvedCustomIconPath = payload['customIconPath'] as String?;
    final cloudFileId = payload['iconCloudFileId'] as String?;
    if (iconType == 'custom' &&
        cloudFileId != null &&
        cloudFileId.isNotEmpty) {
      // 如果本地已有图片文件，且 path 看起来指向已下载的 fileId（相同 basename），
      // 就 skip 下载。否则重新下。
      bool needsDownload = true;
      if (existing != null && (existing.customIconPath ?? '').isNotEmpty) {
        try {
          final abs = await CustomIconService().resolveIconPath(
              existing.customIconPath!);
          if (await File(abs).exists() &&
              existing.customIconPath!.contains(cloudFileId)) {
            needsDownload = false;
            resolvedCustomIconPath = existing.customIconPath;
          }
        } catch (_) {}
      }
      if (needsDownload) {
        try {
          final bytes = await provider.downloadAttachment(fileId: cloudFileId);
          // 写到 `custom_icons/<fileId>`。相对路径保持和 saveCustomIcon 一致
          // 的格式（`custom_icons/<fname>`），resolveIconPath 拼绝对路径。
          final iconDir = await CustomIconService().getIconDirectory();
          final safeName = cloudFileId.replaceAll('/', '_');
          final absPath = '${iconDir.path}/$safeName';
          await File(absPath).writeAsBytes(bytes);
          resolvedCustomIconPath = 'custom_icons/$safeName';
          logger.info('SyncEngine',
              'pull: custom icon downloaded fileId=$cloudFileId size=${bytes.length}B');
        } catch (e, st) {
          logger.warning('SyncEngine',
              'pull: custom icon download failed fileId=$cloudFileId: $e', st);
        }
      }
    }

    if (existing != null) {
      final localId = existing.id;
      await (db.update(db.categories)
            ..where((c) => c.id.equals(localId)))
          .write(CategoriesCompanion(
        name: d.Value(name),
        kind: d.Value(kind),
        level: d.Value(level),
        sortOrder: d.Value(sortOrder),
        icon: d.Value(icon),
        iconType: d.Value(iconType),
        customIconPath: d.Value(resolvedCustomIconPath),
        communityIconId:
            d.Value(payload['communityIconId'] as String?),
        parentId: d.Value(parentId),
      ));
      logger.debug('SyncEngine', 'pull: 更新分类 $syncId');
    } else {
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: name,
              kind: kind,
              level: d.Value(level),
              sortOrder: d.Value(sortOrder),
              icon: d.Value(icon),
              iconType: d.Value(iconType),
              customIconPath: d.Value(resolvedCustomIconPath),
              communityIconId:
                  d.Value(payload['communityIconId'] as String?),
              parentId: d.Value(parentId),
              syncId: d.Value(syncId),
            ),
          );
      logger.debug('SyncEngine', 'pull: 新增分类 $syncId');
    }
  }

  Future<void> _applyTagChange(BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;

    if (change.action == 'delete') {
      final existing = await (db.select(db.tags)
            ..where((t) => t.syncId.equals(syncId)))
          .getSingleOrNull();
      if (existing != null) {
        // 删除关联的 transactionTags
        await (db.delete(db.transactionTags)
              ..where((tt) => tt.tagId.equals(existing.id)))
            .go();
        await (db.delete(db.tags)..where((t) => t.id.equals(existing.id)))
            .go();
        logger.debug('SyncEngine', 'pull: 删除标签 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    final name = payload['name'] as String? ?? '';
    final color = payload['color'] as String?;
    final sortOrder = (payload['sortOrder'] as num?)?.toInt() ?? 0;

    var existing = await (db.select(db.tags)
          ..where((t) => t.syncId.equals(syncId)))
        .getSingleOrNull();

    // Fallback：syncId 查不到 → 按 name 匹配 NULL syncId 的 seed 行。
    if (existing == null && name.isNotEmpty) {
      final seeded = await (db.select(db.tags)
            ..where((t) => t.name.equals(name))
            ..where((t) => t.syncId.isNull()))
          .getSingleOrNull();
      if (seeded != null) {
        await (db.update(db.tags)..where((t) => t.id.equals(seeded.id)))
            .write(TagsCompanion(syncId: d.Value(syncId)));
        existing = seeded;
        logger.info('SyncEngine',
            'pull: 收编本地 seed 标签 name="$name" → syncId=$syncId');
      }
    }

    if (existing != null) {
      final localId = existing.id;
      await (db.update(db.tags)..where((t) => t.id.equals(localId)))
          .write(TagsCompanion(
        name: d.Value(name),
        color: d.Value(color),
        sortOrder: d.Value(sortOrder),
      ));
      logger.debug('SyncEngine', 'pull: 更新标签 $syncId');
    } else {
      await db.into(db.tags).insert(
            TagsCompanion.insert(
              name: name,
              color: d.Value(color),
              sortOrder: d.Value(sortOrder),
              syncId: d.Value(syncId),
            ),
          );
      logger.debug('SyncEngine', 'pull: 新增标签 $syncId');
    }
  }

  /// 应用预算变更。对齐 account/tag:按 syncId upsert,delete 走同样的路径。
  /// ledger/category 的外键在 payload 里以 syncId 形式带来,用
  /// _resolveLedgerIdBySyncId / _resolveCategoryIdBySyncId 换成本地 int id。
  Future<void> _applyBudgetChange(BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;

    if (change.action == 'delete') {
      final existing = await (db.select(db.budgets)
            ..where((b) => b.syncId.equals(syncId)))
          .getSingleOrNull();
      if (existing != null) {
        await (db.delete(db.budgets)..where((b) => b.id.equals(existing.id)))
            .go();
        logger.debug('SyncEngine', 'pull: 删除预算 $syncId');
      }
      return;
    }

    // upsert
    final payload = change.payload!;
    final ledgerSyncId = payload['ledgerSyncId'] as String?;
    final categorySyncId = payload['categoryId'] as String?;
    final type = payload['type'] as String? ?? 'total';
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    final period = payload['period'] as String? ?? 'monthly';
    final startDay = (payload['startDay'] as num?)?.toInt() ?? 1;
    final enabled = payload['enabled'] as bool? ?? true;

    // 先解析外键 —— 本地 ledger 找不到就 skip,等 ledger change 先到再说。
    final localLedgerId = await _resolveLedgerIdBySyncId(ledgerSyncId);
    if (localLedgerId == null) {
      logger.info('SyncEngine',
          'pull: 预算 $syncId 的 ledgerSyncId=$ledgerSyncId 本地未就绪,跳过');
      return;
    }
    final localCategoryId = await _resolveCategoryIdBySyncId(categorySyncId);

    final existing = await (db.select(db.budgets)
          ..where((b) => b.syncId.equals(syncId)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.budgets)..where((b) => b.id.equals(existing.id)))
          .write(BudgetsCompanion(
        ledgerId: d.Value(localLedgerId),
        type: d.Value(type),
        categoryId: d.Value(localCategoryId),
        amount: d.Value(amount),
        period: d.Value(period),
        startDay: d.Value(startDay),
        enabled: d.Value(enabled),
        updatedAt: d.Value(DateTime.now()),
      ));
      logger.debug('SyncEngine', 'pull: 更新预算 $syncId');
    } else {
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
            ledgerId: localLedgerId,
            type: d.Value(type),
            categoryId: d.Value(localCategoryId),
            amount: amount,
            period: d.Value(period),
            startDay: d.Value(startDay),
            enabled: d.Value(enabled),
            syncId: d.Value(syncId),
          ));
      logger.debug('SyncEngine', 'pull: 新增预算 $syncId');
    }
  }

  /// 应用远程下发的账本元数据变更(名字 / 币种)。
  ///
  /// 跟其他 entity 不同:不在本地"新建"账本 —— 账本的创建走 fullPush /
  /// ledger_snapshot 路径。这里只负责"已存在的账本"的 meta 更新。找不到
  /// 对应的本地账本就跳过,等快照路径把它 seed 出来后再复用。
  Future<void> _applyLedgerChange(BeeCountCloudSyncChange change) async {
    final syncId = change.entitySyncId;
    if (change.action == 'delete') {
      // 账本删除走 'ledger_snapshot' 的 delete change,这里不处理 —— 避免
      // 跟 ledger_snapshot 重复触发。
      return;
    }
    final payload = change.payload;
    if (payload == null) return;

    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.syncId.equals(syncId)))
        .getSingleOrNull();
    if (ledger == null) {
      logger.info('SyncEngine',
          'pull: 账本 $syncId 本地未就绪,跳过 meta 更新(等 snapshot 路径)');
      return;
    }

    final name = payload['ledgerName'] as String?;
    final currency = payload['currency'] as String?;
    final comp = LedgersCompanion(
      name: name != null ? d.Value(name) : const d.Value.absent(),
      currency: currency != null ? d.Value(currency) : const d.Value.absent(),
    );
    await (db.update(db.ledgers)..where((l) => l.id.equals(ledger.id)))
        .write(comp);
    logger.debug(
        'SyncEngine', 'pull: 更新账本 $syncId name=$name currency=$currency');
  }

  // ==================== Helper ====================

  /// 同步交易标签关联
  Future<void> _syncTransactionTags(
      int transactionId, Map<String, dynamic> payload) async {
    // 删除旧关联，按新 payload 重建
    await (db.delete(db.transactionTags)
          ..where((tt) => tt.transactionId.equals(transactionId)))
        .go();

    // 新 payload 的 `tagIds`（list 形式的 syncId）优先走 —— 跨设备稳定；
    // 老 payload 只有 comma-name 的 `tags` 兜底。
    final rawTagIds = payload['tagIds'];
    final tagIds = rawTagIds is List
        ? rawTagIds.whereType<String>().toList(growable: false)
        : const <String>[];
    final tagsStr = payload['tags'] as String?;
    final tagNamesFromStr = (tagsStr == null || tagsStr.isEmpty)
        ? const <String>[]
        : tagsStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    // 如果有 syncId 列表：逐个 syncId 查本地 tag，查不到的 syncId 再去 names
    // 里找同索引的 name 做 fallback（因为 tagIds / tags 在 push 时是按相同顺序存的）。
    final linkedLocalIds = <int>{};
    if (tagIds.isNotEmpty) {
      for (var i = 0; i < tagIds.length; i++) {
        final syncId = tagIds[i];
        var tag = await (db.select(db.tags)
              ..where((t) => t.syncId.equals(syncId)))
            .getSingleOrNull();
        if (tag == null && i < tagNamesFromStr.length) {
          final name = tagNamesFromStr[i];
          tag = await (db.select(db.tags)
                ..where((t) => t.name.equals(name)))
              .getSingleOrNull();
          // 把 syncId 补给本地同名 tag（可能是 seed 版），避免下次还要 fallback。
          if (tag != null && (tag.syncId ?? '').isEmpty) {
            await (db.update(db.tags)..where((t) => t.id.equals(tag!.id)))
                .write(TagsCompanion(syncId: d.Value(syncId)));
          }
        }
        if (tag != null) linkedLocalIds.add(tag.id);
      }
    } else {
      // 完全没 tagIds 的老 payload：按 name 查，没有就建个带 syncId 的新 tag。
      for (final name in tagNamesFromStr) {
        var tag = await (db.select(db.tags)
              ..where((t) => t.name.equals(name)))
            .getSingleOrNull();
        if (tag == null) {
          final id = await db.into(db.tags).insert(
                TagsCompanion.insert(
                  name: name,
                  syncId: d.Value(_uuid.v4()),
                ),
              );
          tag = await (db.select(db.tags)
                ..where((t) => t.id.equals(id)))
              .getSingle();
        }
        linkedLocalIds.add(tag.id);
      }
    }

    for (final tagId in linkedLocalIds) {
      await db.into(db.transactionTags).insert(
            TransactionTagsCompanion.insert(
              transactionId: transactionId,
              tagId: tagId,
            ),
          );
    }
  }

  /// 同步交易附件关联（pull 时从 payload 创建/更新/删除本地附件记录）
  ///
  /// payload 里 attachments 的三种情况：
  ///   - 缺失（key 不存在）：legacy 调用 / 没附件信息 → 不动本地
  ///   - `[]`（空数组）：A 端把附件全删光了 → 本地同步删光
  ///   - `[...]`：权威列表 → 本地按 fileName 对齐，多余的删，缺的加
  Future<void> _syncTransactionAttachments(
      int transactionId, Map<String, dynamic> payload) async {
    // key 缺失 → legacy 行为，不碰本地
    if (!payload.containsKey('attachments')) return;
    final attachmentsList =
        (payload['attachments'] as List<dynamic>?) ?? const <dynamic>[];

    // 获取现有附件，按 fileName 索引
    final existing = await (db.select(db.transactionAttachments)
          ..where((a) => a.transactionId.equals(transactionId)))
        .get();
    final existingByFileName = {for (final a in existing) a.fileName: a};

    // 远端权威列表里的 fileName 集合
    final remoteFileNames = <String>{};

    for (final att in attachmentsList) {
      final attMap = att as Map<String, dynamic>;
      final fileName = attMap['fileName'] as String? ?? '';
      if (fileName.isEmpty) continue;
      remoteFileNames.add(fileName);

      final cloudFileId = attMap['cloudFileId'] as String?;
      final cloudSha256 = attMap['cloudSha256'] as String?;

      if (existingByFileName.containsKey(fileName)) {
        // 已存在 → 更新 cloudFileId/cloudSha256（如果远端有新值）
        final ex = existingByFileName[fileName]!;
        if (cloudFileId != null && ex.cloudFileId != cloudFileId) {
          await (db.update(db.transactionAttachments)
                ..where((a) => a.id.equals(ex.id)))
              .write(TransactionAttachmentsCompanion(
            cloudFileId: d.Value(cloudFileId),
            cloudSha256: d.Value(cloudSha256),
          ));
        }
      } else {
        // 不存在 → 创建附件记录
        await db.into(db.transactionAttachments).insert(
              TransactionAttachmentsCompanion.insert(
                transactionId: transactionId,
                fileName: fileName,
                originalName: d.Value(attMap['originalName'] as String?),
                fileSize: d.Value(attMap['fileSize'] as int?),
                width: d.Value(attMap['width'] as int?),
                height: d.Value(attMap['height'] as int?),
                sortOrder: d.Value(attMap['sortOrder'] as int? ?? 0),
                cloudFileId: d.Value(cloudFileId),
                cloudSha256: d.Value(cloudSha256),
              ),
            );
      }
    }

    // 本地有但远端没有的附件 → 对端已删，本地也删。同时清掉落地文件，
    // 避免孤立图片占空间。
    for (final ex in existing) {
      if (remoteFileNames.contains(ex.fileName)) continue;
      await (db.delete(db.transactionAttachments)
            ..where((a) => a.id.equals(ex.id)))
          .go();
      try {
        final file = await _getAttachmentFile(ex.fileName);
        if (file != null && file.existsSync()) {
          await file.delete();
        }
      } catch (e, st) {
        logger.warning(
            'SyncEngine', '删除本地孤立附件文件失败: ${ex.fileName}', st);
      }
    }
  }

  /// 按 syncId 查 ledger 的本地 int id。用于 apply remote change 时把
  /// server 的 external_id（string）映射成本地 autoIncrement id。
  Future<int?> _resolveLedgerIdBySyncId(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final led = await (db.select(db.ledgers)
          ..where((l) => l.syncId.equals(syncId)))
        .getSingleOrNull();
    return led?.id;
  }

  /// 按 syncId 查 category 的本地 int id。优先级比 name+kind 高：设备间
  /// category.syncId 是稳定的，name 可能被改过 / 有重名。
  Future<int?> _resolveCategoryIdBySyncId(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final cat = await (db.select(db.categories)
          ..where((c) => c.syncId.equals(syncId)))
        .getSingleOrNull();
    return cat?.id;
  }

  /// 按 syncId 查 account 的本地 int id。同理，跨设备稳定。
  Future<int?> _resolveAccountIdBySyncId(String? syncId) async {
    if (syncId == null || syncId.isEmpty) return null;
    final acc = await (db.select(db.accounts)
          ..where((a) => a.syncId.equals(syncId)))
        .getSingleOrNull();
    return acc?.id;
  }

  /// 根据分类名和类型查找 categoryId
  Future<int?> _resolveCategoryId({
    String? categoryName,
    String? categoryKind,
  }) async {
    if (categoryName == null || categoryName.isEmpty) return null;
    final query = db.select(db.categories)
      ..where((c) => c.name.equals(categoryName));
    if (categoryKind != null) {
      query.where((c) => c.kind.equals(categoryKind));
    }
    final cat = await query.getSingleOrNull();
    return cat?.id;
  }

  /// 根据账户名查找 accountId
  ///
  /// 账户是 user-scoped（跟 category/tag 一样）—— 同一用户的所有账本共享一份
  /// 账户表。Accounts 表仍带着 ledgerId 字段只是历史遗留（schema 注释里写着
  /// "保留用于v2迁移，后续会移除"），不应该参与解析。
  ///
  /// 之前按 (name + ledgerId) 查会有两个问题：
  ///   1. 同一个账户在别的账本上（因为旧数据沿 ledger 分裂），本账本查不到 → null
  ///      → web 改的 tx 账户在 mobile 上显示空。
  ///   2. 多次同步后 accounts 表里可能出现重名（因为 ledgerId 不同被当成不同
  ///      实体），按 name 全局查会 throw；这里用 take(1) 保守一点。
  Future<int?> _resolveAccountId({
    String? accountName,
    required int ledgerId, // 参数保留兼容上游调用
  }) async {
    if (accountName == null || accountName.isEmpty) return null;
    final rows = await (db.select(db.accounts)
          ..where((a) => a.name.equals(accountName))
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first.id;
  }

  Future<String> _getDeviceId() async {
    final user = await provider.auth.currentUser;
    return user?.metadata?['deviceId'] as String? ?? 'unknown';
  }

  // ==================== 全量推送/拉取 ====================

  /// 首次全量推送（将本地所有数据推送到服务端）
  Future<void> fullPush({required int ledgerId}) async {
    logger.info('SyncEngine', '开始全量推送 ledger=$ledgerId');

    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingle();

    // 1. 先上传 JSON 快照：这一步在服务端 auto-create ledger 行。
    //    必须先做，否则后续 /attachments/upload 会拿不到 ledger 抛 "Ledger not found"。
    //
    //    path 用 ledger.syncId，跟 _push/_pushAllEntities 的 ledger_id 一致，
    //    避免 server 出现两条 external_id 指向同一账本的分裂。
    final pathForSnapshot = ledger.syncId ?? ledger.id.toString();
    try {
      final jsonData = await _exportLedgerJson(ledger);
      await provider.storage.upload(
        path: pathForSnapshot,
        data: jsonData,
        metadata: {
          'ledger_name': ledger.name,
          'currency': ledger.currency,
          'type': 'full_push',
        },
      );
      logger.info('SyncEngine', 'JSON 快照上传成功');
    } catch (e, st) {
      logger.error('SyncEngine', 'JSON 快照上传失败（继续推送个体变更）', e, st);
    }

    // 2. ledger 已就绪，这时再上传附件文件、回填 cloudFileId 到本地 DB。
    //    _pushAllEntities 会把 cloudFileId 写进 transaction payload。
    try {
      await uploadAttachments(ledgerId: ledgerId);
    } catch (e, st) {
      logger.error('SyncEngine', '附件上传失败（不阻塞推送）', e, st);
    }

    // 3. 推送所有实体的个体变更（用于 Web 端和增量同步）
    await _pushAllEntities(ledger);

    // 标记所有已有变更为已推送
    final unpushed =
        await changeTracker.getUnpushedChangesForLedger(ledgerId);
    if (unpushed.isNotEmpty) {
      await changeTracker.markPushed(unpushed.map((c) => c.id).toList());
    }

    logger.info('SyncEngine', '全量推送完成 ledger=${ledger.name}');
  }

  /// 清掉某账本下所有附件的 cloudFileId / cloudSha256。
  /// 用于"远端账本被重建/清空"的场景：本地以为文件在云上，实际已失效，
  /// 重置后下次 uploadAttachments 会把它们当新的重新上传。
  Future<void> _resetAttachmentCloudRefs(int ledgerId) async {
    final txs = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();
    if (txs.isEmpty) return;
    final txIds = txs.map((t) => t.id).toList();
    final count = await (db.update(db.transactionAttachments)
          ..where((a) => a.transactionId.isIn(txIds)))
        .write(const TransactionAttachmentsCompanion(
      cloudFileId: d.Value(null),
      cloudSha256: d.Value(null),
    ));
    if (count > 0) {
      logger.info('SyncEngine', '已重置 $count 条附件的云端引用');
    }
  }

  /// 上传所有分类的自定义图标到云端，返回 categoryId → 云端引用 的映射。
  /// 分类的 customIconPath 是本地文件路径，单独上传后 serializeCategory 会把
  /// cloud 引用写进 payload 让 web 端能拉到。
  /// 服务端按 sha256 去重，所以重复 fullPush 不会物理重传。
  Future<Map<int, ({String fileId, String sha256})>>
      _uploadCategoryIcons(String ledgerIdStr) async {
    final categories = await db.select(db.categories).get();
    final out = <int, ({String fileId, String sha256})>{};
    final iconSvc = CustomIconService();
    for (final cat in categories) {
      if (cat.iconType != 'custom') continue;
      final rel = cat.customIconPath;
      if (rel == null || rel.isEmpty) continue;
      try {
        final abs = await iconSvc.resolveIconPath(rel);
        final file = File(abs);
        if (!file.existsSync()) {
          logger.debug('SyncEngine',
              '分类 ${cat.name} 的自定义图标文件不存在: $abs');
          continue;
        }
        final bytes = await file.readAsBytes();
        final result = await provider.uploadAttachment(
          ledgerId: ledgerIdStr,
          bytes: bytes,
          fileName: rel.split('/').last,
        );
        out[cat.id] = (fileId: result.fileId, sha256: result.sha256);
      } catch (e, st) {
        logger.error(
            'SyncEngine', '分类 ${cat.name} 自定义图标上传失败', e, st);
      }
    }
    if (out.isNotEmpty) {
      logger.info('SyncEngine', '分类自定义图标上传完成: ${out.length} 个');
    }
    return out;
  }

  /// 推送所有实体为个体变更（fullPush 时调用）
  Future<void> _pushAllEntities(Ledger ledger) async {
    // 跟增量 _push 保持一致：用 ledger.syncId 作为 server 认的 external_id，
    // 跨设备时同一账本永远同一个 external_id，不会分裂成多条。
    final ledgerId = ledger.syncId ?? ledger.id.toString();
    final now = DateTime.now().toUtc().toIso8601String();
    final syncChanges = <Map<String, dynamic>>[];

    // 先上传分类自定义图标，拿到每个分类对应的 cloudFileId/sha256。
    final categoryIconCloudRefs = await _uploadCategoryIcons(ledgerId);

    // 账户：虽然 Accounts 表有 ledgerId（历史遗留），账户在 UI 层是跨账本可选的，
    // 所以按全局推送，避免跨账本共享账户在只属于某一账本的 fullPush 中漏推。
    // server 端按 syncId 幂等，不会重复。
    final accounts = await db.select(db.accounts).get();
    for (final account in accounts) {
      final syncId = account.syncId ?? _uuid.v4();
      // 确保 syncId 已持久化
      if (account.syncId == null) {
        await (db.update(db.accounts)
              ..where((a) => a.id.equals(account.id)))
            .write(AccountsCompanion(syncId: d.Value(syncId)));
      }
      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'account',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': EntitySerializer.serializeAccount(account),
        'updated_at': now,
      });
    }

    // 分类
    final categories = await db.select(db.categories).get();
    for (final category in categories) {
      final syncId = category.syncId ?? _uuid.v4();
      if (category.syncId == null) {
        await (db.update(db.categories)
              ..where((c) => c.id.equals(category.id)))
            .write(CategoriesCompanion(syncId: d.Value(syncId)));
      }
      String? parentName;
      if (category.parentId != null) {
        parentName = categories
            .cast<Category?>()
            .firstWhere((p) => p?.id == category.parentId, orElse: () => null)
            ?.name;
      }
      final iconRef = categoryIconCloudRefs[category.id];
      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'category',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': EntitySerializer.serializeCategory(
          category,
          parentName: parentName,
          iconCloudFileId: iconRef?.fileId,
          iconCloudSha256: iconRef?.sha256,
        ),
        'updated_at': now,
      });
    }

    // 标签
    final tags = await db.select(db.tags).get();
    for (final tag in tags) {
      final syncId = tag.syncId ?? _uuid.v4();
      if (tag.syncId == null) {
        await (db.update(db.tags)
              ..where((t) => t.id.equals(tag.id)))
            .write(TagsCompanion(syncId: d.Value(syncId)));
      }
      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'tag',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': EntitySerializer.serializeTag(tag),
        'updated_at': now,
      });
    }

    // 预算:按账本过滤推,不跨账本。分类预算带 categorySyncId。
    final budgets = await (db.select(db.budgets)
          ..where((b) => b.ledgerId.equals(ledger.id)))
        .get();
    for (final budget in budgets) {
      final syncId = budget.syncId ?? _uuid.v4();
      if (budget.syncId == null) {
        await (db.update(db.budgets)
              ..where((b) => b.id.equals(budget.id)))
            .write(BudgetsCompanion(syncId: d.Value(syncId)));
      }
      String? catSyncId;
      if (budget.categoryId != null) {
        final cat = categories
            .cast<Category?>()
            .firstWhere((c) => c?.id == budget.categoryId,
                orElse: () => null);
        catSyncId = cat?.syncId;
      }
      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'budget',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': EntitySerializer.serializeBudget(
          budget,
          ledgerSyncId: ledger.syncId,
          categorySyncId: catSyncId,
        ),
        'updated_at': now,
      });
    }

    // 交易
    final transactions = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledger.id)))
        .get();

    // 预加载所有附件，按 transactionId 分组
    final allAttachments = await (db.select(db.transactionAttachments)
          ..where((a) => a.transactionId
              .isIn(transactions.map((t) => t.id).toList())))
        .get();
    final attachmentsByTx = <int, List<TransactionAttachment>>{};
    for (final a in allAttachments) {
      attachmentsByTx.putIfAbsent(a.transactionId, () => []).add(a);
    }

    for (final tx in transactions) {
      final syncId = tx.syncId ?? _uuid.v4();
      if (tx.syncId == null) {
        await (db.update(db.transactions)
              ..where((t) => t.id.equals(tx.id)))
            .write(TransactionsCompanion(syncId: d.Value(syncId)));
      }

      final cat = tx.categoryId != null
          ? categories
              .cast<Category?>()
              .firstWhere((c) => c?.id == tx.categoryId, orElse: () => null)
          : null;
      final acc = tx.accountId != null
          ? accounts
              .cast<Account?>()
              .firstWhere((a) => a?.id == tx.accountId, orElse: () => null)
          : null;
      final toAcc = tx.toAccountId != null
          ? accounts
              .cast<Account?>()
              .firstWhere((a) => a?.id == tx.toAccountId, orElse: () => null)
          : null;

      final txTags = await (db.select(db.transactionTags)
            ..where((tt) => tt.transactionId.equals(tx.id)))
          .get();
      final tagNames = <String>[];
      final tagSyncIds = <String>[];
      for (final tt in txTags) {
        final tag = tags
            .cast<Tag?>()
            .firstWhere((t) => t?.id == tt.tagId, orElse: () => null);
        if (tag != null) {
          tagNames.add(tag.name);
          if (tag.syncId != null && tag.syncId!.isNotEmpty) {
            tagSyncIds.add(tag.syncId!);
          }
        }
      }

      // 构建附件数据
      final txAtts = attachmentsByTx[tx.id] ?? [];
      final attMaps = txAtts
          .map((a) => <String, dynamic>{
                'fileName': a.fileName,
                'originalName': a.originalName,
                'fileSize': a.fileSize,
                'width': a.width,
                'height': a.height,
                'sortOrder': a.sortOrder,
                if (a.cloudFileId != null) 'cloudFileId': a.cloudFileId,
                if (a.cloudSha256 != null) 'cloudSha256': a.cloudSha256,
              })
          .toList();

      syncChanges.add({
        'ledger_id': ledgerId,
        'entity_type': 'transaction',
        'entity_sync_id': syncId,
        'action': 'upsert',
        'payload': EntitySerializer.serializeTransaction(
          tx,
          categoryName: cat?.name,
          categoryKind: cat?.kind,
          categorySyncId: cat?.syncId,
          accountName: acc?.name,
          accountSyncId: acc?.syncId,
          fromAccountName: tx.type == 'transfer' ? acc?.name : null,
          fromAccountSyncId: tx.type == 'transfer' ? acc?.syncId : null,
          toAccountName: toAcc?.name,
          toAccountSyncId: toAcc?.syncId,
          ledgerSyncId: ledger.syncId,
          tagNames: tagNames.isNotEmpty ? tagNames : null,
          tagSyncIds: tagSyncIds.isNotEmpty ? tagSyncIds : null,
          attachments: attMaps,
        ),
        'updated_at': now,
      });
    }

    // 统计实体数量
    final accountCount = accounts.length;
    final categoryCount = categories.length;
    final tagCount = tags.length;
    final txCount = transactions.length;
    logger.info('SyncEngine',
        '开始推送个体变更 共${syncChanges.length}条 '
        '(accounts=$accountCount, categories=$categoryCount, tags=$tagCount, transactions=$txCount)');

    // 分批推送:每条 change 平均 ~500 字节,500 条 ≈ 250KB,远低于网关限制,
    // 但单次请求内 server 事务处理时间 ~100ms 可接受。
    // 5 倍原先 100 的吞吐,3 万条交易上传从 300 批降到 60 批,耗时约 1/5。
    const batchSize = 500;
    for (var i = 0; i < syncChanges.length; i += batchSize) {
      final end = (i + batchSize > syncChanges.length) ? syncChanges.length : i + batchSize;
      final batch = syncChanges.sublist(i, end);
      try {
        logger.info('SyncEngine', '推送批次 ${i ~/ batchSize + 1}: ${batch.length}条 (${i+1}-$end)');
        await provider.pushChanges(changes: batch);
        logger.info('SyncEngine', '批次 ${i ~/ batchSize + 1} 推送成功');
      } catch (e, st) {
        logger.error('SyncEngine', '批次 ${i ~/ batchSize + 1} 推送失败', e, st);
        rethrow; // 让调用方知道失败
      }
    }

    logger.info('SyncEngine', '全量推送个体变更完成 ${syncChanges.length} 条');
  }

  /// 新设备全量拉取
  Future<({int inserted, int deletedDup})> _fullPull(
      {required int ledgerId}) async {
    logger.info('SyncEngine', '开始全量拉取 ledger=$ledgerId');

    // path 对齐 fullPush 上传时用的 ledger.syncId。
    final ledgerRow = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final path = ledgerRow?.syncId ?? ledgerId.toString();
    final data = await provider.storage.download(path: path);
    if (data == null) {
      logger.warning('SyncEngine', '全量拉取: 服务端无数据');
      return (inserted: 0, deletedDup: 0);
    }

    // 复用 importTransactionsJson
    final result = await importTransactionsJson(repo, ledgerId, data);
    logger.info('SyncEngine', '全量拉取完成: inserted=${result.inserted}');

    // 下载附件
    try {
      await downloadAttachments(ledgerId: ledgerId);
    } catch (e, st) {
      logger.error('SyncEngine', '附件下载失败（不阻塞拉取）', e, st);
    }

    return (inserted: result.inserted, deletedDup: 0);
  }

  Future<String> _exportLedgerJson(Ledger ledger) async {
    final transactions = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledger.id))
          ..orderBy([(t) => d.OrderingTerm.asc(t.happenedAt)]))
        .get();

    final accounts = await (db.select(db.accounts)
          ..where((a) => a.ledgerId.equals(ledger.id)))
        .get();
    final categories = await db.select(db.categories).get();
    final tags = await db.select(db.tags).get();

    final items = <Map<String, dynamic>>[];
    for (final tx in transactions) {
      final cat = tx.categoryId != null
          ? categories
              .cast<Category?>()
              .firstWhere((c) => c?.id == tx.categoryId, orElse: () => null)
          : null;
      final acc = tx.accountId != null
          ? accounts
              .cast<Account?>()
              .firstWhere((a) => a?.id == tx.accountId, orElse: () => null)
          : null;
      final toAcc = tx.toAccountId != null
          ? accounts
              .cast<Account?>()
              .firstWhere((a) => a?.id == tx.toAccountId, orElse: () => null)
          : null;

      final txTags = await (db.select(db.transactionTags)
            ..where((tt) => tt.transactionId.equals(tx.id)))
          .get();
      final tagNames = <String>[];
      final tagSyncIds = <String>[];
      for (final tt in txTags) {
        final tag = tags
            .cast<Tag?>()
            .firstWhere((t) => t?.id == tt.tagId, orElse: () => null);
        if (tag != null) {
          tagNames.add(tag.name);
          if (tag.syncId != null && tag.syncId!.isNotEmpty) {
            tagSyncIds.add(tag.syncId!);
          }
        }
      }

      items.add(EntitySerializer.serializeTransaction(
        tx,
        categoryName: cat?.name,
        categoryKind: cat?.kind,
        categorySyncId: cat?.syncId,
        accountName: acc?.name,
        accountSyncId: acc?.syncId,
        fromAccountName: tx.type == 'transfer' ? acc?.name : null,
        fromAccountSyncId: tx.type == 'transfer' ? acc?.syncId : null,
        toAccountName: toAcc?.name,
        toAccountSyncId: toAcc?.syncId,
        ledgerSyncId: ledger.syncId,
        tagNames: tagNames.isNotEmpty ? tagNames : null,
        tagSyncIds: tagSyncIds.isNotEmpty ? tagSyncIds : null,
      ));
    }

    return jsonEncode({
      'version': 6,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'ledgerId': ledger.id,
      'ledgerName': ledger.name,
      'currency': ledger.currency,
      'count': items.length,
      'accounts':
          accounts.map((a) => EntitySerializer.serializeAccount(a)).toList(),
      'categories': categories.map((c) {
        String? parentName;
        if (c.parentId != null) {
          parentName = categories
              .cast<Category?>()
              .firstWhere((p) => p?.id == c.parentId, orElse: () => null)
              ?.name;
        }
        return EntitySerializer.serializeCategory(c, parentName: parentName);
      }).toList(),
      'tags': tags.map((t) => EntitySerializer.serializeTag(t)).toList(),
      'items': items,
    });
  }

  // ==================== 附件云端同步 ====================

  /// 上传账本中未同步的附件到云端
  Future<int> uploadAttachments({required int ledgerId}) async {
    // 附件 upload 的 ledger_id 必须跟 push / snapshot 对齐用 `ledger.syncId`：
    // B 本地 int id（比如 2）在 server 的 ledgers 表里根本不存在（server 那边
    // external_id 是 A 当初推的 UUID/"5"），直接用会触发 "Ledger not found"。
    final ledgerRow = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    final serverLedgerId = ledgerRow?.syncId ?? ledgerId.toString();

    final txs = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();
    if (txs.isEmpty) return 0;

    final txIds = txs.map((t) => t.id).toList();
    final attachments = await (db.select(db.transactionAttachments)
          ..where((a) => a.transactionId.isIn(txIds)))
        .get();

    int uploaded = 0;
    for (final att in attachments) {
      if (att.cloudFileId != null) continue; // 已上传

      final localFile = await _getAttachmentFile(att.fileName);
      if (localFile == null || !localFile.existsSync()) {
        logger.debug('SyncEngine', '附件本地文件不存在，跳过: ${att.fileName}');
        continue;
      }

      try {
        final bytes = await localFile.readAsBytes();
        final result = await provider.uploadAttachment(
          ledgerId: serverLedgerId,
          bytes: bytes,
          fileName: att.originalName ?? att.fileName,
        );
        // 回填云端引用
        await (db.update(db.transactionAttachments)
              ..where((a) => a.id.equals(att.id)))
            .write(TransactionAttachmentsCompanion(
          cloudFileId: d.Value(result.fileId),
          cloudSha256: d.Value(result.sha256),
        ));
        uploaded++;
        logger.debug('SyncEngine', '附件上传成功: ${att.fileName} -> ${result.fileId}');
      } catch (e, st) {
        logger.error('SyncEngine', '附件上传失败: ${att.fileName}', e, st);
      }
    }

    if (uploaded > 0) {
      logger.info('SyncEngine', '附件上传完成: $uploaded 个');
    }
    return uploaded;
  }

  /// 下载云端附件到本地
  Future<int> downloadAttachments({required int ledgerId}) async {
    final txs = await (db.select(db.transactions)
          ..where((t) => t.ledgerId.equals(ledgerId)))
        .get();
    if (txs.isEmpty) return 0;

    final txIds = txs.map((t) => t.id).toList();
    final attachments = await (db.select(db.transactionAttachments)
          ..where((a) => a.transactionId.isIn(txIds)))
        .get();

    int downloaded = 0;
    for (final att in attachments) {
      if (att.cloudFileId == null) continue; // 没有云端引用

      final localFile = await _getAttachmentFile(att.fileName);
      if (localFile == null) continue;
      if (localFile.existsSync()) continue; // 本地已存在

      try {
        final bytes = await provider.downloadAttachment(
          fileId: att.cloudFileId!,
        );
        // 确保目录存在
        final dir = localFile.parent;
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        await localFile.writeAsBytes(bytes);
        downloaded++;
        logger.debug('SyncEngine', '附件下载成功: ${att.cloudFileId} -> ${att.fileName}');
      } catch (e, st) {
        logger.error('SyncEngine', '附件下载失败: ${att.cloudFileId}', e, st);
      }
    }

    if (downloaded > 0) {
      logger.info('SyncEngine', '附件下载完成: $downloaded 个');
    }
    return downloaded;
  }

  /// 获取附件本地文件路径
  Future<File?> _getAttachmentFile(String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentDir = Directory('${appDir.path}/attachments');
      return File('${attachmentDir.path}/$fileName');
    } catch (e) {
      logger.error('SyncEngine', '获取附件路径失败: $fileName', e);
      return null;
    }
  }

  /// 清理给定交易的本地磁盘附件(原图 + 缩略图)。在 transaction_attachments
  /// 行被 db.delete **之前** 调 —— 之后 fileName 就查不到了。
  ///
  /// 跟 `LocalTransactionRepository._deleteAttachmentsForTransaction` 几乎一样,
  /// 但那个是 private;这里是 sync pull 路径独立使用(不想走完整 repo 接口,
  /// 因为 repo 的 deleteTransaction 会 record changeTracker,会造成 pull →
  /// record → push 的回环)。失败只 warn 不抛,不 block 事件 apply。
  Future<void> _cleanupTxAttachmentFilesOnDisk(int transactionId) async {
    try {
      final attachments = await (db.select(db.transactionAttachments)
            ..where((a) => a.transactionId.equals(transactionId)))
          .get();
      if (attachments.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final attachmentDir = Directory('${appDir.path}/attachments');
      final cacheDir = await getTemporaryDirectory();
      final thumbDir = Directory('${cacheDir.path}/attachment_thumbs');

      for (final att in attachments) {
        final file = File('${attachmentDir.path}/${att.fileName}');
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            logger.warning('SyncEngine',
                'pull delete: unlink attachment failed ${att.fileName}: $e');
          }
        }
        final thumbName =
            '${p.basenameWithoutExtension(att.fileName)}_thumb.jpg';
        final thumbFile = File('${thumbDir.path}/$thumbName');
        if (await thumbFile.exists()) {
          try {
            await thumbFile.delete();
          } catch (_) {/* best effort */}
        }
      }
    } catch (e, st) {
      logger.warning(
          'SyncEngine', 'pull delete: 清理附件磁盘文件异常 tx=$transactionId: $e\n$st');
    }
  }

  /// 清理给定分类(含直接子分类)的本地自定义图标文件。
  /// 跟 LocalCategoryRepository 的 _deleteLocalIconFiles 对齐。删 categories
  /// 行之前调。best-effort。
  Future<void> _cleanupCategoryIconFilesOnDisk(List<int> categoryIds) async {
    if (categoryIds.isEmpty) return;
    try {
      final paths = <String>[];
      final selfRows = await (db.select(db.categories)
            ..where((c) => c.id.isIn(categoryIds)))
          .get();
      for (final r in selfRows) {
        final cp = r.customIconPath;
        if (cp != null && cp.trim().isNotEmpty) paths.add(cp);
      }
      final childRows = await (db.select(db.categories)
            ..where((c) => c.parentId.isIn(categoryIds)))
          .get();
      for (final r in childRows) {
        final cp = r.customIconPath;
        if (cp != null && cp.trim().isNotEmpty) paths.add(cp);
      }
      if (paths.isEmpty) return;

      final appDir = await getApplicationDocumentsDirectory();
      final iconDir = Directory('${appDir.path}/custom_icons');
      for (final rel in paths) {
        final fileName = p.basename(rel);
        final file = File('${iconDir.path}/$fileName');
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            logger.warning(
                'SyncEngine', 'pull delete: unlink custom icon failed $fileName: $e');
          }
        }
      }
    } catch (e, st) {
      logger.warning('SyncEngine', 'pull delete: 清理分类图标磁盘文件异常: $e\n$st');
    }
  }
}

/// 一组 local/remote 计数。-1 表示拉不到(网络错 / 老 server 没这个字段)。
class SyncCountPair {
  const SyncCountPair({required this.local, required this.remote});
  const SyncCountPair.missing()
      : local = 0,
        remote = -1;
  final int local;
  final int remote;
  bool get hasDiff => remote >= 0 && local != remote;
}

/// 深度同步检测报告。UI 分两组展示:
/// - `当前账本`:tx / attachment / budget,随 current ledger 走
/// - `全部账本`:上面三项的全量合计,以及 account / category / tag 这些用户级
///   实体(per-ledger 跟 total 同值)
class SyncHealthReport {
  const SyncHealthReport({
    required this.ledgerTx,
    required this.ledgerAttachments,
    required this.ledgerBudgets,
    required this.totalTx,
    required this.totalAttachments,
    required this.totalBudgets,
    required this.accounts,
    required this.categories,
    required this.tags,
    required this.unpushedChanges,
    this.error,
  });

  factory SyncHealthReport.error(String message) => const SyncHealthReport(
        ledgerTx: SyncCountPair.missing(),
        ledgerAttachments: SyncCountPair.missing(),
        ledgerBudgets: SyncCountPair.missing(),
        totalTx: SyncCountPair.missing(),
        totalAttachments: SyncCountPair.missing(),
        totalBudgets: SyncCountPair.missing(),
        accounts: SyncCountPair.missing(),
        categories: SyncCountPair.missing(),
        tags: SyncCountPair.missing(),
        unpushedChanges: 0,
      ).copyWithError(message);

  SyncHealthReport copyWithError(String message) => SyncHealthReport(
        ledgerTx: ledgerTx,
        ledgerAttachments: ledgerAttachments,
        ledgerBudgets: ledgerBudgets,
        totalTx: totalTx,
        totalAttachments: totalAttachments,
        totalBudgets: totalBudgets,
        accounts: accounts,
        categories: categories,
        tags: tags,
        unpushedChanges: unpushedChanges,
        error: message,
      );

  /// 当前账本口径
  final SyncCountPair ledgerTx;
  final SyncCountPair ledgerAttachments;
  final SyncCountPair ledgerBudgets;

  /// 全量口径(跨当前用户所有账本)
  final SyncCountPair totalTx;
  final SyncCountPair totalAttachments;
  final SyncCountPair totalBudgets;

  /// 用户级实体(per-ledger 跟 total 同值,只留一组)
  final SyncCountPair accounts;
  final SyncCountPair categories;
  final SyncCountPair tags;

  final int unpushedChanges;
  final String? error;

  bool get hasDiff {
    if (error != null) return false;
    if (unpushedChanges > 0) return true;
    return ledgerTx.hasDiff ||
        ledgerAttachments.hasDiff ||
        ledgerBudgets.hasDiff ||
        totalTx.hasDiff ||
        totalAttachments.hasDiff ||
        totalBudgets.hasDiff ||
        accounts.hasDiff ||
        categories.hasDiff ||
        tags.hasDiff;
  }

  /// 本地比远端多,但没 unpushed change → 绕过 changeTracker 的历史种子数据。
  bool get needsBackfill {
    if (error != null || unpushedChanges > 0) return false;
    if (accounts.remote >= 0 && accounts.local > accounts.remote) return true;
    if (categories.remote >= 0 && categories.local > categories.remote) return true;
    if (tags.remote >= 0 && tags.local > tags.remote) return true;
    return false;
  }
}
