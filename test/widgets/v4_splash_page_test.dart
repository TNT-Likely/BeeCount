import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/auth/splash_page.dart';
import 'package:beecount/providers/ui_state_providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final compact in [false, true]) {
    testWidgets('启动保留原安全说明与初始化状态，展示不触发初始化 $compact', (tester) async {
      tester.view.physicalSize =
          compact ? const Size(320, 568) : const Size(398, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var started = false;
      final container = ProviderContainer(overrides: [
        appSplashInitProvider.overrideWith((ref) async {
          started = true;
        })
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              theme: beeTheme(
                  brightness: compact ? Brightness.dark : Brightness.light),
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(compact ? 1.4 : 1)),
                  child: child!),
              home: const SplashPage())));
      await tester.pump(const Duration(milliseconds: 200));
      final l = AppLocalizations.of(tester.element(find.byType(SplashPage)));
      expect(find.text(l.splashAppName), findsOneWidget);
      expect(find.text(l.splashSlogan), findsOneWidget);
      expect(find.text(l.splashSecurityTitle), findsOneWidget);
      expect(
          find.text(
              '${l.splashSecurityFeature1}\n${l.splashSecurityFeature2}\n${l.splashSecurityFeature3}'),
          findsOneWidget);
      expect(tester.getSize(find.byType(BeeBrandMark)), const Size(76, 76));
      expect(tester.getSize(find.byType(CircularProgressIndicator)),
          const Size(22, 22));
      await tester.ensureVisible(find.text(l.splashInitializing));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l.splashInitializing).hitTestable(), findsOneWidget);
      expect(find.byType(BeeButton), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(started, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
