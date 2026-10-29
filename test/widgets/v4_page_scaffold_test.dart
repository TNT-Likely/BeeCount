import 'package:beecount/pages/shared/scaffold/widgets/page_scaffold.dart';
import 'package:beecount/pages/shared/appearance/bindings/page_skin_composition.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/styles/header_skins.dart';
import 'package:beecount/pages/shared/appearance/skin_animation_scope.dart';
import 'package:beecount/pages/shared/appearance/primary_header.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('整页皮肤不重复绘制头部，旧路由仍保留原头部与显式装饰', (tester) async {
    final container = ProviderContainer(overrides: [
      headerSkinProvider.overrideWith((ref) => 'anniv_cake'),
      skinAnimationEnabledProvider.overrideWith((ref) => false)
    ]);
    addTearDown(container.dispose);
    Future<void> render(Widget home) async {
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              theme: beeTheme(),
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: home)));
      await tester.pumpAndSettle();
    }

    const header = PrimaryHeader(title: '页面标题');
    await render(const V4PageScaffold(
        body: Column(children: [header, Expanded(child: SizedBox())])));
    expect(find.byType(SkinAnimationScope), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(PrimaryHeader),
            matching: find.byType(SkinAnimationScope)),
        findsNothing);
    await render(const Scaffold(body: header));
    expect(
        find.descendant(
            of: find.byType(PrimaryHeader),
            matching: find.byType(SkinAnimationScope)),
        findsOneWidget);
    await render(const V4PageScaffold(
        body: PrimaryHeader(
            title: '定制标题',
            decoration: BoxDecoration(color: Color(0xff123456)))));
    expect(
        tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).any((box) =>
            box.decoration is BoxDecoration &&
            (box.decoration as BoxDecoration).color == const Color(0xff123456)),
        isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('无皮肤与两款动态皮肤共用原偏好，切换不重置列表位置或吞掉操作', (tester) async {
    final container = ProviderContainer(overrides: [
      headerSkinProvider.overrideWith((ref) => 'none'),
      skinAnimationEnabledProvider.overrideWith((ref) => false)
    ]);
    final scroll = ScrollController();
    addTearDown(container.dispose);
    addTearDown(scroll.dispose);
    var taps = 0;
    tester.view.physicalSize = const Size(398, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: false),
                child: child!),
            home: V4PageScaffold(
                bottomNavigationBar: TextButton(
                    onPressed: () => taps++, child: const Text('操作')),
                body: ListView.builder(
                    controller: scroll,
                    itemCount: 50,
                    itemBuilder: (context, i) => SizedBox(
                        height: 60,
                        child: Text(
                            '项目 $i，${MediaQuery.disableAnimationsOf(context)}')))))));
    await tester.pumpAndSettle();
    expect(find.byType(SkinAnimationScope), findsNothing);
    scroll.jumpTo(180);
    await tester.pump();
    for (final skin in ['anniversary', 'anniv_cake', 'none']) {
      container.read(headerSkinProvider.notifier).state = skin;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(scroll.offset, 180);
      expect(find.text('项目 3，false'), findsOneWidget);
      final base = tester.widget<ColoredBox>(find
          .descendant(
              of: find.byType(V4PageScaffold),
              matching: find.byType(ColoredBox))
          .first);
      expect(base.color, const Color(0xfff5f6f7));
      if (skin != 'none') {
        expect(find.byType(SkinAnimationScope), findsOneWidget);
        final scopedQuery = find.descendant(
            of: find.byType(SkinAnimationScope),
            matching: find.byType(MediaQuery));
        expect(
            tester.widget<MediaQuery>(scopedQuery.first).data.disableAnimations,
            isTrue);
        final background = find
            .descendant(
                of: find.byType(V4PageScaffold),
                matching: find.byType(IgnorePointer))
            .first;
        expect(tester.getSize(background), const Size(398, 844));
      }
      await tester.tap(find.text('操作'));
      await tester.pump();
    }
    expect(taps, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final dark in [false, true]) {
    testWidgets('我的页皮肤铺满背景且不占用资料空间 $dark', (t) async {
      t.view.physicalSize = const Size(398, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = ProviderContainer(overrides: [
        headerSkinProvider.overrideWith((ref) => 'none'),
        skinAnimationEnabledProvider.overrideWith((ref) => false),
      ]);
      addTearDown(c.dispose);
      const contentKey = ValueKey('profile-content');
      await t.pumpWidget(UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
              theme: beeTheme(
                  brightness: dark ? Brightness.dark : Brightness.light),
              home: const V4PageScaffold(
                  profileHeaderSkin: true,
                  body: Column(children: [
                    SizedBox(height: 48, child: Text('我的')),
                    SizedBox(
                        key: contentKey, height: 120, child: Text('原有资料和账本')),
                  ])))));
      await t.pumpAndSettle();
      final original = t.getRect(find.byKey(contentKey));
      c.read(headerSkinProvider.notifier).state = 'anniv_cake';
      await t.pumpAndSettle();
      final scene =
          t.widget<HeaderSkinPageArtwork>(find.byType(HeaderSkinPageArtwork));
      expect(scene.role, HeaderSkinPageRole.profile);
      expect(scene.dark, dark);
      expect(
          t.getSize(find.byType(HeaderSkinPageArtwork)), const Size(398, 844));
      expect(t.getRect(find.byKey(contentKey)), original);
      expect(find.byType(V4OriginalSkinScene), findsNothing);
      expect(find.text('原有资料和账本'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
