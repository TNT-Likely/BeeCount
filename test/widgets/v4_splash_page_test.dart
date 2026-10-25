import 'dart:ui' as ui;
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/auth/splash_page.dart';
import 'package:beecount/providers/ui_state_providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child,
        {Brightness brightness = Brightness.light,
        double scale = 1,
        bool reduced = true,
        Locale locale = const Locale('zh')}) =>
    MaterialApp(
        theme: beeTheme(brightness: brightness),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 24, bottom: 16),
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduced),
            child: child!),
        home: child);

void _screen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<Uint8List> _pixels(WidgetTester tester, Key key) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    bytes = Uint8List.fromList(data!.buffer.asUint8List());
    image.dispose();
  });
  return bytes;
}

void main() {
  for (final size in [const Size(398, 844), const Size(320, 568)]) {
    for (final locale in [const Locale('zh'), const Locale('en')]) {
      testWidgets('B 启动布局：$size $locale 保留安全说明，首屏可读', (tester) async {
        _screen(tester, size);
        var started = false;
        final container = ProviderContainer(overrides: [
          appSplashInitProvider.overrideWith((ref) async => started = true)
        ]);
        addTearDown(container.dispose);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: _app(const SplashPage(),
                brightness:
                    size.width < 350 ? Brightness.dark : Brightness.light,
                scale: size.width < 350 ? 1.4 : 1,
                locale: locale)));
        await tester.pump();
        final l = AppLocalizations.of(tester.element(find.byType(SplashPage)));
        expect(find.text(l.splashAppName).hitTestable(), findsOneWidget);
        expect(find.text(l.splashSlogan).hitTestable(), findsOneWidget);
        expect(find.text(l.splashInitializing).hitTestable(), findsOneWidget);
        expect(
            find.text(l.splashSecuritySummary).hitTestable(), findsOneWidget);
        expect(find.byType(BeeTrailBackdrop), findsOneWidget);
        expect(find.byType(BeeBrandMark), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(started, false, reason: '展示层不得二次启动或等待预载');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(l.splashSecuritySummary));
        await tester.pump();
        expect(find.byType(BeeLocalSheet), findsOneWidget);
        for (final text in [
          l.splashSecurityFeature1,
          l.splashSecurityFeature2,
          l.splashSecurityFeature3
        ]) {
          expect(find.text(text.replaceFirst(RegExp(r'^\s*•\s*'), '')),
              findsOneWidget);
        }
        await tester.tap(find.byType(CloseButton));
        await tester.pump();
        expect(find.byType(BeeLocalSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('安全说明支持遮罩 / Escape / 系统返回关闭，无 Navigator 新路由', (tester) async {
    _screen(tester, const Size(398, 844));
    await tester.pumpWidget(_app(const SplashPage()));
    final open = find.text('本地存储 · 开源透明');
    await tester.tap(open);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(BeeLocalSheet), findsNothing);
    await tester.tap(open);
    await tester.pump();
    await tester.tapAt(const Offset(10, 60));
    await tester.pump();
    expect(find.byType(BeeLocalSheet), findsNothing);
    await tester.tap(open);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(BeeLocalSheet), findsNothing);
    expect(find.byType(SplashPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('预载结束立刻替换启动页：动画中或安全弹层内均不拦截', (tester) async {
    _screen(tester, const Size(398, 844));
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    await tester.pumpWidget(_app(
        ValueListenableBuilder<bool>(
            valueListenable: ready,
            builder: (_, value, __) => value
                ? const Scaffold(body: Text('原路由目标'))
                : const SplashPage()),
        reduced: false));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('本地存储 · 开源透明'));
    await tester.pump();
    expect(find.byType(BeeLocalSheet), findsOneWidget);
    ready.value = true;
    await tester.pump();
    expect(find.text('原路由目标'), findsOneWidget);
    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(BeeLocalSheet), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('原路由目标'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('描线仅播放一次，退后台暂停，移除时取消 ticker', (tester) async {
    _screen(tester, const Size(398, 844));
    const key = ValueKey('trail-capture');
    await tester.pumpWidget(_app(
        const Scaffold(
            body: RepaintBoundary(
                key: key,
                child: BeeTrailBackdrop(focalPoint: Offset(199, 270)))),
        reduced: false));
    await tester.pump(const Duration(milliseconds: 150));
    final moving = await _pixels(tester, key);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(listEquals(moving, await _pixels(tester, key)), true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    final complete = await _pixels(tester, key);
    expect(listEquals(moving, complete), false);
    await tester.pump(const Duration(seconds: 2));
    expect(listEquals(complete, await _pixels(tester, key)), true);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('系统减少动效：初帧静态描线可见，且没有活动 ticker 或假进度', (tester) async {
    _screen(tester, const Size(320, 568));
    const key = ValueKey('static-trail');
    await tester.pumpWidget(_app(const Scaffold(
        body: RepaintBoundary(
            key: key, child: BeeTrailBackdrop(focalPoint: Offset(160, 155))))));
    await tester.pump();
    final still = await _pixels(tester, key);
    await tester.pump(const Duration(seconds: 2));
    expect(listEquals(still, await _pixels(tester, key)), true);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_app(const SplashPage(), scale: 1.4));
    await tester.pump();
    expect(find.byType(BeeActivityIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
