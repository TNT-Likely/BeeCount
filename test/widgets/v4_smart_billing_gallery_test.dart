import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/dev/component_gallery/billing_guide_sample.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('54组四种完整说明/原弹窗与受控语音松手事件', (t) async {
    t.view.physicalSize = const Size(398, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
            body: SingleChildScrollView(child: BillingGuideSample()))));
    await t.pumpAndSettle();
    final l = AppLocalizations.of(t.element(find.byType(BillingGuideSample)));
    await t.tap(find.text(l.shareBilling));
    await t.pumpAndSettle();
    expect(t.widget<BeeBillingGuide>(find.byType(BeeBillingGuide)).actionHint,
        l.shareBillingActionHint);
    await t.ensureVisible(find.text('预览说明弹窗'));
    await t.tap(find.text('预览说明弹窗'));
    await t.pumpAndSettle();
    expect(find.byType(BeeDialog), findsOneWidget);
    await t.tap(find.text(l.commonKnow));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(Slider));
    await t.pumpAndSettle();
    final bounds = t.getRect(find.byType(Slider));
    final gesture = await t.startGesture(bounds.center);
    await gesture.moveTo(Offset(bounds.right - 1, bounds.center.dy));
    await t.pump();
    expect(find.text('示例松手提交 4000 ms'), findsNothing);
    await gesture.up();
    await t.pumpAndSettle();
    expect(find.text('示例松手提交 4000 ms'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
