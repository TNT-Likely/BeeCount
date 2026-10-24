import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/theme.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount/presentation/v4/gallery/foundation_page.dart';
import 'package:beecount/presentation/v4/gallery/business_page.dart';
import 'package:beecount/presentation/v4/gallery/transaction_row_states.dart';
import 'package:beecount/presentation/v4/gallery/component_gallery_page.dart';

const capture = bool.fromEnvironment('BEECOUNT_CAPTURE_UI');
void main() {
  late int transactionFixtureCount;
  setUpAll(() async {
    transactionFixtureCount = (await transactionStateFixtures).length;
  });
  final boundary = GlobalKey();
  Future<void> open(WidgetTester tester, Widget child,
      {Brightness brightness = Brightness.light,
      Size size = const Size(390, 844),
      double scale = 1,
      bool reduceMotion = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var theme = beeTheme(brightness: brightness);
    if (capture) {
      final font = File('build/v4-recording-fonts/NotoSansSC-400.ttf');
      if (font.existsSync()) {
        final loader = FontLoader('Preview');
        loader.addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())));
        await tester.runAsync(loader.load);
        theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'Preview'));
      }
    }
    if (capture) {
      final font =
          File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
      if (font.existsSync()) {
        final loader = FontLoader('MaterialIcons');
        loader.addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())));
        await tester.runAsync(loader.load);
      }
    }
    await tester.pumpWidget(MaterialApp(
        theme: theme,
        locale: const Locale('zh'),
        supportedLocales: const [Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reduceMotion),
            child: child!),
        home: RepaintBoundary(
            key: boundary, child: Scaffold(body: SafeArea(child: child)))));
    await tester.pump(const Duration(milliseconds: 400));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (!capture) return;
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final f = File('build/v4-components/$name.png');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final config in [
    (
      name: 'light',
      brightness: Brightness.light,
      size: const Size(390, 844),
      scale: 1.0
    ),
    (
      name: 'dark',
      brightness: Brightness.dark,
      size: const Size(390, 844),
      scale: 1.0
    ),
    (
      name: 'narrow',
      brightness: Brightness.light,
      size: const Size(320, 568),
      scale: 1.0
    ),
    (
      name: 'large-text',
      brightness: Brightness.light,
      size: const Size(390, 844),
      scale: 1.4
    )
  ]) {
    testWidgets('两页全部目录无溢出 ${config.name}', (tester) async {
      for (var i = 0; i < foundationCases.length; i++) {
        await open(tester,
            FoundationAcceptancePage(key: ValueKey('f$i'), isolatedCase: i),
            brightness: config.brightness,
            size: config.size,
            scale: config.scale);
        expect(tester.takeException(), isNull, reason: '基础 $i ${config.name}');
        if (config.name == 'light') await shot(tester, 'foundation-$i');
      }
      for (var i = 0; i < businessCases.length; i++) {
        await open(tester,
            BusinessAcceptancePage(key: ValueKey('b$i'), isolatedCase: i),
            brightness: config.brightness,
            size: config.size,
            scale: config.scale);
        expect(tester.takeException(), isNull, reason: '业务 $i ${config.name}');
        if (config.name == 'light') await shot(tester, 'business-$i');
      }
    });
  }
  testWidgets('验收为原 App 内普通路由，切页与返回保留宿主页', (tester) async {
    await open(
        tester,
        Builder(
            builder: (context) => BeeButton(
                label: '组件验收入口',
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ComponentGalleryPage(
                            enableLiveData: false))))));
    await tester.tap(find.text('组件验收入口'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('基础组件验收'), findsOneWidget);
    await tester.tap(find.text('业务组件').last);
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('业务组件验收'), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(AppBar), matching: find.byTooltip('返回')));
    await tester.pumpAndSettle();
    expect(find.text('组件验收入口'), findsOneWidget);
    expect(find.byType(ComponentGalleryPage), findsNothing);
  });
  for (final group in ['foundation', 'business']) {
    testWidgets('平铺 $group：完整目录同时存在，快速定位滚动且保留状态', (tester) async {
      final labels = group == 'foundation' ? foundationCases : businessCases;
      await open(
          tester,
          TickerMode(
              enabled: false,
              child: group == 'foundation'
                  ? const FoundationAcceptancePage()
                  : const BusinessAcceptancePage()),
          reduceMotion: true);
      expect(find.byKey(ValueKey('$group-section-0')), findsOneWidget);
      expect(find.byKey(ValueKey('$group-section-${labels.length - 1}')),
          findsOneWidget);
      if (group == 'foundation') {
        await tester.tap(find.widgetWithText(BeeButton, '保存').first);
      } else {
        await tester.tap(find.widgetWithText(SwitchListTile, '显示品牌'));
      }
      await tester.pumpAndSettle();
      await shot(tester, 'flat-$group');
      await tester.tap(find.byKey(ValueKey('$group-case')));
      await tester.pumpAndSettle();
      final label =
          '${labels.length.toString().padLeft(2, '0')} · ${labels.last}';
      final item = find.widgetWithText(BeeButton, label);
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
      final view = tester.widget<SingleChildScrollView>(
          find.byKey(ValueKey('$group-catalog-scroll')));
      expect(view.controller!.offset, greaterThan(100));
      final last = tester
          .getRect(find.byKey(ValueKey('$group-section-${labels.length - 1}')));
      expect(last.top, greaterThanOrEqualTo(0));
      expect(
          last.top,
          lessThan(tester
              .getRect(find.byKey(ValueKey('$group-catalog-scroll')))
              .bottom));
      expect(find.byKey(ValueKey('$group-section-0')), findsOneWidget);
      if (group == 'foundation') {
        expect(find.text('已点击保存'), findsOneWidget);
      } else {
        expect(
            tester
                .widget<SwitchListTile>(
                    find.widgetWithText(SwitchListTile, '显示品牌'))
                .value,
            isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('平铺交叉操作：转账、排序与单选互不污染', (tester) async {
    await open(tester, const FoundationAcceptancePage());
    await tester.ensureVisible(find.text('转账'));
    await tester.tap(find.text('转账'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final select = find.byType(BeeSelectField<int>).first;
    await tester.ensureVisible(select);
    await tester.pumpAndSettle();
    await tester.tap(find.text('按日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按金额').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('仅云端副本'));
    await tester.tap(find.text('仅云端副本'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<BeeSegmented<int>>(find.byType(BeeSegmented<int>).first)
            .value,
        2);
    expect(tester.widget<BeeSelectField<int>>(select).value, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('平铺弹窗取消、确认、底部弹层关闭均保持原滚动位置', (tester) async {
    await open(tester, const FoundationAcceptancePage());
    // Keep a previously focused input above the dialog section, as on device.
    final field = find.descendant(
        of: find.byType(BeeField).first, matching: find.byType(TextField));
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.enterText(field, '日常生活');
    await tester.pumpAndSettle();
    final trigger = find.widgetWithText(BeeButton, '打开确认弹窗');
    await tester.ensureVisible(trigger);
    await tester.pumpAndSettle();
    final view = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('foundation-catalog-scroll')));
    final offset = view.controller!.offset;
    final y = tester.getTopLeft(trigger).dy;
    for (final action in ['取消', '删除', '关闭']) {
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      if (action == '关闭') {
        await tester.tap(find.byType(CloseButton));
      } else {
        await tester.tap(find.text(action).last);
      }
      await tester.pumpAndSettle();
      expect(view.controller!.offset, closeTo(offset, .1), reason: action);
      expect(tester.getTopLeft(trigger).dy, closeTo(y, .1), reason: action);
    }
    final sheet = find.widgetWithText(BeeButton, '打开底部弹层');
    await tester.ensureVisible(sheet);
    await tester.pumpAndSettle();
    final sheetOffset = view.controller!.offset;
    await tester.tap(sheet);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(BeeSheet)).height, lessThan(240));
    expect(tester.getSize(find.byType(BeeMenuRow).last).height, lessThan(80));
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(view.controller!.offset, closeTo(sheetOffset, .1));
    expect(find.text('日常生活'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('轻提示尺寸、顶部位置、替换、自动关闭及焦点不变', (tester) async {
    late BuildContext host;
    await open(tester, Builder(builder: (context) {
      host = context;
      return const Column(children: [BeeField(label: '备注')]);
    }));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    final focus = FocusManager.instance.primaryFocus;
    final dismiss = showBeeToast(host, '保存成功', tone: BeeTone.success);
    await tester.pump();
    final toast = find.byType(BeeToast);
    expect(tester.getSize(toast).height, inInclusiveRange(44, 80));
    expect(tester.getSize(toast).width, lessThanOrEqualTo(340));
    expect(tester.getTopLeft(toast).dy, 12);
    expect(FocusManager.instance.primaryFocus, same(focus));
    showBeeToast(host, '网络不可用，请重试', tone: BeeTone.error);
    await tester.pump();
    expect(find.byType(BeeToast), findsOneWidget);
    expect(find.text('保存成功'), findsNothing);
    dismiss(); // Dismissing the replaced toast cannot dismiss the new one.
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byType(BeeToast), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(BeeToast), findsNothing);
    final close = showBeeToast(host, '已保存');
    close();
    close(); // Also valid before the overlay has built once.
    await tester.pump();
    expect(find.byType(BeeToast), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('轻提示大字长文浅深色均随内容收缩，不撑满页面', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await open(tester, const FoundationAcceptancePage(isolatedCase: 9),
          brightness: brightness, size: const Size(320, 568), scale: 1.4);
      await tester.ensureVisible(find.text('显示失败提示'));
      await tester.tap(find.text('显示失败提示'));
      await tester.pump();
      final overlay = find.byType(BeeToast).last;
      expect(tester.getSize(overlay).height, lessThan(110));
      final text = tester.widget<Text>(
          find.descendant(of: overlay, matching: find.byType(Text)));
      expect(text.style!.fontSize, 13);
      expect(
          text.style!.color,
          brightness == Brightness.light
              ? Colors.white
              : const Color(0xff262829));
      showBeeToast(tester.element(find.text('显示失败提示')), '网络暂时不可用，请确认网络连接后重试',
          tone: BeeTone.error);
      await tester.pump();
      expect(
          tester.getSize(find.byType(BeeToast).last).height, greaterThan(60));
      expect(tester.getSize(find.byType(BeeToast).last).height, lessThan(130));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      await shot(tester, 'feedback-${brightness.name}-320');
    }
  });
  testWidgets('轻提示调用方卸载后可自动移除，持续状态高度随内容', (tester) async {
    late BuildContext host;
    await open(tester, Builder(builder: (context) {
      host = context;
      return const BeeStatus(label: '已保存', tone: BeeTone.success);
    }));
    expect(tester.getSize(find.byType(BeeStatus)).height, lessThan(60));
    showBeeToast(host, '保存成功');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('基础表单：校验、只读、密码切换、数字过滤和保存', (tester) async {
    await open(tester, const FoundationAcceptancePage(isolatedCase: 15));
    final save = find.widgetWithText(BeeButton, '校验并保存');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('名称不能为空'), findsOneWidget);
    final name = find.descendant(
        of: find.widgetWithText(BeeField, '必填名称'),
        matching: find.byType(TextField));
    await tester.ensureVisible(name);
    await tester.enterText(name, '验收名称');
    await tester.pumpAndSettle();
    expect(find.text('名称不能为空'), findsNothing);
    final readonly = find.descendant(
        of: find.widgetWithText(BeeField, '只读可复制'),
        matching: find.byType(TextField));
    expect(tester.widget<TextField>(readonly).readOnly, isTrue);
    final password = find.descendant(
        of: find.widgetWithText(BeeField, '密码输入'),
        matching: find.byType(TextField));
    expect(tester.widget<TextField>(password).obscureText, isTrue);
    await tester.ensureVisible(find.byTooltip('显示密码'));
    await tester.tap(find.byTooltip('显示密码'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(password).obscureText, isFalse);
    final digits = find.descendant(
        of: find.widgetWithText(BeeField, '数字过滤'),
        matching: find.byType(TextField));
    await tester.ensureVisible(digits);
    await tester.enterText(digits, 'a12b3');
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(digits).controller!.text, '123');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('校验通过：验收名称'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('基础搜索选择：长列表筛选、取消不写入和确认选项', (tester) async {
    await open(tester, const FoundationAcceptancePage(isolatedCase: 14));
    await tester.tap(find.text('打开搜索选择'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '29');
    await tester.pumpAndSettle();
    expect(find.text('选项 29'), findsOneWidget);
    expect(find.text('选项 01'), findsNothing);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('当前：选项 00；关闭不改变选择'), findsOneWidget);
    await tester.tap(find.text('打开搜索选择'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '29');
    await tester.pumpAndSettle();
    await tester.tap(find.text('选项 29'));
    await tester.pumpAndSettle();
    expect(find.text('当前：选项 29；关闭不改变选择'), findsOneWidget);
    await tester.tap(find.text('失败'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开搜索选择'));
    await tester.pumpAndSettle();
    expect(find.text('加载失败，请返回后重试'), findsOneWidget);
    await tester.tap(find.text('返回重试'));
    await tester.pumpAndSettle();
    expect(find.byType(BeeSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('通用标签多选：半选、全选和禁用项相互独立', (tester) async {
    await open(tester, const FoundationAcceptancePage(isolatedCase: 13));
    final all = find.widgetWithText(BeeCheckTile, '全选可用项');
    expect(tester.widget<BeeCheckTile>(all).mixed, isTrue);
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(tester.widget<BeeCheckTile>(all).mixed, isFalse);
    expect(tester.widget<BeeCheckTile>(all).value, isTrue);
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(tester.widget<BeeCheckTile>(all).value, isFalse);
    await tester.tap(find.widgetWithText(BeeChoiceChip, '禁用选项'));
    await tester.pumpAndSettle();
    expect(tester.widget<BeeCheckTile>(all).value, isFalse);
    await tester.tap(find.widgetWithText(BeeChoiceChip, '第二个选项'));
    await tester.pumpAndSettle();
    expect(tester.widget<BeeCheckTile>(all).mixed, isTrue);
  });
  testWidgets('搜索清空与外部 controller 所有权', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: '查询');
    String query = '查询';
    await open(
        tester,
        BeeSearchField(
            controller: controller,
            hint: '搜索',
            clearLabel: '清空搜索',
            onChanged: (v) => query = v));
    final input = tester.getSemantics(find.byType(EditableText));
    expect(input.hasFlag(ui.SemanticsFlag.isTextField), isTrue);
    expect(input.hasFlag(ui.SemanticsFlag.isImage), isFalse);
    semantics.dispose();
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
    expect(query, isEmpty);
    expect(find.byTooltip('清空搜索'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.text = '宿主仍可使用';
    expect(controller.text, '宿主仍可使用');
    controller.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('固定底部操作栏：滚动保持位置，处理中阻止重复操作', (tester) async {
    var submissions = 0;
    var loading = false;
    await open(
        tester,
        StatefulBuilder(
            builder: (context, update) => Scaffold(
                body: ListView(
                    children: List.generate(
                        30, (i) => SizedBox(height: 70, child: Text('条目 $i')))),
                bottomNavigationBar: BeeActionBar(
                    primaryLabel: '提交',
                    onPrimary: () => update(() {
                          submissions++;
                          loading = true;
                        }),
                    loading: loading,
                    secondaryLabel: '返回',
                    onSecondary: () {}))));
    final action = find.byType(BeeActionBar);
    final y = tester.getTopLeft(action).dy;
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(action).dy, y);
    await tester.tap(find.text('提交'));
    await tester.pump();
    await tester.tap(find.text('提交'));
    await tester.pump();
    expect(submissions, 1);
    expect(
        tester
            .widget<FilledButton>(find.ancestor(
                of: find.text('返回'), matching: find.byType(FilledButton)))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('分类选择器保留二级图标与草稿，确认才提交', (tester) async {
    await open(tester, const BusinessAcceptancePage(isolatedCase: 27));
    await tester.tap(find.widgetWithText(RecordingSubcategoryChip, '晚餐'));
    await tester.pumpAndSettle();
    expect(find.text('已确认分类 dinner'), findsNothing);
    await tester.tap(find.text('取消选择'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<RecordingSubcategoryChip>(
                find.widgetWithText(RecordingSubcategoryChip, '午餐'))
            .selected,
        isTrue);
    await tester.tap(find.widgetWithText(RecordingSubcategoryChip, '晚餐'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用分类'));
    await tester.pumpAndSettle();
    expect(find.text('已确认分类 dinner'), findsOneWidget);
    final confirmRect = tester.getRect(find.text('使用分类'));
    await tester.enterText(find.byType(TextField), '奶茶');
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('使用分类')), confirmRect);
    expect(find.widgetWithText(RecordingSubcategoryChip, '奶茶'), findsOneWidget);
    expect(find.widgetWithText(RecordingSubcategoryChip, '午餐'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('账户选择器按币种筛选，支持搜索和暂不设置', (tester) async {
    await open(tester, const BusinessAcceptancePage(isolatedCase: 28));
    expect(find.text('美元账户'), findsNothing);
    await tester.enterText(find.byType(TextField), '招商');
    await tester.pumpAndSettle();
    expect(find.text('微信'), findsNothing);
    await tester.tap(find.text('招商银行'));
    await tester.pumpAndSettle();
    expect(find.text('已选择账户 bank'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('暂不设置账户'));
    await tester.pumpAndSettle();
    expect(find.text('已选择账户 无'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('账本选择器显示当前态、搜索币种与共享信息，并更新选择', (tester) async {
    await open(tester, const BusinessAcceptancePage(isolatedCase: 31));
    expect(find.text('CNY · 个人账本 · 当前账本'), findsOneWidget);
    expect(find.text('CNY · 共享账本 · 2 位成员'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'USD');
    await tester.pumpAndSettle();
    expect(find.text('日常生活'), findsNothing);
    await tester.tap(find.text('旅行账本'));
    await tester.pumpAndSettle();
    expect(find.text('切换账本 旅行账本'), findsOneWidget);
    expect(find.text('USD · 个人账本 · 当前账本'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '不存在');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配账本'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('交易行状态全集：完整存在，隐私、标记、只读及收入色一致', (tester) async {
    await open(
        tester,
        const TickerMode(
            enabled: false, child: BusinessAcceptancePage(isolatedCase: 29)),
        size: const Size(320, 568),
        scale: 1.4);
    await tester.pumpAndSettle();
    expect(
        find.byType(BeeTransactionRow), findsNWidgets(transactionFixtureCount));
    final hidden = find.byKey(const ValueKey('state-hidden'));
    expect(
        find.descendant(
            of: hidden,
            matching: find.textContaining('12.00', findRichText: true)),
        findsNothing);
    expect(find.descendant(of: hidden, matching: find.textContaining('85.20')),
        findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('state-excluded')),
            matching: find.text('不计收支')),
        findsOneWidget);
    final readonly = find.byKey(const ValueKey('state-readonly'));
    await tester.ensureVisible(readonly);
    await tester.drag(readonly, const Offset(-230, 0));
    await tester.pumpAndSettle();
    expect(find.byType(BeeDialog), findsNothing);
    await tester
        .tap(find.descendant(of: readonly, matching: find.text('只读账单')));
    await tester.pumpAndSettle();
    expect(find.text('样式样例：账单详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('确认弹窗在小屏大字下双操作等宽，取消不执行', (tester) async {
    await open(tester, const FoundationAcceptancePage(isolatedCase: 6),
        size: const Size(320, 568), scale: 1.4);
    await tester.tap(find.text('打开确认弹窗'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BeeDialog), findsOneWidget);
    final cancel = find.widgetWithText(TextButton, '取消');
    final confirm = find.widgetWithText(FilledButton, '删除');
    expect(tester.getSize(cancel).width,
        closeTo(tester.getSize(confirm).width, .1));
    expect(
        tester.getRect(cancel).top, closeTo(tester.getRect(confirm).top, .1));
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(44));
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.text('确认删除'), findsNothing);
    expect(tester.takeException(), isNull);
    await shot(tester, 'dialog-cancelled');
  });
  testWidgets('账单标签在金额右侧下方，隐私开关同时隐藏原币折算和余额', (tester) async {
    await open(tester, const BusinessAcceptancePage(isolatedCase: 2));
    await tester.tap(find.text('显示外币折算'));
    await tester.pumpAndSettle();
    final tag = find.widgetWithText(BeeTag, '工作日');
    final title = find.text('午间食堂');
    final money = find.byType(BeeMoney);
    expect(tester.getCenter(tag).dx, greaterThan(tester.getCenter(title).dx));
    expect(tester.getRect(tag).top, greaterThan(tester.getRect(money).top));
    expect(find.text('≈ ¥86.40'), findsOneWidget);
    await open(
        tester,
        const BusinessAcceptancePage(
            key: ValueKey('balance'), isolatedCase: 11));
    expect(tester.getSize(find.byType(BeeLedgerBalance)).height, lessThan(105));
    expect(
        find.textContaining('12,860.50', findRichText: true), findsOneWidget);
    await tester.tap(find.byTooltip('隐藏金额'));
    await tester.pumpAndSettle();
    expect(find.textContaining('12,860.50', findRichText: true), findsNothing);
    expect(find.text('268'), findsOneWidget);
  });
  testWidgets('可点击交易标签仍是紧凑色块，选择器标签保留大触控块', (tester) async {
    var tapped = 0;
    await open(
        tester,
        Column(children: [
          BeeTransactionRow(
              title: '午餐',
              amount: '−32.00',
              icon: const Icon(Icons.restaurant),
              onCategoryTap: () {},
              onTap: () {},
              tags: const [BeeTagData('work', '工作日', Color(0xffaa8b29))],
              onTagTap: (_) => tapped++),
          BeeTag(
              tag: const BeeTagData('choice', '选择器标签', Color(0xffaa8b29)),
              onTap: () {}),
        ]));
    final inline = find.widgetWithText(BeeTag, '工作日');
    final pill = find.descendant(
        of: inline, matching: find.byKey(const ValueKey('bee-tag-pill')));
    expect(tester.getSize(pill).height, closeTo(21, .1));
    expect(tester.getSize(inline).height, 28);
    expect(tester.getSize(find.byType(BeeTransactionRow)).height,
        lessThanOrEqualTo(73));
    await tester.tapAt(tester.getTopLeft(inline) +
        Offset(tester.getSize(inline).width / 2, 1));
    await tester.pumpAndSettle();
    expect(tapped, 1);
    final choice = find.descendant(
        of: find.widgetWithText(BeeTag, '选择器标签'),
        matching: find.byKey(const ValueKey('bee-tag-pill')));
    expect(tester.getSize(choice).height, 44);
    expect(tester.takeException(), isNull);
  });
  testWidgets('标签搜索、清空和确认；关闭弹层不提交草稿', (tester) async {
    await open(tester, const BusinessAcceptancePage(isolatedCase: 6));
    await tester.tap(find.text('选择标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BeeTag, '旅行').first);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('旅行'), findsNothing);
    await tester.tap(find.text('选择标签'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '旅行');
    await tester.pumpAndSettle();
    expect(find.text('网购'), findsNothing);
    await tester.tap(find.widgetWithText(BeeTag, '旅行').first);
    await tester.tap(find.text('使用所选标签'));
    await tester.pumpAndSettle();
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('已选 2 个标签'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('分类图标与账单内容导航隔离；批量选择与左滑入口', (tester) async {
    await open(tester, const BusinessAcceptancePage(isolatedCase: 2));
    await tester.tap(find.byType(BeeCategoryIcon));
    await tester.pumpAndSettle();
    expect(find.text('进入分类详情'), findsOneWidget);
    await tester.tap(find.text('午间食堂'));
    await tester.pumpAndSettle();
    expect(find.text('进入账单详情'), findsOneWidget);
    await tester.tap(find.text('批量操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 笔'), findsOneWidget);
    expect(find.byKey(const ValueKey('transaction-swipe')), findsNothing);
    await tester.tap(find.text('批量操作'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    await tester.longPress(find.text('午间食堂'));
    await tester.pumpAndSettle();
    expect(find.text('账单操作'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const ValueKey('transaction-swipe')), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(find.text('左滑删除：需确认'), findsNothing);
    final delete = find.byKey(const ValueKey('transaction-swipe-delete'));
    expect(tester.getSize(delete).width, 78);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('左滑删除：需确认'), findsOneWidget);
  });
  testWidgets('汇率非法值禁用；昵称编辑取消、去空格保存', (tester) async {
    await open(tester, const BusinessAcceptancePage(isolatedCase: 8));
    await tester.tap(find.widgetWithText(BeeButton, '补充汇率'));
    await tester.pumpAndSettle();
    for (final v in ['0', '-1', 'NaN', 'Infinity', 'abc']) {
      await tester.enterText(find.byType(TextField), v);
      await tester.pump();
      expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '确定'))
              .onPressed,
          isNull);
    }
    await tester.enterText(find.byType(TextField), '7.3');
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('当前示例汇率 7.3'), findsOneWidget);
    await open(
        tester,
        const BusinessAcceptancePage(
            key: ValueKey('nickname'), isolatedCase: 12));
    await tester.tap(find.text('编辑昵称 · 小满'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新昵称');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('编辑昵称 · 小满'), findsOneWidget);
    await tester.tap(find.text('编辑昵称 · 小满'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  小蜂  ');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('编辑昵称 · 小蜂'), findsOneWidget);
  });
  testWidgets('账本当前态；长按与更多打开相同操作菜单', (tester) async {
    await open(tester, const BusinessAcceptancePage(isolatedCase: 9));
    await tester.tap(find.text('家庭账本'));
    await tester.pumpAndSettle();
    final cards =
        tester.widgetList<BeeLedgerCard>(find.byType(BeeLedgerCard)).toList();
    expect(cards[0].current, isFalse);
    expect(cards[1].current, isTrue);
    await tester.longPress(find.text('家庭账本'));
    await tester.pumpAndSettle();
    expect(find.text('仅删除本地'), findsOneWidget);
    expect(find.text('删除账本'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('显示菜单').last);
    await tester.pumpAndSettle();
    expect(find.text('仅删除本地'), findsOneWidget);
  });
  testWidgets('附件来源弹层：拍照、相册与取消回到原组件', (tester) async {
    await open(tester, const BusinessAcceptancePage(isolatedCase: 13));
    final add = find.text('添加示例图片');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BeeMenuRow, '拍照'));
    await tester.pumpAndSettle();
    expect(find.text('选择拍照来源'), findsOneWidget);
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BeeMenuRow, '从相册选择'));
    await tester.pumpAndSettle();
    expect(find.text('选择相册来源'), findsOneWidget);
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('选择相册来源'), findsOneWidget);
    expect(find.byType(BeeSheet), findsNothing);
  });

  testWidgets('附件数量布局与预览缩略图切换', (tester) async {
    await open(
        tester,
        BeeAttachments(items: const [
          BeeAttachment(
              id: 'a',
              image: AssetImage('assets/v4_gallery/attachment-payment.png'),
              label: '凭证',
              info: 'a'),
          BeeAttachment(
              id: 'b',
              image: AssetImage('assets/v4_gallery/attachment-receipt.png'),
              label: '小票',
              info: 'b')
        ], onOpen: (_) {}));
    expect(
        (tester.widget<GridView>(find.byType(GridView)).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2);
    await open(
        tester,
        const BeeAttachmentViewer(items: [
          BeeAttachment(
              id: 'a',
              image: AssetImage('assets/v4_gallery/attachment-payment.png'),
              label: '凭证',
              info: 'a'),
          BeeAttachment(
              id: 'b',
              image: AssetImage('assets/v4_gallery/attachment-receipt.png'),
              label: '小票',
              info: 'b')
        ]));
    expect(find.text('1 / 2 · 凭证'), findsOneWidget);
    await tester.tap(find.byType(InkWell).last);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2 · 小票'), findsOneWidget);
  });
  testWidgets('快捷记账 480ms、滑动松手和未命中取消', (tester) async {
    await open(tester, const BusinessAcceptancePage(isolatedCase: 20));
    final trigger = find.widgetWithText(BeeButton, '记一笔');
    final gesture = await tester.startGesture(tester.getCenter(trigger));
    await tester.pump(const Duration(milliseconds: 479));
    expect(find.text('取消'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();
    expect(find.byType(BeeQuickAddFan), findsOneWidget);
    await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('quick-fan-voice'))));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('滑动选择 voice'), findsOneWidget);
    final cancel = await tester.startGesture(tester.getCenter(trigger));
    await tester.pump(const Duration(milliseconds: 500));
    await cancel.moveTo(const Offset(5, 5));
    await cancel.up();
    await tester.pumpAndSettle();
    expect(find.text('已取消快捷菜单'), findsOneWidget);
    await tester.tap(find.byTooltip('快捷记账菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-fan-gallery')));
    await tester.pumpAndSettle();
    expect(find.text('滑动选择 gallery'), findsOneWidget);
  });
  testWidgets('日期滚轮切换闰年与月份夹取有效日期', (tester) async {
    DateTime date = DateTime(2024, 1, 31);
    await open(
        tester,
        StatefulBuilder(
            builder: (context, update) => BeeDateWheels(
                value: date, onChanged: (v) => update(() => date = v))));
    tester.widget<BeeWheel<int>>(find.byType(BeeWheel<int>).at(1)).onChanged(2);
    await tester.pumpAndSettle();
    expect(date, DateTime(2024, 2, 29));
    tester
        .widget<BeeWheel<int>>(find.byType(BeeWheel<int>).first)
        .onChanged(2025);
    await tester.pumpAndSettle();
    expect(date, DateTime(2025, 2, 28));
    expect(tester.takeException(), isNull);
  });
  testWidgets('搜索汇总卡与冻结 HTML 尺寸一致', (tester) async {
    final fixture = jsonDecode(
            File('test/fixtures/v4-search-geometry.json').readAsStringSync())
        as Map<String, dynamic>;
    final geometry = fixture['summary'] as Map<String, dynamic>;
    await open(
        tester,
        Center(
            child: SizedBox(
                width: (geometry['width'] as num).toDouble(),
                child: BeeSearchSummary(
                    title: '1 笔匹配账单',
                    expenseLabel: '支出合计',
                    expense: '¥124.25',
                    incomeLabel: '收入合计',
                    income: '¥0.00',
                    actionLabel: '批量操作',
                    onAction: () {}))));
    final card = tester.getSize(find.byType(BeeSearchSummary));
    expect(
        card.height,
        closeTo((geometry['height'] as num).toDouble(),
            (fixture['flutterParagraphRoundingTolerance'] as num).toDouble()));
    final amount = tester.getSize(find.text('¥124.25'));
    expect(
        tester
            .getSize(find
                .ancestor(
                    of: find.text('¥124.25'), matching: find.byType(Column))
                .first)
            .width,
        (geometry['metricWidth'] as num).toDouble());
    expect(
        amount.height,
        closeTo((geometry['amountLineHeight'] as num).toDouble(),
            (fixture['flutterParagraphRoundingTolerance'] as num).toDouble()));
    expect(tester.takeException(), isNull);
  });
  testWidgets('紧凑筛选视觉 34 并保留 44 触控区，边缘点击只触发一次', (tester) async {
    var taps = 0;
    await open(
        tester,
        Center(
            child: BeeChoiceChip(
                label: '筛选',
                selected: false,
                compact: true,
                trailing: const BeeLineIcon('X', size: 12),
                onSelected: (_) => taps++)));
    final chip = find.byType(BeeChoiceChip);
    final visual = find.byKey(const ValueKey('bee-choice-chip-visual'));
    expect(tester.getSize(visual).height, 34);
    expect(tester.getSize(chip).height, 44);
    await tester.tapAt(tester.getTopLeft(chip) + const Offset(3, 2));
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('真实 App 与组件页统一中性分隔线，不受旧 Material 种子色影响', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final source = brightness == Brightness.light
          ? BeeTheme.lightTheme()
          : BeeTheme.darkTheme();
      final theme = applyBeeCardTheme(source.copyWith(
          colorScheme:
              source.colorScheme.copyWith(primary: const Color(0xff26a69a))));
      final token = BeeCardTheme.fromBrightness(brightness).divider;
      expect(theme.dividerTheme.color, token);
      expect(theme.dividerColor, token);
      expect(theme.colorScheme.primary, const Color(0xff26a69a));
      await tester.pumpWidget(
          MaterialApp(theme: theme, home: const Scaffold(body: Divider())));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Divider));
      expect(DividerTheme.of(ctx).color, token);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('受限高度空态大字可滚到动作，保留页面尺寸且不溢出', (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!),
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 260,
                    height: 90,
                    child: BeeEmptyState(
                        title: '还没有账单',
                        message: '记录第一笔，保留长说明和原动作。',
                        action: BeeButton(
                            label: '重试', onPressed: () => retries++)))))));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(BeeEmptyState)), const Size(260, 90));
    await tester.ensureVisible(find.text('重试'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('分类图标和隐私操作保留独立按钮语义与回调', (tester) async {
    final semantics = tester.ensureSemantics();
    var category = 0, privacy = 0;
    try {
      await open(
          tester,
          Column(children: [
            BeeSummaryCard(
                title: '10月',
                amount: '32.00',
                amountLabel: '本月支出',
                incomeLabel: '收入',
                income: '0.00',
                expenseLabel: '结余',
                expense: '-32.00',
                privacyLabel: '隐藏金额',
                onPrivacyTap: () => privacy++),
            BeeTransactionRow(
                title: '午餐备注',
                categoryActionLabel: '餐饮 / 午餐',
                amount: '32.00',
                icon: const BeeLineIcon('Utensils'),
                onCategoryTap: () => category++,
                onTap: () {})
          ]));
      for (final label in ['隐藏金额', '餐饮 / 午餐']) {
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        expect(node.hasFlag(ui.SemanticsFlag.isButton), isTrue);
        expect(node.hasFlag(ui.SemanticsFlag.isImage), isFalse);
        await tester.tap(find.bySemanticsLabel(label));
      }
      expect(category, 1);
      expect(privacy, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  for (final dark in [false, true]) {
    testWidgets('扇形菜单与冻结HTML尺寸一致，独立标签和禁用回调 ${dark ? '小屏深色大字' : '标准屏'}',
        (tester) async {
      final contract = jsonDecode(
          File('test/fixtures/v4-quick-add-design-geometry.json')
              .readAsStringSync()) as Map<String, dynamic>;
      final semantics = tester.ensureSemantics();
      final selected = <String>[];
      var dismissed = 0;
      const origin = Offset(160, 450);
      try {
        await open(
            tester,
            BeeQuickAddFan(
                origin: origin,
                title: '快捷记账',
                hint: '长按后滑向目标，松手进入',
                cancelLabel: '取消',
                actions: const [
                  BeeAction(
                      id: 'camera', label: '拍照', icon: BeeLineIcon('Camera')),
                  BeeAction(
                      id: 'gallery', label: '相册', icon: BeeLineIcon('Images')),
                  BeeAction(id: 'voice', label: '语音', icon: BeeLineIcon('Mic')),
                ],
                disabled: const {'gallery'},
                onSelected: selected.add,
                onDismiss: () => dismissed++),
            size: const Size(320, 568),
            brightness: dark ? Brightness.dark : Brightness.light,
            scale: dark ? 1.4 : 1);
        for (final value in contract['actions'] as List) {
          final button = find.byKey(ValueKey('quick-fan-${value['method']}'));
          final circle = find.descendant(
              of: button,
              matching: find.byWidgetPredicate((w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).shape == BoxShape.circle));
          final rect = tester.getRect(circle);
          expect(rect.width, closeTo((value['width'] as num).toDouble(), .01));
          expect(
              rect.height, closeTo((value['height'] as num).toDouble(), .01));
          expect(rect.center.dx - origin.dx,
              closeTo((value['dx'] as num).toDouble(), .01));
          expect(rect.center.dy - origin.dy,
              closeTo((value['dy'] as num).toDouble(), .01));
          expect(tester.getSemantics(button).hasFlag(ui.SemanticsFlag.isButton),
              isTrue);
          expect(tester.getSemantics(button).hasFlag(ui.SemanticsFlag.isImage),
              isFalse);
        }
        final disabled = tester
            .getSemantics(find.byKey(const ValueKey('quick-fan-gallery')));
        expect(disabled.hasFlag(ui.SemanticsFlag.isEnabled), isFalse);
        await tester.tap(find.byKey(const ValueKey('quick-fan-camera')));
        expect(selected, ['camera']);
        await tester.tap(find.byKey(const ValueKey('quick-fan-dismiss')));
        expect(dismissed, 1);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}
