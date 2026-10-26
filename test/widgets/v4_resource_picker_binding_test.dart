import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/tag/widgets/tag_selector.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/currency/currency_picker_sheet.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void pickerTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }
  });
}

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late int work, trip;
  List<int>? selectedTags;
  String? selectedCurrency;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id,name,currency) VALUES(1,'QA','CNY')");
    work = await repo.createTag(name: '工作日', color: '#d5a520');
    trip = await repo.createTag(name: '旅行', color: '#3344ff');
    final tx = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        happenedAt: DateTime(2026, 10, 24));
    await repo.updateTransactionTags(transactionId: tx, tagIds: [work]);
    selectedTags = null;
    selectedCurrency = null;
  });
  tearDown(() async => db.close());

  Future<void> host(WidgetTester tester,
      {Size size = const Size(398, 844), double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
          currentLedgerIdProvider.overrideWith((ref) => 1),
          currencyPickerRatesProvider('CNY')
              .overrideWith((ref) async => {'USD': 7.1}),
        ],
        child: MaterialApp(
            theme: beeTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
                builder: (context) => Scaffold(
                        body: Column(children: [
                      TextButton(
                          onPressed: () async => selectedTags =
                              await TagSelector.show(context,
                                  selectedTagIds: [work]),
                          child: const Text('选择真实标签')),
                      TextButton(
                          onPressed: () async => selectedCurrency =
                              await showCurrencyPickerSheet(context,
                                  selected: 'CNY',
                                  primaryColor: Colors.amber,
                                  rateBase: 'CNY'),
                          child: const Text('选择币种')),
                    ]))))));
    await tester.pumpAndSettle();
  }

  pickerTest('真实标签保留最近使用、语义色和横排选择，确认只返回草稿', (tester) async {
    await host(tester);
    final before = await db.select(db.transactionTags).get();
    await tester.tap(find.text('选择真实标签'));
    await tester.pumpAndSettle();
    expect(find.byType(BeeTagPicker), findsOneWidget);
    expect(find.text('最近使用'), findsOneWidget);
    expect(find.text('工作日'), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), '旅行');
    await tester.pumpAndSettle();
    expect(find.text('工作日'), findsNothing);
    expect(find.text('最近使用'), findsNothing);
    final tag = tester.widget<BeeTag>(find.byType(BeeTag));
    expect(tag.tag.color, const Color(0xff3344ff));
    await tester.tap(find.byType(BeeTag));
    await tester.pumpAndSettle();
    expect(find.text('已选择 2 项'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(selectedTags?.toSet(), {work, trip});
    expect(await db.select(db.transactionTags).get(), before);
    expect(tester.takeException(), isNull);
  });

  pickerTest('标签清空后取消不提交，也不改变真实关联', (tester) async {
    await host(tester);
    await tester.tap(find.text('选择真实标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空选择'));
    await tester.pumpAndSettle();
    expect(find.text('已选择 0 项'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(selectedTags, isNull);
    expect((await db.select(db.transactionTags).get()).single.tagId, work);
  });

  pickerTest('币种弹层保持常用顺序、当前态与汇率，搜索后返回选择', (tester) async {
    await host(tester);
    await tester.tap(find.text('选择币种'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.byType(BeeCurrencyPicker), findsOneWidget);
    final rows =
        tester.widgetList<BeeMenuRow>(find.byType(BeeMenuRow)).toList();
    expect(rows.first.title, '人民币 (CNY)');
    expect(rows.first.selected, isTrue);
    expect(rows[1].title, '美元 (USD)');
    expect(find.text('1 USD ≈ 7.100 CNY'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'USD');
    await tester.pumpAndSettle();
    expect(find.text('人民币 (CNY)'), findsNothing);
    await tester.tap(find.text('美元 (USD)'));
    await tester.pumpAndSettle();
    expect(selectedCurrency, 'USD');
    expect((await repo.getLedgerById(1))!.currency, 'CNY');
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 1.4]) {
    pickerTest('短屏搜索键盘弹出仍可选择标签与确认 $scale', (tester) async {
      await host(tester, size: const Size(320, 568), scale: scale);
      await tester.tap(find.text('选择真实标签'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 230);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '旅行');
      await tester.pumpAndSettle();
      final tag = find.byType(BeeTag);
      await tester.ensureVisible(tag);
      await tester.tap(tag);
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(BeeButton, '确定');
      expect(tester.getBottomRight(confirm).dy, lessThanOrEqualTo(338));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(selectedTags?.toSet(), {work, trip});
      expect(tester.takeException(), isNull);
    });
  }
}
