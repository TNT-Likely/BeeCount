import 'dart:async';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/transaction/recurring_transaction_edit_page.dart';
import 'package:beecount/presentation/v4/bindings/recurring_editor_controls.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/data/recurring_transaction_service.dart';
import 'package:beecount/presentation/v4/bindings/recurring_editor_preview.dart';
import 'package:beecount/presentation/v4/gallery/recurring_editor_sample.dart';
import 'package:beecount_business_ui/recurring_editor.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends LocalRepository {
  _Repository(super.db);
  Completer<void>? addGate;
  @override
  Future<int> addRecurringTransaction(
      {required int ledgerId,
      required String type,
      required double amount,
      int? categoryId,
      int? accountId,
      int? toAccountId,
      String? note,
      required String frequency,
      required int interval,
      int? dayOfMonth,
      int? dayOfWeek,
      int? monthOfYear,
      required DateTime startDate,
      DateTime? endDate,
      bool enabled = true,
      String? currencyCode}) async {
    if (addGate != null) await addGate!.future;
    return super.addRecurringTransaction(
        ledgerId: ledgerId,
        type: type,
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
        toAccountId: toAccountId,
        note: note,
        frequency: frequency,
        interval: interval,
        dayOfMonth: dayOfMonth,
        dayOfWeek: dayOfWeek,
        monthOfYear: monthOfYear,
        startDate: startDate,
        endDate: endDate,
        enabled: enabled,
        currencyCode: currencyCode);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsEn();
  late BeeDatabase db;
  late _Repository repo;
  late GlobalKey<NavigatorState> navigator;
  bool? result;
  double textScale = 1;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repository(db);
    navigator = GlobalKey<NavigatorState>();
    result = null;
    textScale = 1;
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'QA current CNY','CNY'),(2,'QA USD ledger','USD')");
    await db.customStatement(
        "INSERT INTO categories(id,name,kind) VALUES(1,'QA coffee','expense'),(2,'QA salary','income')");
    await db.customStatement(
        "INSERT INTO accounts(id,ledger_id,name,currency,hidden) VALUES(1,1,'QA CNY cash','CNY',0),(2,1,'QA USD cash','USD',0),(3,1,'QA USD bank','USD',0),(4,1,'QA hidden USD','USD',1),(5,1,'QA USD property','USD',0)");
    await db
        .customStatement("UPDATE accounts SET type='real_estate' WHERE id=5");
  });
  tearDown(() async => db.close());

  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
    });
  }

  Future<RecurringTransaction> seed(
      {String type = 'expense',
      String? currency = 'USD',
      int ledger = 1,
      int? from = 2,
      int? to,
      int interval = 3,
      String frequency = 'monthly',
      DateTime? start,
      DateTime? end,
      bool enabled = false}) async {
    final id = await repo.addRecurringTransaction(
        ledgerId: ledger,
        type: type,
        amount: 123.45,
        categoryId: type == 'transfer' ? null : 1,
        accountId: from,
        toAccountId: to,
        note: 'QA original note',
        frequency: frequency,
        interval: interval,
        dayOfMonth: 31,
        dayOfWeek: 4,
        monthOfYear: 8,
        startDate: start ?? DateTime(2050, 1, 1),
        endDate: end,
        enabled: enabled,
        currencyCode: currency);
    await repo.updateLastGeneratedDate(id, DateTime(2050, 2, 1));
    return (await repo.getAllRecurringTransactions()).single;
  }

  Widget host(Widget page) => ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            currentLedgerCurrencyProvider.overrideWithValue('CNY'),
            currencyPickerRatesProvider
                .overrideWith((ref, base) async => <String, double>{}),
          ],
          child: MaterialApp(
              navigatorKey: navigator,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!),
              theme: beeTheme(),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: page));
  void screen(WidgetTester t, {Size size = const Size(398, 1000)}) {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Future<void> open(WidgetTester t, [RecurringTransaction? rule]) async {
    screen(t);
    await t.pumpWidget(host(const Scaffold(body: Text('QA home'))));
    navigator.currentState!
        .push<bool>(MaterialPageRoute(
            builder: (_) => RecurringTransactionEditPage(recurring: rule)))
        .then((value) => result = value);
    await t.pumpAndSettle();
  }

  BeeRecurringEditorForm form(WidgetTester t) =>
      t.widget<BeeRecurringEditorForm>(find.byType(BeeRecurringEditorForm));
  Finder row(BeeRecurringEditorField id) =>
      find.byKey(ValueKey('recurring-editor-${id.name}'));
  Future<void> pick(WidgetTester t, BeeRecurringEditorField id) async {
    await t.ensureVisible(row(id));
    await t.tap(row(id));
    await t.pumpAndSettle();
  }

  Future<void> amount(WidgetTester t, String value) async {
    final field = find.descendant(
        of: find.byKey(const ValueKey('recurring-editor-amount')),
        matching: find.byType(TextFormField));
    await t.ensureVisible(field);
    await t.enterText(field, value);
    await t.pumpAndSettle();
  }

  Future<void> save(WidgetTester t) async {
    t.testTextInput.hide();
    await t.pump();
    await t.tap(find.byKey(const ValueKey('recurring-editor-save')));
    await t.pumpAndSettle();
  }

  Future<void> wheel(WidgetTester t, int index) async {
    final picker = t.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    picker.scrollController!.jumpToItem(index);
    await t.pumpAndSettle();
    await t.tap(find.text(l.commonOk).last);
    await t.pumpAndSettle();
  }

  test('四频率与1至12间隔显示沿用原本地化', () {
    expect(
        RecurringFrequency.values
            .map((f) => recurringEditorFrequencyLabel(l, f)),
        [
          l.recurringTransactionDaily,
          l.recurringTransactionWeekly,
          l.recurringTransactionMonthly,
          l.recurringTransactionYearly
        ]);
    expect(recurringEditorIntervalLabel(l, RecurringFrequency.daily, 12),
        l.recurringTransactionEveryNDays(12));
    expect(recurringEditorIntervalLabel(l, RecurringFrequency.weekly, 12),
        l.recurringTransactionEveryNWeeks(12));
    expect(recurringEditorIntervalLabel(l, RecurringFrequency.monthly, 12),
        l.recurringTransactionEveryNMonths(12));
    expect(recurringEditorIntervalLabel(l, RecurringFrequency.yearly, 12),
        l.recurringTransactionEveryNYears(12));
  });

  scenario('编辑加载完整字段；保存沿用原Repository并记录lastGenerated实际清空', (t) async {
    final rule = await seed(end: DateTime(2051, 1, 1));
    await open(t, rule);
    expect(form(t).amountController.text, '123.45');
    expect(form(t).noteController.text, 'QA original note');
    expect(
        form(t).values[BeeRecurringEditorField.category]!.value, 'QA coffee');
    expect(form(t).values[BeeRecurringEditorField.ledger]!.value,
        'QA current CNY');
    expect(
        form(t).values[BeeRecurringEditorField.account]!.value, 'QA USD cash');
    expect(form(t).values[BeeRecurringEditorField.dayOfMonth]!.value, '31');
    await amount(t, '234.56');
    await save(t);
    expect(result, true);
    expect(find.text('QA home'), findsOneWidget);
    final after = (await repo.getAllRecurringTransactions()).single;
    expect(after.amount, 234.56);
    expect(after.currencyCode, 'USD');
    expect(after.enabled, false);
    expect(after.categoryId, rule.categoryId);
    expect(after.ledgerId, rule.ledgerId);
    expect(after.frequency, 'monthly');
    expect(after.interval, 3);
    expect(after.dayOfMonth, 31);
    expect(after.dayOfWeek, isNull);
    expect(after.monthOfYear, isNull);
    expect(after.startDate, rule.startDate);
    expect(after.endDate, rule.endDate);
    expect(after.lastGeneratedDate, isNull,
        reason:
            'Original adapter defaults to null and original local repository writes Value(null)');
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  scenario('开始日期晚于最近生成日仍沿用原仓储无条件清空lastGenerated', (t) async {
    await open(t, await seed(start: DateTime(2051, 1, 1)));
    await save(t);
    expect((await repo.getAllRecurringTransactions()).single.lastGeneratedDate,
        isNull);
  });

  scenario('切账本改变有效币种后仍保留旧账户，记录原边界', (t) async {
    await open(t, await seed(currency: null, from: 1));
    await pick(t, BeeRecurringEditorField.ledger);
    await t.tap(find.text('QA USD ledger'));
    await t.pumpAndSettle();
    expect(
        form(t).values[BeeRecurringEditorField.account]!.value, 'QA CNY cash');
    await save(t);
    final after = (await repo.getAllRecurringTransactions()).single;
    expect(after.ledgerId, 2);
    expect(after.currencyCode, isNull);
    expect(after.accountId, 1);
  });

  scenario('日期滚轮实际选择二月末并经原Repository保存', (t) async {
    await open(t, await seed());
    await pick(t, BeeRecurringEditorField.startDate);
    var wheels =
        t.widgetList<CupertinoPicker>(find.byType(CupertinoPicker)).toList();
    wheels[1].scrollController!.jumpToItem(1);
    await t.pumpAndSettle();
    wheels =
        t.widgetList<CupertinoPicker>(find.byType(CupertinoPicker)).toList();
    wheels[2].scrollController!.jumpToItem(27);
    await t.pumpAndSettle();
    await t.tap(find.text(l.commonOk).last);
    await t.pumpAndSettle();
    await save(t);
    expect((await repo.getAllRecurringTransactions()).single.startDate,
        DateTime(2050, 2, 28));
  });

  scenario('新建支出必须金额和分类，可不选账户，返回true且仅创建模板', (t) async {
    await open(t);
    expect(form(t).type, 'expense');
    expect(form(t).showDayOfMonth, true);
    expect(
        t
            .widget<BeeButton>(
                find.byKey(const ValueKey('recurring-editor-save')))
            .onPressed,
        isNull);
    await amount(t, '12.50');
    expect(
        t
            .widget<BeeButton>(
                find.byKey(const ValueKey('recurring-editor-save')))
            .onPressed,
        isNull);
    await pick(t, BeeRecurringEditorField.category);
    await t.tap(find.text('QA coffee'));
    await t.pumpAndSettle();
    await save(t);
    expect(result, true);
    final rule = (await repo.getAllRecurringTransactions()).single;
    expect(rule.type, 'expense');
    expect(rule.categoryId, 1);
    expect(rule.accountId, isNull);
    expect(rule.note, isNull);
    expect(rule.currencyCode, isNull);
    expect(rule.enabled, true);
    expect(
        rule.startDate.difference(DateTime.now()).inMinutes.abs(), lessThan(2));
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  scenario('类型切换清分类和转入账户，转账必须不同的双账户', (t) async {
    final rule = await seed();
    await open(t, rule);
    await t.tap(find.text(l.transferTitle));
    await t.pumpAndSettle();
    expect(form(t).type, 'transfer');
    expect(row(BeeRecurringEditorField.category), findsNothing);
    expect(row(BeeRecurringEditorField.toAccount), findsOneWidget);
    expect(
        t
            .widget<BeeButton>(
                find.byKey(const ValueKey('recurring-editor-save')))
            .onPressed,
        isNull);
    await pick(t, BeeRecurringEditorField.toAccount);
    expect(find.text('QA USD cash'), findsOneWidget,
        reason: 'Selected from account exists only behind the dialog');
    expect(find.text('QA hidden USD'), findsNothing);
    expect(find.text('QA CNY cash'), findsNothing);
    await t.tap(find.text('QA USD bank'));
    await t.pumpAndSettle();
    await save(t);
    final after = (await repo.getAllRecurringTransactions()).single;
    expect(after.type, 'transfer');
    expect(after.categoryId, isNull);
    expect(after.accountId, 2);
    expect(after.toAccountId, 3);
  });

  scenario('账户按有效币种过滤并排除hidden，保留原非tradable范围和取消清空', (t) async {
    final rule = await seed();
    await open(t, rule);
    await pick(t, BeeRecurringEditorField.account);
    expect(find.text('QA USD bank'), findsOneWidget);
    expect(find.text('QA USD property'), findsOneWidget);
    expect(find.text('QA hidden USD'), findsNothing);
    expect(find.text('QA CNY cash'), findsNothing);
    await t.tap(find.byType(CloseButton).last);
    await t.pumpAndSettle();
    expect(
        form(t).values[BeeRecurringEditorField.account]!.value, l.accountNone);
    await save(t);
    expect((await repo.getAllRecurringTransactions()).single.accountId, isNull);
  });

  scenario('改币种清空双账户；选择本位币保存NULL，外币ISO正常保存', (t) async {
    final rule = await seed(type: 'transfer', to: 3);
    await open(t, rule);
    await pick(t, BeeRecurringEditorField.currency);
    await t.tap(find.textContaining('(CNY)').last);
    await t.pumpAndSettle();
    expect(
        form(t).values[BeeRecurringEditorField.account]!.value, l.accountNone);
    expect(form(t).values[BeeRecurringEditorField.toAccount]!.value,
        l.accountNone);
    expect(
        t
            .widget<BeeButton>(
                find.byKey(const ValueKey('recurring-editor-save')))
            .onPressed,
        isNull);
    await t.ensureVisible(find.text(l.categoryIncome));
    await t.tap(find.text(l.categoryIncome));
    await t.pumpAndSettle();
    await pick(t, BeeRecurringEditorField.category);
    await t.tap(find.text('QA salary'));
    await t.pumpAndSettle();
    await save(t);
    final after = (await repo.getAllRecurringTransactions()).single;
    expect(after.currencyCode, isNull);
    expect(after.type, 'income');
    expect(after.categoryId, 2);
  });

  scenario('账本切换归一本位币但按原行为保留账户', (t) async {
    final rule = await seed();
    await open(t, rule);
    await pick(t, BeeRecurringEditorField.ledger);
    await t.tap(find.text('QA USD ledger'));
    await t.pumpAndSettle();
    expect(
        form(t).values[BeeRecurringEditorField.ledger]!.value, 'QA USD ledger');
    expect(
        form(t).values[BeeRecurringEditorField.account]!.value, 'QA USD cash');
    await save(t);
    final after = (await repo.getAllRecurringTransactions()).single;
    expect(after.ledgerId, 2);
    expect(after.currencyCode, isNull);
    expect(after.accountId, 2);
  });

  scenario('原滚轮四频率、间隔1至12、每月1至31和取消保持草稿', (t) async {
    await open(t, await seed());
    await pick(t, BeeRecurringEditorField.interval);
    expect(t.widget<BeeWheel<int>>(find.byType(BeeWheel<int>)).values,
        List.generate(12, (i) => i + 1));
    await wheel(t, 11);
    expect(form(t).values[BeeRecurringEditorField.interval]!.value,
        l.recurringTransactionEveryNMonths(12));
    await pick(t, BeeRecurringEditorField.dayOfMonth);
    expect(t.widget<BeeWheel<int>>(find.byType(BeeWheel<int>)).values,
        List.generate(31, (i) => i + 1));
    await wheel(t, 0);
    expect(form(t).values[BeeRecurringEditorField.dayOfMonth]!.value, '1');
    await pick(t, BeeRecurringEditorField.frequency);
    expect(
        t
            .widget<BeeWheel<RecurringFrequency>>(
                find.byType(BeeWheel<RecurringFrequency>))
            .values,
        RecurringFrequency.values);
    await wheel(t, 0);
    expect(form(t).showInterval, false);
    expect(form(t).showDayOfMonth, false);
    await pick(t, BeeRecurringEditorField.frequency);
    await wheel(t, 1);
    expect(form(t).showInterval, true);
    expect(form(t).showDayOfMonth, false);
    expect(form(t).values[BeeRecurringEditorField.interval]!.value,
        l.recurringTransactionEveryNWeeks(1));
    await pick(t, BeeRecurringEditorField.frequency);
    await t.tap(find.text(l.commonCancel).last);
    await t.pumpAndSettle();
    expect(form(t).values[BeeRecurringEditorField.frequency]!.value,
        l.recurringTransactionWeekly);
    await save(t);
    final after = (await repo.getAllRecurringTransactions()).single;
    expect(after.frequency, 'weekly');
    expect(after.interval, 1);
    expect(after.dayOfMonth, 1);
  });

  scenario('日期选择保留今天起始下界、结束下界和2100上界；清结束日期不打开滚轮', (t) async {
    final rule = await seed(end: DateTime(2051, 1, 1));
    await open(t, rule);
    await pick(t, BeeRecurringEditorField.startDate);
    final now = DateTime.now(),
        picker = t.widget<BeeRecurringEditorDateWheels>(
            find.byType(BeeRecurringEditorDateWheels));
    expect(picker.minDate, DateTime(now.year, now.month, now.day));
    expect(picker.maxDate, DateTime(2100));
    await t.tap(find.text(l.commonCancel).last);
    await t.pumpAndSettle();
    await pick(t, BeeRecurringEditorField.endDate);
    expect(
        t
            .widget<BeeRecurringEditorDateWheels>(
                find.byType(BeeRecurringEditorDateWheels))
            .minDate,
        rule.startDate);
    await t.tap(find.text(l.commonCancel).last);
    await t.pumpAndSettle();
    await t.tap(
        find.byTooltip('${l.commonRemove} · ${l.recurringTransactionEndDate}'));
    await t.pumpAndSettle();
    expect(find.byType(BeeRecurringEditorDateWheels), findsNothing);
    expect(form(t).values[BeeRecurringEditorField.endDate]!.value,
        l.recurringTransactionNoEndDate);
    await save(t);
    expect((await repo.getAllRecurringTransactions()).single.endDate, isNull);
  });

  scenario('删除取消保持原对象；确认后仅删除该模板且返回true', (t) async {
    final rule = await seed();
    await open(t, rule);
    await t.tap(find.byTooltip(l.commonDelete));
    await t.pumpAndSettle();
    await t.tap(find.text(l.commonCancel));
    await t.pumpAndSettle();
    expect((await repo.getAllRecurringTransactions()).length, 1);
    expect(result, isNull);
    await t.tap(find.byTooltip(l.commonDelete));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(BeeButton, l.commonDelete));
    await t.pumpAndSettle();
    expect(await repo.getAllRecurringTransactions(), isEmpty);
    expect(result, true);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  scenario('保存错误保留草稿可重试，忙碌阻止重复写入', (t) async {
    await db.customStatement(
        "CREATE TRIGGER qa_fail_recurring BEFORE INSERT ON recurring_transactions BEGIN SELECT RAISE(ABORT,'QA save denied'); END");
    await open(t);
    await amount(t, '19');
    await pick(t, BeeRecurringEditorField.category);
    await t.tap(find.text('QA coffee'));
    await t.pumpAndSettle();
    await save(t);
    expect(find.textContaining('QA save denied'), findsWidgets);
    expect(form(t).amountController.text, '19');
    expect(await repo.getAllRecurringTransactions(), isEmpty);
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    await db.customStatement('DROP TRIGGER qa_fail_recurring');
    repo.addGate = Completer<void>();
    final button = find.byKey(const ValueKey('recurring-editor-save'));
    await t.tap(button);
    await t.pump();
    expect(t.widget<BeeButton>(button).onPressed, isNull);
    await t.tap(button);
    await t.pump();
    repo.addGate!.complete();
    await t.pumpAndSettle();
    expect((await repo.getAllRecurringTransactions()).length, 1);
    expect(result, true);
  });

  scenario('删除失败原模板不变并恢复可重试', (t) async {
    final rule = await seed();
    await db.customStatement(
        "CREATE TRIGGER qa_fail_delete BEFORE DELETE ON recurring_transactions BEGIN SELECT RAISE(ABORT,'QA delete denied'); END");
    await open(t, rule);
    await t.tap(find.byTooltip(l.commonDelete));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(BeeButton, l.commonDelete));
    await t.pumpAndSettle();
    expect(find.textContaining('QA delete denied'), findsWidgets);
    expect((await repo.getAllRecurringTransactions()).single, rule);
    expect(result, isNull);
  });

  scenario('返回取消不写入，原金额校验只检查可解析数字', (t) async {
    await open(t, await seed());
    await amount(t, 'bad-number');
    expect(
        t
            .widget<BeeButton>(
                find.byKey(const ValueKey('recurring-editor-save')))
            .onPressed,
        isNull);
    await amount(t, '-1');
    expect(
        t
            .widget<BeeButton>(
                find.byKey(const ValueKey('recurring-editor-save')))
            .onPressed,
        isNotNull);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(result, isNull);
    expect((await repo.getAllRecurringTransactions()).single.amount, 123.45);
  });

  scenario('320宽1.4倍日期与长频率标题滚轮无溢出', (t) async {
    textScale = 1.4;
    await open(t, await seed());
    t.view.physicalSize = const Size(320, 568);
    await t.pumpAndSettle();
    await pick(t, BeeRecurringEditorField.frequency);
    expect(t.takeException(), isNull);
    await t.tap(find.text(l.commonCancel).last);
    await t.pumpAndSettle();
    await pick(t, BeeRecurringEditorField.startDate);
    expect(t.takeException(), isNull);
    await t.tap(find.text(l.commonCancel).last);
    await t.pumpAndSettle();
  });

  scenario('外币JPY无账户时转入选择显示空态，币种改变后双账户清空', (t) async {
    await open(t, await seed(type: 'transfer', to: 3));
    await pick(t, BeeRecurringEditorField.currency);
    final jpy = find.textContaining('(JPY)').first;
    await t.ensureVisible(jpy);
    await t.tap(jpy);
    await t.pumpAndSettle();
    await pick(t, BeeRecurringEditorField.toAccount);
    expect(find.text(l.commonEmpty), findsOneWidget);
    expect(find.text(l.accountNone), findsNWidgets(2),
        reason: 'No optional null row is offered for to-account');
    await t.tap(find.byType(CloseButton).last);
    await t.pumpAndSettle();
    expect(
        t
            .widget<BeeButton>(
                find.byKey(const ValueKey('recurring-editor-save')))
            .onPressed,
        isNull);
  });

  scenario('真实只读预览和局部草稿样例不更新模板或创建交易', (t) async {
    screen(t);
    final before = await seed();
    await t.pumpWidget(host(const Scaffold(
        body: SingleChildScrollView(child: RecurringEditorPreview()))));
    await t.pumpAndSettle();
    expect(form(t).enabled, false);
    expect(form(t).onType, isNull);
    await t.pumpWidget(host(const Scaffold(
        body: SingleChildScrollView(child: RecurringEditorSample()))));
    await t.pumpAndSettle();
    await t.ensureVisible(find.widgetWithText(BeeButton, l.commonSave));
    await t.tap(find.widgetWithText(BeeButton, l.commonSave));
    await t.pumpAndSettle();
    expect((await repo.getAllRecurringTransactions()).single, before);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  for (final brightness in Brightness.values) {
    scenario('纯表单320宽1.4倍长字段不溢出且只回调宿主 $brightness', (t) async {
      screen(t, size: const Size(320, 568));
      final a = TextEditingController(text: '123456789.00'),
          n = TextEditingController(text: 'QA long note');
      var calls = 0;
      try {
        final values = {
          for (final field in BeeRecurringEditorField.values)
            field: BeeRecurringEditorValue(
                label: 'QA field with a long localized label',
                value: 'Long Unicode 值 that should wrap on narrow phones',
                icon: 'Calendar',
                onSelect: () => calls++,
                onClear: field == BeeRecurringEditorField.endDate
                    ? () => calls++
                    : null)
        };
        await t.pumpWidget(MaterialApp(
            theme: beeTheme(brightness: brightness),
            home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
                child: Scaffold(
                    body: SingleChildScrollView(
                        padding: const EdgeInsets.all(17),
                        child: BeeRecurringEditorForm(
                            amountController: a,
                            noteController: n,
                            type: 'transfer',
                            types: const [
                              BeeSegment('expense', 'Expense'),
                              BeeSegment('income', 'Income'),
                              BeeSegment('transfer', 'Transfer')
                            ],
                            values: values,
                            amountLabel: 'Amount',
                            noteLabel: 'Note',
                            clearLabel: 'Clear',
                            onType: (_) => calls++))))));
        await t.pumpAndSettle();
        await t.ensureVisible(row(BeeRecurringEditorField.ledger));
        await t.tap(row(BeeRecurringEditorField.ledger));
        await t.pump();
        expect(calls, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      } finally {
        a.dispose();
        n.dispose();
      }
    });
  }
}
