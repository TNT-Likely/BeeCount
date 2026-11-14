import 'dart:async';
import 'dart:io';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/attachment/attachment_preview_page.dart';
import 'package:beecount/pages/transaction/category_detail_page.dart';
import 'package:beecount/pages/transaction/transaction_detail_page.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/pages/transaction/detail/bindings/transaction_detail_data.dart';
import 'package:beecount/dev/component_gallery/bindings/transaction_detail_preview.dart';
import 'package:beecount/pages/shared/transactions/bindings/transaction_tile.dart';
import 'package:beecount/dev/component_gallery/transaction_detail_sample.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:beecount/pages/main/home/bindings/transaction_list.dart';
import 'package:beecount/pages/shared/transactions/transaction_list_item.dart';
import 'package:beecount/pages/transaction/detail/bindings/transaction_receipt_dialog.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart'
    show BeeAttachmentViewer;
import 'package:beecount_business_ui/transaction_detail.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends LocalRepository {
  _Repository(super.db);
  bool failRead = false;
  final negativeReads = <int>[];
  Completer<void>? gate;
  @override
  Future<Transaction?> getTransactionById(int id) async {
    if (failRead) throw StateError('QA read failed');
    if (gate != null) await gate!.future;
    return super.getTransactionById(id);
  }

  @override
  Future<Category?> getCategoryById(int id) async {
    if (id < 0) {
      negativeReads.add(id);
      throw StateError('Negative local category read');
    }
    return super.getCategoryById(id);
  }

  @override
  Future<Account?> getAccount(int id) async {
    if (id < 0) {
      negativeReads.add(id);
      throw StateError('Negative local account read');
    }
    return super.getAccount(id);
  }
}

class _Attachments extends AttachmentService {
  _Attachments(super.ref, this.directory);
  final Directory directory;
  @override
  Future<Directory> getAttachmentDirectory() async => directory;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsEn();
  late BeeDatabase db;
  late _Repository repo;
  late Directory temporary;
  late GlobalKey<NavigatorState> navigator;
  int currentLedger = 1;
  double scale = 1;
  Brightness brightness = Brightness.light;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repository(db);
    temporary = await Directory.systemTemp.createTemp('beecount-detail-unit-');
    navigator = GlobalKey<NavigatorState>();
    currentLedger = 1;
    scale = 1;
    brightness = Brightness.light;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'QA CNY ledger','CNY'),(2,'QA JPY ledger','JPY')");
    await db.customStatement(
        "INSERT INTO accounts(id,ledger_id,name,currency) VALUES(1,1,'QA USD cash','USD'),(2,1,'QA USD bank','USD')");
    await db.customStatement(
        "INSERT INTO categories(id,name,kind,level,parent_id) VALUES(1,'QA Food','expense',1,NULL),(2,'QA Coffee','expense',2,1),(3,'QA Salary','income',1,NULL)");
    await db.customStatement(
        "INSERT INTO tags(id,name,color) VALUES(1,'QA friends','#FF6600'),(2,'QA travel','#0000FF')");
  });
  tearDown(() async {
    await db.close();
    await temporary.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
      }
    });
  }

  Future<Transaction> seed(
      {int id = 1,
      int ledger = 1,
      String type = 'expense',
      double amount = 123.45,
      double? native = 882.6675,
      String? currency = 'USD',
      int? account = 1,
      int? to,
      String note = 'QA complete note',
      bool flags = true}) async {
    await db.customStatement(
        'INSERT INTO transactions(id,ledger_id,type,amount,category_id,account_id,to_account_id,happened_at,note,currency_code,native_amount,exclude_from_stats,exclude_from_budget,sync_id) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
        [
          id,
          ledger,
          type,
          amount,
          type == 'transfer'
              ? null
              : type == 'income'
                  ? 3
                  : 2,
          account,
          to,
          DateTime(2026, 10, 25, 12, 30, 45).millisecondsSinceEpoch ~/ 1000,
          note,
          currency,
          native,
          flags ? 1 : 0,
          flags ? 1 : 0,
          'qa-tx-$id'
        ]);
    await db.customStatement(
        'INSERT INTO transaction_tags(transaction_id,tag_id) VALUES(?,1),(?,2)',
        [id, id]);
    return (await repo.getTransactionById(id))!;
  }

  Future<void> attachments(int id, {bool missing = false}) async {
    for (var i = 0; i < 3; i++) {
      final name = 'qa-$i.png';
      if (!missing || i != 1) {
        await File('${temporary.path}/$name').writeAsBytes(
            await File('assets/v4_gallery/attachment-receipt.png')
                .readAsBytes());
      }
      await repo.createAttachment(
          transactionId: id,
          fileName: name,
          originalName: 'QA receipt $i',
          fileSize: 123 + i,
          sortOrder: i);
    }
  }

  Widget host(Widget page) => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
            currentLedgerIdProvider.overrideWith((ref) => currentLedger),
            attachmentServiceProvider
                .overrideWith((ref) => _Attachments(ref, temporary)),
            currencyPickerRatesProvider
                .overrideWith((ref, base) async => <String, double>{}),
          ],
          child: MaterialApp(
              navigatorKey: navigator,
              theme: beeTheme(brightness: brightness),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: page));
  void size(WidgetTester t, {Size value = const Size(398, 1000)}) {
    t.view.physicalSize = value;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Future<void> open(WidgetTester t, {int id = 1, int? ledger = 1}) async {
    size(t);
    await t.pumpWidget(host(const Scaffold(body: Text('QA detail entry'))));
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) =>
            TransactionDetailPage(transactionId: id, ledgerId: ledger)));
    for (var i = 0; i < 60; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await t.pump(const Duration(milliseconds: 30));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          (find.byType(BeeTransactionDetail).evaluate().isNotEmpty ||
              find.byType(BeeEmptyState).evaluate().isNotEmpty)) {
        break;
      }
    }
    await t.pumpAndSettle();
  }

  Future<void> closeToDetail(WidgetTester t) async {
    for (var i = 0;
        i < 4 && find.byType(BeeTransactionDetail).evaluate().isEmpty;
        i++) {
      navigator.currentState!.pop();
      await t.pumpAndSettle();
    }
  }

  BeeTransactionDetail detail(WidgetTester t) =>
      t.widget<BeeTransactionDetail>(find.byType(BeeTransactionDetail));
  Future<void> tapAction(WidgetTester t, String action) async {
    final finder = find.byKey(ValueKey('transaction-detail-$action'));
    await t.ensureVisible(finder);
    await t.tap(finder);
    for (var i = 0; i < 30; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await t.pump(const Duration(milliseconds: 20));
    }
    await t.pumpAndSettle();
  }

  test('真实仓储水合父子分类、标签、附件与固定历史折算，读取不写财务数据', () async {
    final tx = await seed();
    await attachments(tx.id);
    final data = (await loadTransactionDetail(
        repo, const TransactionDetailRequest(1, ledgerId: 1)))!;
    expect(data.row.t, tx);
    expect(data.row.category!.name, 'QA Coffee');
    expect(data.parentCategory!.name, 'QA Food');
    expect(data.tags.map((tag) => tag.name), ['QA friends', 'QA travel']);
    expect(data.attachments.map((a) => a.originalName),
        ['QA receipt 0', 'QA receipt 1', 'QA receipt 2']);
    expect(data.currency, 'USD');
    expect(data.baseCurrency, 'CNY');
    expect(data.historicalRate, closeTo(7.15, .00000001));
    await db.customStatement(
        "INSERT INTO exchange_rate_overrides(base_currency,quote_currency,rate) VALUES('CNY','USD','99.0')");
    final after =
        (await loadTransactionDetail(repo, const TransactionDetailRequest(1)))!;
    expect(after.historicalRate, data.historicalRate);
    expect(after.historicalAmount, 882.6675);
    expect(await repo.getTransactionById(1), tx);
    expect((await db.select(db.transactions).get()).length, 1);
  });

  test('无账户历史币种按账户/账本兜底，零额不推导汇率，缺快照不取实时汇率', () async {
    await seed(currency: null);
    expect(
        (await loadTransactionDetail(repo, const TransactionDetailRequest(1)))!
            .currency,
        'USD');
    await seed(id: 2, ledger: 2, account: null, currency: null, native: null);
    final jpy =
        (await loadTransactionDetail(repo, const TransactionDetailRequest(2)))!;
    expect(jpy.currency, 'JPY');
    expect(jpy.historicalAmount, isNull);
    await seed(id: 3, amount: 0, native: 0);
    expect(
        (await loadTransactionDetail(repo, const TransactionDetailRequest(3)))!
            .historicalRate,
        isNull);
    expect(
        await loadTransactionDetail(repo, const TransactionDetailRequest(-123)),
        isNull);
    expect(
        await loadTransactionDetail(
            repo, const TransactionDetailRequest(1, ledgerId: 2)),
        isNull);
  });

  scenario('完整详情、父子路径、原币金额、历史快照、标签和只读标记', (t) async {
    final tx = await seed();
    await open(t);
    expect(find.text('QA Food / QA Coffee'), findsOneWidget);
    expect(find.text('QA CNY ledger'), findsOneWidget);
    expect(find.text('2026.10.25 12:30:45'), findsOneWidget);
    expect(detail(t).amount, '−123.45');
    expect(find.text('≈ CNY 882.67'), findsOneWidget);
    expect(find.textContaining('7.15000'), findsOneWidget);
    expect(detail(t).tags.length, 2);
    expect(detail(t).statusLabels,
        [l.txFlagExcludeFromStats, l.txFlagExcludeFromBudget]);
    expect(await repo.getTransactionById(1), tx);
    expect(t.takeException(), isNull);
  });

  scenario('隐私开关同时隐藏原金额、折算和隐含汇率，不改交易', (t) async {
    final tx = await seed();
    await open(t);
    await t.tap(find.byTooltip(l.v4AmountsHide));
    await t.pumpAndSettle();
    final texts = t
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
        .join('\n');
    for (final private in ['123.45', '882.67', '7.15000']) {
      expect(texts, isNot(contains(private)));
    }
    expect(detail(t).hidden, true);
    await t.tap(find.byTooltip(l.v4AmountsShow));
    await t.pumpAndSettle();
    expect(detail(t).hidden, false);
    expect(await repo.getTransactionById(1), tx);
  });

  scenario('转账展示双账户且金额不加收入支出符号', (t) async {
    await seed(type: 'transfer', to: 2);
    await open(t);
    expect(detail(t).kind, BeeTransactionKind.transfer);
    expect(detail(t).amount, '123.45');
    expect(find.text('QA USD cash'), findsOneWidget);
    expect(find.text('QA USD bank'), findsOneWidget);
    expect(find.text('QA Food / QA Coffee'), findsNothing);
  });

  scenario('退款与零额符号沿用原列表，历史值与源交易不变', (t) async {
    size(t);
    final cases = [
      ('expense', -12.0, -85.8, '+12.00'),
      ('income', -9.0, -64.35, '−9.00'),
      ('expense', 0.0, 0.0, '0.00')
    ];
    var id = 10;
    for (final entry in cases) {
      final tx = await seed(
          id: id, type: entry.$1, amount: entry.$2, native: entry.$3);
      await t.pumpWidget(
          host(TransactionDetailPage(transactionId: id, ledgerId: 1)));
      await t.pumpAndSettle();
      expect(detail(t).amount, entry.$4);
      expect(await repo.getTransactionById(id), tx);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      id++;
    }
  });

  scenario('真实附件平铺、缺图有占位，点击保持原序号且禁止删除', (t) async {
    await seed();
    await t.runAsync(() => attachments(1, missing: true));
    await open(t);
    expect(detail(t).attachments.length, 3);
    expect(t.takeException(), isNull);
    final grids = find.byType(GridView);
    await t.ensureVisible(grids);
    await t.tap(find.bySemanticsLabel('QA receipt 2'));
    for (var i = 0; i < 40; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 30));
      final viewer = find.byType(BeeAttachmentViewer);
      if (viewer.evaluate().isNotEmpty &&
          t.widget<BeeAttachmentViewer>(viewer).items.length == 3) {
        break;
      }
    }
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    final page =
        t.widget<AttachmentPreviewPage>(find.byType(AttachmentPreviewPage));
    expect(page.transactionId, 1);
    expect(page.initialIndex, 2);
    expect(page.allowDelete, false);
    expect(page.allowAdd, false);
    expect(
        t
            .widget<BeeAttachmentViewer>(find.byType(BeeAttachmentViewer))
            .currentIndex,
        2);
    navigator.currentState!.pop();
    await t.pumpAndSettle();
    expect(await repo.getAttachmentCountByTransaction(1), 3);
  });

  scenario('编辑和复制复用真实入口及原历史金额参数，取消均不新增数据', (t) async {
    final tx = await seed();
    await open(t);
    await tapAction(t, 'edit');
    var editor =
        t.widget<TransactionEditorPage>(find.byType(TransactionEditorPage));
    expect(editor.editingTransactionId, 1);
    expect(editor.initialCurrencyCode, 'USD');
    expect(editor.initialNativeAmount, tx.nativeAmount);
    await closeToDetail(t);
    await tapAction(t, 'copy');
    editor =
        t.widget<TransactionEditorPage>(find.byType(TransactionEditorPage));
    expect(editor.editingTransactionId, isNull);
    expect(editor.isCopy, true);
    expect(editor.initialAmount, tx.amount);
    await closeToDetail(t);
    expect((await db.select(db.transactions).get()).length, 1);
  });

  scenario('详情小票调用原对话框，关闭后仍保持交易和详情', (t) async {
    final tx = await seed();
    await open(t);
    await tapAction(t, 'receipt');
    expect(find.byType(TransactionReceiptDialog), findsOneWidget);
    expect(
        t
            .widget<TransactionReceiptDialog>(
                find.byType(TransactionReceiptDialog))
            .data
            .transaction,
        tx);
    await t.tap(find.byKey(const ValueKey('receipt-close')));
    await t.pumpAndSettle();
    expect(find.byType(BeeTransactionDetail), findsOneWidget);
    expect(await repo.getTransactionById(1), tx);
  });

  scenario('读取失败有重试，删除对象或账本身份不匹配显示真实不存在状态', (t) async {
    await seed();
    repo.failRead = true;
    await open(t);
    expect(find.textContaining('QA read failed'), findsOneWidget);
    repo.failRead = false;
    await t.tap(find.text(l.v4RecordingRetry));
    await t.pumpAndSettle();
    expect(find.byType(BeeTransactionDetail), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
    await db.customStatement('DELETE FROM transactions WHERE id=1');
    await t.pumpWidget(
        host(const TransactionDetailPage(transactionId: 1, ledgerId: 1)));
    await t.pumpAndSettle();
    expect(find.text(l.aiChatTransactionNotFound), findsOneWidget);
  });

  scenario('重建入口仅凭交易与账本参数读取最新记录，不依赖旧Row对象', (t) async {
    await seed();
    await open(t);
    expect(find.text('QA complete note'), findsNWidgets(2));
    final args = {'transactionId': 1, 'ledgerId': 1};
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
    await db.customStatement(
        "UPDATE transactions SET note='QA persisted changed',amount=9.25,native_amount=66.1375 WHERE id=1");
    await t.pumpWidget(host(TransactionDetailPage(
        transactionId: args['transactionId']!, ledgerId: args['ledgerId'])));
    await t.pumpAndSettle();
    expect(detail(t).amount, '−9.25');
    expect(find.text('QA persisted changed'), findsNWidgets(2));
  });

  scenario('共享synthetic分类账户标签使用水合展示，不按负ID读本地实体', (t) async {
    currentLedger = 3;
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,is_shared,my_role,sync_id) VALUES(3,'QA shared ledger','CNY',1,'editor','qa-shared')");
    await db.customStatement(
        "INSERT INTO shared_ledger_categories(ledger_sync_id,sync_id,name,kind,level,parent_sync_id,updated_at) VALUES('qa-shared','qa-parent','QA Shared parent','expense',1,NULL,1),('qa-shared','qa-child','QA Shared child','expense',2,'qa-parent',1)");
    await db.customStatement(
        "INSERT INTO shared_ledger_accounts(ledger_sync_id,sync_id,name,currency,updated_at) VALUES('qa-shared','qa-account','QA Shared USD','USD',1)");
    await db.customStatement(
        "INSERT INTO shared_ledger_tags(ledger_sync_id,sync_id,name,updated_at) VALUES('qa-shared','qa-tag','QA Shared tag',1)");
    await seed(ledger: 3, account: null);
    await db.customStatement(
        "UPDATE transactions SET category_id=NULL,category_sync_id_override='qa-child',account_sync_id_override='qa-account' WHERE id=1");
    await db.customStatement(
        "INSERT INTO transaction_tag_overrides(transaction_sync_id,tag_sync_id,created_at) VALUES('qa-tx-1','qa-tag',1)");
    await open(t, ledger: 3);
    expect(find.text('QA Shared parent / QA Shared child'), findsOneWidget);
    expect(find.text('QA Shared USD'), findsOneWidget);
    expect(detail(t).readOnlyTagIds, isNotEmpty);
    expect(detail(t).onCategory, isNull);
    expect(repo.negativeReads, isEmpty);
    expect(detail(t).onEdit, isNotNull);
    expect(detail(t).onCopy, isNotNull);
    await db.customStatement("UPDATE ledgers SET my_role='viewer' WHERE id=3");
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
    await t.pumpWidget(
        host(const TransactionDetailPage(transactionId: 1, ledgerId: 3)));
    await t.pumpAndSettle();
    expect(detail(t).onEdit, isNull);
    expect(detail(t).onCopy, isNull);
    expect(detail(t).onReceipt, isNotNull);
  });

  scenario('首页长按保留复制小票并新增详情，点击分类仍走分类页', (t) async {
    final tx = await seed();
    size(t);
    final row = (
      t: tx,
      category: await repo.getCategoryById(2),
      account: await repo.getAccount(1),
      toAccount: null
    );
    await t.pumpWidget(host(Scaffold(
        body: TransactionList(hideAmounts: false, transactions: [row]))));
    await t.pumpAndSettle();
    await t.longPress(find.byType(TransactionListItem, skipOffstage: false));
    await t.pumpAndSettle();
    expect(find.text(l.transactionCopyAction), findsOneWidget);
    expect(find.text(l.transactionReceiptAction), findsOneWidget);
    await t.tap(find.text(l.v4TransactionDetailTitle));
    await t.pumpAndSettle();
    expect(find.byType(TransactionDetailPage), findsOneWidget);
    navigator.currentState!.pop();
    await t.pumpAndSettle();
    final item = t.widget<TransactionListItem>(
        find.byType(TransactionListItem, skipOffstage: false));
    expect(item.onTap, isNotNull);
    expect(item.onCategoryTap, isNotNull);
    await t.tapAt(
        t.getTopLeft(find.byType(TransactionListItem, skipOffstage: false)) +
            const Offset(24, 30));
    await t.pumpAndSettle();
    expect(find.byType(CategoryDetailPage), findsOneWidget);
    navigator.currentState!.pop();
    await t.pumpAndSettle();
    await t.tapAt(
        t.getTopLeft(find.byType(TransactionListItem, skipOffstage: false)) +
            const Offset(150, 30));
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    expect(find.byType(TransactionEditorPage), findsOneWidget);
    expect(find.byType(TransactionDetailPage), findsNothing);
  });

  scenario('搜索批量态长按不打开详情且不改变选中，非批量态另有长按详情', (t) async {
    final tx = await seed();
    size(t);
    var selections = 0;
    final row = (
      t: tx,
      category: await repo.getCategoryById(2),
      account: await repo.getAccount(1),
      toAccount: null
    );
    Widget tile(bool batch) => Scaffold(
        body: TransactionTileBinding(
            row: row,
            tags: const [],
            attachmentCount: 0,
            batch: batch,
            selected: true,
            onSelect: () => selections++,
            onReturned: () {}));
    await t.pumpWidget(host(tile(true)));
    await t.pumpAndSettle();
    await t.longPress(find.byType(TransactionListItem));
    await t.pumpAndSettle();
    expect(find.byType(TransactionDetailPage), findsNothing);
    expect(find.text(l.v4TransactionDetailTitle), findsNothing);
    expect(selections, 0);
    await t.tap(find.byType(TransactionListItem));
    await t.pumpAndSettle();
    expect(selections, 1, reason: 'Ordinary tap still toggles selection');

    await t.pumpWidget(host(tile(false)));
    await t.pumpAndSettle();
    await t.longPress(find.byType(TransactionListItem));
    await t.pumpAndSettle();
    await t.tap(find.text(l.v4TransactionDetailTitle));
    await t.pumpAndSettle();
    expect(find.byType(TransactionDetailPage), findsOneWidget);
  });

  scenario('真实只读预览和局部样例不执行复制编辑分享或写入', (t) async {
    final tx = await seed();
    size(t);
    await t.pumpWidget(host(const Scaffold(
        body: SingleChildScrollView(child: TransactionDetailPreview()))));
    await t.pumpAndSettle();
    expect(detail(t).onEdit, isNull);
    expect(detail(t).onCopy, isNull);
    expect(detail(t).onReceipt, isNull);
    await t.pumpWidget(host(const Scaffold(
        body: SingleChildScrollView(child: TransactionDetailSample()))));
    await t.pumpAndSettle();
    await tapAction(t, 'copy');
    expect(find.byType(TransactionEditorPage), findsNothing);
    expect(await repo.getTransactionById(1), tx);
  });

  for (final appearance in Brightness.values) {
    scenario('320宽140%深浅色长字段和缺图无溢出，纯回调无写入 $appearance', (t) async {
      size(t, value: const Size(320, 568));
      var calls = 0;
      final image = MemoryImage(Uint8List.fromList([0, 1, 2]));
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(brightness: appearance),
          home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(17),
                      child: BeeTransactionDetail(
                          title:
                              'QA long title and custom multilingual category 分类',
                          kindLabel: 'Expense',
                          kind: BeeTransactionKind.expense,
                          amount: '−123,456,789.12',
                          currency: 'USD',
                          icon: const BeeLineIcon('Coffee'),
                          items: [
                            BeeDetailItem(
                                label: 'A long account label',
                                value: const Text(
                                    'A sufficiently long UTF8 account name 账户'))
                          ],
                          copyLabel: 'Copy as a new transaction',
                          editLabel: 'Edit transaction',
                          receiptLabel: 'Generate receipt',
                          attachmentLabel: 'Attachments',
                          snapshotLabel: 'Historical conversion',
                          snapshotAmount: '≈ CNY 882,667,512.99',
                          snapshotRateLabel: 'Rate at entry',
                          snapshotRate: '1 USD ≈ 7.15000 CNY',
                          note: 'Long complete note 备注\n' * 12,
                          noteLabel: 'Note',
                          tags: const [
                            BeeTagData('1', 'QA long tag name', Colors.blue)
                          ],
                          attachments: [
                            BeeAttachment(
                                id: 'bad',
                                image: image,
                                label: 'QA missing image',
                                info: '')
                          ],
                          onAttachment: (_) => calls++,
                          onCopy: () => calls++,
                          onEdit: () => calls++,
                          onReceipt: () => calls++))))));
      await t.pumpAndSettle();
      final copy = find.byKey(const ValueKey('transaction-detail-copy'));
      await t.ensureVisible(copy);
      await t.tap(copy);
      await t.pump();
      expect(calls, 1);
      expect(t.takeException(), isNull);
    });
  }
}
