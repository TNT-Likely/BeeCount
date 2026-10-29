import 'dart:convert';
import 'dart:typed_data';
import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/account/overview/widgets/account_sections.dart';
import 'package:beecount/pages/shared/resources/bindings/recording_category_icon.dart';
import 'package:beecount/pages/shared/resources/category_icon_adapter.dart';
import 'package:beecount/utils/account_type_utils.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_business_ui/support.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

final _transparent = Uint8List.fromList(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='));

Widget host(Widget child, {bool dark = false, double scale = 1}) =>
    ProviderScope(
        child: MaterialApp(
            theme:
                beeTheme(brightness: dark ? Brightness.dark : Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(17), child: child)))));

void main() {
  testWidgets('透明自定义图片完整占满图标容器，预设图标仍保留留白', (t) async {
    await t.pumpWidget(host(Row(children: [
      BeeCategoryIcon(
          key: const ValueKey('custom'),
          size: 44,
          image: MemoryImage(_transparent)),
      const BeeCategoryIcon(key: ValueKey('preset'), size: 44),
    ])));
    await t.runAsync(() => precacheImage(MemoryImage(_transparent),
        t.element(find.byType(BeeCategoryIcon).first)));
    await t.pumpAndSettle();
    final image = find.descendant(
        of: find.byKey(const ValueKey('custom')), matching: find.byType(Image));
    expect(t.getSize(image), const Size(44, 44));
    expect(t.widget<Image>(image).fit, BoxFit.contain);
    final line = find.descendant(
        of: find.byKey(const ValueKey('preset')),
        matching: find.byType(BeeLineIcon));
    expect(t.widget<BeeLineIcon>(line).size, 44 * .55);
    expect(t.takeException(), isNull);
  });

  testWidgets('生产分类图片跟随方形容器，行内不膨胀到整行', (t) async {
    const category = Category(
        id: 1,
        name: '自定义',
        kind: 'expense',
        level: 1,
        sortOrder: 0,
        iconType: 'custom',
        customIconPath: 'test.png');
    await t.pumpWidget(host(Column(children: [
      const SizedBox(
          width: 34,
          height: 34,
          child: Center(
              child: RecordingCategoryIcon(category: category, size: 19))),
      const Row(children: [
        RecordingCategoryIcon(category: category, size: 18),
        Text('午餐')
      ]),
    ])));
    final pictures = t
        .widgetList<CategoryIconWidget>(find.byType(CategoryIconWidget))
        .toList();
    expect(pictures.map((x) => x.size), [34, 18]);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 398.0]) {
    for (final scale in [1.0, 1.4]) {
      testWidgets('尾部操作贴右且关于保留完整操作 $width $scale', (t) async {
        t.view.physicalSize = Size(width, 1400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var unit = 0, detail = 0, test = 0, story = 0, source = 0, share = 0;
        await t.pumpWidget(host(
            Column(children: [
              BeeAssetOverviewCard(
                  title: '净资产',
                  balance: '12,860.50',
                  assetsLabel: '资产',
                  assets: '13,860.50',
                  liabilitiesLabel: '负债',
                  liabilities: '1,000.00',
                  hidden: false,
                  privacyLabel: '隐藏',
                  onPrivacy: () {},
                  unitLabel: '折算 CNY',
                  onUnit: () => unit++,
                  footnote: '汇率更新于今天',
                  detailLabel: '明细',
                  onDetails: () => detail++),
              BeeAIModelTestField(
                  title: '文本模型',
                  testLabel: '测试连接',
                  field: const SizedBox(height: 30),
                  onTest: () => test++),
              BeeSupportBrand(
                  logo: const Icon(Icons.emoji_nature),
                  title: '蜜蜂记账',
                  version: '4.0.0-beta.2 (227)',
                  tag: '开源 · 免费',
                  description: '简单记录，安心生活。开源、本地存储与可选云同步。',
                  sourceLabel: '查看源代码',
                  recommendLabel: '推荐给朋友',
                  onStory: () => story++,
                  onSource: () => source++,
                  onRecommend: () => share++,
                  socials: const []),
            ]),
            scale: scale,
            dark: scale > 1));
        await t.pumpAndSettle();
        final card = find.byType(BeeAssetOverviewCard);
        final edge = t.getRect(card).right - 21;
        final unitButton = find
            .ancestor(of: find.text('折算 CNY'), matching: find.byType(InkWell))
            .first;
        final detailButton = find
            .ancestor(of: find.text('明细'), matching: find.byType(InkWell))
            .first;
        expect(t.getRect(unitButton).right, closeTo(edge, .1));
        expect(t.getRect(detailButton).right, closeTo(edge, .1));
        final testButton = find
            .ancestor(
                of: find.text('测试连接'),
                matching: find.byWidgetPredicate((w) => w is TextButton))
            .first;
        expect(t.getRect(testButton).right, closeTo(width - 17, .1));
        expect(t.getCenter(find.byKey(const ValueKey('support-story'))).dx,
            closeTo(width / 2, .1));
        for (final finder in [
          find.text('折算 CNY'),
          find.text('明细'),
          testButton,
          find.byKey(const ValueKey('support-story')),
          find.text('查看源代码'),
          find.text('推荐给朋友')
        ]) {
          await t.ensureVisible(finder);
          await t.tap(finder);
          await t.pump();
        }
        expect([unit, detail, test, story, source, share], [1, 1, 1, 1, 1, 1]);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('账户紧凑列表沿用详情编辑的原彩色SVG', (t) async {
    await t.pumpWidget(host(AccountCardBinding(
        account: const Account(
            id: 1,
            ledgerId: 1,
            name: '支付宝',
            type: 'alipay',
            currency: 'CNY',
            initialBalance: 0,
            sortOrder: 0,
            hidden: false),
        compact: true,
        primaryColor: Colors.amber,
        typeColor: Colors.blue,
        stats: (balance: 20, expense: 0, income: 20),
        display: const AccountCardDisplayData(
            hidden: false,
            compactMoney: false,
            multiCurrencyActive: false,
            base: 'CNY',
            rates: null,
            defaultExpense: null,
            defaultIncome: null),
        onTap: () {},
        onEdit: () {})));
    await t.pumpAndSettle();
    final icon = t.widget<AccountTypeIcon>(find.byType(AccountTypeIcon));
    expect(icon.monochrome, isFalse);
    expect(
        t
            .widget<SvgPicture>(find.descendant(
                of: find.byType(AccountTypeIcon),
                matching: find.byType(SvgPicture)))
            .colorFilter,
        isNull);
    expect(t.takeException(), isNull);
  });
}
