import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/dev/component_gallery/bindings/detail_currency_preview.dart';
import 'package:beecount/dev/component_gallery/detail_currency_sample.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_business_ui/detail_currency.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget child, {double scale = 1}) => MaterialApp(
    theme: beeTheme(),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: Scaffold(
        body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(17), child: child))));
void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  late List<Transaction> before;
  var disposed = false;
  setUp(() async {
    disposed = false;
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      currentLedgerProvider.overrideWith(
          (ref) => repo.watchLedger(ref.watch(currentLedgerIdProvider)))
    ]);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'人民币','CNY'),(2,'美元','USD')");
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 10,
        happenedAt: DateTime(2026, 10, 24));
    await repo.addTransaction(
        ledgerId: 2,
        type: 'expense',
        amount: 20,
        nativeAmount: 20,
        currencyCode: 'USD',
        happenedAt: DateTime(2026, 10, 24));
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.1');
    before = await db.select(db.transactions).get();
  });
  tearDown(() async {
    if (!disposed) container.dispose();
    await db.close();
  });
  for (final scale in [1.4, 2.0]) {
    testWidgets('受控完整/缺失/陈旧与隐私在320/$scale不溢出、不读取真实数据', (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(app(const DetailCurrencySample(), scale: scale));
      await t.pumpAndSettle();
      BeeResourceHero hero() =>
          t.widget<BeeResourceHero>(find.byType(BeeResourceHero));
      expect(hero().amount, '152.00');
      expect(
          t
              .widget<BeeDetailCurrencyNotice>(
                  find.byType(BeeDetailCurrencyNotice))
              .missingLabel,
          isNull);
      await t.tap(find.text('缺失'));
      await t.pumpAndSettle();
      expect(hero().amount, '—');
      expect(
          t
              .widget<BeeDetailCurrencyNotice>(
                  find.byType(BeeDetailCurrencyNotice))
              .missingLabel,
          contains('USD'));
      await t.tap(find.text('陈旧'));
      await t.pumpAndSettle();
      expect(hero().amount, '152.00');
      expect(
          t
              .widget<BeeDetailCurrencyNotice>(
                  find.byType(BeeDetailCurrencyNotice))
              .stale,
          isTrue);
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(hero().amount, '••••');
      expect(hero().metrics[1].value, '••••');
      expect(hero().metrics[2].value, '••••');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
  }
  testWidgets('真实preview只读SQLite、复用当前目标和汇率刷新并尊重隐私', (t) async {
    await t.pumpWidget(UncontrolledProviderScope(
        container: container, child: app(const LiveDetailCurrencyPreview())));
    await t.pumpAndSettle();
    expect(find.textContaining('¥152.00'), findsOneWidget);
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.2');
    container.read(rateRefreshTickProvider.notifier).state++;
    await t.pumpAndSettle();
    expect(find.textContaining('¥154.00'), findsOneWidget);
    container.read(hideAmountsProvider.notifier).state = true;
    await t.pumpAndSettle();
    expect(find.textContaining('154.00'), findsNothing);
    expect(await db.select(db.transactions).get(), before);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    container.dispose();
    disposed = true;
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
  });
}
