import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../services/custom_icon_service.dart';
import '../../services/system/logger_service.dart';
import '../../services/ui/avatar_service.dart';
import '../../utils/app_localizations_resolver.dart';
import '../cloud_version_policy.dart';
import '../sync_service.dart' as app;
import '../recurring/recurring_handoff.dart';
import '../transactions_json.dart';
import 'change_tracker.dart';
import 'entity_serializer.dart';
import 'sync_events.dart';
import 'transaction_sync_payload.dart';
export 'sync_events.dart';

// SyncEngine 按职责拆分到多个 part 文件,共享同一 library:
// - sync_engine_attachments.dart: 附件上传 / 下载 / 本地清理 / 分类图标上传(并发 + retry)
// - sync_engine_resolvers.dart:   跨设备 ID 解析(syncId ↔ 本地 int id)
// - sync_engine_status.dart:      健康检查 + 历史种子数据补登
// - sync_engine_realtime.dart:    WS 事件监听 + auto sync / pull 防抖调度
// - sync_engine_profile.dart:     profile + avatar 同步(theme/income/appearance/ai)
// - sync_engine_apply.dart:       pull 路径远端变更 → 本地 Drift apply(6 种 entityType)
// - sync_engine_serialization.dart: push 路径本地实体 → server payload 序列化 + fullPush
// - sync_engine_pull.dart:        pull 路径错误恢复 — AppCursorStore + SyncErrorStore
//                                 (cursor 安全 + 失败 change 持久化暴露给 UI)
part 'sync_engine_attachments.dart';
part 'sync_engine_outbox.dart';
part 'sync_engine_resolvers.dart';
part 'sync_engine_status.dart';
part 'sync_engine_realtime.dart';
part 'sync_engine_recurring.dart';
part 'sync_engine_profile.dart';
part 'sync_engine_apply.dart';
part 'sync_engine_serialization.dart';
part 'sync_engine_pull.dart';
part 'sync_engine_transaction_moves.dart';

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

enum InitialUploadAction { incremental, create, resume }

/// 核心同步编排器 — 实现 SyncService 接口
/// 负责 push 本地变更到服务端、pull 远程变更到本地
class SyncEngine implements app.SyncService {
  final BeeDatabase db;
  final BeeCountCloudProvider provider;
  final ChangeTracker changeTracker;
  final BaseRepository repo;
  final _recurringInFlight = <int, Future<void>>{};
  Future<void> _transactionMoveTail = Future.value();

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
  String? _pendingAutoSyncReason;

  /// 外部注入:当前活跃 ledgerId 的解析器。WS 重连 / 网络恢复 时需要知道
  /// 往哪个 ledger 触发 sync,但 SyncEngine 内部不挂 Riverpod ref,所以让
  /// sync_providers 构造完之后塞一个函数进来。返回 0 / null 会跳过本次 sync。
  ///
  /// 这是 SyncEngine 唯一保留的反向"UI → engine"读通道(因为 sync 触发时机
  /// 在 engine 内部,需要主动读当前 ledger)。所有正向"engine → UI"通知都
  /// 走 [events] stream。
  String Function()? ledgerIdResolver;

  /// 版本匹配守护：仅在触发必须档（低于 min 版本）时暂停云同步，本地记账不受影响。
  Future<CloudVersionCompatibility?> Function()? versionGuard;

  /// 同步请求收到服务端 HTTP 426 时回调，立即通知 UI 切换到必须更新 App 状态。
  void Function(CloudVersionCompatibility compatibility)? onUpgradeRequired;

  /// 对外广播事件总线 — UI 通过 Riverpod `syncEventStreamProvider` 订阅,
  /// SyncEngine 完全不知道 widget / ref 存在。
  ///
  /// **sync: true 关键**:默认 broadcast 是 async 模式,`_emit` 调 `add` 后
  /// listener 要延迟到下个 microtask 才跑。这跟 PR3 之前直接 `onXxx?.call(...)`
  /// 的同步语义不一致 —— 多次 `_emit` 会触发多次独立 microtask,Flutter 有
  /// 机会在两次 listener 之间 schedule rebuild,导致 state 变更分散到多帧,
  /// 视觉上看到首页"刷一次又刷一次"。sync: true 让 add 同步调 listener,跟
  /// 原 callback 行为完全等价,多次 emit 内的 state 变更在同一同步代码段内
  /// batch 成一帧 rebuild。
  final StreamController<SyncEvent> _eventsController =
      StreamController<SyncEvent>.broadcast(sync: true);

  /// 订阅 sync 事件。
  Stream<SyncEvent> get events => _eventsController.stream;

  /// 内部 helper:emit 新事件到 stream。
  void _emit(SyncEvent event) {
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  /// app 侧 cursor + pull 失败 change 持久化的 DAO。
  /// 详见 [AppCursorStore] / [SyncErrorStore](sync_engine_pull.dart)。
  late final AppCursorStore appCursor;
  late final SyncErrorStore pullErrors;

  /// 自定义分类图标下载队列。`_applyCategoryChange` 在主事务内 enqueue,
  /// `pull` 在事务 commit 之后调 [drainCustomIconQueue] 并发处理。详见
  /// [CustomIconDownloadJob](sync_engine_pull.dart) 和
  /// [drainCustomIconQueue](sync_engine_attachments.dart)。
  final List<CustomIconDownloadJob> pendingCustomIconJobs = [];

  /// pull 期间生效的 [LookupCache]。pull 入口 new + prime,pull 结束清 null。
  /// resolvers 路径(`sync_engine_resolvers.dart`)优先查它,消除 N+1 SELECT。
  /// 详见 [LookupCache](sync_engine_pull.dart)。
  LookupCache? activePullCache;

  /// push / fullPush 的 in-flight 单飞锁。**per-ledger** —— 不同 ledger
  /// 并发不互相阻塞,只阻塞同 ledger 的并发触发。
  ///
  /// 背景:app 启动期 `_triggerInitialCloudSync` 由 microtask + listenManual
  /// 双入口触发,曾经导致同设备 2-3 路 fullPush 并发,服务端 sync_changes
  /// 表 2-2.5x 膨胀。详见 `.docs/concurrent-fullpush-bloat.md`。
  ///
  /// `_pushInFlight` key 用 String(跟 [push] 入参一致),`_fullPushInFlight`
  /// 用 int(跟 [fullPush] 入参一致)。
  final Map<String, Completer<_PushTally>> _pushInFlight = {};
  final Map<int, Completer<_PushTally>> _fullPushInFlight = {};

  /// user-global 实体(account/category/tag)推送的**全局**单飞锁。
  ///
  /// 用户多账本场景下,Phase 2 并发跑多个 `_push(ledgerN)` / `fullPush(ledgerN)`,
  /// 每个 caller 各自读 user-global unpushed change → 都 push 一份 → server
  /// sync_changes 表里 user-global 实体按 ledger 数倍数膨胀(已观察到 4 账本
  /// 用户的 account/category/tag 4x 膨胀)。
  ///
  /// 解法:所有 push 路径都先 `await pushUserGlobalEntities()`,**单飞**保证
  /// 全 session 只跑一次 user-global push,后续 caller 复用第一个的 future,
  /// 拿到的时候 ChangeTracker 已经 markPushed,再各自处理 ledger-scoped 部分。
  Completer<_PushTally>? _userGlobalPushInFlight;

  /// fullPull 的 in-flight 单飞锁。**per-ledger**,跟 fullPush 同款。
  ///
  /// 防御性:用户连点"下载"按钮时,避免两次并发 fullPull 重复下载同一份 JSON
  /// snapshot + 重复 apply。apply 路径是 idempotent upsert(同 syncId 不会插
  /// 重复行),所以不会数据膨胀,但浪费带宽 + CPU。
  ///
  /// 跟 fullPush 不同:**不会**真的把多账本并发拉成 N 倍 —— fullPull 只在用户
  /// 点"下载"时触发,正常单次调用;这个锁是给"快速连点"等边界场景兜底。
  final Map<int, Completer<({int inserted, int deletedDup})>>
      _fullPullInFlight = {};

  /// legacy 数据补 ChangeTracker 记录的一次性 flag。
  ///
  /// 历史:v19 migration 给老 account/category/tag 回填了 syncId,但**没在
  /// local_changes 表里登记对应的 create change**。如果某用户跨过 v19→v27 都
  /// 没开过云同步,后面 fullPush 走 ChangeTracker 驱动就拿不到这些 legacy 实
  /// 体 → 数据丢失。
  ///
  /// 解法:每个 session 第一次跑 `pushUserGlobalEntities` 时扫一遍 DB,给
  /// `local_changes` 里没记录的 user-global 实体补一条 upsert change,后续
  /// 正常走 ChangeTracker 流程。flag 持久存在 SyncEngine 实例上(per-session),
  /// 实例重建时(冷启)再跑一次,代价是一次轻量 SELECT。
  bool _userGlobalLegacyBackfilled = false;

  SyncEngine({
    required this.db,
    required this.provider,
    required this.changeTracker,
    required this.repo,
  }) {
    appCursor = AppCursorStore(provider);
    pullErrors = SyncErrorStore(db);
  }

  // ==================== SyncService 接口实现 ====================

  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) async {
    logger.info('SyncEngine', '上传账本 ledger=$ledgerId');

    // A partial restore must never replace an existing remote snapshot. Only
    // this device's persisted, unfinished preparation can resume an initial upload.
    final ledger = await (db.select(db.ledgers)..where((l) => l.id.equals(ledgerId))).getSingleOrNull();
    if (ledger != null && await _hasFullPreparation(ledger)) {
      final remote = await provider.storage.list(path: '');
      final action = await initialUploadAction(ledger, remoteExists: remote.any((r) => r.path == ledger.syncId));
      if (action != InitialUploadAction.incremental) {
        await fullPush(ledgerId: ledgerId, resumePreparation: action == InitialUploadAction.resume);
      }
    }
    final pushed = await push(ledgerId.toString());
    logger.info('SyncEngine', '上传账本完成：增量推送 $pushed 条变更');

    _statusCache.remove(ledgerId);
    _localChanged = false;
  }

  @override
  Future<({int inserted, int deletedDup})> downloadAndRestoreToCurrentLedger(
      {required int ledgerId}) async {
    logger.info('SyncEngine', '下载并恢复账本 ledger=$ledgerId');

    final result = await runFullPull(ledgerId: ledgerId);
    _statusCache.remove(ledgerId);
    return result;
  }

  @override
  Future<app.SyncStatus> getStatus({required int ledgerId}) async {
    try {
      final user = await provider.auth.currentUser;
      if (user == null) {
        return const app.SyncStatus(
          diff: app.SyncDiff.notLoggedIn,
          localCount: 0,
          localFingerprint: '',
        );
      }

      final ledgerRowStatus = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerId)))
          .getSingleOrNull();
      final preparing = ledgerRowStatus != null && await _hasFullPreparation(ledgerRowStatus);
      final unpushedCount = await _countPendingUploads(ledgerId) + (preparing ? 1 : 0);
      final fingerprint = unpushedCount > 0 ? 'has_changes' : 'synced';
      final cached = _statusCache[ledgerId];
      if (!_localChanged &&
          cached != null &&
          cached.localFingerprint == fingerprint) {
        return cached;
      }
      final txCount = db.transactions.id.count();
      final countRow = await (db.selectOnly(db.transactions)
            ..addColumns([txCount])
            ..where(db.transactions.ledgerId.equals(ledgerId)))
          .getSingle();
      final localCount = countRow.read(txCount) ?? 0;

      // 检查云端是否有数据。path 用 ledger.syncId 跟 push 侧保持一致。
      final hasRemote = await provider.storage.exists(
        path: ledgerRowStatus?.syncId ?? ledgerId.toString(),
      );

      app.SyncDiff diff;
      if (unpushedCount > 0) {
        diff = app.SyncDiff.localNewer;
      } else if (!hasRemote && localCount == 0) {
        diff = app.SyncDiff.noRemote;
      } else if (!hasRemote) {
        diff = app.SyncDiff.localNewer; // 本地有数据，云端没有
      } else {
        diff = app.SyncDiff.inSync;
      }

      final status = app.SyncStatus(
        diff: diff,
        localCount: localCount,
        localFingerprint: fingerprint,
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

  /// 释放资源。Runtime 在释放底层 provider 前等待 realtime listener 关闭。
  Future<void> dispose() async {
    _pendingAutoSyncReason = null;
    _pullDebounce?.cancel();
    _pullDebounce = null;
    _autoSyncDebounce?.cancel();
    _autoSyncDebounce = null;
    final subscription = _realtimeSubscription;
    _realtimeSubscription = null;
    await subscription?.cancel();
    await _eventsController.close();
  }

  // ==================== 核心同步逻辑 ====================

  /// 执行完整同步（先 push 后 pull）
  Future<SyncResult> sync({required String ledgerId}) async {
    logger.info('SyncEngine', '开始同步 ledger=$ledgerId');
    try {
      final versionCheck = await versionGuard?.call();
      if (versionCheck != null && versionCheck.isBlocking) {
        logger.warning('SyncEngine',
            '版本不兼容，已暂停云同步 (${versionCheck.status.name})');
        return const SyncResult(error: 'sync_paused_version_mismatch');
      }
      await _recoverTransactionMoves();
      final ledgerIdInt = int.tryParse(ledgerId) ?? -1;
      var outcome = const _PushTally();

      // 先上传附件文件，确保 cloudFileId 写入本地 DB，后续 push 的 payload 才包含 cloudFileId
      try {
        await uploadAttachments(ledgerId: ledgerIdInt);
      } catch (e, st) {
        logger.error('SyncEngine', '附件上传失败（不阻塞主同步）', e, st);
      }

      // 决策：fullPush 还是增量 push
      //
      // 单 ledger 粒度:本账本的 syncId **不在** 远端 `/sync/ledgers` 列表
      // 里 → fullPush;在 → 增量 _push。
      //
      // 跟旧 `storage.exists(path: ledger.syncId)` 等价(后者内部就是 list +
      // path 比对),但显式 list 一次自己比对,避免后续 snapshot 概念退场后
      // 误判持续返 false。
      //
      // 边界:`ledger.syncId == null`(本地刚建账本还没 sync 过)→ 一定不在
      // 远端列表,触发 fullPush。fullPush 内部 `_ensureLedgerSyncId` 会先
      // 生成 UUID 写回,确保 `pathForSnapshot` 合法。
      final ledgerRow = await (db.select(db.ledgers)
            ..where((l) => l.id.equals(ledgerIdInt)))
          .getSingleOrNull();

      // 短路:本地账本已删除(deleteLedger 路径)。这种情况下:
      //   - hasRemote 检查没意义(syncId 已经丢,fallback 到 int id 对 UUID 账本
      //     会误判)
      //   - fullPush 会 getSingle 抛错(ledger 行不存在)
      //   - pull 也没意义(账本都没了拉啥)
      // 唯一要做的是把 deleteLedger 已登记到 local_changes 的 ledger_snapshot:
      // delete + transaction:delete + budget:delete 推到 server,清掉 canonical
      // state,否则 remote ledgers 列表里还会显示这个被删的账本。
      if (ledgerRow == null) {
        final outcome = await _pushResult(ledgerId);
        logger.info(
            'SyncEngine', '账本 $ledgerId 已本地删除,push delete changes: ${outcome.accepted} 条');
        return outcome.syncResult(0);
      }

      // §7 共享账本:Editor 永不 fullPush(会把 Editor 本地状态覆盖 Owner 的)。
      bool? remoteExists;
      if (!ledgerRow.isShared || ledgerRow.myRole == 'owner') {
        try {
          final remote = await provider.storage.list(path: '');
          remoteExists = remote.any((r) => r.path == ledgerRow.syncId);
        } catch (e, st) {
          logger.warning('SyncEngine', '远端 ledger 列表查询失败,仅推已登记变更: $e', st);
        }
      }
      final action = await initialUploadAction(ledgerRow, remoteExists: remoteExists);
      if (action != InitialUploadAction.incremental) {
        final resumePreparation = action == InitialUploadAction.resume;
        // 远端没这个账本 → 首次绑定 / server 数据被清。
        // fullPush 推所有 entity + ledger 自身。

        // 关键:fullPush 前先确保 ledger.syncId 已生成(UUID 串)。否则会
        // fallback 到 `ledger.id.toString()` = 短数字串(如 "2"),触发
        // server 端 WriteLedgerCreateRequest 的 min_length=3 校验失败,并且
        // 跨设备时 server 上挂着的 external_id 也会变成本地 int id,后续多
        // 设备 sync 必然分裂。
        await _ensureLedgerSyncId(ledgerRow);

        if (!resumePreparation) {
          // Only a genuinely new remote ledger needs fresh attachment references.
          await _resetAttachmentCloudRefs(ledgerIdInt);
        }
        outcome = await _fullPushResult(ledgerIdInt, remoteExists: resumePreparation);
        // Deletes and edits made during the upload need their own receipts.
        if (outcome.rejected == 0) outcome += await _pushResult(ledgerId);
      } else {
        outcome = await _pushResult(ledgerId);
        logger.info('SyncEngine', '增量推送: ${outcome.accepted} 条');
      }

      final pulled = await pull(ledgerId);

      // 下载远端附件文件（上传已在 push 前完成）
      try {
        await downloadAttachments(ledgerId: ledgerIdInt);
      } catch (e, st) {
        logger.error('SyncEngine', '附件下载失败（不阻塞主同步）', e, st);
      }

      // 顺手再拉一次 profile（多数场景 bootstrap 已经拉过，这里幂等兜底）。
      await syncMyProfile();

      final result = outcome.syncResult(pulled);
      final pushed = outcome.accepted;
      // 【根因修复】同步完成后清掉本账本 getStatus 的 _statusCache,跟手动上传/
      // 下载路径(uploadToCloudFromCurrentLedger / downloadAndRestoreToCurrentLedger
      // 里的 _statusCache.remove)保持一致。否则 push 后 unpushedCount 已归零,但
      // 「我的」页 syncStatus 仍命中旧缓存(localNewer),用户必须手动去详情页下拉
      // 刷新(那条路径清了缓存)状态才更新 —— 这正是本 bug 的根因。
      if (ledgerIdInt > 0) {
        clearStatusCache(ledgerId: ledgerIdInt);
      }
      // 手动 sync 也会拉回新附件；元数据与原件就绪后发出同一完成事件，
      // 避免只依赖 WS auto-pull 的刷新使首页继续显示删除前的零附件计数。
      if (pulled > 0) {
        _emit(PullCompleted(
            ledgerId: ledgerRow.syncId ?? ledgerId, applied: pulled));
      }
      // 缓存清掉只是让下次 getStatus 会重算;还得有人触发 syncStatusProvider 去重读。
      // push 上传了本地变更时 emit PushCompleted,listener 收到后 bump
      // syncStatusRefresh → 重读 getStatus(缓存已清 → 重算为 inSync)。
      if (pushed > 0) {
        _emit(PushCompleted(ledgerId: ledgerId, pushed: pushed));
      }
      if (result.hasError) {
        logger.warning('SyncEngine', '同步存在未接受的变更: $result');
      } else {
        logger.info('SyncEngine', '同步完成: $result');
      }
      return result;
    } on BeeCountCloudUpgradeRequiredException catch (e) {
      logger.warning('SyncEngine', '服务端要求升级 App，已暂停云同步: $e');
      onUpgradeRequired?.call(CloudVersionCompatibility.fromUpgradeRequired(e));
      return const SyncResult(error: 'sync_paused_version_mismatch');
    } catch (e, st) {
      logger.error('SyncEngine', '同步失败', e, st);
      return SyncResult(error: e.toString());
    }
  }

  /// fullPush 前确保 ledger.syncId 已生成。
  ///
  /// 没 syncId 时 `pathForSnapshot` 会 fallback 到 `ledger.id.toString()`(短
  /// 数字串如 "2"),走两个失败路径:
  /// - `writeCreateLedger` 的 `WriteLedgerCreateRequest.ledger_id` 校验 min_length=3
  /// - server 端 ledger.external_id 被写成 int id 字符串,跨设备时同一账本
  ///   external_id 会分裂(A 设备的 syncId=UUID,B 设备的 syncId=int)
  ///
  /// 这里在 fullPush 入口做最后兜底,生成 UUID 写回。
  Future<void> _ensureLedgerSyncId(Ledger ledger) async {
    if (ledger.syncId != null && ledger.syncId!.length >= 3) return;
    final newSyncId = _uuid.v4();
    await (db.update(db.ledgers)..where((l) => l.id.equals(ledger.id)))
        .write(LedgersCompanion(syncId: d.Value(newSyncId)));
    logger.info(
        'SyncEngine', 'fullPush 前补生成 ledger.syncId: ${ledger.id} → $newSyncId');
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
  /// 并发互斥锁 — **static** 跨 SyncEngine 实例共享。
  /// Runtime 已统一 engine 实例；static 锁同时兜住独立测试容器或并行调用方。
  static Completer<int>? _syncLedgersInFlight;

  Future<int> syncLedgersFromServer() async {
    final existing = _syncLedgersInFlight;
    if (existing != null) {
      logger.info('SyncEngine', 'syncLedgersFromServer 已在执行中,等待 in-flight 结果');
      return existing.future;
    }
    final completer = Completer<int>();
    _syncLedgersInFlight = completer;
    try {
      final n = await _syncLedgersFromServerLocked();
      completer.complete(n);
      return n;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      _syncLedgersInFlight = null;
    }
  }

  Future<int> _syncLedgersFromServerLocked() async {
    logger.info('SyncEngine', 'syncLedgersFromServer start');
    try {
      // A list request can finish after a local edit has already been acknowledged.
      // Keep its edited fields even when they have disappeared from the pending queue.
      final (watermark, pendingBeforeRead) = await db.transaction(() async {
        final lastId = db.localChanges.id.max();
        final row = await (db.selectOnly(db.localChanges)..addColumns([lastId]))
            .getSingle();
        return (row.read(lastId) ?? 0, await _ledgerChangesToProtect());
      });
      final remote = await provider.readLedgers();
      int upserted = 0;
      int inserted = 0;
      // 新设备登录场景:Editor 已是 server LedgerMember 但本地 ledgers 表为空。
      // 检测到 isShared && myRole != owner 的新 insert 时,记下 syncId,本轮
      // 结束后批量拉 /shared-resources 落 SharedLedger* 表。不放循环里直接
      // await 是因为 fetchAndStoreSharedResources 走 HTTP,放循环里会串行慢,
      // 也会让单个失败影响其它账本。
      final newSharedLedgerSyncIds = <String>[];
      await db.transaction(() async {
        final edits = <String, List<LocalChange>>{};
        final recent = await _ledgerChangesToProtect(afterId: watermark);
        for (final c in [...pendingBeforeRead, ...recent]) {
          (edits[c.entitySyncId] ??= []).add(c);
        }
        for (final r in remote) {
          final syncId = r.ledgerId;
          if (syncId.isEmpty) continue;
          final localEdits = edits[syncId] ?? const <LocalChange>[];
          if (localEdits.any((c) => c.entityType == 'ledger_snapshot')) {
            continue;
          }
          // 用 get() 不用 getSingleOrNull() — 历史可能已经产生过同 syncId 多行
          // (并发 syncLedgersFromServer 串行化前的遗留 / 老版本残留)。这里取 list,
          // 有就保第一行,GC 其余 dup。
          final existingList = await (db.select(db.ledgers)
                ..where((l) => l.syncId.equals(syncId)))
              .get();
          if (existingList.isNotEmpty) {
            final existing = existingList.first;
            final metadata = _remoteLedgerMetadata(localEdits,
                name: r.ledgerName,
                currency: r.currency,
                monthStartDay: r.monthStartDay);
            await (db.update(db.ledgers)..where((l) => l.id.equals(existing.id)))
                .write(metadata.copyWith(
              myRole: d.Value(r.role),
              isShared: d.Value(r.isShared),
              memberCount: d.Value(r.memberCount),
            ));
            // 删 dup 行(及其关联 tx/local_changes,虽然 dup 行还没有这些)
            if (existingList.length > 1) {
              final dupIds = existingList.skip(1).map((l) => l.id).toList();
              logger.warning('SyncEngine',
                  '检测到 ledger.syncId=$syncId 重复 ${existingList.length} 行,清除 dup id=$dupIds');
              await (db.delete(db.transactions)
                    ..where((t) => t.ledgerId.isIn(dupIds)))
                  .go();
              await (db.delete(db.localChanges)
                    ..where((c) => c.ledgerId.isIn(dupIds)))
                  .go();
              await (db.delete(db.ledgers)..where((l) => l.id.isIn(dupIds))).go();
            }
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
              myRole: d.Value(r.role),
              isShared: d.Value(r.isShared),
              memberCount: d.Value(r.memberCount),
              monthStartDay: r.monthStartDay != null
                  ? d.Value(r.monthStartDay!.clamp(1, 28))
                  : const d.Value.absent(),
            ));
            upserted++;
            continue;
          }
          // 全新账本：insert。id 是本地 autoIncrement，跟 server 无关。
          await db.into(db.ledgers).insert(LedgersCompanion.insert(
                name: r.ledgerName,
                currency: d.Value(r.currency),
                syncId: d.Value(syncId),
                myRole: d.Value(r.role),
                isShared: d.Value(r.isShared),
                memberCount: d.Value(r.memberCount),
                monthStartDay: r.monthStartDay != null
                    ? d.Value(r.monthStartDay!.clamp(1, 28))
                    : const d.Value.absent(),
              ));
          inserted++;
          // 新设备登录:Editor 的共享账本需要拉 /shared-resources 才能在
          // picker / 详情页 / 洞察 等显示 Owner 的资源。fallback 给 byName
          // 收编路径不记(那是同 ledger 的 syncId 收编,不算新 ledger)。
          if (r.isShared && r.role != 'owner') {
            newSharedLedgerSyncIds.add(syncId);
          }
        }
      });
      logger.info('SyncEngine',
          'syncLedgersFromServer done: total=${remote.length} upserted=$upserted inserted=$inserted');

      // GC 1:清掉本地 isShared=true 但 server 没返回的 ledger — Owner 删了
      // 共享账本,Editor 应该自动清(WS member_change.removed 是主路径,这是
      // 兜底,处理 WS 离线时没推到的情况)。
      final remoteSyncIdSet = remote.map((r) => r.ledgerId).toSet();
      final localShared = await (db.select(db.ledgers)
            ..where((l) => l.isShared.equals(true)))
          .get();
      for (final localLedger in localShared) {
        final sid = localLedger.syncId;
        if (sid == null || sid.isEmpty) continue;
        if (remoteSyncIdSet.contains(sid)) continue;
        // server 不再返这个共享账本 = Owner 删了 / Editor 被踢 → 清本地
        logger.info('SyncEngine', 'GC: server 不再返共享账本 syncId=$sid,清本地数据');
        await _purgeLocalLedgerByExternalId(sid);
      }

      // GC 2:清掉 SharedLedger* 表里 ledger.syncId 在新拉的 ledgers 表里找不
      // 到的孤儿行(测试残留 / 退出账本残留 / 老 invite 接受过又被 byName
      // fallback 改 syncId 时遗弃的旧 ledger_sync_id 行)
      await _gcOrphanSharedLedgerRows();

      // 新设备登录场景的二次拉取:本轮 insert 的共享账本(Editor 角色)逐个
      // 拉 /shared-resources 把 SharedLedger* 镜像表填上。每个独立 await
      // 单一错误不影响其它账本;成功后 bump tick 让 UI 立即生效。
      if (newSharedLedgerSyncIds.isNotEmpty) {
        logger.info('SyncEngine',
            '新 insert 的共享账本(Editor)$newSharedLedgerSyncIds — 拉 /shared-resources');
        for (final sid in newSharedLedgerSyncIds) {
          try {
            await fetchAndStoreSharedResources(sid);
          } catch (e, st) {
            logger.warning('SyncEngine',
                'fetchAndStoreSharedResources 失败 ledger=$sid: $e', st);
          }
        }
        // 通知 UI 刷新(picker / 详情页 watch sharedResourceRefreshProvider)
        // 这里只是拉了 SharedLedger* 镜像表,tx 没变,不该 emit PullCompleted
        // 触发 home 全刷,走 SharedResourceChanged 精确信号。
        _emit(const SharedResourceChanged(ledgerId: ''));
      }

      return inserted;
    } catch (e, st) {
      logger.warning('SyncEngine', 'syncLedgersFromServer failed: $e', st);
      return 0;
    }
  }

  Future<List<LocalChange>> _ledgerChangesToProtect(
      {String? syncId, int? afterId}) {
    final query = db.select(db.localChanges)
      ..where((c) => c.entityType.equals('ledger') |
          (c.entityType.equals('ledger_snapshot') & c.action.equals('delete')))
      ..where((c) => afterId == null
          ? c.pushedAt.isNull()
          : c.pushedAt.isNull() | c.id.isBiggerThanValue(afterId));
    if (syncId != null) query.where((c) => c.entitySyncId.equals(syncId));
    return query.get();
  }

  LedgersCompanion _remoteLedgerMetadata(Iterable<LocalChange> edits,
      {String? name, String? currency, int? monthStartDay}) {
    final dirty = <String>{};
    for (final change in edits) {
      final payload = change.payloadJson;
      // Older clients journaled the whole row, without a field list.
      if (payload == null) return const LedgersCompanion();
      try {
        final fields = jsonDecode(payload);
        if (fields is! Map<String, dynamic>) return const LedgersCompanion();
        dirty.addAll(fields.keys);
      } on FormatException {
        return const LedgersCompanion();
      }
    }
    return LedgersCompanion(
      name: name != null && !dirty.contains('ledgerName')
          ? d.Value(name)
          : const d.Value.absent(),
      currency: currency != null && !dirty.contains('currency')
          ? d.Value(currency)
          : const d.Value.absent(),
      monthStartDay: monthStartDay != null && !dirty.contains('monthStartDay')
          ? d.Value(monthStartDay.clamp(1, 28))
          : const d.Value.absent(),
    );
  }

  /// 推送 user-global 实体(account / category / tag)的未推 change。
  ///
  /// **全局单飞**:并发调用复用第一个的 future。多账本场景下 Phase 2 并行的
  /// `_push(ledgerN)` / `fullPush(ledgerN)` 都先 await 这个方法,保证 user-global
  /// 实体每个 session 只推一次。
  ///
  /// 注意:**不要在 `_push` / `_pushAllEntities` 内部重复推 user-global**,
  /// 否则单飞失效。这俩内部应该只处理 ledger-scope change(transaction / budget /
  /// ledger / ledger_snapshot)。
  Future<int> pushUserGlobalEntities() async =>
      (await _pushUserGlobalResult()).requireSuccess();

  Future<_PushTally> _pushUserGlobalResult() async {
    final inFlight = _userGlobalPushInFlight;
    if (inFlight != null) {
      logger.info('SyncEngine', 'pushUserGlobalEntities 已在执行,复用 in-flight');
      final result = await inFlight.future;
      return _PushTally(conflicts: result.conflicts, rejected: result.rejected);
    }
    final completer = Completer<_PushTally>();
    completer.future.ignore();
    _userGlobalPushInFlight = completer;
    try {
      final n = await _doPushUserGlobalEntities();
      completer.complete(n);
      return n;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_userGlobalPushInFlight == completer) {
        _userGlobalPushInFlight = null;
      }
    }
  }

  Future<_PushTally> _doPushUserGlobalEntities() async {
    // Legacy backfill:v19 migration 给老 user-global 实体填了 syncId 但没登记
    // local_changes,这里一次性补登记。每 SyncEngine 实例只跑一次。
    if (!_userGlobalLegacyBackfilled) {
      await _backfillLegacyUserGlobalChanges();
      _userGlobalLegacyBackfilled = true;
    }

    final globalChanges = await changeTracker.getUnpushedChangesForLedger(0);
    if (globalChanges.isEmpty) {
      logger.debug(
          'SyncEngine', 'pushUserGlobalEntities: 无未推 user-global change');
      return const _PushTally();
    }

    final main = globalChanges.where((c) => c.entityType != 'exchange_rate_override').toList();
    final overrides = globalChanges.where((c) => c.entityType == 'exchange_rate_override').toList();
    final first = await _sendTracked(main, null);
    if (overrides.isEmpty) return first;
    try {
      return first + await _sendTracked(overrides, null);
    } on CloudStorageException catch (e) {
      // Older servers can reject this entity type while accepting other changes.
      logger.warning('SyncEngine', '自定义汇率保留待传: $e');
      return first + _PushTally(rejected: overrides.length);
    }
  }

  /// 扫 accounts/categories/tags,给 local_changes 里没登记过的 legacy 实体
  /// 补一条 upsert change。详见 [_userGlobalLegacyBackfilled] doc。
  ///
  /// 兼顾兜底两件事:
  /// 1. 实体 syncId 为 NULL(v22 migration 没覆盖到的脏数据)→ 生成 v4 UUID 写回
  /// 2. 已有 syncId 但 local_changes 表里完全没记录该实体的 change → 补 upsert
  Future<void> _backfillLegacyUserGlobalChanges() async {
    // 预拉:local_changes 表里所有 user-global 实体 syncId,做 in-memory dedup,
    // 避免逐 entity SELECT。
    final existingChanges = await (db.select(db.localChanges)
          ..where((c) => c.entityType.isIn(['account', 'category', 'tag'])))
        .get();
    final knownSyncIds = existingChanges.map((c) => c.entitySyncId).toSet();

    var backfilled = 0;

    // accounts
    final accounts = await db.select(db.accounts).get();
    for (final a in accounts) {
      var syncId = a.syncId;
      if (syncId == null) {
        syncId = _uuid.v4();
        await (db.update(db.accounts)..where((row) => row.id.equals(a.id)))
            .write(AccountsCompanion(syncId: d.Value(syncId)));
      }
      if (!knownSyncIds.contains(syncId)) {
        await changeTracker.recordUserGlobalChange(
          entityType: 'account',
          entityId: a.id,
          entitySyncId: syncId,
          action: 'upsert',
        );
        backfilled++;
      }
    }

    // categories
    final categories = await db.select(db.categories).get();
    for (final c in categories) {
      var syncId = c.syncId;
      if (syncId == null) {
        syncId = _uuid.v4();
        await (db.update(db.categories)..where((row) => row.id.equals(c.id)))
            .write(CategoriesCompanion(syncId: d.Value(syncId)));
      }
      if (!knownSyncIds.contains(syncId)) {
        await changeTracker.recordUserGlobalChange(
          entityType: 'category',
          entityId: c.id,
          entitySyncId: syncId,
          action: 'upsert',
        );
        backfilled++;
      }
    }

    // tags
    final tags = await db.select(db.tags).get();
    for (final t in tags) {
      var syncId = t.syncId;
      if (syncId == null) {
        syncId = _uuid.v4();
        await (db.update(db.tags)..where((row) => row.id.equals(t.id)))
            .write(TagsCompanion(syncId: d.Value(syncId)));
      }
      if (!knownSyncIds.contains(syncId)) {
        await changeTracker.recordUserGlobalChange(
          entityType: 'tag',
          entityId: t.id,
          entitySyncId: syncId,
          action: 'upsert',
        );
        backfilled++;
      }
    }

    if (backfilled > 0) {
      logger.info('SyncEngine',
          'legacy backfill: 补登记 $backfilled 条 user-global ChangeTracker entry');
    } else {
      logger.debug('SyncEngine', 'legacy backfill: 无需补登记');
    }
  }

  /// 推送本地未同步的变更到服务端。
  ///
  /// **in-flight 单飞**:同 ledger 的并发调用复用第一个的 future,避免双触发
  /// 在 sync_changes 表里造成重复 row。不同 ledger 并发不互相阻塞。
  ///
  /// 注意:**只推 ledger-scope change**(transaction / budget / ledger / ledger_snapshot)。
  /// user-global change(account / category / tag)由 [pushUserGlobalEntities] 统一推
  /// (在 [_doPush] 开头调用),避免多账本场景下并行 push 重复推送 user-global。
  Future<int> push(String ledgerId) async =>
      (await _pushResult(ledgerId)).requireSuccess();

  Future<_PushTally> _pushResult(String ledgerId) async {
    await _recoverTransactionMoves();
    final full = _fullPushInFlight[int.tryParse(ledgerId)];
    if (full != null) await full.future;
    final inFlight = _pushInFlight[ledgerId];
    if (inFlight != null) {
      logger.info('SyncEngine', 'push(ledger=$ledgerId) 已在执行,复用 in-flight');
      return inFlight.future;
    }
    final completer = Completer<_PushTally>();
    completer.future.ignore(); // 防 unhandled async error
    _pushInFlight[ledgerId] = completer;
    try {
      final result = await _doPush(ledgerId);
      completer.complete(result);
      return result;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_pushInFlight[ledgerId] == completer) {
        _pushInFlight.remove(ledgerId);
      }
    }
  }

  Future<_PushTally> _doPush(String ledgerId) async {
    final ledgerIdInt = int.tryParse(ledgerId) ?? -1;

    // 1) 先推 user-global change(account / category / tag)。
    //    全局单飞,Phase 2 多 ledger 并行场景下只跑一次,跨 ledger 不再各推一份。
    //    详见 [pushUserGlobalEntities] doc + .docs/concurrent-fullpush-bloat.md。
    final userGlobalPushed = await _pushUserGlobalResult();

    // 2) ledgerId="0" / "" 语义是"只推 user-global",上面一步已经做完。
    if (ledgerIdInt == 0) return userGlobalPushed;

    final ledger = await (db.select(db.ledgers)
          ..where((l) => l.id.equals(ledgerIdInt)))
        .getSingleOrNull();

    // 3) 再推这个 ledger 的 ledger-scope change(transaction / budget / ledger /
    //    ledger_snapshot)。ledger 删除路径:即使 ledger 行已没,ledger_snapshot:
    //    delete change 还在 local_changes 里,这里照常推。
    //
    // 关键:ledger 已被本地删除时不能直接 return 0。因为 deleteLedger 会先
    // 登记 ledger_snapshot:delete change 再 hard-delete ledger 行,这条 delete
    // change 的 ledger_id 字段就是这个本地 id。如果这里因 ledger==null 短路,
    // 这条 delete change 永远卡在本地不推,云端账本和它的快照永远删不掉,
    // remote ledgers list 还会继续显示。
    //
    // 所以策略改为:先按这个 ledgerIdInt 查未推送变更,有变更就继续推,没
    // 变更才安全 return。
    final held = ledger == null ? <int>{} : await _adoptBeforeUpload(ledger);
    final ledgerChanges =
        await changeTracker.getUnpushedChangesForLedger(ledgerIdInt);
    // 仅这个 ledger 的 ledger-scope change。user-global 已在上面统一推走。
    final changes = ledgerChanges
        .where((change) => !_holdRecurringChange(change, held))
        .toList();
    if (changes.isEmpty) {
      if (ledger == null) {
        logger.warning('SyncEngine', 'push: 本地账本 $ledgerId 已删除且无待推送变更,跳过');
      } else {
        logger.debug('SyncEngine',
            'push: 无 ledger-scope 待推变更(user-global 已推 $userGlobalPushed 条)');
      }
      return userGlobalPushed;
    }
    // 当本地 ledger 行已删,从同批 changes 里捞 ledger_snapshot:delete 的
    // entity_sync_id(= 被删账本的 syncId / UUID),用它给所有相关 change 的
    // push payload 设置 ledger_id 字段。否则 fallback 到 ledgerId 字符串
    // (本地 int id),server 端会把它当成一个不存在的账本 → 整批 delete 静
    // 默失败,canonical state 不变,远端数据看着像没删。
    String? deletedLedgerSyncId;
    if (ledger == null) {
      for (final c in changes) {
        if (c.entityType == 'ledger_snapshot' && c.action == 'delete') {
          deletedLedgerSyncId = c.entitySyncId;
          break;
        }
      }
      logger.info(
          'SyncEngine',
          'push: 本地账本 $ledgerId 已删除,但还有 ${changes.length} 条未推送变更(应包含 ledger_snapshot:delete),'
              '从 snapshot change 拿到 ledgerSyncId=$deletedLedgerSyncId,继续 push');
    }

    return userGlobalPushed + await _sendTracked(
        changes, ledger?.syncId ?? deletedLedgerSyncId ?? ledgerId);
  }

  /// 拉取远程变更并应用到本地。
  ///
  /// 改造点(详见 `.docs/full-pull-refactor/`):
  /// 1. **cursor 安全**:cloud-sync 包 `pullChanges(persistCursor: false)`,
  ///    app 侧用 [appCursor] 管,**整页 apply 成功后**才推进
  /// 2. **失败隔离**:整页 apply 抛错 → rollback + 错误入 [pullErrors] 表 +
  ///    cursor 不推进 + 后续页不再拉,UI 显示"同步暂停"
  /// 3. **busy retry**:SQLite busy/locked 单条 retry 2 次
  /// 4. **小颗粒度**:单页 limit 50(原 500),让 retry 范围 + UI 反馈更可控
  ///
  /// 传 [sinceOverride]=0 = 从头重放(等价旧 replayAllChanges)。
  ///
  /// **单飞锁**:多个 caller(bootstrap / WS push / ledger switch /
  /// connectivity restored / 用户下拉刷新)同时触发 pull 时,SQLite 排队 +
  /// main isolate 拥塞会让 apply 时间翻倍。这里用 [_pullInFlight] 互斥:
  /// - 普通 pull(sinceOverride=null)碰到 in-flight 时**复用结果**(节省一
  ///   轮)
  /// - replay(sinceOverride 非 null)语义独立,等 in-flight 完成后再自己跑
  Future<int> pull(String ledgerId, {int? sinceOverride}) async {
    final versionCheck = await versionGuard?.call();
    if (versionCheck != null && versionCheck.isBlocking) {
      logger.warning('SyncEngine',
          '版本不兼容，已暂停拉取 (${versionCheck.status.name})');
      return 0;
    }
    await _recoverTransactionMoves();
    // 1. in-flight 单飞
    final inFlight = _pullInFlight;
    if (inFlight != null) {
      if (sinceOverride == null && _pullInFlightSince == null) {
        // 普通 pull 复用 in-flight 结果
        logger.info('SyncEngine', 'pull 已在执行中,复用 in-flight 结果');
        return inFlight.future;
      }
      // replay / since 不同 → 等当前 pull 完成再独立跑
      logger.info('SyncEngine',
          'pull(sinceOverride=$sinceOverride) 等待 in-flight pull 完成');
      try {
        await inFlight.future;
      } catch (_) {/* 忽略 in-flight 的错,自己单独跑 */}
    }

    final completer = Completer<int>();
    // 默认订阅 future 让出错时不抛 unhandled async error — 后续 caller
    // 复用 in-flight 时会自己 await,如果没人 await(单 caller 场景),
    // completer.completeError 触发的 Future 错误会被 zone 当成 unhandled。
    // 这里 ignore() 等于说"我已经知道这个错,通过 rethrow 抛给当前 caller 了"。
    completer.future.ignore();
    _pullInFlight = completer;
    _pullInFlightSince = sinceOverride;
    try {
      final n = await _doPull(ledgerId, sinceOverride);
      completer.complete(n);
      return n;
    } on BeeCountCloudUpgradeRequiredException catch (e) {
      logger.warning('SyncEngine', '拉取时服务端要求升级 App，已暂停云同步: $e');
      onUpgradeRequired?.call(CloudVersionCompatibility.fromUpgradeRequired(e));
      completer.complete(0);
      return 0;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_pullInFlight == completer) {
        _pullInFlight = null;
        _pullInFlightSince = null;
      }
    }
  }

  /// pull 单飞锁。多个 caller 同时调 pull 时,只第一个真跑,后续复用 / 等待。
  Completer<int>? _pullInFlight;
  int? _pullInFlightSince;

  Future<int> _doPull(String ledgerId, int? sinceOverride) async {
    final restoreCursor = await appCursor._readRestoreCursor();
    int nextSince = sinceOverride ?? restoreCursor ?? await appCursor.read();
    if (nextSince == 0 && sinceOverride == null && restoreCursor == null) {
      await appCursor.migrateFromProviderCursor();
      nextSince = await appCursor.read();
    }
    final restoring =
        nextSince == 0 || (sinceOverride == null && restoreCursor != null);
    // An explicit replay can start from an advanced normal cursor. Remember
    // its starting point even if the very first request or transaction fails.
    if (sinceOverride == 0) await appCursor._restartRestore();

    // **Lazy prime**:先 HTTP 一次试探有没有数据。99% 场景(无变更)直接
    // return,跳过 LookupCache 全表 SELECT(transactions 10k+ 行的 prime
    // 每次都要 200-500ms 主线程时间)。多账本场景这里是大头 — 启动时 5 个
    // ledger 各跑一次 sync,空跑也要 prime 5 次,白白卡 1-2s。
    final probe = await _readPullPage(nextSince, restoring: restoring);
    if (probe.changes.isEmpty) {
      if (restoreCursor != null || sinceOverride == 0) {
        await appCursor.commit(probe.serverCursor, restoring: true);
      }
      logger.info(
          'SyncEngine', 'pull: since=$nextSince 无新变更,跳过 LookupCache prime');
      return 0;
    }

    // 有数据 → prime LookupCache,然后跑 loop(把已拉的第一页喂进去)
    final cache = LookupCache();
    await cache.prime(db);
    activePullCache = cache;

    try {
      return await _runPullLoop(ledgerId, nextSince,
          restoring: restoring, firstPage: probe);
    } finally {
      activePullCache = null;
    }
  }

  Future<BeeCountCloudPullResult> _readPullPage(int since,
          {required bool restoring}) =>
      restoring
          ? provider.pullRestorePage(since: since, limit: 500)
          : provider.pullChanges(since: since, limit: 500, persistCursor: false);

  Future<int> _runPullLoop(
    String ledgerId,
    int nextSince, {
    required bool restoring,
    BeeCountCloudPullResult? firstPage,
  }) async {
    int totalApplied = 0;
    bool hasMore = true;
    int pageIndex = 0;
    final loopStart = DateTime.now();
    BeeCountCloudPullResult? reuseResult = firstPage;
    while (hasMore) {
      pageIndex++;
      final pageStart = DateTime.now();
      final BeeCountCloudPullResult result;
      if (reuseResult != null) {
        // 第一轮:复用 _doPull 的探针结果,不再发一次 HTTP
        result = reuseResult;
        reuseResult = null;
        logger.info('SyncEngine',
            'pull #$pageIndex: since=$nextSince got ${result.changes.length} hasMore=${result.hasMore} (reused probe)');
      } else {
        result = await _readPullPage(nextSince, restoring: restoring);
        final httpMs = DateTime.now().difference(pageStart).inMilliseconds;
        logger.info('SyncEngine',
            'pull #$pageIndex: since=$nextSince got ${result.changes.length} hasMore=${result.hasMore} (HTTP ${httpMs}ms)');
      }
      if (result.changes.isEmpty) {
        if (restoring) await appCursor.commit(result.serverCursor, restoring: true);
        break;
      }

      final applyStart = DateTime.now();
      await _recoverTransactionMoves();
      final outcome = await _applyPullPage(result.changes, restoring: restoring);
      final applyMs = DateTime.now().difference(applyStart).inMilliseconds;
      logger.info('SyncEngine',
          'pull #$pageIndex: applied ${outcome.applied}/${result.changes.length} (apply ${applyMs}ms, page total ${DateTime.now().difference(pageStart).inMilliseconds}ms)');
      totalApplied += outcome.applied;
      if (outcome.blocked) {
        logger.warning(
            'SyncEngine', 'pull 被错误阻塞 cursor 停在 $nextSince — UI 应显示同步异常');
        break;
      }

      // 整页成功:推进 cursor,处理本页 enqueue 的自定义图标
      await appCursor.commit(result.serverCursor,
          restoring: restoring, hasMore: result.hasMore);
      nextSince = result.serverCursor;

      // 同 change_id 之前如果有未 resolved 错误(server 修了脏数据 + 推新
      // change → apply 通过)→ markResolved 让 UI 不再显示
      for (final ch in result.changes) {
        await pullErrors.markResolved(ch.changeId);
      }

      // 主事务已 commit,fire-and-forget 并发处理图标 queue,不阻塞下一页
      if (pendingCustomIconJobs.isNotEmpty) {
        unawaited(drainCustomIconQueue());
      }

      hasMore = result.hasMore;
    }

    final totalMs = DateTime.now().difference(loopStart).inMilliseconds;
    if (totalApplied > 0 || pageIndex > 0) {
      logger.info('SyncEngine',
          'pull: 累计 apply $totalApplied 条 / $pageIndex 页 / 总耗时 ${totalMs}ms');
    }
    return totalApplied;
  }

  /// 单页 apply。整页事务 try/catch:
  /// - 不可恢复异常 → rollback + 错误入 [pullErrors] + return blocked
  /// - SQLite busy/locked → 单条 retry 2 次
  Future<_PullPageOutcome> _applyPullPage(
      List<BeeCountCloudSyncChange> changes, {required bool restoring}) async {
    int applied = 0;
    int skipped = 0;
    BeeCountCloudSyncChange? failingChange;

    try {
      await _applyWithAttachmentCleanup((removedFiles) async {
        for (final ch in changes) {
          failingChange = ch;
          final ok = await _applyOneWithBusyRetry(ch, removedFiles,
              restoring: restoring);
          if (ok) {
            applied++;
          } else {
            skipped++;
          }
        }
      });
      if (skipped > 0) {
        logger.info('SyncEngine', 'pull: 应用 $applied / 跳过 $skipped (本页)');
      }
      return _PullPageOutcome(applied: applied, blocked: false);
    } catch (e, st) {
      // 整页 rollback 已自动完成(Drift transaction 抛错回滚)
      logger.error(
          'SyncEngine',
          '本页 apply 抛错 change_id=${failingChange?.changeId} '
              'type=${failingChange?.entityType}',
          e,
          st);
      final ch = failingChange;
      if (ch != null) {
        await pullErrors.record(change: ch, error: e, stackTrace: st);
      }
      return const _PullPageOutcome(applied: 0, blocked: true);
    }
  }

  /// 单条 apply 带 SQLite busy/locked retry。其它异常直接抛,让外层整页 rollback。
  ///
  /// 用 `e.toString()` 探测 SqliteException 类型,避免引入 sqlite3 包依赖
  /// (Drift 内部用,但这里直接 import 会触发 depend_on_referenced_packages)。
  Future<bool> _applyOneWithBusyRetry(
      BeeCountCloudSyncChange ch, Set<String> removedFiles, {required bool restoring}) async {
    var attempts = 0;
    while (true) {
      try {
        return await _applyRemoteChange(ch, removedFiles, restoring: restoring);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        final transient =
            (msg.contains('sqlite') || msg.contains('database')) &&
                (msg.contains('busy') || msg.contains('locked'));
        if (transient && attempts < 2) {
          attempts++;
          await Future.delayed(Duration(milliseconds: 50 * (1 << attempts)));
          continue;
        }
        rethrow;
      }
    }
  }

  /// 从 change_id=0 起把整段 sync_changes 重拉一遍并幂等应用。
  /// 用在"账本刚从 server 拉到本地、本地 tx 为空但 cursor 已经被推到顶"
  /// 的恢复场景。跟 S3/WebDAV 的 `_fullPull` 不同，这里走的还是 BeeCount
  /// Cloud 的增量日志，只是把起点拨回 0，符合 BeeCount Cloud 的同步模型。
  Future<int> replayAllChanges() async {
    logger.info('SyncEngine', 'replayAllChanges: 从 0 开始重拉 sync_changes');
    return pull('', sinceOverride: 0);
  }

  // 附件相关方法搬到 sync_engine_attachments.dart 这个 part 文件:
  //   _resetAttachmentCloudRefs / _uploadCategoryIcons / uploadAttachments
  //   downloadAttachments / _getAttachmentFile / _applyWithAttachmentCleanup
  //   _cleanupCategoryIconFilesOnDisk

  /// 新设备全量拉取。
  ///
  /// **in-flight 单飞**:防御性,挡用户连点"下载"按钮时两次并发拉取。
  Future<({int inserted, int deletedDup})> runFullPull(
      {required int ledgerId}) async {
    final inFlight = _fullPullInFlight[ledgerId];
    if (inFlight != null) {
      logger.info(
          'SyncEngine', 'runFullPull(ledger=$ledgerId) 已在执行,复用 in-flight');
      return inFlight.future;
    }
    final completer = Completer<({int inserted, int deletedDup})>();
    completer.future.ignore();
    _fullPullInFlight[ledgerId] = completer;
    try {
      final result = await _doRunFullPull(ledgerId: ledgerId);
      completer.complete(result);
      return result;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (_fullPullInFlight[ledgerId] == completer) {
        _fullPullInFlight.remove(ledgerId);
      }
    }
  }

  Future<({int inserted, int deletedDup})> _doRunFullPull(
      {required int ledgerId}) async {
    logger.info('SyncEngine', '开始全量拉取 ledger=$ledgerId');

    final ledger = await repo.getLedgerById(ledgerId);
    if (ledger == null) throw StateError('Download target ledger does not exist');
    final watermark = await _hydrationWatermark();
    await _checkHydrationEdits(ledger, watermark, includeOwnDictionaries: true);
    final transactions = db.transactions;
    final maxId = transactions.id.max();
    final before = await (db.selectOnly(transactions)..addColumns([maxId]))
        .getSingle();
    final lastId = before.read(maxId) ?? 0;
    // New incremental changes may belong to other ledgers. They cannot repair
    // an older target change that a previous global cursor already skipped.
    await pull(ledgerId.toString());
    await hydrateLedgerFromServer(ledger.syncId ?? ledgerId.toString(),
        recoveryTarget: ledger, journalWatermark: watermark);
    // Both the delta and the snapshot can add transactions. Their local IDs
    // auto-increment, even when the same download also deletes older rows.
    final changes = db.localChanges;
    final localCreates = db.selectOnly(changes)
      ..addColumns([changes.entityId])
      ..where(changes.id.isBiggerThanValue(watermark) &
          changes.ledgerId.equals(ledgerId) &
          changes.entityType.equals('transaction') &
          changes.action.equals('create'));
    final count = transactions.id.count();
    final downloaded = await (db.selectOnly(transactions)
          ..addColumns([count])
          ..where(transactions.ledgerId.equals(ledgerId) &
              transactions.id.isBiggerThanValue(lastId) &
              transactions.id.isNotInQuery(localCreates)))
        .getSingle();
    // 下载附件
    try {
      await downloadAttachments(ledgerId: ledgerId);
    } catch (e, st) {
      logger.error('SyncEngine', '附件下载失败（不阻塞拉取）', e, st);
    }

    return (inserted: downloaded.read(count) ?? 0, deletedDup: 0);
  }

  // ==================== 附件云端同步 ====================
  //
  // uploadAttachments / downloadAttachments / _getAttachmentFile
  // _applyWithAttachmentCleanup / _cleanupCategoryIconFilesOnDisk
  // 这些方法都搬到 sync_engine_attachments.dart 这个 part 文件里了。
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
    required this.categoryAttachments,
    required this.accounts,
    required this.categories,
    required this.tags,
    required this.unpushedChanges,
    this.recentConflicts = 0,
    this.error,
  });

  factory SyncHealthReport.error(String message) => const SyncHealthReport(
        ledgerTx: SyncCountPair.missing(),
        ledgerAttachments: SyncCountPair.missing(),
        ledgerBudgets: SyncCountPair.missing(),
        totalTx: SyncCountPair.missing(),
        totalAttachments: SyncCountPair.missing(),
        totalBudgets: SyncCountPair.missing(),
        categoryAttachments: SyncCountPair.missing(),
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
        categoryAttachments: categoryAttachments,
        accounts: accounts,
        categories: categories,
        tags: tags,
        unpushedChanges: unpushedChanges,
        recentConflicts: recentConflicts,
        error: message,
      );

  /// 当前账本口径。`ledgerAttachments` 只算交易附件(server 端
  /// `attachment_kind='transaction'`),分类自定义图标见 [categoryAttachments]。
  final SyncCountPair ledgerTx;
  final SyncCountPair ledgerAttachments;
  final SyncCountPair ledgerBudgets;

  /// 全量口径(跨当前用户所有账本)。`totalAttachments` 同样只算交易附件。
  final SyncCountPair totalTx;
  final SyncCountPair totalAttachments;
  final SyncCountPair totalBudgets;

  /// 分类自定义图标 — user-global,不分账本。server 端 `attachment_kind=
  /// 'category_icon'`,跨账本只占一份存储。
  final SyncCountPair categoryAttachments;

  /// 用户级实体(per-ledger 跟 total 同值,只留一组)
  final SyncCountPair accounts;
  final SyncCountPair categories;
  final SyncCountPair tags;

  final int unpushedChanges;
  final int recentConflicts;
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
        categoryAttachments.hasDiff ||
        accounts.hasDiff ||
        categories.hasDiff ||
        tags.hasDiff;
  }

  /// 本地比远端多,但没 unpushed change → 绕过 changeTracker 的历史种子数据。
  bool get needsBackfill {
    if (error != null || unpushedChanges > 0) return false;
    if (accounts.remote >= 0 && accounts.local > accounts.remote) return true;
    if (categories.remote >= 0 && categories.local > categories.remote) {
      return true;
    }
    if (tags.remote >= 0 && tags.local > tags.remote) return true;
    return false;
  }
}

/// pull 单页处理结果。详见 [SyncEngine._applyPullPage]。
class _PullPageOutcome {
  const _PullPageOutcome({required this.applied, required this.blocked});

  /// 本页成功 apply 的条数。整页 rollback 时为 0。
  final int applied;

  /// 是否被错误阻塞(整页 rollback,cursor 不推进)。
  final bool blocked;
}
