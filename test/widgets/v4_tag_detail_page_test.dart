import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/tag/tag_detail_page.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/presentation/v4/bindings/tag_detail.dart';
import 'package:beecount/presentation/v4/bindings/tag_detail_sections.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TagDetailTestRepository extends LocalRepository {
  TagDetailTestRepository(super.db);
  bool failReferencesOnce = false;
  @override
  Future<List<Category>> getAllCategoriesIncludingShared() {
    if (failReferencesOnce) {
      failReferencesOnce = false;
      throw StateError('Synthetic resource read failure');
    }
    return super.getAllCategoriesIncludingShared();
  }
}

void main() {
  late BeeDatabase db;
  late TagDetailTestRepository repo;
  late ProviderContainer container;
  late int tag, food, cash, bank;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = TagDetailTestRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,month_start_day) VALUES(1,'日常生活','CNY',8),(2,'美元旅行','USD',1)");
    tag = await repo.createTag(name: '旅行', color: '#219c9c');
    food = await repo.createCategory(name: '餐饮', kind: 'expense');
    cash = await repo.createAccount(ledgerId: 1, name: '现金');
    bank = await repo.createAccount(ledgerId: 1, name: '银行卡');
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo)
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<int> tx(
      {double amount = 12,
      double? native = 85.2,
      String currency = 'USD',
      String type = 'expense',
      int ledger = 1,
      bool exclude = false,
      String note = '咖啡',
      DateTime? at}) async {
    final id = await repo.addTransaction(
        ledgerId: ledger,
        type: type,
        amount: amount,
        nativeAmount: native,
        currencyCode: currency,
        accountId: cash,
        toAccountId: type == 'transfer' ? bank : null,
        categoryId: food,
        note: note,
        happenedAt: at ?? DateTime.now().copyWith(hour: 12, minute: 34),
        excludeFromStats: exclude,
        excludeFromBudget: exclude);
    await repo.addTagToTransaction(transactionId: id, tagId: tag);
    return id;
  }

  Future<void> open(WidgetTester tester,
      {bool all = false,
      int? id,
      double scale = 1,
      Size size = const Size(398, 900)}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(
                brightness: scale > 1 ? Brightness.dark : Brightness.light),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => TagDetailPage(
                                    tagId: id ?? tag,
                                    tagName: '旅行',
                                    allLedgers: all))),
                        child: const Text('打开真实标签')))))));
    await tester.tap(find.text('打开真实标签'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  TagDetailSections section(WidgetTester t) =>
      t.widget<TagDetailSections>(find.byType(TagDetailSections));
  BeeResourceHero hero(WidgetTester t) =>
      t.widget<BeeResourceHero>(find.byType(BeeResourceHero));

  testWidgets('真实统计保留原币快照、排除标记、时间、账户、标签和附件', (tester) async {
    final id = await tx();
    await tx(
        amount: 3, native: 3, currency: 'CNY', exclude: true, note: '不计支出');
    await tx(amount: 9, native: 9, currency: 'CNY', type: 'income');
    await tx(amount: 2, native: 2, currency: 'CNY', type: 'transfer');
    await repo.createAttachment(
        transactionId: id, fileName: 'synthetic.png', fileSize: 20);
    container.read(showTransactionTimeProvider.notifier).state = true;
    final before = await repo.getTransactionsByLedger(1);
    await open(tester);
    expect(hero(tester).amount, '85.20');
    expect(section(tester).stats.requireValue,
        (count: 4, expense: 85.2, income: 9.0));
    final data = section(tester).data.requireValue;
    expect(data.rows, hasLength(4));
    expect(data.rows.singleWhere((r) => r.t.id == id).t.nativeAmount, 85.2);
    expect(data.tags[id]!.single.id, tag);
    expect(data.attachments[id], 1);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    final rows = tester
        .widgetList<BeeTransactionRow>(find.byType(BeeTransactionRow))
        .toList();
    expect(
        rows.any((r) =>
            r.amount.contains(r'US$12.00') &&
            r.converted == '≈ ¥85.20' &&
            r.showTime &&
            r.attachmentCount == 1),
        isTrue);
    expect(
        rows.any((r) =>
            r.kind == BeeTransactionKind.transfer &&
            r.accountName == '现金 → 银行卡'),
        isTrue);
    expect(await repo.getTransactionsByLedger(1), before);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('当前与全部账本范围保持原金额口径及来源账本', (tester) async {
    await tx(amount: 10, native: 10, currency: 'CNY');
    await tx(amount: 20, native: 20, ledger: 2);
    await open(tester);
    expect(section(tester).stats.requireValue.count, 1);
    await close(tester);
    await open(tester, all: true);
    expect(section(tester).stats.requireValue,
        (count: 2, expense: 30.0, income: 0.0));
    expect(section(tester).data.requireValue.ledgers[2]!.currency, 'USD');
    expect(find.text('按原账本金额汇总'), findsOneWidget);
    await close(tester);
  });

  testWidgets('真实流新增后统计同步刷新，不依赖手动页面重开', (tester) async {
    await tx(amount: 10, native: 10, currency: 'CNY');
    await open(tester);
    expect(hero(tester).amount, '10.00');
    await tx(amount: 20, native: 20, currency: 'CNY');
    await tester.pumpAndSettle();
    expect(hero(tester).amount, '30.00');
    expect(section(tester).stats.requireValue.count, 2);
    await close(tester);
  });

  testWidgets('删除标签取消不变，确认只删标签关系而不删除账单', (tester) async {
    await tx();
    final before = await repo.getTransactionsByLedger(1);
    await open(tester);
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(find.byType(BeeDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect((await repo.getAllTags()).any((t) => t.id == tag), isTrue);
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect((await repo.getAllTags()).any((t) => t.id == tag), isFalse);
    expect(await repo.getTransactionsByLedger(1), before);
    expect(await repo.getTagsForTransaction(before.single.id), isEmpty);
    await close(tester);
  });

  testWidgets('带标签记账传递真实身份，返回取消不新增交易', (tester) async {
    await open(tester);
    final l = AppLocalizations.of(tester.element(find.byType(TagDetailPage)));
    await tester.ensureVisible(find.text(l.v4TagRecord));
    await tester.tap(find.text(l.v4TagRecord));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TransactionEditorPage>(find.byType(TransactionEditorPage))
            .initialTagIds,
        [tag]);
    await tester.tap(find.byTooltip(l.commonBack));
    await tester.pumpAndSettle();
    expect(await repo.getTransactionsByLedger(1), isEmpty);
    await close(tester);
  });

  testWidgets('真实资源读取失败可重试，320深色大字不溢出', (tester) async {
    await tx();
    repo.failReferencesOnce = true;
    await open(tester, size: const Size(320, 568), scale: 1.4);
    expect(section(tester).data.hasError, isTrue);
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(section(tester).data.requireValue.rows, hasLength(1));
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  test('自定义8日起始日和全部历史范围保持', () {
    final range = tagDetailRange(TagDetailPeriod.month, 8, DateTime(2026, 10));
    expect(range!.start, DateTime(2026, 10, 8));
    expect(range.end, DateTime(2026, 11, 8));
    expect(tagDetailRange(TagDetailPeriod.all, 8, DateTime(2026, 10)), isNull);
    expect(tagDetailColor('invalid', Colors.teal), Colors.teal);
  });

  test('共享synthetic标签保留原共享账户身份与完整快照', () async {
    final book = await db.into(db.ledgers).insert(LedgersCompanion.insert(
        name: '共享',
        syncId: const Value('shared-book'),
        myRole: const Value('editor'),
        isShared: const Value(true)));
    await db.into(db.sharedLedgerTags).insert(SharedLedgerTagsCompanion.insert(
        ledgerSyncId: 'shared-book',
        syncId: 'shared-tag',
        name: '共享标签',
        updatedAt: DateTime(2026)));
    await db.into(db.sharedLedgerAccounts).insert(
        SharedLedgerAccountsCompanion.insert(
            ledgerSyncId: 'shared-book',
            syncId: 'shared-cash',
            name: '共享现金',
            updatedAt: DateTime(2026)));
    final id = await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
            ledgerId: book,
            type: 'expense',
            amount: 12,
            nativeAmount: const Value(85.2),
            currencyCode: const Value('USD'),
            syncId: const Value('shared-tx'),
            accountSyncIdOverride: const Value('shared-cash')));
    await db.into(db.transactionTagOverrides).insert(
        TransactionTagOverridesCompanion.insert(
            transactionSyncId: 'shared-tx',
            tagSyncId: 'shared-tag',
            createdAt: DateTime(2026)));
    final raw = await repo
        .watchTransactionsByTag(syntheticIdForSyncId('shared-tag'),
            ledgerId: book)
        .first;
    final data = await container.read(tagDetailRowsProvider(raw).future);
    expect(data.rows.single.t.id, id);
    expect(data.rows.single.t.nativeAmount, 85.2);
    expect(data.rows.single.account!.name, '共享现金');
    expect(data.rows.single.account!.id, syntheticIdForSyncId('shared-cash'));
  });
}
