import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/budget/budget_edit_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo extends LocalRepository {
  _Repo(super.db);
  bool failRead = false, failWrite = false;
  int creates = 0, updates = 0;
  Completer<void>? writeGate;
  @override
  Future<List<Category>> getAllCategories() async {
    if (failRead) throw StateError('synthetic budget read');
    return super.getAllCategories();
  }

  @override
  Future<int> createBudget(
      {required int ledgerId,
      required String type,
      int? categoryId,
      required double amount,
      String period = 'monthly',
      int startDay = 1}) async {
    creates++;
    await writeGate?.future;
    if (failWrite) throw StateError('synthetic budget write');
    return super.createBudget(
        ledgerId: ledgerId,
        type: type,
        categoryId: categoryId,
        amount: amount,
        period: period,
        startDay: startDay);
  }

  @override
  Future<void> updateBudget(int id,
      {double? amount, int? startDay, bool? enabled}) async {
    updates++;
    return super
        .updateBudget(id, amount: amount, startDay: startDay, enabled: enabled);
  }
}

void main() {
  late BeeDatabase db;
  late _Repo repo;
  late ProviderContainer c;
  late int parent, child, income;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repo(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,month_start_day) VALUES(1,'预算编辑测试','USD',8),(2,'其他账本','CNY',1)");
    parent = await repo.createCategory(
        name: '合成咖啡', kind: 'expense', icon: 'coffee');
    child = await repo.createSubCategory(
        name: '只作历史二级', kind: 'expense', parentId: parent);
    income = await repo.createCategory(
        name: '收入不可选', kind: 'income', icon: 'salary');
    await db.customStatement(
        "INSERT INTO transactions(ledger_id,type,amount,happened_at) VALUES(1,'expense',12,1792000000)");
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService())
    ]);
    repo.creates = 0;
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<List<Map<String, Object?>>> rows(String table) async =>
      (await db.customSelect('SELECT * FROM $table ORDER BY id').get())
          .map((r) => r.data)
          .toList();
  Future<void> ready(WidgetTester t, Finder f) async {
    for (var i = 0; i < 80; i++) {
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
      {Budget? budget,
      bool category = false,
      bool narrow = false,
      bool error = false}) async {
    t.view.physicalSize = narrow ? const Size(320, 568) : const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await c.read(currentLedgerProvider.future);
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
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => BudgetEditPage(
                                    budget: budget, isCategory: category))),
                        child: const Text('open')))))));
    await t.tap(find.text('open'));
    await ready(t,
        error ? find.byType(BeeEmptyState) : find.byType(BeeBudgetEditorForm));
    final frozen = jsonDecode(
        File('test/fixtures/v4-budget-editor-geometry.json')
            .readAsStringSync());
    final strings = AppLocalizations.of(t.element(find.byType(BudgetEditPage)));
    final saveButton = find.widgetWithText(BeeButton, strings.commonSave);
    expect(t.getSize(saveButton).width,
        (narrow ? 320 : 398) - 2 * (frozen['pageInset'] as num),
        reason: 'HTML固定保存栏应撑满内容宽度');
    expect(t.getSize(saveButton).height, frozen['saveButtonHeight']);
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(BudgetEditPage)));
  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 3));
  }

  Future<void> save(WidgetTester t) async {
    await t.tap(find.widgetWithText(BeeButton, l(t).commonSave));
    await ready(t, find.text('open'));
  }

  Future<Budget> total({double amount = 2000.125}) async {
    final id = await repo.createBudget(
        ledgerId: 1, type: 'total', amount: amount, startDay: 17);
    return (await repo.getAllBudgets(1)).firstWhere((b) => b.id == id);
  }

  for (final narrowInput in [false, true]) {
    testWidgets('真实点击预算金额请求数值系统键盘：紧凑$narrowInput', (t) async {
      await open(t, narrow: narrowInput);
      final amount = find.descendant(
          of: find.byType(BeeBudgetEditorForm),
          matching: find.byType(TextField));
      t.testTextInput.log.clear();
      await t.tap(amount);
      await t.pumpAndSettle();
      final field = t.widget<TextField>(amount);
      final editable = t.widget<EditableText>(
          find.descendant(of: amount, matching: find.byType(EditableText)));
      expect(field.enabled, isTrue);
      expect(field.readOnly, isFalse);
      expect(field.keyboardType,
          const TextInputType.numberWithOptions(decimal: true));
      expect(editable.focusNode.hasFocus, isTrue);
      expect(t.testTextInput.hasAnyClients, isTrue);
      expect(t.testTextInput.isVisible, isTrue,
          reason: 'tap 生产表单需请求 IME，不能由 enterText 模拟成功');
      expect(t.testTextInput.log.map((call) => call.method),
          contains('TextInput.show'));
      expect(repo.creates, 0);
      expect(t.takeException(), isNull);
      await close(t);
    });
  }

  testWidgets('总预算真实创建保留USD账本/UUID、月周期和默认历史startDay，不改交易', (t) async {
    final before = await rows('transactions');
    await open(t);
    expect(t.widget<BeeBudgetEditorForm>(find.byType(BeeBudgetEditorForm)).type,
        'total');
    await t.enterText(find.byType(TextField), '1234。567');
    expect(
        t
            .widget<BeeBudgetEditorForm>(find.byType(BeeBudgetEditorForm))
            .amountController
            .text,
        '1234.56');
    await save(t);
    final all = await repo.getAllBudgets(1);
    expect(all.length, 1);
    expect(all.single.amount, 1234.56);
    expect(all.single.type, 'total');
    expect(all.single.startDay, 1);
    expect(all.single.syncId, isNotEmpty);
    expect(await rows('transactions'), before);
    await close(t);
  });
  testWidgets('编辑回填原始小数精度，未改保存保留预算身份/类别/历史起始日', (t) async {
    final original = await total();
    final before = await rows('transactions');
    await open(t, budget: original);
    final form =
        t.widget<BeeBudgetEditorForm>(find.byType(BeeBudgetEditorForm));
    expect(form.amountController.text, '2000.125');
    expect(form.editing, true);
    await save(t);
    final saved = (await repo.getAllBudgets(1)).single;
    expect(saved.amount, original.amount);
    expect(saved.syncId, original.syncId);
    expect(saved.id, original.id);
    expect(saved.startDay, 17);
    expect(saved.categoryId, original.categoryId);
    expect(await rows('transactions'), before);
    await close(t);
  });
  testWidgets('已有总预算自动分类且禁用总预算；原底部分类只选支出父级', (t) async {
    await total();
    await open(t);
    final form =
        t.widget<BeeBudgetEditorForm>(find.byType(BeeBudgetEditorForm));
    expect(form.type, 'category');
    expect(form.totalUnavailable, true);
    await t.tap(find.byType(BeeMenuRow));
    await ready(t, find.byType(BeeChoicePicker<Category>));
    expect(find.byType(BeeSheet), findsOneWidget);
    final choices = t
        .widget<BeeChoicePicker<Category>>(
            find.byType(BeeChoicePicker<Category>))
        .items;
    expect(choices.map((c) => c.value.id), isNot(contains(child)));
    expect(choices.map((c) => c.value.id), isNot(contains(income)));
    expect(find.text('只作历史二级'), findsNothing);
    expect(find.text('收入不可选'), findsNothing);
    await t.enterText(find.byType(TextField).first, '合成咖啡');
    await t.pumpAndSettle();
    await t.tap(find.text('合成咖啡'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '500.25');
    await save(t);
    final saved =
        (await repo.getAllBudgets(1)).firstWhere((b) => b.type == 'category');
    expect(saved.categoryId, parent);
    expect(saved.amount, 500.25);
    await close(t);
  });
  testWidgets('分类未选与零值拒绝；草稿返回完全不写', (t) async {
    await open(t, category: true);
    await t.enterText(find.byType(TextField), '0');
    await t.tap(find.widgetWithText(BeeButton, l(t).commonSave));
    await t.pump();
    expect(
        t
            .widget<BeeBudgetEditorForm>(find.byType(BeeBudgetEditorForm))
            .amountError,
        isNotNull);
    await t.enterText(find.byType(TextField), '120');
    await t.tap(find.widgetWithText(BeeButton, l(t).commonSave));
    await t.pump();
    expect(await repo.getAllBudgets(1), isEmpty);
    await t.tap(find.byType(BackButton));
    await ready(t, find.text('open'));
    expect(await repo.getAllBudgets(1), isEmpty);
    await close(t);
  });
  testWidgets('删除确认保持规范弹窗，取消不写，确认沿用总预算级联范围', (t) async {
    final original = await total();
    await repo.createBudget(
        ledgerId: 1, type: 'category', categoryId: parent, amount: 500);
    final before = await rows('transactions');
    await open(t, budget: original);
    final strings = l(t);
    await t.tap(find.byTooltip(strings.commonDelete));
    await ready(t, find.byType(BeeDialog));
    await t.tap(find.widgetWithText(BeeButton, strings.commonCancel));
    await t.pumpAndSettle();
    expect((await repo.getAllBudgets(1)).length, 2);
    await t.tap(find.byTooltip(strings.commonDelete));
    await ready(t, find.byType(BeeDialog));
    await t.tap(find.widgetWithText(BeeButton, strings.commonDelete));
    await ready(t, find.text('open'));
    expect(await repo.getAllBudgets(1), isEmpty);
    expect(await rows('transactions'), before);
    await close(t);
  });
  testWidgets('只删分类预算保留总预算及其他账本', (t) async {
    await total();
    final id = await repo.createBudget(
        ledgerId: 1, type: 'category', categoryId: parent, amount: 500);
    await repo.createBudget(ledgerId: 2, type: 'total', amount: 900);
    final cat = (await repo.getAllBudgets(1)).firstWhere((b) => b.id == id);
    await open(t, budget: cat);
    final strings = l(t);
    await t.tap(find.byTooltip(strings.commonDelete));
    await ready(t, find.byType(BeeDialog));
    await t.tap(find.widgetWithText(BeeButton, strings.commonDelete));
    await ready(t, find.text('open'));
    expect((await repo.getAllBudgets(1)).single.type, 'total');
    expect((await repo.getAllBudgets(2)).single.amount, 900);
    await close(t);
  });
  testWidgets('共享编辑者隐藏删除、保存禁用且不会写入', (t) async {
    final original = await total();
    await db.customStatement(
        "UPDATE ledgers SET is_shared=1,my_role='editor' WHERE id=1");
    await open(t, budget: original);
    expect(find.byTooltip(l(t).commonDelete), findsNothing);
    expect(
        t
            .widget<BeeButton>(find.widgetWithText(BeeButton, l(t).commonSave))
            .onPressed,
        isNull);
    expect(
        t.widget<BeeBudgetEditorForm>(find.byType(BeeBudgetEditorForm)).enabled,
        false);
    expect(repo.updates, 0);
    await close(t);
  });
  testWidgets('真实写入防重并展示忙态', (t) async {
    await open(t);
    repo.writeGate = Completer<void>();
    await t.enterText(find.byType(TextField), '88.75');
    await t.tap(find.widgetWithText(BeeButton, l(t).commonSave));
    await t.pump();
    await t.pump(const Duration(milliseconds: 30));
    expect(repo.creates, 1);
    expect(
        t
            .widget<BeeButton>(find.widgetWithText(BeeButton, l(t).commonSave))
            .loading,
        true);
    repo.writeGate!.complete();
    await ready(t, find.text('open'));
    expect(repo.creates, 1);
    expect((await repo.getAllBudgets(1)).single.amount, 88.75);
    await close(t);
  });
  testWidgets('真实仓库读取失败可重试，写入失败保留草稿可重试', (t) async {
    repo.failRead = true;
    await open(t, error: true);
    repo.failRead = false;
    await t.tap(find.widgetWithText(BeeButton, l(t).v4RecordingRetry));
    await ready(t, find.byType(BeeBudgetEditorForm));
    repo.failWrite = true;
    await t.enterText(find.byType(TextField), '99.25');
    await t.tap(find.widgetWithText(BeeButton, l(t).commonSave));
    await t.pumpAndSettle();
    expect(await repo.getAllBudgets(1), isEmpty);
    expect(
        t
            .widget<BeeBudgetEditorForm>(find.byType(BeeBudgetEditorForm))
            .amountController
            .text,
        '99.25');
    repo.failWrite = false;
    await save(t);
    expect((await repo.getAllBudgets(1)).single.amount, 99.25);
    await close(t);
  });
  testWidgets('Q18 A编辑预算分类只读，金额与原身份仍正常保存', (t) async {
    final other = await repo.createCategory(
        name: '其他支出父级', kind: 'expense', icon: 'shopping');
    final id = await repo.createBudget(
        ledgerId: 1,
        type: 'category',
        categoryId: parent,
        amount: 500,
        startDay: 17);
    final original =
        (await repo.getAllBudgets(1)).firstWhere((b) => b.id == id);
    await open(t, budget: original);
    expect(
        t
            .widget<BeeBudgetEditorForm>(find.byType(BeeBudgetEditorForm))
            .categoryName,
        '合成咖啡');
    expect(t.widget<BeeMenuRow>(find.byType(BeeMenuRow)).onTap, isNull);
    await t.tap(find.byType(BeeMenuRow));
    await t.pumpAndSettle();
    expect(find.byType(BeeChoicePicker<Category>), findsNothing);
    expect(find.text('其他支出父级'), findsNothing);
    await t.enterText(find.byType(TextField), '550.25');
    await save(t);
    final saved = (await repo.getAllBudgets(1)).firstWhere((b) => b.id == id);
    expect(saved.categoryId, parent);
    expect(saved.categoryId, isNot(other));
    expect(saved.amount, 550.25);
    expect(saved.startDay, 17);
    expect(saved.syncId, original.syncId);
    await close(t);
  });
  testWidgets('编辑期间当前账本变化时拒绝写入原记录或新账本', (t) async {
    final original = await total();
    await open(t, budget: original);
    final before = await rows('budgets');
    c.read(currentLedgerIdProvider.notifier).state = 2;
    await t.pump();
    await t.enterText(find.byType(TextField), '800');
    await t.tap(find.widgetWithText(BeeButton, l(t).commonSave));
    await t.pumpAndSettle();
    expect(repo.updates, 0);
    expect(await rows('budgets'), before);
    expect(find.byType(BudgetEditPage), findsOneWidget);
    await close(t);
  });
  testWidgets('320英文深色140%及系统键盘时固定保存仍可达', (t) async {
    await open(t, category: true, narrow: true);
    t.view.viewInsets = const FakeViewPadding(bottom: 220);
    await t.pumpAndSettle();
    expect(find.widgetWithText(BeeButton, l(t).commonSave).hitTestable(),
        findsOneWidget);
    expect(t.takeException(), isNull);
    t.view.resetViewInsets();
    await close(t);
  });
}
