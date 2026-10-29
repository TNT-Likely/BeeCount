import 'package:beecount/dev/component_gallery/business_page.dart';
import 'package:beecount/dev/component_gallery/foundation_page.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester t, Widget sample) async {
    t.view.physicalSize = const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: sample)));
    await t.pumpAndSettle();
  }

  testWidgets('逐字文本在实际动态组中可重播并恢复完整静态文字', (t) async {
    await open(t, const FoundationAcceptancePage(isolatedCase: 24));
    expect(find.byType(TypewriterText), findsNWidgets(2));
    expect(find.text('一笔一笔，记录生活。'), findsOneWidget);
    await t.ensureVisible(find.text('重播描线'));
    await t.tap(find.text('重播描线'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 180));
    final texts = t.widgetList<Text>(find.byType(Text)).map((w) => w.data);
    expect(texts, contains('一笔'));
    await t.tap(find.text('静态背景'));
    await t.pump();
    expect(find.text('一笔一笔，记录生活。'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('安全组提供双重验证、错误恢复及取消且不请求服务端', (t) async {
    await open(t, const BusinessAcceptancePage(isolatedCase: 26));
    await t.ensureVisible(find.text('打开双重验证示例'));
    await t.tap(find.text('打开双重验证示例'));
    await t.pumpAndSettle();
    expect(find.byType(BeeTwoFactorChallengeDialog), findsOneWidget);
    await t.enterText(find.byType(TextField), '000000');
    await t.pump();
    await t.tap(find.text('验证示例'));
    await t.pump(const Duration(milliseconds: 350));
    await t.pumpAndSettle();
    expect(find.text('示例校验失败，请输入其他验证码'), findsOneWidget);
    await t.tap(find.text('恢复码'));
    await t.pump();
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
    await t.enterText(find.byType(TextField), 'QA-RECOVERY');
    await t.tap(find.text('取消'));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 350));
    expect(find.byType(BeeTwoFactorChallengeDialog), findsNothing);
    expect(find.text('已取消示例'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('支持组产品紧凑卡可打开介绍、截图浏览并关闭', (t) async {
    await open(t, const BusinessAcceptancePage(isolatedCase: 73));
    expect(find.byType(BeePromotionCard), findsOneWidget);
    final compact = find.byType(BeePromotionCompact);
    await t.ensureVisible(compact);
    await t.tap(compact);
    await t.pumpAndSettle();
    expect(find.byType(BeePromotionDialog), findsOneWidget);
    final screenshot = find.byType(BeePromotionScreenshot).last;
    await t.ensureVisible(screenshot);
    await t.tap(screenshot);
    await t.pumpAndSettle();
    expect(find.byType(BeePromotionGallery), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(find.byType(BeePromotionGallery), findsNothing);
    expect(find.byType(BeePromotionDialog), findsOneWidget);
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 1));
  });
}
