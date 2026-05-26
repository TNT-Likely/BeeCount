import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/main/home_page.dart';
import 'pages/main/analytics_page.dart';
import 'pages/account/accounts_page.dart';
import 'pages/main/mine_page.dart';
import 'pages/transaction/transaction_editor_page.dart';
import 'providers.dart';
import 'l10n/app_localizations.dart';
import 'widget/widget_manager.dart';
import 'widgets/ui/ui.dart';
import 'widgets/ui/speed_dial_fab.dart';
import 'cloud/sync_service.dart';
import 'cloud/transactions_sync_manager.dart';
import 'cloud/sync/sync_engine.dart';
import 'providers/sync_providers.dart' as sp;
import 'utils/voice_billing_helper.dart';
import 'utils/image_billing_helper.dart';
import 'ai/providers/ai_constants.dart';
import 'pages/ai/ai_chat_page.dart';
import 'services/platform/app_link_service.dart';
import 'services/platform/quick_actions_service.dart';
import 'services/system/logger_service.dart';
import 'services/security/app_lock_service.dart';
import 'providers/security_providers.dart';
import 'styles/tokens.dart';
import 'providers/avatar_providers.dart';

class BeeApp extends ConsumerStatefulWidget {
  const BeeApp({super.key});

  @override
  ConsumerState<BeeApp> createState() => _BeeAppState();
}

class _BeeAppState extends ConsumerState<BeeApp>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _pages = const [
    HomePage(),
    AnalyticsPage(),
    AccountsPage(asTab: true),
    MinePage(),
  ];

  // 双击检测：记录最后一次点击的时间和索引
  DateTime? _lastTapTime;
  int? _lastTappedIndex;

  // 双击返回退出：记录最后一次返回键按下时间
  DateTime? _lastBackPressTime;

  // AppLink 监听订阅
  ProviderSubscription<AppLinkAction?>? _appLinkSubscription;

  // 快捷操作服务
  final QuickActionsService _quickActionsService = QuickActionsService();

  // 防止 AppLink 动作重复执行（使用静态变量，跨实例共享）
  static bool _isHandlingAppLink = false;
  static DateTime? _lastAppLinkHandleTime;

  // 记账按钮相关状态
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  int? _hoveredIndex;
  OverlayEntry? _overlayEntry;
  final GlobalKey _centerButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 初始化记账按钮动画控制器
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOut,
    );

    // 后台刷新账本同步状态
    _refreshLedgersStatusInBackground();
    // 延迟监听 AppLink，确保 context 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAppLinkListener();
      _setupQuickActions();
    });
  }

  /// 设置快捷操作
  void _setupQuickActions() {
    logger.info('QuickActions', 'BeeApp: 设置快捷操作服务...');
    _quickActionsService.onNavigate = (action) {
      if (mounted) {
        logger.info('QuickActions', 'BeeApp: 执行快捷操作 $action');
        _handleAppLinkAction(context, action);
      }
    };
    _quickActionsService.initialize();
    // 处理可能在初始化前就触发的快捷操作
    _quickActionsService.processPendingAction();
    logger.info('QuickActions', 'BeeApp: 快捷操作服务已设置');
  }

  /// 设置 AppLink 监听
  void _setupAppLinkListener() {
    logger.info('AppLink', 'BeeApp: 设置 AppLink 监听...');
    _appLinkSubscription = ref.listenManual<AppLinkAction?>(
      pendingAppLinkActionProvider,
      (previous, next) {
        logger.info('AppLink',
            'BeeApp: 监听触发 previous=$previous, next=$next, mounted=$mounted');
        if (next != null && mounted) {
          logger.info('AppLink', 'BeeApp: 执行动作 $next');
          _handleAppLinkAction(context, next);
          // 清除待处理动作
          ref.read(pendingAppLinkActionProvider.notifier).state = null;
        }
      },
      fireImmediately: true,
    );
    logger.info('AppLink', 'BeeApp: AppLink 监听已设置');
  }

  /// 后台刷新账本同步状态 / 触发首次同步
  ///
  /// 坑点：syncServiceProvider 只在 cloud_sync_page 里被 watch。重启 app 后
  /// 这里是一次 ref.read，等 beecountCloudProviderInstance 异步就绪再重建时没有
  /// 监听者，provider 内部的 auto-sync 块永远跑不到 —— 用户看到"app 启动没同步本地
  /// 数据到 BeeCount Cloud"。这里 listenManual 保持 provider 活跃，并在它从占位
  /// 对象变成真正的 SyncEngine 时主动触发一次 sync。
  void _refreshLedgersStatusInBackground() {
    // 冷启动时先 eager-await beecountCloudProviderInstance 一次，强制让这个
    // FutureProvider 真正跑起来。否则只是"被定义"但没人读，
    // BeeCountCloudAuthService.initialize() 永远不会跑，session 不会从
    // SharedPreferences 恢复 —— 就是之前用户感受到的"必须打开配置保存才会
    // 登录"bug 的根因。后面的 listenManual 再做后续响应式逻辑。
    Future.microtask(() async {
      try {
        await ref.read(sp.beecountCloudProviderInstance.future);
      } catch (_) {
        // 非 BeeCount Cloud 配置或初始化失败：忽略，让下面的 listenManual 兜住。
      }
    });

    // 启动同步走 `Future.microtask` 而**不是** `addPostFrameCallback`。
    //
    // 历史:之前为了首屏更快试过 addPostFrameCallback,首帧渲染完才开始 sync,
    // 代价是 sync 完成后 bump 一堆 refresh ticker → home 已渲染好的内容触发
    // 二次 cascade rebuild,FutureProvider invalidate 走 loading→data 切换,
    // 用户感知"进首页 → 出现预算卡片 / 列表展开 → 整页刷新一遍"。
    //
    // 改回 microtask:让 sync 在首屏渲染**之前**就开始抢占主线程跑,首屏出
    // 来时 ticker bump 已经发生或正在发生,跟首屏渲染叠加成单次"加载",没
    // 有"先显示后又刷新"的二次绘制感。Phase1/Phase2 分层结构保留(下面的
    // `_triggerInitialCloudSync` 还是分层并行,避免多账本场景重复跑用户级
    // 操作),只换了 trigger 时机。
    Future.microtask(() async {
      try {
        final syncService = ref.read(syncServiceProvider);
        if (syncService is TransactionsSyncManager) {
          await syncService.refreshAllLedgersStatus();
          ref.read(ledgerListRefreshProvider.notifier).state++;
        } else if (syncService is SyncEngine) {
          _triggerInitialCloudSync(syncService);
        }
      } catch (e) {
        // 静默失败,不影响 App 启动
      }
    });

    // 持续监听 syncServiceProvider：即使第一次读到的是 LocalOnly（配置尚未加载）
    // 也能在 SyncEngine 实例就绪后再触发一次同步。
    ref.listenManual<SyncService>(
      syncServiceProvider,
      (prev, next) {
        if (prev is SyncEngine || next is! SyncEngine) return;
        _triggerInitialCloudSync(next);
      },
      fireImmediately: false,
    );
  }

  void _triggerInitialCloudSync(SyncEngine engine) {
    Future(() async {
      try {
        // 启动同步分层策略(2026-05-24 改造):
        //
        // 旧实现 `for (ledger in ledgers) { engine.sync(ledger) }` 串行 5
        // 次完整 sync,每次内部都跑 `syncMyProfile` / `storage.list` / `pull`
        // 等**用户级**操作(跟 ledgerId 无关),5 次重复浪费;且串行 HTTP 任
        // 一慢就累积卡 UI。
        //
        // 改造:
        //   Phase 1 — 用户级数据(只跑一次,跨 ledger 共享)
        //     a. syncMyProfile         HTTP profile/me
        //     b. storage.list          HTTP /sync/ledgers 拿远端账本列表
        //     c. pull                  HTTP /sync/pull 用户级 sync_changes 流
        //   Phase 2 — 每个 ledger 并行(push + 附件上下行)
        //     a. fast skip:无 unpushed change + 已在远端 → 跳
        //     b. 否则:uploadAttachments + push + downloadAttachments
        //   并发限制由 SQLite mutex 自然控制(Drift 内部排队,不会真并发写)
        final db = ref.read(databaseProvider);
        final ledgers = await db.select(db.ledgers).get();
        if (ledgers.isEmpty) {
          logger.info('AppStart', '本地无账本,跳过首次同步');
          return;
        }
        logger.info('AppStart',
            'BeeCount Cloud 首次同步: 本地账本数=${ledgers.length}');
        final overallStart = DateTime.now();

        // ========== Phase 1: 用户级一次性 ==========
        // a) profile + appearance + AI config + avatar
        unawaited(() async {
          try {
            await engine.syncMyProfile();
          } catch (e, st) {
            logger.warning('AppStart', 'syncMyProfile 失败', st);
            logger.warning('AppStart', 'error: $e');
          }
        }());

        // b) 远端账本列表(单次拉,所有 ledger 用同一份决定 fullPush)
        List<dynamic>? remoteLedgers;
        try {
          remoteLedgers = await engine.provider.storage.list(path: '');
          logger.info(
              'AppStart', 'Phase1: 远端账本=${remoteLedgers.length}');
        } catch (e, st) {
          logger.warning('AppStart', 'Phase1: 拉 remote_ledgers 失败,fallback', st);
          logger.warning('AppStart', 'error: $e');
        }

        // c) 用户级 sync_changes 流(只拉一次,所有 ledger 共享 cursor)
        try {
          final pulled = await engine.pull('');
          logger.info('AppStart', 'Phase1: pull(用户级) applied=$pulled');
        } catch (e, st) {
          logger.error('AppStart', 'Phase1: pull 失败', e, st);
        }

        // ========== Phase 2: 每个 ledger 并行 push + 附件 ==========
        final remoteSyncIds = <String>{
          if (remoteLedgers != null)
            for (final r in remoteLedgers)
              if (r.path is String) r.path as String,
        };

        final futures = ledgers.map((ledger) async {
          final tag = '${ledger.name}(${ledger.id})';
          try {
            final unpushed = await engine.changeTracker
                .getUnpushedChangesForLedger(ledger.id);
            final mySyncId = ledger.syncId;
            final hasSyncId = mySyncId != null && mySyncId.isNotEmpty;
            final inRemote = hasSyncId && remoteSyncIds.contains(mySyncId);

            // fast skip:无待推送 + 已在远端 + 非共享 Editor 或 Owner
            if (unpushed.isEmpty && inRemote) {
              logger.info('AppStart', 'Phase2 skip $tag (无待推送 + 已绑定)');
              return _LedgerSyncResult.skip();
            }

            // 共享账本 Editor:只 push 自己的 unpushed change,不 fullPush
            // (会覆盖 Owner 数据)
            final isSharedAsEditor =
                ledger.isShared && ledger.myRole != 'owner';

            // 需要 fullPush:非 Editor 且账本不在远端
            if (!inRemote && !isSharedAsEditor) {
              logger.info('AppStart', 'Phase2 $tag → fullPush');
              try {
                await engine.uploadAttachments(ledgerId: ledger.id);
              } catch (e, st) {
                logger.warning('AppStart', '$tag uploadAttachments 失败', st);
                logger.warning('AppStart', 'error: $e');
              }
              await engine.fullPush(ledgerId: ledger.id);
              // 推剩余 delete change
              final extra = await engine.push(ledger.id.toString());
              try {
                await engine.downloadAttachments(ledgerId: ledger.id);
              } catch (e, st) {
                logger.warning('AppStart', '$tag downloadAttachments 失败', st);
                logger.warning('AppStart', 'error: $e');
              }
              return _LedgerSyncResult(pushed: extra + 1, pulled: 0);
            }

            // 普通 push 路径:有 unpushed 才走附件 + push
            try {
              await engine.uploadAttachments(ledgerId: ledger.id);
            } catch (e, st) {
              logger.warning('AppStart', '$tag uploadAttachments 失败', st);
              logger.warning('AppStart', 'error: $e');
            }
            final pushed = await engine.push(ledger.id.toString());
            try {
              await engine.downloadAttachments(ledgerId: ledger.id);
            } catch (e, st) {
              logger.warning('AppStart', '$tag downloadAttachments 失败', st);
              logger.warning('AppStart', 'error: $e');
            }
            logger.info('AppStart', 'Phase2 $tag done: pushed=$pushed');
            return _LedgerSyncResult(pushed: pushed, pulled: 0);
          } catch (e, st) {
            logger.error('AppStart', 'Phase2 $tag 异常', e, st);
            return _LedgerSyncResult(pushed: 0, pulled: 0);
          }
        });
        final results = await Future.wait(futures);

        final totalPushed = results.fold<int>(0, (a, b) => a + b.pushed);
        final skipped = results.where((r) => r.skipped).length;
        final totalMs =
            DateTime.now().difference(overallStart).inMilliseconds;
        logger.info('AppStart',
            'BeeCount Cloud 首次同步完成: synced=${ledgers.length - skipped} skipped=$skipped pushed=$totalPushed 总耗时 ${totalMs}ms');
        ref.read(syncStatusRefreshProvider.notifier).state++;
        ref.read(ledgerListRefreshProvider.notifier).state++;
      } catch (e, st) {
        logger.error('AppStart', 'BeeCount Cloud 首次同步异常', e, st);
      }
    });
  }

  /// 处理 AppLink 动作
  void _handleAppLinkAction(BuildContext context, AppLinkAction action) {
    // 防止重复执行（使用时间戳和标志双重检查）
    final now = DateTime.now();
    if (_isHandlingAppLink ||
        (_lastAppLinkHandleTime != null &&
            now.difference(_lastAppLinkHandleTime!) <
                const Duration(seconds: 1))) {
      logger.info('AppLink', 'BeeApp: 忽略重复的动作 $action');
      return;
    }
    _isHandlingAppLink = true;
    _lastAppLinkHandleTime = now;

    // 延迟重置标志，允许下一次动作
    Future.delayed(const Duration(seconds: 1), () {
      _isHandlingAppLink = false;
    });

    switch (action) {
      case AppLinkAction.voice:
        // 打开语音记账
        VoiceBillingHelper.startVoiceBilling(context, ref);
        break;
      case AppLinkAction.image:
        // 打开图片记账（从相册）
        ImageBillingHelper.pickImageForBilling(context, ref);
        break;
      case AppLinkAction.camera:
        // 打开拍照记账
        ImageBillingHelper.openCameraForBilling(context, ref);
        break;
      case AppLinkAction.aiChat:
        // 打开 AI 小助手
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AIChatPage()),
        );
        break;
      case AppLinkAction.newTransaction:
        // 打开手动记账页面（从小组件快捷入口）
        final type = ref.read(pendingNewTransactionTypeProvider) ?? 'expense';
        ref.read(pendingNewTransactionTypeProvider.notifier).state = null;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionEditorPage(initialKind: type),
          ),
        );
        break;
      default:
        // 其他动作在 AppLinkService 中已处理
        break;
    }
  }

  /// 检查语音识别是否可用（需要开启AI智能识别并配置GLM API Key）
  Future<bool> _checkGlmApiKeyConfigured() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final aiEnabled =
          prefs.getBool(AIConstants.keyAiBillExtractionEnabled) ?? false;
      final apiKey = prefs.getString(AIConstants.keyGlmApiKey) ?? '';
      return aiEnabled && apiKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _appLinkSubscription?.close();
    _removeOverlay();
    _expandController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _expandController.forward();
    _showOverlay();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _updateHoveredIndex(details.globalPosition);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    final centerActions = [
      SpeedDialAction(
        icon: Icons.camera_alt_rounded,
        label: AppLocalizations.of(context).fabActionCamera,
        onTap: () => ImageBillingHelper.openCameraForBilling(context, ref),
      ),
      SpeedDialAction(
        icon: Icons.photo_library_rounded,
        label: AppLocalizations.of(context).fabActionGallery,
        onTap: () => ImageBillingHelper.pickImageForBilling(context, ref),
      ),
      SpeedDialAction(
        icon: Icons.mic_rounded,
        label: AppLocalizations.of(context).fabActionVoice,
        onTap: () => VoiceBillingHelper.startVoiceBilling(context, ref),
      ),
    ];

    if (_hoveredIndex != null && _hoveredIndex! < centerActions.length) {
      final action = centerActions[_hoveredIndex!];
      if (action.enabled && action.onTap != null) {
        action.onTap!();
      }
    }

    _hoveredIndex = null;
    _expandController.reverse();
    _removeOverlay();
  }

  void _showOverlay() {
    final RenderBox? renderBox =
        _centerButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => _SpeedDialOverlay(
        buttonPosition: position,
        buttonSize: size,
        actions: [
          SpeedDialAction(
            icon: Icons.camera_alt_rounded,
            label: AppLocalizations.of(context).fabActionCamera,
            onTap: () => ImageBillingHelper.openCameraForBilling(context, ref),
          ),
          SpeedDialAction(
            icon: Icons.photo_library_rounded,
            label: AppLocalizations.of(context).fabActionGallery,
            onTap: () => ImageBillingHelper.pickImageForBilling(context, ref),
          ),
          SpeedDialAction(
            icon: Icons.mic_rounded,
            label: AppLocalizations.of(context).fabActionVoice,
            onTap: () => VoiceBillingHelper.startVoiceBilling(context, ref),
          ),
        ],
        animation: _expandAnimation,
        hoveredIndex: _hoveredIndex,
        backgroundColor: ref.read(primaryColorProvider),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateHoveredIndex(Offset globalPosition) {
    final RenderBox? renderBox =
        _centerButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final buttonPosition = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;
    final buttonCenter = Offset(
      buttonPosition.dx + buttonSize.width / 2,
      buttonPosition.dy + buttonSize.height / 2,
    );

    final angles = [210.0, 270.0, 330.0];
    const distance = 85.0;
    const buttonRadius = 26.0;

    int? newHoveredIndex;
    for (int i = 0; i < 3 && i < angles.length; i++) {
      final angle = angles[i];
      final radians = angle * 3.14159265359 / 180;
      final offsetX = distance * _cos(radians);
      final offsetY = distance * _sin(radians);

      final actionCenter = Offset(
        buttonCenter.dx + offsetX,
        buttonCenter.dy + offsetY,
      );

      final dx = globalPosition.dx - actionCenter.dx;
      final dy = globalPosition.dy - actionCenter.dy;
      final distanceToButton = _sqrt(dx * dx + dy * dy);

      if (distanceToButton <= buttonRadius) {
        newHoveredIndex = i;
        break;
      }
    }

    if (newHoveredIndex != _hoveredIndex) {
      setState(() {
        _hoveredIndex = newHoveredIndex;
      });
      _overlayEntry?.markNeedsBuild();
    }
  }

  static double _cos(double x) {
    x = x % (2 * 3.14159265359);
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double _sin(double x) {
    x = x % (2 * 3.14159265359);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _sqrt(double x) {
    if (x < 0) return double.nan;
    if (x == 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive) {
      // 多任务切换时显示隐私模糊屏（仅在应用锁启用时）
      if (ref.read(appLockEnabledProvider)) {
        ref.read(showPrivacyScreenProvider.notifier).state = true;
      }
    } else if (state == AppLifecycleState.paused) {
      // 记录进入后台时间
      AppLockService.recordBackgroundTime();
    } else if (state == AppLifecycleState.resumed) {
      // 移除隐私模糊屏
      ref.read(showPrivacyScreenProvider.notifier).state = false;
      // 检查是否需要锁定
      _checkAppLockOnResume();
      // 当app从后台恢复到前台时，更新小组件数据
      _updateWidget();
    }
  }

  Future<void> _checkAppLockOnResume() async {
    final shouldLock = await AppLockService.shouldLockOnResume();
    if (shouldLock && mounted) {
      ref.read(isAppLockedProvider.notifier).state = true;
    }
  }

  Future<void> _updateWidget() async {
    try {
      final repository = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);
      final primaryColor = ref.read(primaryColorProvider);
      final redForIncome = ref.read(incomeExpenseColorSchemeProvider);

      final widgetManager = WidgetManager();
      await widgetManager.updateWidget(
        repository,
        ledgerId,
        primaryColor,
        redForIncome: redForIncome,
      );
      print('✅ App恢复前台，小组件数据已更新');
    } catch (e) {
      print('❌ 更新小组件失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = ref.watch(bottomTabIndexProvider);
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final avatarPath = ref.watch(avatarPathProvider).asData?.value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;

        final now = DateTime.now();

        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          showToast(context, l10n.commonPressAgainToExit);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            extendBody: true, // 让页面内容延伸到底部栏后面
            body: IndexedStack(
              index: idx,
              children: _pages,
            ),
            bottomNavigationBar: _BeeBottomBar(
              currentIndex: idx,
              primaryColor: primaryColor,
              isDark: isDark,
              bottomPadding: bottomPadding,
              l10n: l10n,
              avatarPath: avatarPath,
              centerButtonKey: _centerButtonKey,
              onTabTap: (index) {
                final now = DateTime.now();
                if (_lastTappedIndex == index &&
                    _lastTapTime != null &&
                    now.difference(_lastTapTime!) <
                        const Duration(milliseconds: 300)) {
                  if (index == 0) {
                    ref.read(homeScrollToTopProvider.notifier).state++;
                  }
                  _lastTapTime = null;
                  _lastTappedIndex = null;
                } else {
                  _lastTapTime = now;
                  _lastTappedIndex = index;
                  ref.read(bottomTabIndexProvider.notifier).state = index;
                }
              },
              onCenterTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TransactionEditorPage(
                      initialKind: 'expense',
                      quickAdd: true,
                    ),
                  ),
                );
              },
              onCenterLongPressStart: _onLongPressStart,
              onCenterLongPressMoveUpdate: _onLongPressMoveUpdate,
              onCenterLongPressEnd: _onLongPressEnd,
            ),
          ),
          // 开发模式下的主题切换按钮
          if (kDebugMode)
            Positioned(
              right: 16,
              bottom: 100,
              child: FloatingActionButton.small(
                heroTag: 'themeSwitcher',
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                onPressed: () {
                  final current = ref.read(themeModeProvider);
                  final next = current == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                  ref.read(themeModeProvider.notifier).state = next;
                },
                child: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Telegram 风格悬浮胶囊底部导航栏
class _BeeBottomBar extends StatelessWidget {
  final int currentIndex;
  final Color primaryColor;
  final bool isDark;
  final double bottomPadding;
  final AppLocalizations l10n;
  final String? avatarPath;
  final GlobalKey centerButtonKey;
  final ValueChanged<int> onTabTap;
  final VoidCallback onCenterTap;
  final GestureLongPressStartCallback onCenterLongPressStart;
  final GestureLongPressMoveUpdateCallback onCenterLongPressMoveUpdate;
  final GestureLongPressEndCallback onCenterLongPressEnd;

  const _BeeBottomBar({
    required this.currentIndex,
    required this.primaryColor,
    required this.isDark,
    required this.bottomPadding,
    required this.l10n,
    this.avatarPath,
    required this.centerButtonKey,
    required this.onTabTap,
    required this.onCenterTap,
    required this.onCenterLongPressStart,
    required this.onCenterLongPressMoveUpdate,
    required this.onCenterLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = BeeTokens.tabBarBackground(context);
    final inactiveColor = isDark ? Colors.white70 : Colors.black54;

    const barHeight = 56.0;

    return SizedBox(
      height: barHeight + bottomPadding + 12, // 12dp 浮动间距
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomPadding + 12,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: BeeTokens.tabBarShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Row(
              children: [
                _buildTabItem(
                    0, Icons.receipt_long_outlined, Icons.receipt_long, l10n.tabHome, inactiveColor),
                _buildTabItem(1, Icons.pie_chart_outline_rounded,
                    Icons.pie_chart_rounded, l10n.tabInsights, inactiveColor),
                // 中间记账按钮（作为 Tab 样式）
                _buildCenterTabItem(inactiveColor),
                _buildTabItem(2, Icons.account_balance_wallet_outlined,
                    Icons.account_balance_wallet, l10n.tabAssets, inactiveColor),
                _buildAvatarTabItem(3, l10n.tabMine, inactiveColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(
      int index, IconData icon, IconData activeIcon, String label, Color inactiveColor) {
    final isActive = index == currentIndex;
    final iconColor = isActive ? primaryColor : inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTabTap(index),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? primaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isActive ? activeIcon : icon, color: iconColor, size: 22),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? primaryColor : inactiveColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterTabItem(Color inactiveColor) {
    return Expanded(
      child: GestureDetector(
        key: centerButtonKey,
        behavior: HitTestBehavior.opaque,
        onTap: onCenterTap,
        onLongPressStart: onCenterLongPressStart,
        onLongPressMoveUpdate: onCenterLongPressMoveUpdate,
        onLongPressEnd: onCenterLongPressEnd,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: inactiveColor, size: 22),
              const SizedBox(height: 1),
              Text(
                l10n.tabRecord,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 10,
                  color: inactiveColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarTabItem(int index, String label, Color inactiveColor) {
    final isActive = index == currentIndex;
    final hasAvatar = avatarPath != null;

    Widget iconWidget;
    if (hasAvatar) {
      iconWidget = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isActive ? Border.all(color: primaryColor, width: 1.5) : null,
          image: DecorationImage(
            image: FileImage(File(avatarPath!)),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      iconWidget = Icon(isActive ? Icons.person_rounded : Icons.person_outline_rounded,
          color: isActive ? primaryColor : inactiveColor, size: 24);
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTabTap(index),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? primaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconWidget,
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? primaryColor : inactiveColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 扇形菜单覆盖层
class _SpeedDialOverlay extends StatelessWidget {
  final Offset buttonPosition;
  final Size buttonSize;
  final List<SpeedDialAction> actions;
  final Animation<double> animation;
  final int? hoveredIndex;
  final Color backgroundColor;

  const _SpeedDialOverlay({
    required this.buttonPosition,
    required this.buttonSize,
    required this.actions,
    required this.animation,
    required this.hoveredIndex,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final buttonCenter = Offset(
      buttonPosition.dx + buttonSize.width / 2,
      buttonPosition.dy + buttonSize.height / 2,
    );

    final angles = [210.0, 270.0, 330.0];
    const distance = 85.0;
    const pi = 3.14159265359;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (animation.value == 0) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3 * animation.value),
                ),
              ),
            ),
            for (int i = 0; i < actions.length && i < angles.length; i++)
              Builder(builder: (context) {
                final angle = angles[i];
                final radians = angle * pi / 180;
                final progress = animation.value;
                final offsetX = progress * distance * _cos(radians);
                final offsetY = progress * distance * _sin(radians);

                const btnSize = 48.0;
                final left = buttonCenter.dx + offsetX - btnSize / 2;
                final top = buttonCenter.dy + offsetY - btnSize / 2;

                final isEnabled = actions[i].enabled;
                final bgColor =
                    isEnabled ? backgroundColor : Colors.grey.shade400;
                final isHovered = i == hoveredIndex;

                return Positioned(
                  left: left,
                  top: top,
                  child: Transform.scale(
                    scale: progress,
                    child: Opacity(
                      opacity: progress,
                      child: AnimatedScale(
                        scale: isHovered ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Material(
                          color: bgColor,
                          shape: const CircleBorder(),
                          elevation: isHovered ? 8 : 4,
                          child: Container(
                            width: btnSize,
                            height: btnSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: isHovered
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                            child: Icon(
                              actions[i].icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  static double _cos(double x) {
    x = x % (2 * 3.14159265359);
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double _sin(double x) {
    x = x % (2 * 3.14159265359);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
}

/// `_triggerInitialCloudSync` Phase2 单 ledger 处理结果。
class _LedgerSyncResult {
  const _LedgerSyncResult({required this.pushed, required this.pulled})
      : skipped = false;
  const _LedgerSyncResult.skip()
      : pushed = 0,
        pulled = 0,
        skipped = true;
  final int pushed;
  final int pulled;
  final bool skipped;
}
