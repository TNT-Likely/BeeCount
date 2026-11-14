import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/auth/welcome_page.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'auto_sync': false}));
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('初始化五步保留选择并可在小屏访问 $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
              theme: beeTheme(),
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const WelcomePage())));
      await tester.pumpAndSettle();
      expect(find.byType(BeeOnboardingStep), findsWidgets);
      // Footer stays reachable while individual steps scroll.
      for (var step = 0; step < 4; step++) {
        expect(find.text('下一步'), findsOneWidget);
        await tester.tap(find.text('下一步'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('完成'), findsOneWidget);
      await tester.tap(find.text('上一步'));
      await tester.pumpAndSettle();
      expect(find.text('下一步'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('分层分类图标、展开、编辑与管理是独立入口', (tester) async {
    final events = <String>[];
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: BeeCategoryManagementList(
                reorderLabel: '拖动排序',
                items: const [
                  BeeManagedCategory(
                      id: 'food',
                      name: '餐饮',
                      detail: '2 个二级分类',
                      icon: Icon(Icons.restaurant),
                      children: [
                        BeeManagedCategory(
                            id: 'lunch',
                            name: '午餐',
                            detail: '',
                            icon: Icon(Icons.rice_bowl)),
                      ]),
                ],
                manageLabel: '管理',
                onEdit: (v) => events.add('edit:$v'),
                onManageChildren: (v) => events.add('manage:$v'),
                onReorder: (_, __) {}))));
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.rice_bowl), findsOneWidget);
    await tester.tap(find.text('午餐'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理'));
    await tester.pumpAndSettle();
    expect(events, ['edit:lunch', 'manage:food']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('转账账户选择器保留宿主筛选后的历史币种且不提供空账户', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: BeeAccountPicker(
                accounts: const [
              BeeAccountChoice(
                  id: 'cny', name: '现金', currency: 'CNY', balance: '120'),
              BeeAccountChoice(
                  id: 'retained',
                  name: '历史美元账户',
                  currency: 'USD',
                  balance: '30'),
            ],
                currency: 'CNY',
                filterByCurrency: false,
                allowUnset: false,
                selected: 'retained',
                searchLabel: '搜索账户',
                emptyLabel: '没有账户',
                unsetLabel: '不设置账户',
                onSelected: (v) => selected = v))));
    expect(find.text('不设置账户'), findsNothing);
    await tester.tap(find.text('历史美元账户'));
    expect(selected, 'retained');
  });
}
