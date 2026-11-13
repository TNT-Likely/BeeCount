import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/shared/feedback/recording_progress_dialog.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [320.0, 398.0]) {
      testWidgets('记账进度跟随真实阶段，无百分比且小屏无溢出 $dark/$width', (t) async {
        t.view.physicalSize = Size(width, 568);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final saving = ValueNotifier(false);
        await t.pumpWidget(MaterialApp(
          theme:
              beeTheme(brightness: dark ? Brightness.dark : Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!),
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => RecordingProgressDialog(
                              saving: saving,
                              sourceLabel: '图片记账',
                              ledgerName: '测试日常账本')),
                      child: const Text('开始')))),
        ));
        await t.tap(find.text('开始'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 350));
        expect(find.text('正在识别账单'), findsOneWidget);
        expect(
            t
                .widget<LinearProgressIndicator>(
                    find.byType(LinearProgressIndicator))
                .value,
            isNull);
        final rect = t.getRect(find.byType(RecordingProgressCard));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        await t.binding.handlePopRoute();
        await t.pump();
        expect(find.byType(RecordingProgressCard), findsOneWidget);
        saving.value = true;
        await t.pump();
        expect(find.text('正在记账'), findsOneWidget);
        expect(find.text('正在识别账单'), findsNothing);
        await t.pump(const Duration(seconds: 13));
        expect(find.text('这次处理时间稍长，仍在继续处理。'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        saving.dispose();
        await t.pump(const Duration(seconds: 20));
        expect(t.takeException(), isNull);
      });
    }
  }
}
