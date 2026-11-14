import 'package:beecount_business_ui/annual_report.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final annual in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('海报操作遵循规范并保留真实回调 $annual/$dark', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final theme =
            beeTheme(brightness: dark ? Brightness.dark : Brightness.light);
        var busy = false, saving = 0, sharing = 0;
        Rect? anchor;
        late StateSetter update;
        await tester.pumpWidget(MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.4)),
                child: child!),
            home: Scaffold(body: StatefulBuilder(builder: (context, state) {
              update = state;
              return annual
                  ? BeeAnnualPosterPreview(
                      title: '年度账单',
                      closeLabel: '关闭',
                      privacyLabel: '隐藏收入',
                      saveLabel: '保存到相册',
                      shareLabel: '分享',
                      preview: const SizedBox(width: 100, height: 100),
                      busy: busy,
                      onPrivacy: () {},
                      onSave: () => saving++,
                      onShare: () => sharing++,
                      onClose: () {})
                  : BeeReceiptComposer(
                      title: '账单小票',
                      closeLabel: '关闭',
                      fieldsLabel: '展示信息',
                      saveLabel: '保存到相册',
                      shareLabel: '分享',
                      preview: const SizedBox(width: 100, height: 100),
                      fields: const [],
                      selected: const {},
                      busy: busy,
                      onChanged: (_) {},
                      onClose: () {},
                      onSave: () => saving++,
                      onShare: (rect) {
                        sharing++;
                        anchor = rect;
                      });
            }))));
        await tester.pumpAndSettle();
        final prefix = annual ? 'annual-poster' : 'receipt';
        for (final name in ['save', 'share']) {
          final finder = find.byKey(ValueKey('$prefix-$name'));
          expect(tester.widget(finder), isA<BeeButton>());
          final inner =
              find.descendant(of: finder, matching: find.byType(FilledButton));
          final button = tester.widget<FilledButton>(inner);
          expect(
              button.style!.backgroundColor!.resolve({}),
              name == 'save'
                  ? BeeCardTheme.of(tester.element(inner)).soft
                  : theme.colorScheme.primary);
          expect(
              button.style!.foregroundColor!.resolve({}),
              name == 'save'
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onPrimary);
          expect(
              (button.style!.shape!.resolve({})! as RoundedRectangleBorder)
                  .borderRadius,
              BorderRadius.circular(15));
          expect(tester.getSize(finder).height, greaterThanOrEqualTo(44));
          await tester.tap(finder);
        }
        expect([saving, sharing], [1, 1]);
        if (!annual) {
          expect(anchor,
              tester.getRect(find.byKey(const ValueKey('receipt-share'))));
        }
        update(() => busy = true);
        await tester.pump();
        for (final name in ['save', 'share']) {
          final finder = find.byKey(ValueKey('$prefix-$name'));
          expect(tester.widget<BeeButton>(finder).onPressed, isNull);
          await tester.tap(finder);
        }
        expect([saving, sharing], [1, 1]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
