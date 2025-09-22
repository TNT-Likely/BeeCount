import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'theme.dart';
import 'providers.dart';
import 'styles/colors.dart';
import 'providers/font_scale_provider.dart';
import 'config.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as s;
import 'utils/route_logger.dart';
import 'pages/splash_page.dart';
import 'services/notification_service.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();
  if (AppConfig.hasSupabase) {
    await s.Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }
  // 初始化通知服务
  await NotificationService.initialize();
  runApp(const ProviderScope(child: MainApp()));
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 检查应用初始化状态
    final initState = ref.watch(appInitStateProvider);
    final selectedLanguage = ref.watch(languageProvider);
    
    // 如果是启屏状态，启动初始化
    if (initState == AppInitState.splash) {
      ref.watch(appSplashInitProvider);
    }
    
    final primary = ref.watch(primaryColorProvider);
    final platform = Theme.of(context).platform; // 当前平台
    final base = BeeTheme.lightTheme(platform: platform);
    final baseTextTheme = base.textTheme;

    final theme = base.copyWith(
      textTheme: baseTextTheme,
      colorScheme: base.colorScheme.copyWith(primary: primary),
      primaryColor: primary,
      scaffoldBackgroundColor: Colors.white,
      dividerColor: BeeColors.divider,
      listTileTheme: const ListTileThemeData(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
        iconColor: BeeColors.primaryText,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: baseTextTheme.titleMedium?.copyWith(
            color: BeeColors.primaryText, fontWeight: FontWeight.w600),
        contentTextStyle:
            baseTextTheme.bodyMedium?.copyWith(color: BeeColors.secondaryText),
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
        title: 'Bee Accounting',
        scrollBehavior: const NoGlowScrollBehavior(),
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: BeeTheme.darkTheme(),
        navigatorObservers: [LoggingNavigatorObserver()],
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
          Locale('ja'),
          Locale('ko'),
          Locale('es'),
          Locale('fr'),
          Locale('de'),
        ],
        locale: selectedLanguage,
        // 显式命名根路由，便于路由日志与 popUntil 精确识别
        home: initState == AppInitState.ready ? const BeeApp() : const SplashPage(),
        onGenerateRoute: (settings) {
          if (settings.name == Navigator.defaultRouteName ||
              settings.name == '/') {
            return MaterialPageRoute(
                builder: (_) => initState == AppInitState.ready ? const BeeApp() : const SplashPage(),
                settings: const RouteSettings(name: '/'));
          }
          return null;
        },
      ),
    );
  }
}
