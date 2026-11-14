import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:beecount/pages/shared/appearance/skin_animation_scope.dart';
import 'package:beecount/pages/shared/scaffold/widgets/page_scaffold.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/styles/header_skins.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Life {
  final initialized = <String, int>{};
  final disposed = <String, int>{};
}

class _DraftPage extends StatefulWidget {
  const _DraftPage(
      {super.key, required this.id, required this.life, required this.scroll});
  final String id;
  final _Life life;
  final ScrollController scroll;
  @override
  State<_DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<_DraftPage> {
  final draft = TextEditingController();
  var count = 0;
  @override
  void initState() {
    super.initState();
    widget.life.initialized.update(widget.id, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  void dispose() {
    widget.life.disposed.update(widget.id, (n) => n + 1, ifAbsent: () => 1);
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
            child: ListView(
                key: ValueKey('list-${widget.id}'),
                controller: widget.scroll,
                children: [
              SizedBox(
                  height: 128,
                  child: BeeSurface(
                      child: TextField(
                          key: ValueKey('draft-${widget.id}'),
                          controller: draft,
                          decoration:
                              const InputDecoration(labelText: 'Draft')))),
              for (var i = 0; i < 80; i++)
                SizedBox(
                    height: 64, child: Text('${widget.id} transaction $i')),
            ])),
        TextButton(
            key: ValueKey('count-${widget.id}'),
            onPressed: () => setState(() => count++),
            child: Text('${widget.id} count $count')),
        TextButton(
            key: ValueKey('popup-${widget.id}'),
            onPressed: () => showBeeDialog<void>(context,
                    title: 'Animation popup',
                    child: const Text('Background is still visible'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Dismiss animation popup'))
                    ]),
            child: const Text('Cover with popup')),
        TextButton(
            key: ValueKey('detail-${widget.id}'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const V4PageScaffold(
                        body: Column(children: [
                      BackButton(),
                      BeeSurface(child: Text('Detail route')),
                    ])))),
            child: const Text('Open detail')),
      ]);
}

class _PageTabs extends StatefulWidget {
  const _PageTabs({required this.life, required this.scrolls});
  final _Life life;
  final List<ScrollController> scrolls;
  @override
  State<_PageTabs> createState() => _PageTabsState();
}

class _PageTabsState extends State<_PageTabs> {
  var index = 0;
  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
            child: IndexedStack(index: index, children: [
          for (var i = 0; i < 2; i++)
            TickerMode(
                enabled: i == index,
                child: V4PageScaffold(
                    key: ValueKey('host-$i'),
                    body: _DraftPage(
                        key: ValueKey('page-$i'),
                        id: '$i',
                        life: widget.life,
                        scroll: widget.scrolls[i]))),
        ])),
        Row(children: [
          for (var i = 0; i < 2; i++)
            Expanded(
                child: TextButton(
                    key: ValueKey('tab-$i'),
                    onPressed: () => setState(() => index = i),
                    child: Text('Page $i'))),
        ]),
      ]);
}

class _PopupHarness extends StatefulWidget {
  const _PopupHarness();
  @override
  State<_PopupHarness> createState() => _PopupHarnessState();
}

class _PopupHarnessState extends State<_PopupHarness> {
  String flow = 'all';
  bool local = false;
  int menus = 0;
  Future<void> filter() async {
    var draft = flow;
    final result = await showBeeSheet<String>(context,
        title: 'Filter transactions',
        child: StatefulBuilder(
            builder: (context, update) => BeeAccountFlowFilter(
                flow: draft,
                flows: const [
                  BeeSegment('all', 'All'),
                  BeeSegment('income', 'Income'),
                  BeeSegment('expense', 'Expense'),
                ],
                sort: 'time',
                sortLabel: 'Sort',
                sorts: const [BeeSegment('time', 'Time')],
                confirmLabel: 'Apply',
                onFlowChanged: (v) => update(() => draft = v),
                onSortChanged: (_) {},
                onConfirm: () => Navigator.pop(context, draft))));
    if (mounted && result != null) setState(() => flow = result);
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        ExcludeSemantics(
            excluding: local,
            child: BeeSurface(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Applied $flow'),
              TextButton(onPressed: filter, child: const Text('Open filter')),
              TextButton(
                  onPressed: () => showBeeDialog<void>(context,
                          title: 'Confirm',
                          child: const Text('Unsaved draft'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel dialog'))
                          ]),
                  child: const Text('Open dialog')),
              TextButton(
                  onPressed: () async {
                    final box = context.findRenderObject()! as RenderBox;
                    final result = await showBeeContextMenu<String>(context,
                        anchor: box.localToGlobal(const Offset(40, 40)),
                        items: const [
                          BeeMenuAction(value: 'pick', label: 'Menu pick')
                        ]);
                    if (result != null && mounted) setState(() => menus++);
                  },
                  child: const Text('Open menu')),
              Text('Menu selections $menus'),
              TextButton(
                  onPressed: () => setState(() => local = true),
                  child: const Text('Open local sheet')),
            ]))),
        if (local)
          Positioned.fill(
              child: BeeLocalSheet(
                  title: 'Local filter',
                  onClose: () => setState(() => local = false),
                  child: const Text('Local draft remains unsubmitted'))),
      ]);
}

void main() {
  ProviderContainer container(
          {bool animated = false, String skin = 'anniversary'}) =>
      ProviderContainer(overrides: [
        headerSkinsEnabledProvider.overrideWith((_) => true),
        headerSkinProvider.overrideWith((_) => skin),
        skinAnimationEnabledProvider.overrideWith((_) => animated),
      ]);

  Future<void> open(WidgetTester t, ProviderContainer c, Widget child,
      {double width = 398, bool dark = false}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, width == 320 ? 568 : 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme:
                beeTheme(brightness: dark ? Brightness.dark : Brightness.light),
            home: child)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
  }

  Animation<double> animation(WidgetTester t, String host) {
    final page = find.byKey(ValueKey(host), skipOffstage: false);
    final scope = find.descendant(
        of: page,
        matching: find.byType(SkinAnimationScope, skipOffstage: false),
        skipOffstage: false);
    expect(scope, findsOneWidget);
    final artwork = find.descendant(
        of: scope,
        matching: find.byType(HeaderSkinPageArtwork, skipOffstage: false),
        skipOffstage: false);
    final paint = t
        .widgetList<CustomPaint>(find.descendant(
            of: artwork,
            matching: find.byType(CustomPaint, skipOffstage: false),
            skipOffstage: false))
        .map((w) => w.painter)
        .firstWhere((p) => p.runtimeType.toString() == '_PageSkinPainter');
    return (paint as dynamic).animation as Animation<double>;
  }

  Future<Color> rowPixel(WidgetTester t, GlobalKey boundaryKey) async {
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final result = await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final x = image.width - 20, y = image.height - 9;
      final offset = (y * image.width + x) * 4;
      final bytes = data.buffer.asUint8List();
      final color = Color.fromARGB(bytes[offset + 3], bytes[offset],
          bytes[offset + 1], bytes[offset + 2]);
      image.dispose();
      return color;
    });
    return result!;
  }

  for (final width in [320.0, 398.0]) {
    for (final dark in [false, true]) {
      testWidgets(
          'skin/tab/route changes preserve unsaved draft and scroll $width dark=$dark',
          (t) async {
        final c = container(skin: 'none'), life = _Life();
        final scrolls = [ScrollController(), ScrollController()];
        addTearDown(c.dispose);
        for (final scroll in scrolls) {
          addTearDown(scroll.dispose);
        }
        await open(t, c, _PageTabs(life: life, scrolls: scrolls),
            width: width, dark: dark);
        await t.enterText(
            find.byKey(const ValueKey('draft-0')), 'unsaved original');
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('count-0')));
        await t.pumpAndSettle();
        scrolls[0].jumpTo(240);
        await t.pumpAndSettle();
        final offset = scrolls[0].offset;
        expect(offset, greaterThan(100));
        final state =
            t.state<_DraftPageState>(find.byKey(const ValueKey('page-0')));
        for (final skin in ['anniversary', 'anniv_cake', 'mountains', 'none']) {
          c.read(headerSkinProvider.notifier).state = skin;
          await t.pumpAndSettle();
          expect(
              identical(t.state(find.byKey(const ValueKey('page-0'))), state),
              isTrue);
          expect(scrolls[0].offset, offset);
          expect(state.draft.text, 'unsaved original');
          expect(find.text('0 count 1'), findsOneWidget);
        }
        await t.tap(find.byKey(const ValueKey('tab-1')));
        await t.pumpAndSettle();
        await t.drag(
            find.byKey(const ValueKey('list-1')), const Offset(0, -150));
        await t.pumpAndSettle();
        final secondOffset = scrolls[1].offset;
        await t.tap(find.byKey(const ValueKey('tab-0')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('detail-0')));
        await t.pumpAndSettle();
        c.read(headerSkinProvider.notifier).state = 'anniv_cake';
        await t.pumpAndSettle();
        expect(find.text('Detail route'), findsOneWidget);
        await t.tap(find.byType(BackButton));
        await t.pumpAndSettle();
        expect(scrolls[0].offset, offset);
        expect(scrolls[1].offset, secondOffset);
        expect(state.draft.text, 'unsaved original');
        expect(life.initialized, {'0': 1, '1': 1});
        expect(life.disposed, isEmpty);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });

      testWidgets(
          'filter/dialog/context/local overlays stay opaque and cancel safely $width dark=$dark',
          (t) async {
        final c = container();
        addTearDown(c.dispose);
        await open(t, c, const V4PageScaffold(body: _PopupHarness()),
            width: width, dark: dark);
        await t.pumpAndSettle();
        await t.tap(find.text('Open filter'));
        await t.pumpAndSettle();
        expect(
            t.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor!.a,
            1);
        await t.tap(find.text('Income'));
        await t.pumpAndSettle();
        await t.tap(find.byType(CloseButton));
        await t.pumpAndSettle();
        expect(find.text('Applied all'), findsOneWidget);
        await t.tap(find.text('Open filter'));
        await t.pumpAndSettle();
        await t.tap(find.text('Expense'));
        await t.tap(find.text('Apply'));
        await t.pumpAndSettle();
        expect(find.text('Applied expense'), findsOneWidget);
        await t.tap(find.text('Open dialog'));
        await t.pumpAndSettle();
        expect(t.widget<Dialog>(find.byType(Dialog)).backgroundColor!.a, 1);
        await t.tap(find.text('Cancel dialog'));
        await t.pumpAndSettle();
        await t.tap(find.text('Open menu'));
        await t.pumpAndSettle();
        final menuSurface = find
            .ancestor(
                of: find.text('Menu pick'), matching: find.byType(Material))
            .first;
        expect(t.widget<Material>(menuSurface).color!.a, 1);
        await t.tap(find.text('Menu pick'));
        await t.pumpAndSettle();
        expect(find.text('Menu selections 1'), findsOneWidget);
        await t.tap(find.text('Open local sheet'));
        await t.pumpAndSettle();
        final localSurface = find
            .descendant(
                of: find.byType(BeeLocalSheet), matching: find.byType(Material))
            .first;
        expect(t.widget<Material>(localSurface).color!.a, 1);
        await t.tap(find.byType(CloseButton));
        await t.pumpAndSettle();
        expect(find.text('Applied expense'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }

  for (final width in [320.0, 398.0]) {
    for (final dark in [false, true]) {
      testWidgets(
          'translucent swipe paints no hidden red and cancels without delete $width dark=$dark',
          (t) async {
        final c = container();
        addTearDown(c.dispose);
        final boundaryKey = GlobalKey();
        var requested = 0;
        const backdrop = Color(0xff336699);
        final row = SizedBox(
            height: 80,
            child: BeeSurface(
                padding: EdgeInsets.zero,
                child: BeeTransactionRow(
                    title: 'Bill',
                    amount: '-12.00',
                    icon: const Icon(Icons.restaurant),
                    onCategoryTap: () {},
                    onTap: () {},
                    deleteLabel: 'Delete transaction',
                    onDeleteRequested: () async {
                      requested++;
                    })));
        await open(
            t,
            c,
            V4PageScaffold(
                body: Center(
                    child: SizedBox(
                        width: width - 34,
                        child: RepaintBoundary(
                            key: boundaryKey,
                            child: ColoredBox(color: backdrop, child: row))))),
            width: width,
            dark: dark);
        await t.pumpAndSettle();
        final color = await rowPixel(t, boundaryKey);
        final surfaceContext = t.element(find.byType(BeeSurface));
        final expected =
            Color.alphaBlend(BeeCardTheme.of(surfaceContext).surface, backdrop);
        expect((color.r - expected.r).abs(), lessThanOrEqualTo(1 / 255));
        expect((color.g - expected.g).abs(), lessThanOrEqualTo(1 / 255));
        expect((color.b - expected.b).abs(), lessThanOrEqualTo(1 / 255));
        final red = find.byWidgetPredicate((w) =>
            w is Material &&
            (w.color == const Color(0xffcf6559) ||
                w.color == const Color(0xffae4e43)));
        final clippingStrip =
            find.ancestor(of: red, matching: find.byType(ClipRect)).first;
        expect(t.getSize(clippingStrip).width, 0);
        final gesture = await t.startGesture(
            t.getCenter(find.byKey(const ValueKey('transaction-swipe'))));
        await gesture.moveBy(const Offset(-24, 0));
        await t.pump();
        await gesture.moveBy(const Offset(-38, 0));
        await t.pump();
        expect(t.getSize(clippingStrip).width, greaterThan(0));
        await gesture.cancel();
        await t.pumpAndSettle();
        expect(t.getSize(clippingStrip).width, 0);
        expect(await rowPixel(t, boundaryKey), color);
        expect(requested, 0);
        await t.drag(find.byKey(const ValueKey('transaction-swipe')),
            const Offset(-110, 0));
        await t.pumpAndSettle();
        expect(t.getSize(clippingStrip).width, 78);
        await t.tapAt(
            t.getTopLeft(find.byKey(const ValueKey('transaction-swipe'))) +
                const Offset(25, 40));
        await t.pumpAndSettle();
        expect(t.getSize(clippingStrip).width, 0);
        expect(await rowPixel(t, boundaryKey), color);
        expect(requested, 0);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('first-card document anchor does not drift while list scrolls',
      (t) async {
    final c = container(), life = _Life(), scroll = ScrollController();
    addTearDown(c.dispose);
    addTearDown(scroll.dispose);
    await open(
        t,
        c,
        V4PageScaffold(
            body: _DraftPage(id: 'anchor', life: life, scroll: scroll)));
    await t.pumpAndSettle();
    final scene =
        t.widget<BeeSceneScope>(find.byType(BeeSceneScope)).controller;
    final original = scene.value;
    expect(original, isNotNull);
    await t.drag(
        find.byKey(const ValueKey('list-anchor')), const Offset(0, -240));
    await t.pumpAndSettle();
    expect(scroll.offset, greaterThan(100));
    expect(scene.value, original,
        reason:
            'Scene artwork binds to the document card, not scrolling viewport rectangles');
    scroll.jumpTo(1400);
    await t.pumpAndSettle();
    expect(scene.value, original,
        reason:
            'Lazy disposal beyond cacheExtent must not retarget the scene to a later row');
    scroll.jumpTo(0);
    await t.pumpAndSettle();
    expect(scene.value, original,
        reason: 'Reattached original card keeps its document anchor');

    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  for (final id in ['anniversary', 'anniv_cake']) {
    testWidgets(
        'real skin ticker stops in background, covered routes and inactive tabs then resumes $id',
        (t) async {
      final c = container(animated: true, skin: id), life = _Life();
      final scrolls = [ScrollController(), ScrollController()];
      addTearDown(c.dispose);
      for (final scroll in scrolls) {
        addTearDown(scroll.dispose);
      }
      addTearDown(() =>
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await open(t, c, _PageTabs(life: life, scrolls: scrolls));
      await t.pump(const Duration(milliseconds: 120));
      final first = animation(t, 'host-0');
      final initial = first.value;
      await t.pump(const Duration(milliseconds: 120));
      expect(first.value, isNot(initial));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      final background = first.value;
      await t.pump(const Duration(milliseconds: 700));
      expect(first.value, background);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(milliseconds: 300));
      expect(first.value, background);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      expect(first.value, isNot(background));
      await t.tap(find.byKey(const ValueKey('tab-1')));
      await t.pump();
      final inactive = first.value;
      final second = animation(t, 'host-1');
      final secondInitial = second.value;
      await t.pump(const Duration(milliseconds: 700));
      expect(first.value, inactive);
      expect(second.value, isNot(secondInitial));
      await t.tap(find.byKey(const ValueKey('tab-0')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('popup-0')));
      await t.pump(const Duration(milliseconds: 450));
      final covered = first.value;
      await t.pump(const Duration(milliseconds: 700));
      expect(first.value, covered);
      await t.tap(find.text('Dismiss animation popup'));
      await t.pump(const Duration(milliseconds: 450));
      await t.pump(const Duration(milliseconds: 120));
      expect(first.value, isNot(covered));
      c.read(skinAnimationEnabledProvider.notifier).state = false;
      await t.pump();
      final disabled = first.value;
      await t.pump(const Duration(milliseconds: 700));
      expect(first.value, disabled);
      expect(life.initialized, {'0': 1, '1': 1});
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
