import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:beecount/pages/shared/scaffold/widgets/page_scaffold.dart';
import 'package:beecount/pages/shared/appearance/bindings/page_skin_composition.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/styles/header_skins.dart';
import 'package:beecount/pages/shared/appearance/primary_header.dart';
import 'package:beecount/pages/shared/appearance/skin_animation_scope.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Home extends ConsumerWidget {
  const _Home({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) => V4PageScaffold(
      locallyComposedSkin: true,
      body: Column(children: [
        PrimaryHeader(
            title: '',
            showTitleSection: false,
            padding: const EdgeInsets.fromLTRB(17, 6, 17, 8),
            content: Column(children: [
              const SizedBox(
                  height: 64,
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('蜜蜂记账',
                          key: ValueKey('identity'),
                          style: TextStyle(fontSize: 20)))),
              const SizedBox(height: 5),
              BeeSummaryCard(
                  key: const ValueKey('summary'),
                  title: '2026年10月',
                  amount: '3,286.50',
                  amountLabel: '本月支出',
                  currencyLabel: '人民币 · CNY',
                  incomeLabel: '本月收入',
                  income: '12,000.00',
                  expenseLabel: '本月结余',
                  expense: '8,713.50',
                  background: homeSkinCardBackground(context, ref),
                  onContextTap: onTap),
            ])),
        Expanded(
            child: ListView.builder(
                key: const ValueKey('journal'),
                itemCount: 30,
                itemBuilder: (_, i) =>
                    SizedBox(height: 56, child: Text('账单 $i')))),
      ]));
}

void main() {
  final geometryRecords = <Map<String, Object?>>[];
  setUpAll(() async {
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdk.path}/material_fonts').existsSync() &&
        sdk.parent.path != sdk.path) {
      sdk = sdk.parent;
    }
    final font = FontLoader('SkinTestRoboto');
    font.addFont(Future.value(ByteData.sublistView(
        await File('${sdk.path}/material_fonts/Roboto-Regular.ttf')
            .readAsBytes())));
    await font.load();
    final georgia = File('/System/Library/Fonts/Supplemental/Georgia.ttf');
    if (georgia.existsSync()) {
      final originalMark = FontLoader('Georgia');
      originalMark.addFont(
          Future.value(ByteData.sublistView(georgia.readAsBytesSync())));
      await originalMark.load();
    }
    final cjkFile = File('/System/Library/Fonts/STHeiti Light.ttc');
    if (cjkFile.existsSync()) {
      final cjk = FontLoader('SkinTestCJK');
      cjk.addFont(
          Future.value(ByteData.sublistView(cjkFile.readAsBytesSync())));
      await cjk.load();
    }
  });
  const capture = bool.fromEnvironment('BEECOUNT_CAPTURE_SKIN');
  tearDownAll(() {
    if (capture) {
      final out = File('.docs/v4-beta4-skin/geometry-check.json');
      out.parent.createSync(recursive: true);
      out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'status': geometryRecords.length == 54 ? 'PASS' : 'INCOMPLETE',
        'geometryCases': geometryRecords.length,
        'maxDeltaPx': 0,
        'source':
            'Flutter V4PageScaffold real render geometry; synthetic fixture with public components',
        'cases': geometryRecords,
        'limitations': [
          'Widget rendering, not device acceptance',
          'Bottom bar production UI requires main-thread device verification'
        ],
      }));
    }
  });
  List<List<double>> rects(List<Rect> boxes) =>
      boxes.map((r) => [r.left, r.top, r.width, r.height]).toList();
  final boundary = GlobalKey();
  Future<void> open(WidgetTester t, ProviderContainer c, Widget body,
      {double width = 398,
      double height = 844,
      bool dark = false,
      bool reduceMotion = false}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, width == 320 ? 568 : height);
    var theme = beeTheme(brightness: dark ? Brightness.dark : Brightness.light);
    theme = theme.copyWith(
        textTheme: theme.textTheme.apply(
            fontFamily: 'SkinTestRoboto',
            fontFamilyFallback: const ['SkinTestCJK']));
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: theme,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 34),
                    disableAnimations: reduceMotion),
                child: RepaintBoundary(key: boundary, child: child)),
            home: body)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  Future<Uint8List> pixels(WidgetTester t, {String? path}) async =>
      (await t.runAsync(() async {
        final b = boundary.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final image = await b.toImage(pixelRatio: 1);
        final data = (await image.toByteData(
                format: path == null
                    ? ui.ImageByteFormat.rawRgba
                    : ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        image.dispose();
        if (path != null) {
          final file = File(path);
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(data);
        }
        return data;
      }))!;

  test('原周年和山峦parts保持3.9字节；19款普通静态皮肤及原图片builder保留', () {
    final hashes = {
      'skin_common.dart':
          '9bf14bce7b857a53ac84952ce149402499b9e109de616f30ae15b8471734773c',
      'anniversary_skin.dart':
          'ed19fed0335529ee3b5f98363171ebf784d0deb1d27142ee706ba0414f7a66e3',
      'anniv_cake_skin.dart':
          'b9953ee141b3f1d387ff82325ba5305c457b0d12156bdfdc7a2bc5aa0336f059',
      'mountains_skin.dart':
          'aad54c5a46310b6c863e19fa8cc2e9aba7c21258c1b0fb32c95a9fe9b61ebc14'
    };
    for (final e in hashes.entries) {
      expect(
          sha256
              .convert(
                  File('lib/styles/header_skins/${e.key}').readAsBytesSync())
              .toString(),
          e.value);
    }
    expect(kHeaderSkins.where((s) => !s.isAnimated && s.id != 'example').length,
        19);
    expect(headerSkinById('anniversary')!.tabBarBuilder, isNotNull);
    expect(headerSkinById('anniv_cake')!.tabBarBuilder, isNotNull);
  });

  for (final width in [320.0, 398.0, 414.0]) {
    for (final dark in [false, true]) {
      testWidgets('B整页皮肤保持原品牌、首卡、列表几何与点击 $width dark=$dark', (t) async {
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final c = ProviderContainer(overrides: [
          headerSkinProvider.overrideWith((_) => 'none'),
          skinAnimationEnabledProvider.overrideWith((_) => false)
        ]);
        addTearDown(c.dispose);
        var taps = 0;
        await open(t, c, _Home(onTap: () => taps++), width: width, dark: dark);
        List<Rect> boxes() => ['identity', 'summary', 'journal']
            .map((k) => t.getRect(find.byKey(ValueKey(k))))
            .toList();
        final plain = boxes();
        for (final id in ['anniversary', 'anniv_cake', 'mountains']) {
          c.read(headerSkinProvider.notifier).state = id;
          await t.pump();
          await t.pump(const Duration(milliseconds: 50));
          expect(boxes(), plain, reason: '只叠加皮肤，不为展示图案挪动内容');
          geometryRecords.add({
            'role': 'home',
            'width': width,
            'dark': dark,
            'skin': id,
            'baseline': rects(plain),
            'skinned': rects(boxes())
          });
          final scope = t.widget<V4PageSkinLayoutScope>(
              find.byType(V4PageSkinLayoutScope));
          expect(scope.controller.value.card, isNotNull);
          expect(scope.controller.value.protectedRegions, isNotEmpty);
          await t.tap(find.text('2026年10月'));
          await t.pump();
          if (capture) {
            await pixels(t,
                path:
                    '.docs/v4-beta4-skin/skin-$id-$width-${dark ? 'dark' : 'light'}.png');
          }
          expect(t.takeException(), isNull);
        }
        expect(taps, 3);
        await t.pumpWidget(const SizedBox());
      });
    }
  }

  for (final profile in [false, true]) {
    for (final width in [320.0, 398.0, 414.0]) {
      for (final dark in [false, true]) {
        testWidgets('我的与子页保持无皮肤几何 profile=$profile $width dark=$dark',
            (t) async {
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final c = ProviderContainer(overrides: [
            headerSkinProvider.overrideWith((_) => 'none'),
            skinAnimationEnabledProvider.overrideWith((_) => false)
          ]);
          addTearDown(c.dispose);
          final body = V4PageScaffold(
              profileHeaderSkin: profile,
              body: Column(children: [
                BeePageHeader(
                    key: const ValueKey('pageTitle'),
                    title: profile ? '我的' : '账户详情'),
                if (profile)
                  const SizedBox(height: 70, child: Text('小满 · 简单记录，安心生活')),
                const Padding(
                    padding: EdgeInsets.all(17),
                    child: BeeSurface(
                        key: ValueKey('firstCard'),
                        child: SizedBox(
                            height: 75,
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text('日常生活 · ¥12,860.50'))))),
                Expanded(
                    child: ListView(
                        key: const ValueKey('rows'),
                        children: const [
                      ListTile(title: Text('数据同步')),
                      ListTile(title: Text('应用设置'))
                    ])),
              ]));
          await open(t, c, body, width: width, dark: dark);
          List<Rect> boxes() => ['pageTitle', 'firstCard', 'rows']
              .map((k) => t.getRect(find.byKey(ValueKey(k))))
              .toList();
          final plain = boxes();
          for (final id in ['anniversary', 'anniv_cake', 'mountains']) {
            c.read(headerSkinProvider.notifier).state = id;
            await t.pump();
            await t.pump(const Duration(milliseconds: 50));
            expect(boxes(), plain);
            geometryRecords.add({
              'role': profile ? 'profile' : 'detail',
              'width': width,
              'dark': dark,
              'skin': id,
              'baseline': rects(plain),
              'skinned': rects(boxes())
            });
            expect(t.takeException(), isNull);
            if (capture && width == 398) {
              await pixels(t,
                  path:
                      '.docs/v4-beta4-skin/${profile ? 'mine' : 'detail'}-$id-${dark ? 'dark' : 'light'}.png');
            }
          }
          await t.pumpWidget(const SizedBox());
        });
      }
    }
  }

  testWidgets('所有普通静态皮肤和原图片builder都能整页适配，无头图矩形边缘', (t) async {
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final c = ProviderContainer(overrides: [
      headerSkinProvider.overrideWith((_) => 'none'),
      skinAnimationEnabledProvider.overrideWith((_) => false)
    ]);
    addTearDown(c.dispose);
    for (final skin in kHeaderSkins.where((s) => !s.isAnimated)) {
      c.read(headerSkinProvider.notifier).state = skin.id;
      for (final dark in [false, true]) {
        await open(t, c, _Home(onTap: () {}), dark: dark);
        expect(find.byType(HeaderSkinPageArtwork), findsOneWidget);
        expect(t.takeException(), isNull, reason: '${skin.id} dark=$dark');
      }
    }
    await t.pumpWidget(const SizedBox());
  });

  for (final id in ['anniversary', 'anniv_cake']) {
    testWidgets('原10秒动画、用户关闭与系统减弱动效 $id', (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = ProviderContainer(overrides: [
        headerSkinProvider.overrideWith((_) => id),
        skinAnimationEnabledProvider.overrideWith((_) => true)
      ]);
      addTearDown(c.dispose);
      await open(t, c, _Home(onTap: () {}));
      final before = await pixels(t);
      await t.pump(const Duration(milliseconds: 600));
      expect(await pixels(t), isNot(orderedEquals(before)));
      c.read(skinAnimationEnabledProvider.notifier).state = false;
      await t.pump();
      await t.pump();
      final off = await pixels(t);
      await t.pump(const Duration(milliseconds: 600));
      expect(await pixels(t), orderedEquals(off));
      c.read(skinAnimationEnabledProvider.notifier).state = true;
      await open(t, c, _Home(onTap: () {}), reduceMotion: true);
      final reduced = await pixels(t);
      await t.pump(const Duration(milliseconds: 600));
      expect(await pixels(t), orderedEquals(reduced));
      expect(find.byType(HeaderSkinPageArtwork), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  for (final id in ['anniversary', 'anniv_cake']) {
    testWidgets('原底栏皮肤动效随开关联动且操作仍可点 $id', (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = ProviderContainer(
          overrides: [skinAnimationEnabledProvider.overrideWith((_) => true)]);
      addTearDown(c.dispose);
      var taps = 0;
      final skin = headerSkinById(id)!;
      await open(
          t,
          c,
          Scaffold(
              body: const Center(child: Text('原底栏皮肤')),
              bottomNavigationBar: SizedBox(
                  height: 56,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(fit: StackFit.expand, children: [
                        Positioned.fill(
                            child: IgnorePointer(
                                child: SkinAnimationScope(
                                    child: skin.tabBarBuilder!(
                                        skin.boundPrimary!, false)))),
                        TextButton(
                            onPressed: () => taps++, child: const Text('记账')),
                      ])))));
      final first = await pixels(t);
      await t.pump(const Duration(milliseconds: 600));
      expect(await pixels(t), isNot(orderedEquals(first)));
      c.read(skinAnimationEnabledProvider.notifier).state = false;
      await t.pump();
      await t.pump();
      final off = await pixels(t);
      await t.pump(const Duration(milliseconds: 600));
      expect(await pixels(t), orderedEquals(off));
      if (capture) {
        await pixels(t, path: '.docs/v4-beta4-skin/tab-$id.png');
      }
      await t.tap(find.text('记账'));
      await t.pump();
      expect(taps, 1);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
