import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import '../cloud/sync_service.dart';
import 'shared_ledger_providers.dart';
import '../cloud/sync/sync_coordinator.dart';
import '../cloud/sync/sync_engine.dart';
import '../cloud/sync/sync_providers.dart' as sync_p;
import '../cloud/transactions_sync_manager.dart';
import '../models/ledger_display_item.dart';
import '../ai/providers/ai_provider_manager.dart';
import '../pages/ai/ai_provider_manage_page.dart' show aiProviderListRefreshProvider;
import 'ai_config_providers.dart';
import '../services/attachment_service.dart' show attachmentListRefreshProvider;
import '../services/system/logger_service.dart';
import '../services/ui/avatar_service.dart';
import 'theme_providers.dart';
import 'budget_providers.dart';
import 'calendar_providers.dart';
import 'database_providers.dart';
import 'avatar_providers.dart';
import 'tag_providers.dart';
import 'ui_state_providers.dart';
import 'statistics_providers.dart';

/// SyncEngine 对外广播事件流(PR 1 引入)。
///
/// 当前阶段:跟老的 7 个 callback 字段(`onAutoPullCompleted` 等)**并行**运行,
/// 每个 callback fire 点同时 emit 等价 [SyncEvent]。新的 UI caller 应订阅这
/// 个 provider;老 caller 暂保留(PR 2 逐个迁移,PR 3 删 callback)。
///
/// 不是 SyncEngine 模式时返空 stream,订阅者拿不到事件即可。
final StreamProvider<SyncEvent> syncEventStreamProvider =
    StreamProvider<SyncEvent>((ref) {
  final svc = ref.watch(syncServiceProvider);
  if (svc is! SyncEngine) {
    return const Stream<SyncEvent>.empty();
  }
  return svc.events;
});

// 同步状态（根据 ledgerId 与刷新 tick 缓存），避免因 UI 重建重复拉取
final syncStatusProvider =
    FutureProvider.family<SyncStatus, int>((ref, ledgerId) async {
  final sync = ref.watch(syncServiceProvider);
  // 依赖 tick，使得手动刷新时重新获取；否则保持缓存
  ref.watch(syncStatusRefreshProvider);
  ref.watch(syncStatusRefreshByLedgerProvider(ledgerId));

  final status = await sync.getStatus(ledgerId: ledgerId);

  // 写入最近一次成功值，供 UI 在刷新期间显示旧值，避免闪烁
  ref.read(lastSyncStatusProvider(ledgerId).notifier).state = status;
  return status;
});

// 最近一次同步状态缓存（按 ledgerId）
final lastSyncStatusProvider =
    StateProvider.family<SyncStatus?, int>((ref, ledgerId) => null);

/// 同步代数计数器：每次 pull 把远端变更写入本地 Drift 之后 +1。
/// 派生 Provider（首页交易列表/统计/账户等）watch 这个值，即可在增量同步
/// 完成后重新运行，UI 不再读到旧缓存。
///
/// 为什么不直接 `ref.invalidate(watchTransactionsProvider)`：Supabase Realtime
/// 通道绑在同一个 stream provider 上，invalidate 会把通道拆掉再建，反而更慢；
/// 用一个独立 bump 计数器是最便宜的信号。
final syncGenerationProvider = StateProvider<int>((ref) => 0);

/// 最近一次同步错误信息（供 UI 状态栏展示）。
/// PostProcessor / SyncEngine 的 catch 分支把错误写到这里，避免 silent swallow。
final lastSyncErrorProvider = StateProvider<String?>((ref) => null);

// 自动同步开关：值与设置
final autoSyncValueProvider = FutureProvider.autoDispose<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final link = ref.keepAlive();
  ref.onDispose(() => link.close());
  return prefs.getBool('auto_sync') ?? false;
});

class AutoSyncSetter {
  AutoSyncSetter(this._ref);
  final Ref _ref;
  Future<void> set(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', v);
    // 使缓存失效，触发读取最新值
    _ref.invalidate(autoSyncValueProvider);
  }
}

final autoSyncSetterProvider = Provider<AutoSyncSetter>((ref) {
  return AutoSyncSetter(ref);
});

// ====== 云服务配置 ======

final cloudServiceStoreProvider =
    Provider<CloudServiceStore>((_) => CloudServiceStore());

// 当前激活配置（Future，因需读 SharedPreferences）
final activeCloudConfigProvider =
    FutureProvider<CloudServiceConfig>((ref) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadActive();
});

// Supabase配置(不管是否激活)
final supabaseConfigProvider = FutureProvider<CloudServiceConfig?>((ref) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadSupabase();
});

// BeeCount Cloud 配置(不管是否激活)
final beecountCloudConfigProvider =
    FutureProvider<CloudServiceConfig?>((ref) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadBeeCountCloud();
});

// WebDAV配置(不管是否激活)
final webdavConfigProvider = FutureProvider<CloudServiceConfig?>((ref) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadWebdav();
});

// S3配置(不管是否激活)
final s3ConfigProvider = FutureProvider<CloudServiceConfig?>((ref) async {
  final store = ref.watch(cloudServiceStoreProvider);
  return store.loadS3();
});

final authServiceProvider = FutureProvider<CloudAuthService>((ref) async {
  final activeAsync = ref.watch(activeCloudConfigProvider);
  if (!activeAsync.hasValue) {
    return NoopAuthService();
  }

  final config = activeAsync.value!;
  if (!config.valid || config.type == CloudBackendType.local) {
    return NoopAuthService();
  }

  try {
    final services = await createCloudServices(config);
    if (services.auth != null) {
      return services.auth!;
    }
  } catch (e) {
    // 初始化失败，返回 NoopAuthService
  }

  return NoopAuthService();
});

// 防重入锁：避免 Provider 重建导致多个自动同步并发执行
bool _autoSyncInProgress = false;

final syncServiceProvider = Provider<SyncService>((ref) {
  final activeAsync = ref.watch(activeCloudConfigProvider);
  if (!activeAsync.hasValue) return LocalOnlySyncService();

  final config = activeAsync.value!;
  if (!config.valid || config.type == CloudBackendType.local) {
    return LocalOnlySyncService();
  }

  // BeeCount Cloud → SyncEngine（增量同步）
  if (config.type == CloudBackendType.beecountCloud) {
    final providerAsync = ref.watch(beecountCloudProviderInstance);
    if (!providerAsync.hasValue || providerAsync.value == null) {
      // Provider 尚未初始化，返回 LocalOnly 等待
      return LocalOnlySyncService();
    }
    final cloudProvider = providerAsync.value!;
    final db = ref.watch(databaseProvider);
    // SyncEngine 改走 family 缓存唯一实例 — 跟 shared_ledger_providers.dart
    // / join_shared_ledger_page.dart 共享同一 engine。否则两个独立 engine
    // 各跑各的 sync(同一 ledger 1 秒内 2-3 次)。disposal 归 family,这里
    // 不再 ref.onDispose(engine.dispose())。
    final engine = ref.watch(sync_p.syncEngineProvider(cloudProvider));

    // PR 2/3:订阅 SyncEvent stream 替代 7 个 callback 绑定。
    //
    // SyncEngine 完全不知道 Riverpod / widget 存在,只往 events stream 写;
    // 本 listener 把事件 dispatch 到对应的 provider bump / invalidate。
    //
    // 直接订阅 `engine.events` 而不是走 [syncEventStreamProvider] —— 否则会跟
    // syncServiceProvider 形成循环依赖(syncEventStreamProvider 需要 watch
    // syncServiceProvider 拿 engine,syncServiceProvider 又 listen
    // syncEventStreamProvider,运行时 Riverpod 抛 CircularDependencyError)。
    // syncEventStreamProvider 仍然存在,留给 UI/测试直接订阅 SyncEvent 用,
    // 跟本 listener 互不冲突。
    //
    // 历史背景(原 callback 注释保留意图):
    //   - PullCompleted:每次 auto-pull 都 fire(含空 pull),用于刷新各域 tick;
    //     `sharedResourceRefreshProvider` 故意不在这里 bump 避免 home 全局刷新,
    //     它走单独的 SharedResourceChanged event。
    //   - SharedResourceChanged:Owner 共享资源(分类/账户/标签)变了,Editor 端
    //     SharedLedger* 镜像表已更新,UI 应重建。
    //   - AvatarChanged:只在真下载新头像时 fire,不是每次 pull 都触发,避免
    //     冷启动头像闪一下。
    //   - ProfileFieldApplied:server 下来的 theme/income/appearance/aiConfig
    //     回写本地 Riverpod state + SharedPreferences。
    final eventSub = engine.events.listen((event) {
      switch (event) {
        case PullCompleted(:final applied):
          // pulled=0 是大量"空 sync"场景的常态:WS 重连、connectivity 恢复、
          // 自我推送回声被过滤掉、profile_change 触发的 pull、新设备首次绑定
          // 后又被触发的 sync 等等。这些场景下没有任何实质数据变化,如果照样
          // bump 一堆 refresh tick → home/统计/预算/StreamBuilder 全部 cascade
          // rebuild,体感就是"莫名其妙首页全量刷一次"。
          //
          // 真有数据被 apply 时(applied > 0)才走完整刷新链。
          if (applied == 0) break;
          // 同步 bump — 跟 PR3 前的 onAutoPullCompleted callback 等价。配合
          // SyncEngine 的 broadcast(sync: true),listener 收到 emit 后立即同步
          // 执行 state 变更,Flutter framework 把所有 markNeedsBuild 合并到当前
          // 帧的同一次 rebuild,不会跨帧 cascade。
          ref.read(syncStatusRefreshProvider.notifier).state++;
          ref.read(ledgerListRefreshProvider.notifier).state++;
          // currentLedgerProvider 是 FutureProvider,Drift 写入不会自动重算,
          // 远端改名 / 改币种落库后必须显式 invalidate,否则首页 header
          // 等 watch 它的 widget 永远显示旧账本名。
          ref.invalidate(currentLedgerProvider);
          ref.read(syncGenerationProvider.notifier).state++;
          ref.read(statsRefreshProvider.notifier).state++;
          ref.read(budgetRefreshProvider.notifier).state++;
          ref.read(tagListRefreshProvider.notifier).state++;
          ref.read(calendarRefreshProvider.notifier).state++;
          ref.read(attachmentListRefreshProvider.notifier).state++;
          // 切到 Stream 模式 — 否则 Drift 已更新但 TransactionList 仍用
          // Splash 阶段 cache 住的 accountName。不清 cachedTransactionsProvider:
          // 切到 stream 模式后 cache 不再被读取,留旧值给到 stream 推送之前
          // 平滑过渡。
          ref.read(homeSwitchToStreamProvider.notifier).state++;
        case SharedResourceChanged():
          ref.read(sharedResourceRefreshProvider.notifier).state++;
        case AvatarChanged():
          ref.read(avatarRefreshProvider.notifier).state++;
        case ProfileFieldApplied(:final field, :final value):
          switch (field) {
            case ProfileField.themeColor:
              _applyThemeColorFromServer(ref, value as String);
            case ProfileField.incomeColor:
              _applyIncomeColorFromServer(ref, value as bool);
            case ProfileField.appearance:
              _applyAppearanceFromServer(
                  ref, value as Map<String, dynamic>);
            case ProfileField.aiConfig:
              unawaited(() async {
                await AIProviderManager.applyFromServer(
                    value as Map<String, dynamic>);
                try {
                  ref
                      .read(aiCapabilityBindingRefreshProvider.notifier)
                      .state++;
                  ref
                      .read(aiProviderListForCapabilityRefreshProvider
                          .notifier)
                      .state++;
                  ref.read(aiProviderListRefreshProvider.notifier).state++;
                  ref.invalidate(aiConfigProvider);
                } catch (e, st) {
                  logger.warning(
                      'CloudSync', 'AI 配置 apply 后 UI bump 失败: $e', st);
                }
              }());
          }
      }
    });

    // 让 SyncEngine 在 WS 重连 / 网络恢复触发 auto sync 时能拿到当前 ledgerId
    engine.ledgerIdResolver = () {
      final id = ref.read(currentLedgerIdProvider);
      return id > 0 ? id.toString() : '';
    };

    // AI 配置变更时推到 server。包含 providers / binding / custom_prompt /
    // strategy 等;调用在 AIProviderManager 的 save 点。
    AIProviderManager.onConfigChanged = () {
      unawaited(() async {
        try {
          final cloud = await ref.read(beecountCloudProviderInstance.future);
          if (cloud == null) return;
          final snapshot = await AIProviderManager.snapshotForSync();
          await cloud.updateMyProfileAiConfig(aiConfig: snapshot);
          logger.info('CloudSync', 'AI 配置已推送到 server');
        } catch (e, st) {
          logger.warning(
              'CloudSync', 'AI 配置推送失败 (non-blocking): $e', st);
        }
      }());
    };

    engine.startListeningRealtime();

    // §7 共享账本兜底:切账本时(尤其是切回共享账本时)触发一次 sync。
    // 用户报告"切到自己账本再切回来 WS 不同步" — 实际可能 WS 还在但
    // pull 漏了或某次 ws 推送漏了。这里 ref.listen 切账本就主动同步,
    // 跟 _scheduleAutoSync 的 2 秒防抖叠加可以兜住绝大多数边界。
    ref.listen<int>(currentLedgerIdProvider, (prev, next) {
      if (prev == next || next <= 0) return;
      logger.info('SyncProvider',
          'ledger switched $prev → $next, schedule auto sync as fallback');
      engine.triggerAutoSync(reason: 'ledger_switched');
    });

    // 反应式同步触发器:监听 local_changes 表,任何 mutation 写进未推送
    // 行都会自动调度 sync。把"是否触发同步"的责任完全转移到"是否记录
    // 变更"——后者是数据层的天然职责。详见 sync_coordinator.dart 的注释。
    final coordinator = SyncCoordinator(db: db, engine: engine);
    coordinator.start();

    // 监听网络连接状态：从"无网"恢复时触发一次 sync 把离线累积的
    // local_changes 推出去。SyncEngine 内部有 2 秒防抖，WS 重连和 connectivity
    // 恢复几乎同时命中时最终只会触发 1 次 sync。
    Timer? connectivityDebounce;
    final connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (!online) {
        logger.info('SyncProvider', 'connectivity 变为离线, 不触发 sync');
        return;
      }
      // 这里也加一层防抖：WiFi ↔ 移动网络快速切换时 OS 会连打多条事件。
      connectivityDebounce?.cancel();
      connectivityDebounce = Timer(const Duration(milliseconds: 500), () {
        logger.info('SyncProvider', 'connectivity 恢复, 触发 auto sync');
        engine.triggerAutoSync(reason: 'connectivity_restored');
      });
    });

    // 当 Provider 被销毁时停止监听。engine.dispose 归 syncEngineProvider
    // (family),这里只清本 provider 自己持有的资源。
    ref.onDispose(() {
      eventSub.cancel();
      connectivityDebounce?.cancel();
      connectivitySubscription.cancel();
      coordinator.dispose();
    });

    // Profile（含头像）同步和 ledger 同步解耦：新设备首次登录时，用户可能还
    // 没有任何 ledger，`engine.sync(ledgerId)` 因此会被短路，之前的头像同步
    // 代码夹在 sync() 内部永远跑不到。这里直接 fire-and-forget 拉一次 profile。
    // pull 完成后调一次 reconcileProfileToServer,把"server 上缺而本地有"的
    // 字段补推上去(theme / income / appearance / ai_config) —— 用户之前
    // 一直用 A,升级到带同步的版本时本地早就有配置,server 却是空的。
    Future(() async {
      // avatar bump 走 engine.onAvatarChanged 回调,不再用 changed 兜底
      // (changed=true 包含 theme/income/appearance/ai 等任意字段被 apply,
      // 不只是头像,会引发头像组件无谓重渲)。
      await engine.syncMyProfile();
      await reconcileProfileToServer(
        cloudProviderFuture: ref.read(beecountCloudProviderInstance.future),
        currentThemeColor: ref.read(primaryColorProvider),
        currentIncomeIsRed: ref.read(incomeExpenseColorSchemeProvider),
        currentHeaderStyle: ref.read(headerDecorationStyleProvider),
        currentCompactAmount: ref.read(compactAmountProvider),
        currentShowTransactionTime: ref.read(showTransactionTimeProvider),
      );
    });

    // Bootstrap 串行：必须等 `syncLedgersFromServer` 完成（把 A 的账本 2/3/…
    // 插入到 B 本地 ledgers 表）之后，再触发 `engine.sync()` 的 pull。否则
    // pull 到的 tx change 里的 ledger_id 在 B 本地还找不到对应的 ledger 行，
    // 就会被 fallback 成错位的 int id，导致"A 的账本 2 历史交易拉到 B 后
    // 挂到错位或不存在的账本"。
    final currentLedgerId = ref.read(currentLedgerIdProvider);
    logger.info('SyncProvider', 'SyncEngine 就绪, ledgerId=$currentLedgerId');
    if (currentLedgerId > 0 && !_autoSyncInProgress) {
      _autoSyncInProgress = true;
      Future(() async {
        try {
          // Step 1: 先拉账本列表，保证所有 A 的账本已经在 B 本地落库
          int newLedgerCount = 0;
          try {
            newLedgerCount = await engine.syncLedgersFromServer();
            if (newLedgerCount > 0) {
              ref.read(ledgerListRefreshProvider.notifier).state++;
              logger.info(
                  'SyncProvider', '从 server 拉回 $newLedgerCount 个新账本');
            }
          } catch (e, st) {
            logger.warning(
                'SyncProvider', 'syncLedgersFromServer 失败: $e', st);
          }

          // Step 1.5: 如果有新账本插进来，要从 cursor=0 把 sync_changes 重放
          // 一遍。否则 B 设备的全局 cursor 可能已经被早期 pull 推到顶，增量
          // `_pull` 再也拿不回这些账本的历史 tx/category/account。
          // BeeCount Cloud 的 apply 是按 entity_sync_id upsert 幂等的，重放
          // 安全。
          if (newLedgerCount > 0) {
            try {
              final replayed = await engine.replayAllChanges();
              logger.info(
                  'SyncProvider', '重放 sync_changes 应用 $replayed 条历史变更');
            } catch (e, st) {
              logger.warning(
                  'SyncProvider', 'replayAllChanges 失败: $e', st);
            }
          }

          // Step 2: 账本就绪后再跑全量同步。sync() 的 pull 里每条 tx change
          // 都能按 ledger_sync_id / 本地 id fallback 正确映射。
          logger.info('SyncProvider', '开始自动同步 ledger=$currentLedgerId');
          final result = await engine.sync(ledgerId: currentLedgerId.toString());
          if (result.hasError) {
            logger.error('SyncProvider', '自动同步返回错误: ${result.error}');
          } else {
            logger.info('SyncProvider', '自动同步成功: pushed=${result.pushed}, pulled=${result.pulled}');
          }
          ref.read(syncStatusRefreshProvider.notifier).state++;
          ref.read(ledgerListRefreshProvider.notifier).state++;
          ref.read(syncGenerationProvider.notifier).state++;
          ref.read(statsRefreshProvider.notifier).state++;
          ref.read(budgetRefreshProvider.notifier).state++;
          ref.read(tagListRefreshProvider.notifier).state++;
          ref.read(calendarRefreshProvider.notifier).state++;
          ref.read(homeSwitchToStreamProvider.notifier).state++;
          ref.read(cachedTransactionsProvider.notifier).state = null;
          // 不再无条件 bump avatarRefreshProvider — engine.onAvatarChanged
          // 只在真下载头像时触发,避免每次 bootstrap 闪一次头像。
          ref.read(lastSyncErrorProvider.notifier).state = null;
        } catch (e, st) {
          logger.error('SyncProvider', '自动同步异常', e, st);
          ref.read(lastSyncErrorProvider.notifier).state = e.toString();
        } finally {
          _autoSyncInProgress = false;
        }
      });
    } else if (currentLedgerId > 0 && _autoSyncInProgress) {
      logger.info('SyncProvider', '自动同步已在执行中，跳过重复触发');
    } else {
      // 没有 current ledger（一般不会发生）。单独拉一次账本列表兜底。
      Future(() async {
        try {
          final inserted = await engine.syncLedgersFromServer();
          if (inserted > 0) {
            ref.read(ledgerListRefreshProvider.notifier).state++;
            logger.info('SyncProvider', '从 server 拉回 $inserted 个新账本');
          }
        } catch (e, st) {
          logger.warning(
              'SyncProvider', 'syncLedgersFromServer 失败: $e', st);
        }
      });
    }

    return engine;
  }

  // 其他 provider → TransactionsSyncManager（快照同步）
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(repositoryProvider);
  return TransactionsSyncManager(config: config, db: db, repo: repo);
});

/// 已初始化的 BeeCountCloudProvider 实例
/// 用于 SyncEngine 和其他需要直接访问 BeeCount Cloud API 的场景
final beecountCloudProviderInstance =
    FutureProvider<BeeCountCloudProvider?>((ref) async {
  final configAsync = ref.watch(activeCloudConfigProvider);
  if (!configAsync.hasValue) return null;

  final config = configAsync.value!;
  if (!config.valid || config.type != CloudBackendType.beecountCloud) {
    return null;
  }

  try {
    final services = await createCloudServices(config);
    if (services.provider is! BeeCountCloudProvider) return null;
    final provider = services.provider as BeeCountCloudProvider;

    final email = config.beecountCloudEmail;
    final password = config.beecountCloudPassword;

    // 把邮密交给 auth service,让它在任何时刻发现 session 失效都能自动重登。
    // 这是解决"token 过期后必须到配置页点一下才能恢复"的关键:auth service
    // 内部会在 currentUser / requireAccessToken 触发时尝试恢复,不再等 Provider
    // 重建。
    if (services.auth is BeeCountCloudAuthService) {
      (services.auth as BeeCountCloudAuthService).setRecoveryCredentials(
        email: email,
        password: password,
      );
    }

    // 双重保险:构造之后也触发一次 currentUser,让 initialize() 没恢复出
    // session 的场景立刻走一次恢复登录(email+password 有时),减少用户第一次
    // 操作时的卡顿感。currentUser 内部已经自带 _tryRecoveryLogin。
    if (services.auth != null) {
      try {
        final user = await services.auth!.currentUser;
        if (user != null) {
          logger.info('CloudSync', 'BeeCount Cloud session ready: ${user.email}');
        } else if (email != null && email.isNotEmpty) {
          logger.info('CloudSync', 'BeeCount Cloud 未登录,等首次 API 触发恢复');
        }
      } catch (e, st) {
        logger.warning('CloudSync', 'BeeCount Cloud 初始 currentUser 失败: $e', st);
      }
    }
    return provider;
  } catch (e, st) {
    logger.error('CloudSync', 'BeeCountCloudProvider 初始化失败', e, st);
  }
  return null;
});

/// BeeCount Cloud 服务端版本号。Mine 页面 / 云同步页都能直接用;失败就
/// null,UI 自己隐藏。非 BeeCount Cloud 模式直接 null。
///
/// **自动刷新**:依赖 [syncStatusRefreshProvider],每次同步完成会 bump 这个
/// ticker,版本号 provider 重新跑 fetchServerVersion。这样 server 升级后用户
/// 不需要重登/手动到云配置页点确认,下一次同步触发后版本号就更新了。
///
/// /version 是个轻量 endpoint,跟着每次 sync 多发一次 HTTP 请求开销可忽略。
final beecountCloudServerVersionProvider =
    FutureProvider<String?>((ref) async {
  // server 升级后用户在 app 内做任何会触发同步的操作(加交易 / 切账本 / 进
  // Mine 页面 bump refresh 等)都能让版本号刷新。
  ref.watch(syncStatusRefreshProvider);

  final cloud = await ref.watch(beecountCloudProviderInstance.future);
  if (cloud == null) return null;
  try {
    final v = await cloud.fetchServerVersion();
    return v.version.isEmpty ? null : v.version;
  } catch (_) {
    return null;
  }
});

/// 双向对齐 profile:server 上缺失但本地有的字段,把本地推上去。
/// 解决"用户一直在用 A,但 AI 配置 / 主题 / 外观早就设好了,server 从未收到过"
/// 这个"初次开启跨设备同步时对端啥都没有"的坑。
///
/// 运行时机:
///   1. Bootstrap 完成 syncMyProfile 之后 —— 首次开启云同步,自动推上去
///   2. 云同步页下拉深度检测时 —— 用户手动触发,也做一次对账
///
/// 规则:只推 server 为空但本地非默认的字段。不强制覆盖 —— 如果双方都有值,
/// 以 server 为权威(syncMyProfile 里的 apply 已经把 server 值落到本地了)。
///
/// 参数 [read] 接受 Ref.read 或 WidgetRef.read(两者签名相同,共用实现),
/// 这样 bootstrap FutureProvider 和 UI 下拉刷新都能调。
Future<void> reconcileProfileToServer({
  required Future<BeeCountCloudProvider?> cloudProviderFuture,
  required Color currentThemeColor,
  required bool currentIncomeIsRed,
  required String currentHeaderStyle,
  required bool currentCompactAmount,
  required bool currentShowTransactionTime,
}) async {
  try {
    final cloud = await cloudProviderFuture;
    if (cloud == null) return;
    final profile = await cloud.getMyProfile();

    // theme_primary_color
    if (profile.themePrimaryColor == null ||
        profile.themePrimaryColor!.isEmpty) {
      try {
        // ignore: deprecated_member_use
        final hex =
            '#${currentThemeColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
        await cloud.updateMyProfileThemeColor(hex: hex);
        logger.info('CloudSync', 'reconcile: pushed theme_primary_color=$hex');
      } catch (e, st) {
        logger.warning('CloudSync', 'reconcile theme 推送失败: $e', st);
      }
    }

    // income_is_red
    if (profile.incomeIsRed == null) {
      try {
        await cloud.updateMyProfileIncomeColorScheme(
            incomeIsRed: currentIncomeIsRed);
        logger.info('CloudSync',
            'reconcile: pushed income_is_red=$currentIncomeIsRed');
      } catch (e, st) {
        logger.warning('CloudSync', 'reconcile income 推送失败: $e', st);
      }
    }

    // appearance
    if (profile.appearance == null || profile.appearance!.isEmpty) {
      try {
        final appearance = <String, dynamic>{
          'header_decoration_style': currentHeaderStyle,
          'compact_amount': currentCompactAmount,
          'show_transaction_time': currentShowTransactionTime,
        };
        await cloud.updateMyProfileAppearance(appearance: appearance);
        logger.info('CloudSync', 'reconcile: pushed appearance=$appearance');
      } catch (e, st) {
        logger.warning('CloudSync', 'reconcile appearance 推送失败: $e', st);
      }
    }

    // ai_config
    if (profile.aiConfig == null || profile.aiConfig!.isEmpty) {
      try {
        final snapshot = await AIProviderManager.snapshotForSync();
        // 只在本地有实际内容时推 —— 新用户 providers 里只有默认 GLM 且
        // apiKey 为空,推上去也是空壳子,跳过避免污染。
        final providers = snapshot['providers'] as List? ?? const [];
        final hasAnyValidProvider = providers.any((p) =>
            p is Map && (p['apiKey'] as String?)?.isNotEmpty == true);
        if (hasAnyValidProvider) {
          await cloud.updateMyProfileAiConfig(aiConfig: snapshot);
          logger.info('CloudSync',
              'reconcile: pushed ai_config (providers=${providers.length})');
        }
      } catch (e, st) {
        logger.warning('CloudSync', 'reconcile ai_config 推送失败: $e', st);
      }
    }

    // avatar —— 首次上传的坑:老用户本地早就有头像,但 server 上是空的,
    // 之前 reconcile 完全没碰头像逻辑,只 syncMyProfile 里单向下载。
    // 规则:server 没 avatarUrl 且本地存在 avatar 文件 → 上传。避免覆盖 server
    // 更新的头像(server 有就跳过,以 server 为权威)。
    if (profile.avatarUrl == null || profile.avatarUrl!.isEmpty) {
      try {
        final localPath = await AvatarService.getAvatarPath();
        if (localPath != null && await File(localPath).exists()) {
          final bytes = await File(localPath).readAsBytes();
          if (bytes.isNotEmpty) {
            final fileName = localPath.split('/').last;
            final mimeType = fileName.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg';
            final result = await cloud.uploadMyAvatar(
              bytes: bytes,
              fileName: fileName,
              mimeType: mimeType,
            );
            await AvatarService.setStoredRemoteVersion(result.avatarVersion);
            logger.info('CloudSync',
                'reconcile: pushed avatar server_version=${result.avatarVersion}');
          }
        }
      } catch (e, st) {
        logger.warning('CloudSync', 'reconcile avatar 推送失败: $e', st);
      }
    }
  } catch (e, st) {
    logger.warning('CloudSync', 'reconcileProfileToServer 失败: $e', st);
  }
}

// ==================== /profile/me 拉下来的值回写本地的工具函数 ====================
//
// 下面三个函数都由 SyncEngine 的 onThemeColorApplied / onIncomeColorApplied /
// onAppearanceApplied 回调触发:先比对当前值,不同才写。写 Riverpod state 会
// 触发 theme_providers 里的 ref.listen,那段 listener 原本会推送回 server ——
// "写了相同值不再触发" 的保证由 Riverpod 自己给,StateProvider 收到相同值不
// 会 notify。所以只要我们正确跳过"相同值",就不会产生 echo 循环。

void _applyThemeColorFromServer(Ref ref, String hex) {
  try {
    final normalized = hex.startsWith('#') ? hex : '#$hex';
    final code = int.tryParse(normalized.substring(1), radix: 16);
    if (code == null) return;
    final currentColor = ref.read(primaryColorProvider);
    final nextColor = Color(0xFF000000 | code);
    // ignore: deprecated_member_use
    if (currentColor.value == nextColor.value) return;
    ref.read(primaryColorProvider.notifier).state = nextColor;
    logger.info('profile_sync', 'applied theme_primary_color from server: $normalized');
  } catch (e, st) {
    logger.warning('profile_sync', 'apply theme color failed: $e', st);
  }
}

void _applyIncomeColorFromServer(Ref ref, bool incomeIsRed) {
  final current = ref.read(incomeExpenseColorSchemeProvider);
  if (current == incomeIsRed) return;
  ref.read(incomeExpenseColorSchemeProvider.notifier).state = incomeIsRed;
  logger.info('profile_sync', 'applied income_is_red from server: $incomeIsRed');
}

void _applyAppearanceFromServer(Ref ref, Map<String, dynamic> appearance) {
  final headerStyle = appearance['header_decoration_style'] as String?;
  if (headerStyle != null && headerStyle.isNotEmpty) {
    final current = ref.read(headerDecorationStyleProvider);
    if (current != headerStyle) {
      ref.read(headerDecorationStyleProvider.notifier).state = headerStyle;
    }
  }
  final compact = appearance['compact_amount'] as bool?;
  if (compact != null) {
    final current = ref.read(compactAmountProvider);
    if (current != compact) {
      ref.read(compactAmountProvider.notifier).state = compact;
    }
  }
  final showTime = appearance['show_transaction_time'] as bool?;
  if (showTime != null) {
    final current = ref.read(showTransactionTimeProvider);
    if (current != showTime) {
      ref.read(showTransactionTimeProvider.notifier).state = showTime;
    }
  }
  logger.info('profile_sync', 'applied appearance from server: $appearance');
}

// 用于触发设置页同步状态的刷新（每次 +1 即可触发 FutureBuilder 重新获取）
final syncStatusRefreshProvider = StateProvider<int>((ref) => 0);

/// 按账本触发同步状态刷新（用于远端增量拉取后的局部刷新）
final syncStatusRefreshByLedgerProvider =
    StateProvider.family<int, int>((ref, _) => 0);

/// 按账本触发页面数据刷新（减少全局刷新带来的闪烁）
final ledgerDataRefreshByLedgerProvider =
    StateProvider.family<int, int>((ref, _) => 0);

/// 按账本记录"远端变更应用中"状态，用于页面局部防闪渲染
final remoteApplyInProgressByLedgerProvider =
    StateProvider.family<bool, int>((ref, _) => false);

/// 待重试的头像上传本地路径
final pendingAvatarUploadPathProvider = StateProvider<String?>((ref) => null);

/// 最近一次头像上传失败信息（用于云同步页提示）
final pendingAvatarUploadErrorProvider = StateProvider<String?>((ref) => null);

/// 当前用户云端资料
final cloudMyProfileProvider =
    FutureProvider<BeeCountCloudProfile?>((ref) async {
  ref.watch(syncStatusRefreshProvider);
  final config = await ref.watch(activeCloudConfigProvider.future);
  if (!config.valid || config.type != CloudBackendType.beecountCloud) {
    return null;
  }
  // TODO(cloud-v2): 在 Phase 2 通过 SyncEngine 获取用户资料
  return null;
});

// ====== 账本同步相关 ======

/// 刷新账本列表的触发器
final ledgerListRefreshProvider = StateProvider<int>((ref) => 0);

/// 当前正在上传的账本ID集合
final uploadingLedgerIdsProvider = StateProvider<Set<int>>((ref) => {});

/// 本地账本列表（快速，仅本地）
final localLedgersProvider =
    FutureProvider<List<LedgerDisplayItem>>((ref) async {
  // 监听刷新触发器（账本列表和统计信息）
  ref.watch(ledgerListRefreshProvider);
  ref.watch(statsRefreshProvider); // 监听统计刷新，确保自动记账后刷新

  try {
    final repo = ref.watch(repositoryProvider);

    // 获取账户功能开启状态
    final accountFeatureEnabled =
        await ref.watch(accountFeatureEnabledProvider.future);

    final localLedgers = await repo.getAllLedgers();

    final result = <LedgerDisplayItem>[];
    for (final ledger in localLedgers) {
      final stats = await repo.getLedgerStats(
        ledgerId: ledger.id,
        accountFeatureEnabled: accountFeatureEnabled,
      );

      result.add(LedgerDisplayItem.fromLocal(
        id: ledger.id,
        name: ledger.name,
        currency: ledger.currency,
        createdAt: ledger.createdAt,
        transactionCount: stats.transactionCount,
        balance: stats.balance,
        isShared: ledger.isShared,
        memberCount: ledger.memberCount,
        myRole: ledger.myRole,
      ));
    }

    return result;
  } catch (e, stackTrace) {
    logger.error('LocalLedgers', '获取本地账本列表失败', e, stackTrace);
    return [];
  }
});

/// 远程账本列表（慢速，网络请求）
///
/// 调用 BeeCount Cloud 的 `/read/ledgers` 取 server 上当前用户所有账本，再
/// 跟本地 Drift ledgers 表按 `syncId` 对齐，把**已经在本地存在**的那部分过滤
/// 掉，只把**纯远程**的账本作为 remote-only 展示在账本页。
///
/// 这样自动 bootstrap 拉不下来的账本（网络抖动 / 竞态 / 后续新建等），
/// 用户点一下列表里的 "远程账本" 就能手动恢复。
final remoteLedgersProvider =
    FutureProvider<List<LedgerDisplayItem>>((ref) async {
  // 监听刷新触发器
  ref.watch(ledgerListRefreshProvider);

  final activeAsync = ref.watch(activeCloudConfigProvider);
  if (!activeAsync.hasValue) return const [];
  final config = activeAsync.value!;
  if (!config.valid || config.type != CloudBackendType.beecountCloud) {
    return const [];
  }

  final providerAsync = ref.watch(beecountCloudProviderInstance);
  if (!providerAsync.hasValue || providerAsync.value == null) {
    return const [];
  }
  final cloudProvider = providerAsync.value!;

  // 未登录不查（readLedgers 会 401）
  try {
    final user = await cloudProvider.auth.currentUser;
    if (user == null) return const [];
  } catch (_) {
    return const [];
  }

  try {
    final remote = await cloudProvider.readLedgers();

    // 本地已有的 syncId 集合，用来过滤掉"已下载过"的账本
    final repo = ref.read(repositoryProvider);
    final localLedgers = await repo.getAllLedgers();
    final localSyncIds = <String>{
      for (final l in localLedgers)
        if (l.syncId != null && l.syncId!.isNotEmpty) l.syncId!,
    };

    final out = <LedgerDisplayItem>[];
    for (final r in remote) {
      if (r.ledgerId.isEmpty) continue;
      if (localSyncIds.contains(r.ledgerId)) continue;
      // 共享账本不出现在"远端账本"列表 — 远端账本是单人账本的备份恢复
      // 概念,共享账本是动态成员关系,只能通过"加入共享账本"流程进入。
      // Editor "仅删除本地"等同于退出账本(走 DELETE /members/self),
      // 不应再显示让用户重复"恢复",会绕开 server 的 membership 校验。
      if (r.isShared) continue;
      out.add(LedgerDisplayItem.fromRemote(
        remoteSyncId: r.ledgerId,
        name: r.ledgerName.isEmpty ? '(unnamed)' : r.ledgerName,
        currency: r.currency,
        updatedAt: r.updatedAt ?? DateTime.now(),
        transactionCount: r.transactionCount,
        balance: r.incomeTotal - r.expenseTotal,
      ));
    }
    return out;
  } catch (e, st) {
    logger.warning('SyncProvider', 'remoteLedgersProvider: readLedgers 失败: $e', st);
    return const [];
  }
});

/// 账本列表（带刷新支持）- 兼容旧代码
final allLedgersProvider = FutureProvider<List<LedgerDisplayItem>>((ref) async {
  // 监听刷新触发器
  ref.watch(ledgerListRefreshProvider);

  try {
    final repo = ref.watch(repositoryProvider);
    final localLedgers = await repo.getAllLedgers();

    final result = <LedgerDisplayItem>[];
    for (final ledger in localLedgers) {
      final stats = await repo.getLedgerStats(
        ledgerId: ledger.id,
        accountFeatureEnabled: false,
      );

      result.add(LedgerDisplayItem.fromLocal(
        id: ledger.id,
        name: ledger.name,
        currency: ledger.currency,
        createdAt: ledger.createdAt,
        transactionCount: stats.transactionCount,
        balance: stats.balance,
        isShared: ledger.isShared,
        memberCount: ledger.memberCount,
        myRole: ledger.myRole,
      ));
    }

    return result;
  } catch (e, stackTrace) {
    logger.error('AllLedgers', '获取账本列表失败', e, stackTrace);
    return [];
  }
});
