import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_business_ui/share_posters.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> showView(WidgetTester tester, Widget view,
    {bool settle = true}) async {
  await tester.pumpWidget(MaterialApp(
      theme: applyBeeCardTheme(ThemeData()), home: Scaffold(body: view)));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const promo = BeePromotionData(
    logoAsset: 'missing-synthetic-logo.png',
    title: '合成产品',
    subtitle: '产品说明',
    introBody: '纯展示内容',
    brandColor: Colors.amber,
    contactEmail: 'qa@example.invalid',
    screenshotAssets: ['synthetic-screen.png']);
const promoTexts = BeePromotionTexts(
    betaDialogTitle: '内测',
    betaDialogMessage: '内测说明',
    emailLabel: '申请邮箱',
    emailButton: '申请内测',
    websiteButton: '官网',
    openStoreButton: '商店',
    testFlightButton: 'TestFlight');

void main() {
  testWidgets('2FA展示受控方法、输入限制、错误与忙状态，不执行验证', (tester) async {
    final controller = TextEditingController();
    final changed = <String>[];
    String? method;
    var submitted = 0;
    Widget challenge({bool busy = false}) => BeeTwoFactorChallengeDialog(
        title: '验证',
        email: 'qa@example.invalid',
        method: 'totp',
        totpLabel: '验证码',
        recoveryLabel: '恢复码',
        totpHint: '六位数字',
        recoveryHint: '恢复码',
        cancelLabel: '取消',
        verifyLabel: '确定',
        controller: controller,
        hasRecovery: true,
        verifying: busy,
        canSubmit: !busy,
        errorMessage: '错误由宿主传入',
        onMethodChanged: (value) => method = value,
        onCodeChanged: changed.add,
        onSubmit: () => submitted++,
        onCancel: () {});
    await showView(tester, challenge());
    await tester.enterText(find.byType(TextField), 'ab12345678');
    expect(controller.text, '123456');
    expect(changed.last, '123456');
    expect(find.text('错误由宿主传入'), findsOneWidget);
    await tester.tap(find.text('恢复码'));
    expect(method, 'recovery_code');
    await tester.tap(find.text('确定'));
    expect(submitted, 1);
    await showView(tester, challenge(busy: true), settle: false);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('推广未上架展示邮箱和申请，截图与动作交还宿主', (tester) async {
    final actions = <String>[];
    int? screenshot;
    await showView(
        tester,
        BeePromotionDialog(
            info: promo,
            texts: promoTexts,
            hasStore: false,
            dualStore: false,
            onWebsite: () => actions.add('website'),
            onEmail: () => actions.add('email'),
            onCopyEmail: () => actions.add('copy'),
            onScreenshot: (index) => screenshot = index));
    expect(find.text('申请内测'), findsOneWidget);
    expect(find.text('TestFlight'), findsNothing);
    await tester.ensureVisible(find.byType(BeePromotionScreenshot));
    final thumb = tester.getRect(find.byType(BeePromotionScreenshot));
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    final visible = thumb.intersect(viewport);
    expect(visible.height, greaterThan(0));
    await tester.tapAt(visible.center);
    expect(screenshot, 0);
    await tester.ensureVisible(find.text('qa@example.invalid'));
    await tester.tap(find.text('qa@example.invalid'));
    await tester.tap(find.text('申请内测'));
    await tester.tap(find.text('官网'));
    expect(actions, ['copy', 'email', 'website']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('推广双渠道与图片预览保持受控，不在包内导航', (tester) async {
    final actions = <String>[];
    await showView(
        tester,
        BeePromotionDialog(
            info: promo,
            texts: promoTexts,
            hasStore: true,
            dualStore: true,
            onWebsite: () {},
            onEmail: () {},
            onCopyEmail: () {},
            onScreenshot: (_) {},
            onStore: () => actions.add('store'),
            onTestFlight: () => actions.add('testflight')));
    expect(find.text('申请内测'), findsNothing);
    await tester.ensureVisible(find.text('TestFlight'));
    await tester.tap(find.text('TestFlight'));
    await tester.tap(find.text('商店'));
    expect(actions, ['testflight', 'store']);
    var closed = 0;
    await showView(
        tester,
        BeePromotionGallery(
            assets: const ['first.png', 'second.png'],
            initialIndex: 1,
            onClose: () => closed++));
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(closed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('年度海报保留章节、隐私值、空态与成就状态', (tester) async {
    await showView(
        tester,
        const SingleChildScrollView(
            child: BeeAnnualReportPoster(
                header: Text('品牌'),
                footer: Text('页脚'),
                year: '2026',
                subtitle: '年度记录',
                expenseLabel: '支出 CNY',
                expense: '¥120.00',
                accent: Colors.amber,
                summaryMetrics: [
              BeePosterMetric('收入', '**')
            ],
                chapters: [
              BeeAnnualPosterChapter(index: '01', title: '记录', metricGroups: [
                [BeePosterMetric('日均', '¥12.00')]
              ]),
              BeeAnnualPosterChapter(
                  index: '02',
                  title: '分类',
                  categories: [],
                  rankingTitle: '排名',
                  emptyLabel: '暂无分类'),
              BeeAnnualPosterChapter(
                  index: '03',
                  title: '成就',
                  moments: [
                    BeeAnnualPosterMoment(
                        label: '坚持',
                        note: '尚未解锁',
                        icon: Icon(Icons.star),
                        unlocked: false)
                  ],
                  emptyMomentLabel: '暂无记录'),
            ])));
    for (final label in ['2026', '**', '¥12.00', '暂无分类', '尚未解锁', '暂无记录']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
        tester.widget<BeePosterMoment>(find.byType(BeePosterMoment)).unlocked,
        isFalse);
    expect(tester.takeException(), isNull);
  });
}
