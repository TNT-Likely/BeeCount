import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/presentation/v4/gallery/foundation_page.dart';
import 'package:beecount/presentation/v4/gallery/business_page.dart';
import 'package:beecount/presentation/v4/gallery/refresh_business_samples.dart';
import 'package:beecount_business_ui/card_refinements.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {bool compact = false}) => MaterialApp(
    theme: beeTheme(brightness: compact ? Brightness.dark : Brightness.light),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(compact ? 1.4 : 1)),
        child: child!),
    home: Scaffold(body: TickerMode(enabled: false, child: child)));
void size(WidgetTester t, bool compact) {
  t.view.physicalSize = compact ? const Size(320, 568) : const Size(430, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  for (final compact in [false, true]) {
    for (final index in [22, 23, 24, 25]) {
      testWidgets('新增基础组 $index 小屏大字=$compact', (t) async {
        size(t, compact);
        await t.pumpWidget(app(FoundationAcceptancePage(isolatedCase: index),
            compact: compact));
        await t.pump();
        expect(find.textContaining(foundationCases[index]), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
    for (final index in [75, 76, 77]) {
      testWidgets('新增业务组 $index 小屏大字=$compact 无数据绑定副作用', (t) async {
        size(t, compact);
        await t.pumpWidget(
            app(BusinessAcceptancePage(isolatedCase: index), compact: compact));
        await t.pump();
        expect(find.textContaining(businessCases[index]), findsOneWidget);
        if (index == 76) {
          for (final label in [
            '个人档案',
            '应用分享',
            '月度总结',
            '年度总结',
            '账本总结',
            '年度长图',
            '账单小票'
          ]) {
            expect(find.byKey(ValueKey('poster-label-$label')), findsOneWidget);
          }
        }
        if (index == 77) {
          expect(find.byType(BeeSyncHealthHeader), findsNWidgets(4));
        }
        expect(t.takeException(), isNull);
      });
    }
  }
  testWidgets('局部弹层可关闭，资产工具栏只更新本地回调', (t) async {
    size(t, false);
    await t.pumpWidget(app(const FoundationAcceptancePage(isolatedCase: 24)));
    await t.ensureVisible(find.text('打开局部弹层'));
    await t.tap(find.text('打开局部弹层'));
    await t.pump();
    expect(find.byType(BeeLocalSheet), findsOneWidget);
    await t.tap(find.byType(CloseButton));
    await t.pump();
    expect(find.byType(BeeLocalSheet), findsNothing);
    await t.pumpWidget(
        app(const SingleChildScrollView(child: AssetToolbarSample())));
    await t.tap(find.byTooltip('搜索账户示例'));
    await t.pump();
    expect(find.text('点击搜索账户'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('新增目录保持平铺且快速定位可到达', (t) async {
    size(t, false);
    await t.pumpWidget(app(const FoundationAcceptancePage()));
    for (final i in [22, 23, 24, 25]) {
      expect(find.byKey(ValueKey('foundation-section-$i')), findsOneWidget);
    }
    await t.tap(find.byKey(const ValueKey('foundation-case')));
    await t.pumpAndSettle();
    final target = find.descendant(
        of: find.byType(BeeSheet), matching: find.text('26 · 主题与系统状态栏'));
    await t.ensureVisible(target);
    await t.tap(target);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('foundation-section-25')).hitTestable(),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('海报同时保留七类，放大关闭与收入开关不调用平台导出', (t) async {
    size(t, true);
    await t.pumpWidget(
        app(const BusinessAcceptancePage(isolatedCase: 76), compact: true));
    await t.ensureVisible(find.text('隐藏样例海报收入'));
    await t.tap(find.text('隐藏样例海报收入'));
    await t.pump();
    final zoom = find.text('放大查看').first;
    await t.ensureVisible(zoom);
    await t.tap(zoom);
    await t.pumpAndSettle();
    expect(find.byType(BeeDialog), findsOneWidget);
    await t.tap(find.byType(CloseButton));
    await t.pumpAndSettle();
    expect(find.byType(BeeDialog), findsNothing);
    for (final label in [
      '个人档案',
      '应用分享',
      '月度总结',
      '年度总结',
      '账本总结',
      '年度长图',
      '账单小票'
    ]) {
      expect(find.byKey(ValueKey('poster-label-$label')), findsOneWidget);
    }
    expect(t.takeException(), isNull);
  });
  testWidgets('默认新增示例不持续运行ticker，动效需要显式播放', (t) async {
    size(t, false);
    for (final sample in [
      const StartupLayoutSample(),
      const SyncHealthSample()
    ]) {
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(body: SingleChildScrollView(child: sample))));
      await t.pump(const Duration(milliseconds: 1300));
      expect(t.binding.transientCallbackCount, 0);
      expect(t.takeException(), isNull);
    }
  });
}
