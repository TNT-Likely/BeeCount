import 'dart:async';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/currency/exchange_rate_page.dart';
import 'package:beecount/presentation/v4/bindings/exchange_rate_actions.dart';
import 'package:beecount/presentation/v4/bindings/exchange_rate_editor.dart';
import 'package:beecount/presentation/v4/bindings/exchange_rate_preview.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/currency/exchange_rate_service.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Explicit deterministic transport: SQLite and production provider/actions stay real.
// These tests do not claim public-rate API or Cloud connectivity.
class _Rates extends ExchangeRateService {
  int calls = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<RateFetchResult> fetch(String base) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('synthetic rate network failure');
    return RateFetchResult(
        rateDate: '2026-10-25',
        source: 'synthetic-widget-transport',
        ratesBaseToQuote: base == 'CNY'
            ? {'USD': '0.14', 'EUR': '0.125', 'AED': '0.5'}
            : {'CNY': '7.0', 'EUR': '0.9', 'AED': '3.6'});
  }
}

class _Repo extends LocalRepository {
  _Repo(super.db);
  bool failRead = false, failWrite = false;
  @override
  Future<List<ExchangeRate>> getLatestAutoRates(String base) {
    if (failRead) throw StateError('synthetic read failure');
    return super.getLatestAutoRates(base);
  }

  @override
  Future<void> setOverride(
      {required String base, required String quote, required String rate}) {
    if (failWrite) throw StateError('synthetic write failure');
    return super.setOverride(base: base, quote: quote, rate: rate);
  }
}

void main() {
  late BeeDatabase db;
  late _Repo repo;
  late _Rates rates;
  late ProviderContainer c;
  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'auto_sync': false, 'baseCurrency': 'CNY'});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repo(db);
    rates = _Rates();
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'生活','CNY'),(2,'旅行','USD')");
    for (final code in ['CNY', 'USD', 'EUR', 'AED']) {
      await db.customStatement(
          "INSERT INTO accounts(ledger_id,name,currency) VALUES(1,'合成$code','$code')");
    }
    for (final base in ['CNY', 'USD']) {
      await repo.upsertAutoRates(
          base: base,
          rateDate: '2026-01-01',
          rates: base == 'CNY'
              ? {'USD': '7.200000', 'EUR': '8.0', 'JPY': '0.05'}
              : {'CNY': '0.14'},
          source: 'synthetic-local-cache',
          fetchedAt: DateTime.now().toUtc());
    }
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.10000000');
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      exchangeRateServiceProvider.overrideWithValue(rates),
      beecountCloudProviderInstance.overrideWith((ref) async => null)
    ]);
    await c.read(baseCurrencyInitProvider.future);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<void> ready(WidgetTester t, Finder f) async {
    for (var i = 0; i < 100; i++) {
      await t.pump(const Duration(milliseconds: 30));
      if (f.evaluate().isNotEmpty) {
        await t.pump(const Duration(milliseconds: 300));
        return;
      }
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    expect(f, findsWidgets);
  }

  Future<void> open(WidgetTester t,
      {bool narrow = false, bool live = false}) async {
    t.view.physicalSize = narrow ? const Size(320, 568) : const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: beeTheme(
                brightness: narrow ? Brightness.dark : Brightness.light),
            locale: narrow ? const Locale('en') : const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(narrow ? 1.4 : 1)),
                child: child!),
            home: live
                ? const Scaffold(
                    body:
                        SingleChildScrollView(child: LiveExchangeRatePreview()))
                : const ExchangeRatePage())));
    await ready(t, find.byType(BeeExchangeRateRow));
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(BeeExchangeRateRow).first));
  Finder row(String code) =>
      find.byWidgetPredicate((w) => w is BeeExchangeRateRow && w.code == code);
  Future<void> editor(WidgetTester t, String code) async {
    await t.ensureVisible(row(code));
    await t.pump();
    await t.tap(row(code));
    await ready(t, find.byType(ExchangeRateEditor));
  }

  Future<void> button(WidgetTester t, String text) async {
    await t.tap(find
        .descendant(of: find.byType(BeeDialog), matching: find.text(text))
        .last);
    await t.pump(const Duration(milliseconds: 400));
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump(const Duration(milliseconds: 300));
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 4));
  }

  Future<List<Map<String, Object?>>> accounts() async =>
      (await db.customSelect('SELECT * FROM accounts ORDER BY id').get())
          .map((r) => r.data)
          .toList();
  testWidgets('真实仓库只列使用中外币并排序，手动优先、陈旧与未获取完整展示，进页24h节流', (t) async {
    await open(t);
    final rows = t
        .widgetList<BeeExchangeRateRow>(find.byType(BeeExchangeRateRow))
        .toList();
    expect(rows.map((r) => r.code), ['AED', 'EUR', 'USD']);
    expect(rows.last.value, '1 USD = 7.10000 CNY');
    expect(rows.last.manual, true);
    expect(rows[1].stale, true);
    expect(rows.first.value, '—');
    expect(rates.calls, 0);
    await close(t);
  });
  testWidgets('手动原字符串回填，取消及关闭退场不写，精度原样保存且账户不重算', (t) async {
    await open(t);
    final before = await accounts(),
        original = (await repo.getOverrides('CNY')).single;
    await editor(t, 'USD');
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
        '7.10000000');
    await t.enterText(find.byType(TextField), '7.123456789');
    await button(t, l(t).commonCancel);
    expect((await repo.getOverrides('CNY')).single, original);
    expect(t.takeException(), isNull);
    await editor(t, 'USD');
    await t.enterText(find.byType(TextField), '7.123456789');
    await button(t, l(t).commonSave);
    await ready(t, find.text('1 USD = 7.12346 CNY'));
    final saved = (await repo.getOverrides('CNY')).single;
    expect(saved.rate, '7.123456789');
    expect(saved.syncId, original.syncId);
    expect(await accounts(), before);
    await close(t);
  });
  testWidgets('原手动恢复自动删除覆盖而保留自动缓存；未获取设置后立即回显', (t) async {
    await open(t);
    final strings = l(t);
    await editor(t, 'USD');
    await button(t, strings.rateResetToAuto);
    expect(await repo.getOverrides('CNY'), isEmpty);
    await ready(t, find.text('1 USD = 7.20000 CNY'));
    await editor(t, 'AED');
    expect(find.text(strings.rateResetToAuto), findsNothing);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
    await t.enterText(find.byType(TextField), '1.95000000');
    await button(t, strings.commonSave);
    expect((await repo.getOverrides('CNY')).single.rate, '1.95000000');
    await close(t);
  });
  testWidgets('原范围边界拒绝0/极小/极大/多小数点，错误清除后保存', (t) async {
    await open(t);
    final strings = l(t);
    await editor(t, 'AED');
    for (final value in ['0', '0.000001', '1000000000', '1.2.3']) {
      await t.enterText(find.byType(TextField), value);
      await button(t, strings.commonSave);
      expect(find.text(strings.commonError), findsOneWidget);
      expect(await repo.getOverrides('CNY'), hasLength(1));
    }
    await t.enterText(find.byType(TextField), '0.0000011');
    await t.pump();
    expect(find.text(strings.commonError), findsNothing);
    await button(t, strings.commonSave);
    expect((await repo.getOverrides('CNY')).any((r) => r.rate == '0.0000011'),
        true);
    await close(t);
  });
  testWidgets('规范刷新防重，真实SQLite接收显式合成网络倒数，手动不被自动覆盖', (t) async {
    await open(t);
    rates.gate = Completer<void>();
    final strings = l(t);
    await t.tap(find.byTooltip(strings.exchangeRatePageTitle));
    await t.pump();
    expect(find.byTooltip(strings.exchangeRatePageTitle), findsNothing);
    for (var i = 0; i < 20 && rates.calls == 0; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump();
    }
    expect(rates.calls, 1);
    rates.gate!.complete();
    await ready(t, find.byType(BeeToast));
    expect(find.text(strings.rateRefreshSuccess), findsOneWidget);
    expect(
        (await repo.getLatestAutoRates('CNY'))
            .firstWhere((r) => r.quoteCurrency == 'AED')
            .rate,
        '2.00000000000');
    expect((await repo.getOverrides('CNY')).single.rate, '7.10000000');
    await close(t);
  });
  testWidgets('刷新失败保留原缓存，写入失败错误反馈而不变更覆盖', (t) async {
    await open(t);
    rates.fail = true;
    final strings = l(t), before = await repo.getOverrides('CNY');
    await t.tap(find.byTooltip(strings.exchangeRatePageTitle));
    await ready(t, find.text(strings.rateRefreshFailed));
    expect(await repo.getOverrides('CNY'), before);
    repo.failWrite = true;
    await editor(t, 'USD');
    await t.enterText(find.byType(TextField), '8');
    await button(t, strings.commonSave);
    expect(find.text(strings.commonError), findsOneWidget);
    expect(await repo.getOverrides('CNY'), before);
    await close(t);
  });
  testWidgets('320英文深色140%含键盘，完整币种值、反向提示与恢复取消保存可达', (t) async {
    await open(t, narrow: true);
    final strings = l(t);
    await editor(t, 'USD');
    t.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    expect(find.byType(BeeExchangeRateField), findsOneWidget);
    await t.ensureVisible(find.text(strings.rateResetToAuto));
    await t.pump();
    expect(t.takeException(), isNull);
    await button(t, strings.commonCancel);
    expect(t.takeException(), isNull);
    await close(t);
  });
  testWidgets('真实只读预览展示原覆盖，不写入且提供生产入口', (t) async {
    await open(t, live: true);
    final before = await repo.getOverrides('CNY');
    expect(find.text('真实汇率（只读） · CNY'), findsOneWidget);
    for (final r
        in t.widgetList<BeeExchangeRateRow>(find.byType(BeeExchangeRateRow))) {
      expect(r.onTap, isNull);
    }
    await t.ensureVisible(find.text('打开真实汇率管理'));
    await t.pump();
    await t.tap(find.text('打开真实汇率管理'));
    await ready(t, find.byType(ExchangeRatePage));
    expect(await repo.getOverrides('CNY'), before);
    await close(t);
  });
  testWidgets('主币种搜索底部弹层取消不改；选择USD保留CNY手动覆盖并持久化', (t) async {
    await open(t);
    final strings = l(t), before = await accounts();
    await t.tap(find.text(strings.baseCurrencyLabel));
    await ready(t, find.byType(BeeCurrencyPicker));
    expect(find.byType(BeeSheet), findsOneWidget);
    await t.tap(find.byType(CloseButton));
    await t.pumpAndSettle();
    expect(c.read(baseCurrencyProvider), 'CNY');
    await t.tap(find.text(strings.baseCurrencyLabel));
    await ready(t, find.byType(BeeCurrencyPicker));
    await t.enterText(find.byType(TextField), 'USD');
    await t.pumpAndSettle();
    await t.tap(find.text('美元 (USD)'));
    await t.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 80; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 30));
      if (c.read(baseCurrencyProvider) == 'USD' && rates.calls >= 2) break;
    }
    expect(c.read(baseCurrencyProvider), 'USD');
    expect((await SharedPreferences.getInstance()).getString('baseCurrency'),
        'USD');
    expect((await repo.getOverrides('CNY')).single.rate, '7.10000000');
    expect(await accounts(), before);
    await close(t);
  });
  testWidgets('仓库读取错误显示重试，恢复后重新读取真实列表', (t) async {
    repo.failRead = true;
    t.view.physicalSize = const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ExchangeRatePage())));
    await ready(t, find.byType(BeeEmptyState));
    final retry = t.widget<BeeButton>(find.byType(BeeButton));
    repo.failRead = false;
    await t.tap(find.text(retry.label));
    await ready(t, find.byType(BeeExchangeRateRow));
    expect(find.byType(BeeExchangeRateRow), findsNWidgets(3));
    await close(t);
  });
  test('6位有效数字与原7天陈旧阈值保留', () {
    expect(formatExchangeRate('7.10000000'), '7.10000');
    expect(formatExchangeRate('bad'), 'bad');
    expect(
        exchangeRateIsStale('2026-10-18', now: DateTime(2026, 10, 25)), false);
    expect(
        exchangeRateIsStale('2026-10-17', now: DateTime(2026, 10, 25)), true);
    expect(exchangeRateIsStale('invalid'), false);
  });
}
