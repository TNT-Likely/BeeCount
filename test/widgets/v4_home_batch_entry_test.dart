import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/transaction/search_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/biz/transaction_list_item.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'生活','CNY'),(2,'旅行','USD')");
    for (final id in [1, 1, 2]) {
      await repo.addTransaction(
          ledgerId: id,
          type: 'expense',
          amount: id * 10,
          happenedAt: DateTime(2026, 10, 24),
          note: '账本$id的记录');
    }
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      currentLedgerProvider.overrideWith((ref) => repo.watchLedger(1)),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      accountFeatureEnabledProvider.overrideWith((ref) async => true),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester,
      {bool batch = true, bool filter = false, double scale = 1}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
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
                    body: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => SearchPage(
                                    initialBatchMode: batch,
                                    initialOpenFilter: filter))),
                        child: const Text('打开明细')))))));
    await tester.tap(find.text('打开明细'));
    await tester.pumpAndSettle();
  }

  testWidgets('首页直接批量入口不要求关键词，展示当前账本并可退出，实时新增同步刷新', (tester) async {
    await open(tester);
    expect(find.byType(TransactionListItem), findsNWidgets(2));
    final l10n = AppLocalizations.of(tester.element(find.byType(SearchPage)));
    expect(find.text(l10n.v4SearchSelected(0)), findsOneWidget);
    await tester.tap(find.text(l10n.searchSelectAll).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.v4SearchSelected(2)), findsOneWidget);
    await repo.addTransaction(
        ledgerId: 1,
        type: 'income',
        amount: 5,
        happenedAt: DateTime(2026, 10, 24),
        note: '实时新增');
    await tester.pumpAndSettle();
    expect(find.text(l10n.v4SearchSelected(2)), findsOneWidget);
    expect(find.textContaining(l10n.searchResultsCount(3)), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.searchExitBatchMode));
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsNothing);
    expect((await repo.getCountsForLedger(ledgerId: 1)).txCount, 3);
    expect((await repo.getCountsForLedger(ledgerId: 2)).txCount, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('批量空账本仍有退出操作，普通搜索保留无关键词提示', (tester) async {
    container.read(currentLedgerIdProvider.notifier).state = 99;
    await open(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(SearchPage)));
    expect(find.text(l10n.v4SearchSelected(0)), findsOneWidget);
    expect(find.byTooltip(l10n.searchExitBatchMode), findsOneWidget);
    await tester.tap(find.byTooltip(l10n.searchExitBatchMode));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await open(tester, batch: false);
    expect(find.text(l10n.searchNoInput), findsOneWidget);
    expect(find.byType(TransactionListItem), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
  testWidgets('批量列表将真实转账作为中性金额，保留双账户与原有标记', (tester) async {
    final from =
        await repo.createAccount(ledgerId: 1, name: '转出账户', currency: 'CNY');
    final to =
        await repo.createAccount(ledgerId: 1, name: '转入账户', currency: 'CNY');
    await repo.addTransaction(
        ledgerId: 1,
        type: 'transfer',
        amount: 25,
        accountId: from,
        toAccountId: to,
        happenedAt: DateTime(2026, 10, 24),
        excludeFromStats: true,
        excludeFromBudget: true);
    await open(tester);
    expect(find.text('25.00', findRichText: true), findsOneWidget);
    expect(find.text('+25.00', findRichText: true), findsNothing);
    expect(find.textContaining('转出账户 → 转入账户'), findsOneWidget);
    final transfer = tester
        .widgetList<BeeTransactionRow>(find.byType(BeeTransactionRow))
        .singleWhere((row) => row.kind == BeeTransactionKind.transfer);
    expect(transfer.statusLabels, hasLength(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('真实批量备注入口只修改备注，不丢外币快照、共享引用与附件', (tester) async {
    final id = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        currencyCode: 'USD',
        nativeAmount: 85.2,
        categorySyncIdOverride: 'shared-category',
        accountSyncIdOverride: 'shared-account',
        happenedAt: DateTime(2026, 10, 24, 12, 34, 56),
        note: '外币旧备注',
        excludeFromStats: true,
        excludeFromBudget: true);
    final attachment = await repo.createAttachment(
        transactionId: id, fileName: 'synthetic.png', fileSize: 20);
    final before = (await repo.getTransactionById(id))!.toJson();
    await open(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(SearchPage)));
    await tester.tap(find.text(l10n.searchSelectAll).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.searchBatchSetNote));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '统一备注');
    await tester.tap(find.widgetWithText(FilledButton, l10n.commonConfirm));
    await tester.pumpAndSettle();
    expect((await repo.getTransactionById(id))!.toJson(),
        {...before, 'note': '统一备注'});
    expect((await repo.getAttachmentById(attachment))!.fileSize, 20);
    expect(find.text(l10n.v4SearchSelected(0)), findsOneWidget);
    expect(await repo.getTransactionsByLedger(2), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('小屏大字筛选使用规范弹窗，取消不应用输入或修改账单', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final before = await repo.getTransactionsByLedger(1);
    await open(tester, batch: false, filter: true, scale: 1.4);
    expect(find.byType(BeeDialog), findsOneWidget);
    final dialogL10n =
        AppLocalizations.of(tester.element(find.byType(SearchPage)));
    expect(find.widgetWithText(FilledButton, dialogL10n.commonConfirm),
        findsOneWidget);
    final fields = find.descendant(
        of: find.byType(BeeDialog), matching: find.byType(TextField));
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.first, '100');
    final l10n = AppLocalizations.of(tester.element(find.byType(SearchPage)));
    await tester.tap(find.descendant(
        of: find.byType(BeeDialog), matching: find.text(l10n.commonCancel)));
    await tester.pumpAndSettle();
    expect(find.byType(BeeDialog), findsNothing);
    expect(find.text(l10n.searchNoInput), findsOneWidget);
    expect(await repo.getTransactionsByLedger(1), before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
  testWidgets('小屏大字批量操作始终贴底，滚动只移动结果且无选择时禁用', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var i = 0; i < 20; i++) {
      await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: i + 1,
          happenedAt: DateTime(2026, 10, 24),
          note: '滚动$i');
    }
    await open(tester, scale: 1.4);
    final bar = find.byType(BeeBatchActionBar);
    final rect = tester.getRect(bar);
    expect(rect.bottom, 568);
    expect(
        tester
            .widgetList<TextButton>(
                find.descendant(of: bar, matching: find.byType(TextButton)))
            .every((b) => b.onPressed == null),
        isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(bar), rect);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
  testWidgets('真实批量标签走横排选择器，取消不写入，确认保留交易其他字段', (tester) async {
    final tag = await repo.createTag(name: '周末', color: '#219c9c');
    final before = await repo.getTransactionsByLedger(1);
    await open(tester);
    final l = AppLocalizations.of(tester.element(find.byType(SearchPage)));
    await tester.tap(find.text(l.searchSelectAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.v4SearchSetTags));
    await tester.pumpAndSettle();
    expect(find.byType(BeeTagPicker), findsOneWidget);
    await tester.tap(find.text('周末').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton).last);
    await tester.pumpAndSettle();
    for (final tx in before) {
      expect(await repo.getTagsForTransaction(tx.id), isEmpty);
    }
    await tester.tap(find.text(l.v4SearchSetTags));
    await tester.pumpAndSettle();
    await tester.tap(find.text('周末').last);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(BeeTagPicker), matching: find.text(l.commonConfirm)));
    await tester.pumpAndSettle();
    for (final tx in before) {
      expect((await repo.getTagsForTransaction(tx.id)).single.id, tag);
    }
    expect(await repo.getTransactionsByLedger(1), before);
    expect(await repo.getTagsForTransaction(3), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
  testWidgets('搜索分类筛选传递账本范围，只显示共享拥有者分类并保留负数身份', (tester) async {
    await repo.createCategory(name: '个人私有分类', kind: 'expense');
    await db.customStatement(
        "UPDATE ledgers SET sync_id='filter-ledger',is_shared=1,my_role='editor' WHERE id=1");
    await db.customStatement(
        "INSERT INTO shared_ledger_categories(ledger_sync_id,sync_id,name,kind,icon,level,sort_order,updated_at) VALUES('filter-ledger','filter-parent','共享筛选父类','expense','restaurant',1,0,1792713600)");
    await db.customStatement(
        "INSERT INTO shared_ledger_categories(ledger_sync_id,sync_id,name,kind,icon,level,parent_sync_id,sort_order,updated_at) VALUES('filter-ledger','filter-child','共享筛选子类','expense','coffee',2,'filter-parent',0,1792713600)");
    final before = await db.select(db.transactions).get();
    await open(tester, batch: false, filter: true);
    final l = AppLocalizations.of(tester.element(find.byType(SearchPage)));
    await tester.tap(find.widgetWithText(BeeMenuRow, l.searchCategoryFilter));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(RecordingCategoryTile, '个人私有分类'), findsNothing);
    expect(
        find.widgetWithText(RecordingCategoryTile, '共享筛选父类'), findsOneWidget);
    await tester.tap(find.widgetWithText(RecordingSubcategoryChip, '共享筛选子类'));
    await tester.pumpAndSettle();
    expect(find.text('共享筛选子类'), findsOneWidget);
    await tester.tap(find.text(l.commonConfirm));
    await tester.pumpAndSettle();
    expect(find.text('共享筛选子类'), findsOneWidget);
    expect(await db.select(db.transactions).get(), before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
