import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'theme.dart';
import 'providers.dart';
import 'providers/font_scale_provider.dart';
import 'providers/cloud_mode_providers.dart';
import 'providers/ui_state_providers.dart';
import 'utils/notification_factory.dart';
import 'pages/auth/splash_page.dart';
import 'pages/auth/welcome_page.dart';
import 'pages/auth/app_lock_screen.dart';
import 'providers/security_providers.dart';
import 'services/system/reminder_monitor_service.dart';
import 'providers/credit_card_reminder_providers.dart';
import 'services/platform/screenshot_monitor_service.dart';
import 'services/platform/image_share_handler_service.dart';
import 'services/platform/app_link_service.dart';
import 'services/system/logger_service.dart';
import 'l10n/app_localizations.dart';
import 'widget/widget_manager.dart';
import 'package:home_widget/home_widget.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志系统（确保原生日志桥接就绪）
  logger.info('App', '应用启动，日志系统已初始化');
  print('📱 LoggerService 已初始化');

  // 初始化时区（必须在通知服务之前，修复iOS通知问题）
  try {
    NotificationFactory.initializeTimeZone();
  } catch (e) {
    print('⚠️  时区初始化失败（可能在不支持的平台上运行）: $e');
  }

  // 配置iOS App Group（widget和主app共享数据必需）
  try {
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId('group.com.tntlikely.beecount');
    }
  } catch (e) {
    print('⚠️  HomeWidget 插件初始化失败（可能在不支持的平台上运行）: $e');
  }

  // 初始化通知服务
  try {
    final notificationUtil = NotificationFactory.getInstance();
    await notificationUtil.initialize();
  } catch (e) {
    print('⚠️  通知服务初始化失败（可能在不支持的平台上运行）: $e');
  }

  // 恢复用户的记账提醒设置（关键修复：应用重启后自动恢复提醒）
  await _restoreUserReminder();

  // 启动提醒监控服务（监听应用生命周期，自动恢复丢失的提醒）
  try {
    ReminderMonitorService().startMonitoring();
  } catch (e) {
    print('⚠️  提醒监控服务启动失败（可能在不支持的平台上运行）: $e');
  }

  // 创建全局ProviderContainer（需要在周期交易生成之前创建，因为需要使用 repositoryProvider）
  final container = ProviderContainer();

  // 初始化应用模式（需要在生成重复交易之前，确保模式正确）
  // 直接从 SharedPreferences 读取并设置到 appModeProvider
  await _initializeAppMode(container);

  // 注意：不再在启动时生成重复交易
  // 周期交易生成已移至 appSplashInitProvider 中（等待数据库完全初始化后执行）
  // await _generatePendingRecurringTransactions(container);

  // 恢复信用卡还款提醒
  try {
    final repo = container.read(repositoryProvider);
    await CreditCardReminderService.restoreAllReminders(
      getCreditCardAccounts: () => repo.getCreditCardAccounts(),
    );
  } catch (e) {
    // 静默失败，不影响启动
  }

  // [已删除] v1.15.0 账户独立迁移 & v2.7.1 转账分类迁移
  // 所有活跃用户已完成，Drift onUpgrade 已覆盖相关 schema 变更
  // 硬编码 SQL 重建表会导致新增字段丢失（如 sort_order），故移除

  // 注册小组件交互回调
  try {
    await WidgetManager.registerCallback();
  } catch (e) {
    print('⚠️  小组件回调注册失败（可能在不支持的平台上运行）: $e');
  }

  // 恢复截图自动识别设置（Android专属），传入container
  await _restoreScreenshotMonitor(container);

  // 初始化图片分享处理服务（Android专属）
  if (Platform.isAndroid) {
    _setupImageShareHandler(container);
  }

  // 启动 URL 监听（用于快捷指令/AppLink 自动记账）
  _setupUrlListener(container);

  // 启动一次性磁盘孤立文件 GC(attachments / attachment_thumbs / custom_icons),
  // 清理历史版本遗留的文件。标志位 SharedPreferences 保证只跑一次。后台异步
  // 执行,失败不致命。
  unawaited(_runOrphanFileGcOnce(container));

  runApp(ProviderScope(
    parent: container,
    observers: const [_WidgetUpdateObserver()],
    child: const MainApp(),
  ));
}

/// Provider observer to update widget on app start
class _WidgetUpdateObserver extends ProviderObserver {
  const _WidgetUpdateObserver();
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    // Update widget when current ledger is loaded
    if (provider == currentLedgerIdProvider && newValue != null) {
      _updateWidgetOnStart(container);
    }
  }

  void _updateWidgetOnStart(ProviderContainer container) async {
    try {
      final repository = container.read(repositoryProvider);
      final ledgerId = container.read(currentLedgerIdProvider);
      final primaryColor = container.read(primaryColorProvider);
      final redForIncome = container.read(incomeExpenseColorSchemeProvider);

      final widgetManager = WidgetManager();
      await widgetManager.updateWidget(
        repository,
        ledgerId,
        primaryColor,
        redForIncome: redForIncome,
      );

      print('✅ 小组件数据已更新');
    } catch (e) {
      print('❌ 更新小组件失败（可能在不支持的平台上运行）: $e');
    }
  }
}

/// 恢复用户之前设置的记账提醒
///
/// 问题场景：
/// - 应用被系统杀死后，通知任务会丢失
/// - 应用更新后，通知任务会被清除
/// - 手机重启后，通知任务需要重新设置
///
/// 解决方案：
/// - 在应用启动时检查用户是否开启了提醒
/// - 如果开启了，重新设置通知任务
Future<void> _restoreUserReminder() async {
  try {
    print('🔄 检查并恢复记账提醒...');
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('reminder_enabled') ?? false;

    if (isEnabled) {
      final hour = prefs.getInt('reminder_hour') ?? 21;
      final minute = prefs.getInt('reminder_minute') ?? 0;
      print('✅ 发现用户已启用记账提醒: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
      print('🔔 正在重新设置提醒任务...');

      try {
        final notificationUtil = NotificationFactory.getInstance();
        await notificationUtil.scheduleDailyReminder(
          id: 1001,
          title: '记账提醒',
          body: '别忘了记录今天的收支哦 💰',
          hour: hour,
          minute: minute,
        );
        print('✅ 记账提醒已成功恢复');
      } catch (e) {
        print('❌ 记账提醒设置失败（可能在不支持的平台上运行）: $e');
      }
    } else {
      print('ℹ️  用户未启用记账提醒，跳过恢复');
    }
  } catch (e) {
    print('❌ 恢复记账提醒失败: $e');
    // 不抛出异常，避免影响应用启动
  }
}

/// 恢复截图自动识别设置（仅Android）
///
/// 问题场景：
/// - 应用重启后，截图监听服务会丢失
/// - 需要自动恢复用户之前的设置
///
/// 解决方案：
/// - 在应用启动时检查用户是否开启了截图监听
/// - 如果开启了，重新启动监听服务
Future<void> _restoreScreenshotMonitor(ProviderContainer container) async {
  if (!Platform.isAndroid) return;

  try {
    print('📸 检查并恢复截图自动识别...');
    final screenshotMonitor = ScreenshotMonitorService(container);
    final isEnabled = await screenshotMonitor.isEnabled();

    if (isEnabled) {
      print('✅ 发现用户已启用截图自动识别');
      print('🔄 正在重新启动监听服务...');
      await screenshotMonitor.enable();
      print('✅ 截图监听服务已成功恢复');
    } else {
      print('ℹ️  用户未启用截图自动识别，跳过恢复');
    }
  } catch (e) {
    print('❌ 恢复截图监听失败: $e');
    // 不抛出异常，避免影响应用启动
  }
}

/// 初始化应用模式
///
/// 在应用启动时从 SharedPreferences 读取模式并设置到 appModeProvider
/// 这样可以确保后续使用 repositoryProvider 时能获取到正确的模式
/// [container] Provider容器
Future<void> _initializeAppMode(ProviderContainer container) async {
  try {
    print('⏳ 初始化应用模式...');

    // 从 SharedPreferences 直接读取模式
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('app_mode');
    final mode = modeStr != null ? AppMode.fromString(modeStr) : AppMode.local;

    // 使用 switchMode 方法设置模式，确保 repositoryProvider 能立即获取到正确的模式
    // switchMode 不会重复写入 SharedPreferences，因为值已经存在
    await container.read(appModeProvider.notifier).switchMode(mode);

    print('✅ 应用模式已初始化: ${mode.label}');
  } catch (e, stackTrace) {
    print('⚠️  应用模式初始化失败: $e');
    logger.error('Main', '应用模式初始化失败', e, stackTrace);
  }
}


/// 设置图片分享处理（Android专属）
///
/// 初始化 ImageShareHandlerService 以接收从相册或其他应用分享的图片
/// 分享的图片会自动触发记账流程
void _setupImageShareHandler(ProviderContainer container) {
  try {
    logger.info('App', '🖼️  [Android] 初始化图片分享处理服务...');

    // 初始化服务（会自动设置MethodChannel监听器）
    ImageShareHandlerService(container);

    logger.info('App', '✅ [Android] 图片分享处理服务已启动');
  } catch (e) {
    logger.error('App', '❌ [Android] 图片分享处理服务初始化失败', e);
    // 不抛出异常，避免影响应用启动
  }
}

/// 设置 URL 监听（用于 AppLink）
///
/// 监听 beecount:// URL Scheme 调用
/// 支持的URL格式:
/// - beecount://voice - 语音记账
/// - beecount://image - 图片记账（从相册）
/// - beecount://camera - 拍照记账
/// - beecount://ai-chat - AI 小助手
/// - beecount://add?amount=100&type=expense - 自动记账
/// - beecount://auto-billing?text=... - 文本自动记账（兼容旧版）
/// - beecount://quick-billing - 快速记账（兼容旧版）
void _setupUrlListener(ProviderContainer container) {
  try {
    logger.info('AppLink', '初始化URL监听...');

    final appLinks = AppLinks();
    final appLinkService = AppLinkService(container);

    // 设置导航回调
    appLinkService.onNavigate = (action, {params}) {
      logger.info('AppLink', '触发导航: $action');
      if (action == AppLinkAction.newTransaction && params != null) {
        container.read(pendingNewTransactionTypeProvider.notifier).state = params.type;
      }
      container.read(pendingAppLinkActionProvider.notifier).state = action;
    };

    // 监听URL（应用在后台时）
    appLinks.uriLinkStream.listen((uri) {
      logger.info('AppLink', '收到URL: $uri');
      appLinkService.handleUrl(uri);
    }, onError: (err) {
      logger.error('AppLink', 'URL监听错误', err);
    });

    // 注意：不使用 getInitialLink/getLatestLink，因为它们会缓存旧链接
    // 只依赖 uriLinkStream，它会在应用通过 URL 启动时立即触发

    logger.info('AppLink', 'URL监听已启动');
  } catch (e) {
    logger.error('AppLink', 'URL监听初始化失败', e);
    // 不抛出异常，避免影响应用启动
  }
}

class NoGlowScrollBehavior extends MaterialScrollBehavior {
  const NoGlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // 去除 Android 上的发光效果，避免顶部出现一抹红
  }
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  // 根据初始化状态和欢迎页面状态决定显示哪个页面
  Widget _getHomePage(AppInitState initState, WidgetRef ref) {
    // 首先检查是否需要显示欢迎页面
    final shouldShowWelcome = ref.watch(shouldShowWelcomeProvider);
    if (shouldShowWelcome) {
      return const WelcomePage();
    }

    // 欢迎页面完成后，根据初始化状态显示对应页面
    if (initState != AppInitState.ready) {
      return const SplashPage();
    }

    // 检查是否需要显示锁屏
    final isLocked = ref.watch(isAppLockedProvider);
    if (isLocked) {
      return const AppLockScreen();
    }

    return const BeeApp();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 首先检查是否需要显示欢迎页面
    ref.watch(welcomeCheckProvider);

    // 检查应用初始化状态
    final initState = ref.watch(appInitStateProvider);
    final selectedLanguage = ref.watch(languageProvider);

    // 如果是启屏状态，启动初始化
    if (initState == AppInitState.splash) {
      ref.watch(appSplashInitProvider);
    }

    // 周期交易生成已统一在 appSplashInitProvider 中处理

    final primary = ref.watch(primaryColorProvider);
    final platform = Theme.of(context).platform; // 当前平台
    final base = BeeTheme.lightTheme(platform: platform);
    final baseTextTheme = base.textTheme;

    // ⭐ 亮色主题
    final theme = base.copyWith(
      textTheme: baseTextTheme,
      colorScheme: base.colorScheme.copyWith(primary: primary),
      primaryColor: primary,
      scaffoldBackgroundColor: Colors.white,
      dividerColor: Colors.black.withOpacity(0.06),
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        iconColor: const Color(0xFF111827),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: baseTextTheme.titleMedium?.copyWith(
            color: const Color(0xFF111827), fontWeight: FontWeight.w600),
        contentTextStyle:
            baseTextTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: baseTextTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        selectedItemColor: primary,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
    );
    // Clamp 系统字体缩放，避免部分设备设置 1.5+ 造成 UI 溢出
    final media = MediaQuery.of(context);
    // init font scale persistence
    ref.watch(fontScaleInitProvider);
    final customScale = ref.watch(effectiveFontScaleProvider);
    final clamped = media.textScaler.clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.15,
    );
    final combinedScale = clamped.scale(customScale); // returns double
    final newScaler = TextScaler.linear(combinedScale);
    return MediaQuery(
      data: media.copyWith(textScaler: newScaler),
      child: MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        scrollBehavior: const NoGlowScrollBehavior(),
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: BeeTheme.darkTheme(platform: platform).copyWith(
          colorScheme: BeeTheme.darkTheme(platform: platform).colorScheme.copyWith(primary: primary),
          primaryColor: primary,
        ),                                                // ⭐ 暗黑主题（使用动态主题色）
        themeMode: ref.watch(themeModeProvider),         // ⭐ 使用 provider 支持手动切换
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('zh'),
          Locale('zh', 'TW'),
        ],
        locale: selectedLanguage,
        builder: (context, child) {
          final showPrivacy = ref.watch(showPrivacyScreenProvider);
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              if (showPrivacy)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        // 显式命名根路由，便于路由日志与 popUntil 精确识别
        home: _getHomePage(initState, ref),
        onGenerateRoute: (settings) {
          if (settings.name == Navigator.defaultRouteName ||
              settings.name == '/') {
            return MaterialPageRoute(
                builder: (_) => _getHomePage(initState, ref),
                settings: const RouteSettings(name: '/'));
          }
          return null;
        },
      ),
    );
  }
}

/// 一次性磁盘孤立文件清理 —— 清历史版本遗留的:
///   - `attachments/*.jpg` + `attachment_thumbs/*.jpg`:历史 sync pull 删交易时
///     只删表行不清磁盘,或者用户端在某版本之前没有完整清理的附件
///   - `custom_icons/*.png`:旧版 deleteCategory 只删分类行,customIconPath 指向
///     的本地图标文件遗留
///
/// SharedPreferences 标志位 `orphan_file_gc_v1_done` 保证只跑一次。失败全部
/// try/catch 吞掉 —— 这是 nice-to-have,不应 block app 启动。
Future<void> _runOrphanFileGcOnce(ProviderContainer container) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    const flagKey = 'orphan_file_gc_v1_done';
    if (prefs.getBool(flagKey) == true) return;

    final db = container.read(databaseProvider);

    // 给主线程让路,启动关键路径先跑完
    await Future.delayed(const Duration(seconds: 3));

    var attCleaned = 0;
    var thumbCleaned = 0;
    var iconCleaned = 0;

    // --- attachments / attachment_thumbs ---
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attDir = Directory('${appDir.path}/attachments');
      if (await attDir.exists()) {
        final usedNames = <String>{
          for (final row in await db.select(db.transactionAttachments).get())
            row.fileName,
        };
        await for (final entity in attDir.list()) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (!usedNames.contains(name)) {
            try {
              await entity.delete();
              attCleaned++;
            } catch (e) {
              logger.warning('OrphanGC', 'unlink attachment failed $name: $e');
            }
          }
        }
      }

      final cacheDir = await getTemporaryDirectory();
      final thumbDir = Directory('${cacheDir.path}/attachment_thumbs');
      if (await thumbDir.exists()) {
        // 缩略图命名规则:`<basename(fileName)>_thumb.jpg`
        final usedThumbNames = <String>{
          for (final row in await db.select(db.transactionAttachments).get())
            '${p.basenameWithoutExtension(row.fileName)}_thumb.jpg',
        };
        await for (final entity in thumbDir.list()) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (!usedThumbNames.contains(name)) {
            try {
              await entity.delete();
              thumbCleaned++;
            } catch (_) {/* best effort */}
          }
        }
      }
    } catch (e, st) {
      logger.warning('OrphanGC', 'attachment scan failed: $e\n$st');
    }

    // --- custom_icons ---
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final iconDir = Directory('${appDir.path}/custom_icons');
      if (await iconDir.exists()) {
        final usedIconNames = <String>{};
        final categoryRows = await (db.select(db.categories)
              ..where((c) => c.customIconPath.isNotNull()))
            .get();
        for (final row in categoryRows) {
          final cp = row.customIconPath;
          if (cp != null && cp.trim().isNotEmpty) {
            usedIconNames.add(p.basename(cp));
          }
        }
        await for (final entity in iconDir.list()) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (!usedIconNames.contains(name)) {
            try {
              await entity.delete();
              iconCleaned++;
            } catch (e) {
              logger.warning('OrphanGC', 'unlink custom icon failed $name: $e');
            }
          }
        }
      }
    } catch (e, st) {
      logger.warning('OrphanGC', 'custom_icons scan failed: $e\n$st');
    }

    await prefs.setBool(flagKey, true);
    logger.info(
      'OrphanGC',
      '一次性清理完成 attachments=$attCleaned thumbs=$thumbCleaned icons=$iconCleaned',
    );
  } catch (e, st) {
    // 任何异常都不该影响 app 启动。下次启动还会重试(因为没设 flag)。
    logger.warning('OrphanGC', '一次性清理异常(会在下次启动重试): $e\n$st');
  }
}
