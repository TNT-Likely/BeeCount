import 'dart:async';
import 'dart:io';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/models/ledger_display_item.dart';
import 'package:beecount/pages/main/ledgers_page_new.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Files extends AttachmentService {
  _Files(super.ref, this.directory);
  final Directory directory;
  @override
  Future<Directory> getAttachmentDirectory() async => directory;
  @override
  Future<Directory> getThumbnailDirectory() async =>
      Directory('${directory.path}/thumbs')..createSync(recursive: true);
}

class _FailPeriodRepository extends LocalRepository {
  _FailPeriodRepository(super.db);
  bool fail = true;
  @override
  Future<void> updateLedger(
      {required int id,
      String? name,
      String? currency,
      int? monthStartDay}) async {
    if (fail && monthStartDay != null) {
      fail = false;
      throw StateError('synthetic period failure');
    }
    await super.updateLedger(
        id: id, name: name, currency: currency, monthStartDay: monthStartDay);
  }
}

class _ConflictSync extends LocalOnlySyncService {
  final upload = Completer<void>();
  int uploads = 0;
  @override
  Future<SyncStatus> getStatus({required int ledgerId}) async =>
      const SyncStatus(
          diff: SyncDiff.different,
          localCount: 2,
          localFingerprint: '',
          cloudCount: 1,
          cloudFingerprint: 'x');
  @override
  Future<void> uploadCurrentLedger({required int ledgerId}) {
    uploads++;
    return upload.future;
  }
}

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  late Directory directory;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('home_widget'),
            (call) async =>
                call.method == 'getInstalledWidgets' ? <dynamic>[] : true);
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    directory = await Directory.systemTemp.createTemp('beecount-ledger-v4-');
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'生活','CNY'),(2,'旅游','CNY')");
    await db.customStatement(
        "INSERT INTO transactions(id,ledger_id,type,amount,note) VALUES(1,1,'expense',10,'原午餐'),(2,1,'income',20,'原工资'),(3,2,'expense',6,'车票')");
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      attachmentServiceProvider.overrideWith((ref) => _Files(ref, directory))
    ]);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    container.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> ready(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (target.evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 300));
        return;
      }
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    expect(target, findsWidgets);
  }

  Future<void> open(WidgetTester tester,
      {bool create = false,
      Size size = const Size(398, 844),
      double scale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
            home: LedgersPageNew(autoOpenCreateDialog: create))));
    await ready(tester,
        create ? find.byType(BeeLedgerEditorForm) : find.byType(BeeLedgerCard));
  }

  Future<void> menu(WidgetTester tester, {String name = '生活'}) async {
    await tester.longPress(find.text(name));
    await tester.pumpAndSettle();
    expect(find.byType(BeeLedgerActions), findsOneWidget);
  }

  Future<void> finishIo(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 2300));
  }

  testWidgets('真实统计、当前选中、整卡切换且本地模式隐藏共享入口', (tester) async {
    await open(tester);
    var cards =
        tester.widgetList<BeeLedgerCard>(find.byType(BeeLedgerCard)).toList();
    expect(cards.first.current, isTrue);
    expect(cards.first.expenseLabel, '本月支出'); expect(cards.first.incomeLabel, '本月收入');
    expect(cards.first.expense, '¥10.00');
    expect(cards.first.income, '¥20.00');
    expect(find.text('加入共享账本'), findsNothing);
    await tester.tap(find.text('旅游'));
    await finishIo(tester);
    expect(container.read(currentLedgerIdProvider), 2);
    cards =
        tester.widgetList<BeeLedgerCard>(find.byType(BeeLedgerCard)).toList();
    expect(cards.last.current, isTrue);
    expect(cards.first.current, isFalse);
    expect((await db.select(db.transactions).get()).length, 3);
  });

  testWidgets('创建草稿币种和28日起始日保存，取消选择不写数据库', (tester) async {
    await open(tester, create: true);
    final create = find.widgetWithText(BeeButton, '创建');
    expect(tester.widget<BeeButton>(create).onPressed, isNull);
    await tester.enterText(find.byType(TextFormField), '美元旅行');
    await tester.tap(find.text('主币种'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'USD');
    await tester.pump();
    await tester.tap(find.text('美元 (USD)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每月起始日'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('28'));
    await tester.tap(find.text('28'));
    await tester.pumpAndSettle();
    expect((await repo.getAllLedgers()).length, 2);
    await tester.tap(create);
    await finishIo(tester);
    final added =
        (await repo.getAllLedgers()).singleWhere((l) => l.name == '美元旅行');
    expect(added.currency, 'USD');
    expect(added.monthStartDay, 28);
    expect(added.syncId, isNotEmpty);
    expect(container.read(currentLedgerIdProvider), 1);
    expect((await db.select(db.transactions).get()).length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('原编辑弹窗取消，修改名称与周期保存不改变账单和原币', (tester) async {
    await open(tester);
    await menu(tester);
    await tester.tap(find.text('编辑账本').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '放弃草稿');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect((await repo.getLedgerById(1))!.name, '生活');
    await menu(tester);
    await tester.tap(find.text('编辑账本').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '新的生活');
    await tester.tap(find.text('每月起始日'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await finishIo(tester);
    final row = (await repo.getLedgerById(1))!;
    expect((row.name, row.currency, row.monthStartDay), ('新的生活', 'CNY', 8));
    expect((await db.select(db.transactions).get()).map((t) => t.note),
        ['原午餐', '原工资', '车票']);
  });

  testWidgets('更改本位币必须二次确认，取消不改原折算快照', (tester) async {
    await open(tester);
    await menu(tester);
    await tester.tap(find.text('编辑账本').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('主币种'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'USD');
    await tester.pump();
    await tester.tap(find.text('美元 (USD)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await ready(tester, find.textContaining('重算全部历史交易'));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect((await repo.getLedgerById(1))!.currency, 'CNY');
    expect((await db.select(db.transactions).get()).map((t) => t.amount),
        [10, 20, 6]);
  });

  testWidgets('真实清空仅删目标交易，跨账本共用附件不误删', (tester) async {
    await tester.runAsync(() async {
      await File('${directory.path}/shared.png').writeAsBytes([1, 2, 3]);
      await File('${directory.path}/owned.png').writeAsBytes([4, 5, 6]);
    });
    await repo.createAttachment(transactionId: 1, fileName: 'shared.png');
    await repo.createAttachment(transactionId: 2, fileName: 'owned.png');
    await repo.createAttachment(transactionId: 3, fileName: 'shared.png');
    await open(tester);
    await menu(tester);
    await tester.tap(find.text('清空账本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect((await db.select(db.transactions).get()).length, 3);
    await menu(tester);
    await tester.tap(find.text('清空账本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await finishIo(tester);
    expect((await repo.getAllLedgers()).length, 2);
    expect((await db.select(db.transactions).get()).map((t) => t.id), [3]);
    expect(File('${directory.path}/shared.png').readAsBytesSync(), [1, 2, 3]);
    expect(File('${directory.path}/owned.png').existsSync(), isFalse);
  });

  testWidgets('编辑者不显示所有者操作，但保留预算与仅删除本地', (tester) async {
    await db.customStatement(
        "UPDATE ledgers SET my_role='editor',is_shared=1,member_count=2 WHERE id=1");
    await open(tester);
    await menu(tester);
    final menuWidget =
        tester.widget<BeeLedgerActions>(find.byType(BeeLedgerActions));
    expect(menuWidget.actions.map((a) => a.id), ['budget', 'deleteLocal']);
    expect(find.text('成员管理'), findsNothing);
  });

  testWidgets('真实仅删除本地当前账本后选剩余，其他账单保持', (tester) async {
    await open(tester);
    await menu(tester);
    await tester.tap(find.text('仅删除本地账本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await finishIo(tester);
    expect((await repo.getAllLedgers()).map((l) => l.id), [2]);
    expect(container.read(currentLedgerIdProvider), 2);
    expect((await db.select(db.transactions).get()).map((t) => t.id), [3]);
  });

  testWidgets('完整删除取消和确认，未选中账本不影响当前账本', (tester) async {
    await open(tester);
    await menu(tester, name: '旅游');
    await tester.tap(find.text('删除账本').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect((await repo.getAllLedgers()).length, 2);
    await menu(tester, name: '旅游');
    await tester.tap(find.text('删除账本').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await finishIo(tester);
    expect((await repo.getAllLedgers()).map((l) => l.id), [1]);
    expect(container.read(currentLedgerIdProvider), 1);
    expect((await db.select(db.transactions).get()).map((t) => t.id), [1, 2]);
  });

  testWidgets('无账本自动打开新建，创建后选实际新身份且不播种账单', (tester) async {
    await db.customStatement('DELETE FROM transactions');
    await db.customStatement('DELETE FROM ledgers');
    await open(tester, create: true);
    await tester.enterText(find.byType(TextFormField), '第一本');
    await tester.pump();
    await tester.tap(find.widgetWithText(BeeButton, '创建'));
    await finishIo(tester);
    final row = (await repo.getAllLedgers()).single;
    expect(container.read(currentLedgerIdProvider), row.id);
    expect((await db.select(db.transactions).get()), isEmpty);
  });

  testWidgets('远端独立卡片只提供下载与远端删除，取消不落本地', (tester) async {
    container.dispose();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      remoteLedgersProvider.overrideWith((ref) async => [
            LedgerDisplayItem(
                id: 999,
                name: '远端旅行',
                currency: 'USD',
                transactionCount: 3,
                balance: 12,
                lastUpdated: DateTime(2026, 10, 23),
                isRemoteOnly: true,
                remoteSyncId: 'synthetic-remote-id')
          ])
    ]);
    await open(tester);
    await tester.scrollUntilVisible(find.text('远端旅行'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.longPress(find.text('远端旅行'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<BeeLedgerActions>(find.byType(BeeLedgerActions))
            .actions
            .map((a) => a.id),
        ['download', 'delete']);
    await tester.tap(find
        .text(tester
            .widget<BeeLedgerActions>(find.byType(BeeLedgerActions))
            .actions
            .first
            .label)
        .last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect((await repo.getAllLedgers()).length, 2);
  });

  testWidgets('创建起始日写入失败整笔回滚，重新提交只产生一个账本', (tester) async {
    container.dispose();
    final faulty = _FailPeriodRepository(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(faulty),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService())
    ]);
    await open(tester, create: true);
    Future<void> fillAndSave() async {
      await tester.enterText(find.byType(TextFormField), '故障后重试');
      await tester.tap(find.text('每月起始日'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(BeeButton, '创建'));
      await finishIo(tester);
    }

    await fillAndSave();
    expect((await repo.getAllLedgers()).length, 2);
    await tester.tap(find.byTooltip('创建'));
    await tester.pumpAndSettle();
    await fillAndSave();
    expect(
        (await repo.getAllLedgers()).where((l) => l.name == '故障后重试').length, 1);
    expect((await db.select(db.transactions).get()).length, 3);
  });

  testWidgets('远端慢加载与失败不阻塞真实本地账本，保留重试和新建', (tester) async {
    final remote = Completer<List<LedgerDisplayItem>>();
    container.dispose();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      remoteLedgersProvider.overrideWith((ref) => remote.future)
    ]);
    await open(tester);
    expect(find.text('生活'), findsOneWidget);
    remote.completeError(StateError('QA remote unavailable'));
    await finishIo(tester);
    await tester.scrollUntilVisible(find.text('重试'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('新建账本'), findsOneWidget);
    expect((await repo.getAllLedgers()).length, 2);
  });

  testWidgets('短指纹冲突弹窗不崩溃，处理中不能重复提交', (tester) async {
    final sync = _ConflictSync();
    container.dispose();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      syncServiceProvider.overrideWithValue(sync)
    ]);
    await open(tester);
    await tester.tap(find.text('生活'));
    await ready(tester, find.text('同步冲突'));
    final upload = find.widgetWithText(FilledButton, '上传到云端');
    await tester.tap(upload);
    await tester.pump();
    expect(
        find.descendant(
            of: find.byType(BeeDialog), matching: find.byType(FilledButton)),
        findsNothing);
    expect(sync.uploads, 1);
    sync.upload.complete();
    await finishIo(tester);
    expect((await db.select(db.transactions).get()).length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320大字表单和月起始日可滚动，底部动作不溢出', (tester) async {
    await open(tester, create: true, size: const Size(320, 568), scale: 1.4);
    await tester.enterText(find.byType(TextFormField), '旅行账本');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.ensureVisible(find.text('每月起始日'));
    await tester.tap(find.text('每月起始日'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('28'));
    await tester.tap(find.text('28'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
