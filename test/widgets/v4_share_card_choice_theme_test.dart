import 'package:beecount_business_ui/share_card.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final small in [false, true]) {
      testWidgets('原分享双模板跟随主题、可切换且忙碌时禁用 $dark/$small', (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(small ? 320 : 398, small ? 568 : 844);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        var selected = 'profile';
        var busy = false;
        final calls = <String>[];
        late StateSetter redraw;
        final baseTheme =
            beeTheme(brightness: dark ? Brightness.dark : Brightness.light);
        final theme = small
            ? baseTheme.copyWith(
                colorScheme: baseTheme.colorScheme
                    .copyWith(primary: const Color(0xff219c9c)))
            : baseTheme;
        await t.pumpWidget(MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(small ? 1.4 : 1)),
                child: child!),
            home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
              redraw = setState;
              return BeeShareCard(
                  title: '分享卡片',
                  closeLabel: '关闭',
                  saveLabel: '保存到相册',
                  shareLabel: '分享',
                  generatingLabel: '生成中',
                  retryLabel: '重试',
                  preview: const ColoredBox(
                      key: ValueKey('unchanged-poster'),
                      color: Colors.yellow,
                      child: SizedBox(width: 120, height: 200)),
                  templates: const [
                    BeeShareCardTemplate('profile', '我的档案'),
                    BeeShareCardTemplate('app', '分享应用')
                  ],
                  selected: selected,
                  busy: busy,
                  onTemplate: (id) {
                    calls.add(id);
                    setState(() => selected = id);
                  });
            }))));
        final profile =
            find.byKey(const ValueKey('share-card-template-profile'));
        final app = find.byKey(const ValueKey('share-card-template-app'));
        Color selectedPaint(Finder target) {
          final inkColors = t
              .widgetList<Ink>(
                  find.descendant(of: target, matching: find.byType(Ink)))
              .map((ink) => ink.decoration)
              .whereType<ShapeDecoration>()
              .map((d) => d.color);
          final materialColors = t
              .widgetList<Material>(
                  find.descendant(of: target, matching: find.byType(Material)))
              .map((m) => m.color);
          return [...inkColors, ...materialColors].firstWhere(
              (color) => color != null && color != Colors.transparent)!;
        }

        // Approved D uses a neutral segmented track and white selected surface.
        expect(selectedPaint(profile),
            BeeCardTheme.of(t.element(find.byType(BeeShareCard))).surface);
        expect(t.getSize(profile).height, greaterThanOrEqualTo(44));
        await t.tap(app);
        await t.pumpAndSettle();
        expect(calls, ['app']);
        expect(selectedPaint(app),
            BeeCardTheme.of(t.element(find.byType(BeeShareCard))).surface);
        redraw(() => busy = true);
        // Busy shows an intentional indeterminate spinner; verify the disabled
        // control after a bounded frame rather than waiting for it to stop.
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(profile);
        await t.pump(const Duration(milliseconds: 400));
        expect(calls, ['app']);
        expect(find.byKey(const ValueKey('unchanged-poster')), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
