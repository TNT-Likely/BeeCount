import 'dart:async';
import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/pages/account/account_edit_page.dart';
import 'package:beecount/presentation/v4/bindings/recording_save.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/currency/exchange_rate_service.dart';
import 'package:beecount/widgets/biz/amount_editor_sheet.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoNetworkRates extends ExchangeRateService {
  int calls = 0;
  @override
  Future<RateFetchResult> fetch(String base) async {
    calls++;
    throw StateError('QA deliberately has no rate network');
  }
}

class BlockingTransferRepository extends LocalRepository {
  BlockingTransferRepository(super.db);
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<void> updateTransactionTags(
      {required int transactionId, required List<int> tagIds}) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super
        .updateTransactionTags(transactionId: transactionId, tagIds: tagIds);
  }
}

void inlineTransferTest(String name, Future<void> Function(WidgetTester) body) {
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
  late int cnyFrom, cnyTo, usdFrom, usdTo, hidden, tag;
  late NoNetworkRates rates;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    rates = NoNetworkRates();
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency)VALUES(1,'QA 人民币账本','CNY')");
    cnyFrom = await repo.createAccount(
        ledgerId: 1, name: 'QA 人民币现金', currency: 'CNY', initialBalance: 1000);
    cnyTo = await repo.createAccount(
        ledgerId: 1, name: 'QA 人民币银行', currency: 'CNY', initialBalance: 50);
    usdFrom = await repo.createAccount(
        ledgerId: 1, name: 'QA 美元现金', currency: 'USD', initialBalance: 100);
    usdTo = await repo.createAccount(
        ledgerId: 1, name: 'QA 美元银行', currency: 'USD', initialBalance: 5);
    await repo.createAccount(ledgerId: 1, name: 'QA 欧元账户', currency: 'EUR');
    hidden =
        await repo.createAccount(ledgerId: 1, name: 'QA 隐藏美元', currency: 'USD');
    await db
        .customStatement('UPDATE accounts SET hidden=1 WHERE id=?', [hidden]);
    tag = await repo.createTag(name: 'QA 转账标签');
    await repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-10-25',
        rates: {'USD': '7.2', 'EUR': '8.0'},
        source: 'QA',
        fetchedAt: DateTime(2026, 10, 25));
  });
  tearDown(() async => db.close());
  Future<void> open(WidgetTester tester,
      {Widget? page,
      Size size = const Size(398, 844),
      double scale = 1,
      Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
          currentLedgerProvider.overrideWith(
              (ref) => repo.watchLedger(ref.watch(currentLedgerIdProvider))),
          beecountCloudProviderInstance.overrideWith((ref) async => null),
          syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
          exchangeRateServiceProvider.overrideWithValue(rates)
        ],
        child: MaterialApp(
            theme: beeTheme(brightness: brightness),
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
                                builder: (_) =>
                                    page ??
                                    const TransactionEditorPage(
                                        initialKind: 'transfer'))),
                        child: const Text('打开主记账')))))));
    await tester.tap(find.text('打开主记账'));
    await tester.pumpAndSettle();
  }

  Finder pairRow(bool from) => find
      .descendant(
          of: find.byType(BeeTransferAccountPair),
          matching: find.byType(BeeMenuRow))
      .at(from ? 0 : 1);
  Future<void> select(WidgetTester tester, bool from, String name) async {
    await tester.ensureVisible(pairRow(from));
    await tester.tap(pairRow(from));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing,
        reason: 'only account selection may open a sheet');
    expect(find.byType(AmountEditorSheet), findsOneWidget);
  }

  Future<void> typeTen(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('recording-key-1')));
    await tester.tap(find.byKey(const ValueKey('recording-key-0')));
    await tester.pumpAndSettle();
  }

  for (final state in ['empty', 'unselected', 'selected']) {
    for (final small in [false, true]) {
      inlineTransferTest('转账日期左侧不保留单账户空槽 $state ${small ? '320大字' : '标准屏'}',
          (tester) async {
        if (state == 'empty') {
          await db.customStatement('DELETE FROM accounts');
        }
        await open(tester,
            page: TransactionEditorPage(
                initialKind: 'transfer',
                initialAccountId: state == 'selected' ? cnyFrom : null,
                initialToAccountId: state == 'selected' ? cnyTo : null),
            size: small ? const Size(320, 568) : const Size(398, 844),
            scale: 1.4);
        final details = tester
            .widget<RecordingDetailsCard>(find.byType(RecordingDetailsCard));
        expect(details.account, isNull,
            reason:
                'transfer accounts are selected above, not a blank Expanded');
        final card =
            tester.getRect(find.byKey(const ValueKey('recording-details')));
        final date =
            tester.getRect(find.byKey(const ValueKey('recording-date')));
        final toggle = find.byKey(const ValueKey('recording-note-compact'));
        final expectedLeft = details.noteExpanded
            ? card.left + 12
            : tester.getRect(toggle).right + 4;
        expect(date.left, closeTo(expectedLeft, .1),
            reason:
                'date is flush with padding or the real compact note target');
        expect(date.right, lessThanOrEqualTo(card.right));
        expect(find.byKey(const ValueKey('recording-tags')), findsOneWidget);
        expect(find.byType(RecordingKeypad), findsOneWidget);
        if (state == 'empty') {
          expect(find.text('暂无账户'), findsOneWidget);
          final add = find.byKey(const ValueKey('transfer-add-account'));
          await tester.ensureVisible(add);
          await tester.tap(add);
          await tester.pumpAndSettle();
          expect(find.byType(AccountEditPage), findsOneWidget);
          await tester.tap(find.byType(BackButton).last);
          await tester.pumpAndSettle();
          expect(find.byType(TransactionEditorPage), findsOneWidget);
          expect(find.text('暂无账户'), findsOneWidget);
        } else {
          expect(find.byType(BeeTransferAccountPair), findsOneWidget);
          if (state == 'selected') {
            expect(find.text('QA 人民币现金'), findsOneWidget);
            expect(find.text('QA 人民币银行'), findsOneWidget);
          } else {
            expect(find.text('选择账户'), findsWidgets);
          }
        }
        expect(await db.select(db.transactions).get(), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  inlineTransferTest('暂无账户可连续新增同币种账户并回到原转账草稿', (tester) async {
    await db.customStatement('DELETE FROM accounts');
    await open(tester,
        page: const TransactionEditorPage(
            initialKind: 'transfer', initialNote: 'QA 保留转账草稿'));
    for (final name in ['QA 新现金', 'QA 新银行']) {
      final add = find.byKey(const ValueKey('transfer-add-account'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(AccountEditPage), findsOneWidget);
      await tester.enterText(
          find.descendant(
              of: find.byKey(const ValueKey('account-name')),
              matching: find.byType(TextFormField)),
          name);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(BeeButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionEditorPage), findsOneWidget);
      expect(find.text('QA 保留转账草稿'), findsOneWidget);
    }
    expect(find.text('暂无账户'), findsNothing);
    expect(find.byKey(const ValueKey('transfer-add-account')), findsNothing);
    await select(tester, true, 'QA 新现金');
    await select(tester, false, 'QA 新银行');
    expect(
        tester
            .widget<AmountEditorSheet>(find.byType(AmountEditorSheet))
            .canSubmit,
        isTrue);
    expect(
        (await repo.getAllAccounts()).map((a) => a.name), ['QA 新现金', 'QA 新银行']);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final foreign in [false, true]) {
    inlineTransferTest(
        '主记账${foreign ? 'CNY账本 USD→USD' : 'CNY→CNY'}同屏选择、原币余额和统计',
        (tester) async {
      await open(tester);
      expect(find.byType(RecordingKeypad), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await typeTen(tester);
      await tester.enterText(
          find.byKey(const ValueKey('recording-note')), 'QA 同屏草稿');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await select(tester, true, foreign ? 'QA 美元现金' : 'QA 人民币现金');
      await tester.tap(pairRow(false));
      await tester.pumpAndSettle();
      final picker =
          tester.widget<BeeAccountPicker>(find.byType(BeeAccountPicker));
      expect(
          picker.accounts.every(
              (account) => account.currency == (foreign ? 'USD' : 'CNY')),
          isTrue);
      expect(picker.accounts.map((account) => account.name),
          isNot(contains(foreign ? 'QA 人民币银行' : 'QA 美元银行')));
      expect(picker.accounts.map((account) => account.name),
          isNot(contains('QA 隐藏美元')));
      await tester.tap(find.text(foreign ? 'QA 美元银行' : 'QA 人民币银行').last);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('QA 同屏草稿'), findsOneWidget);
      expect(find.text(foreign ? 'USD' : 'CNY'), findsOneWidget);
      if (foreign) expect(find.text('≈ ¥72.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recording-save')));
      await tester.pumpAndSettle();
      final tx = (await db.select(db.transactions).get()).single;
      expect(tx.type, 'transfer');
      expect(tx.amount, 10);
      expect(tx.nativeAmount, foreign ? 72 : 10);
      expect(tx.currencyCode, foreign ? 'USD' : 'CNY');
      expect(tx.note, 'QA 同屏草稿');
      expect(tx.accountId, foreign ? usdFrom : cnyFrom);
      expect(tx.toAccountId, foreign ? usdTo : cnyTo);
      expect(await repo.getAccountBalance(foreign ? usdFrom : cnyFrom),
          foreign ? 90 : 990);
      expect(await repo.getAccountBalance(foreign ? usdTo : cnyTo),
          foreign ? 15 : 60);
      final totals =
          await repo.yearlyTotals(ledgerId: 1, year: tx.happenedAt.year);
      expect(totals, (0.0, 0.0));
      expect(
          await repo.getAccountCategoryStats(foreign ? usdFrom : cnyFrom,
              type: 'expense'),
          isEmpty);
      expect(find.text('打开主记账'), findsOneWidget);
      expect(rates.calls, 0);
      expect(tester.takeException(), isNull);
    });
  }
  inlineTransferTest('更换账户币种只清旧汇率，保留金额备注标签日期草稿', (tester) async {
    final date = DateTime(2026, 8, 14, 9, 30);
    await open(tester,
        page: TransactionEditorPage(
            initialKind: 'transfer',
            initialAccountId: cnyFrom,
            initialToAccountId: cnyTo,
            initialAmount: 10,
            initialNote: 'QA 保留字段',
            initialDate: date,
            initialTagIds: [tag],
            initialCurrencyCode: 'CNY',
            initialNativeAmount: 10));
    await select(tester, true, 'QA 美元现金');
    expect(
        tester
            .widget<AmountEditorSheet>(find.byType(AmountEditorSheet))
            .canSubmit,
        isFalse);
    expect(find.text('QA 保留字段'), findsOneWidget);
    expect(find.text('≈ ¥72.00'), findsOneWidget);
    await select(tester, false, 'QA 美元银行');
    await tester.tap(find.byKey(const ValueKey('recording-save')));
    await tester.pumpAndSettle();
    final tx = (await db.select(db.transactions).get()).single;
    expect(tx.amount, 10);
    expect(tx.currencyCode, 'USD');
    expect(tx.nativeAmount, 72);
    expect(tx.note, 'QA 保留字段');
    expect(tx.happenedAt, date);
    expect((await repo.getTagsForTransaction(tx.id)).single.id, tag);
    expect(tester.takeException(), isNull);
  });
  inlineTransferTest('同账户与不同币种预填不能保存', (tester) async {
    for (final target in [cnyFrom, usdTo]) {
      await open(tester,
          page: TransactionEditorPage(
              initialKind: 'transfer',
              initialAccountId: cnyFrom,
              initialToAccountId: target,
              initialAmount: 10));
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('recording-save')))
              .onPressed,
          isNull);
      expect(await db.select(db.transactions).get(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    }
  });
  inlineTransferTest('缺失汇率和非法汇率阻止保存，可用本笔合法汇率继续', (tester) async {
    await open(tester,
        page: TransactionEditorPage(
            initialKind: 'transfer',
            initialAccountId: usdFrom,
            initialToAccountId: usdTo,
            initialAmount: 10,
            initialCurrencyCode: 'USD',
            initialNativeAmount: 0));
    await tester.tap(find.byKey(const ValueKey('recording-save')));
    await tester.pumpAndSettle();
    expect(await db.select(db.transactions).get(), isEmpty);
    await tester.tap(find.byKey(const ValueKey('recording-conversion')));
    await tester.pumpAndSettle();
    final field = find.descendant(
        of: find.byType(BeeDialog), matching: find.byType(TextField));
    for (final invalid in ['0', '-1', 'NaN', 'Infinity']) {
      await tester.enterText(field, invalid);
      await tester.pump();
      expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '确定'))
              .onPressed,
          isNull);
      expect(await db.select(db.transactions).get(), isEmpty);
    }
    await tester.enterText(field, '7.3');
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recording-save')));
    await tester.pumpAndSettle();
    final tx = (await db.select(db.transactions).get()).single;
    expect(tx.nativeAmount, 73);
    expect(tx.amount, 10);
    expect(tx.currencyCode, 'USD');
    expect(rates.calls, 0);
  });
  inlineTransferTest('真正缺失自动汇率仅调用替代源，失败后绝不把原币写成本位币', (tester) async {
    await db.customStatement('DELETE FROM exchange_rates');
    await open(tester,
        page: TransactionEditorPage(
            initialKind: 'transfer',
            initialAccountId: usdFrom,
            initialToAccountId: usdTo,
            initialAmount: 10));
    await tester.tap(find.byKey(const ValueKey('recording-save')));
    await tester.pumpAndSettle();
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(rates.calls, 1);
    expect(find.textContaining('请手动填写本笔汇率后保存'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  for (final copy in [false, true]) {
    inlineTransferTest('${copy ? '复制同币种' : '历史跨币种隐藏账户编辑'}保留字段、标签和旧快照',
        (tester) async {
      await db.customStatement(
          'UPDATE accounts SET hidden=1 WHERE id=?', [usdFrom]);
      final originalId = await repo.addTransaction(
          ledgerId: 1,
          type: 'transfer',
          amount: 12,
          accountId: usdFrom,
          toAccountId: copy ? usdTo : cnyTo,
          happenedAt: DateTime(2025, 1, 2),
          note: 'QA 历史备注',
          currencyCode: 'USD',
          nativeAmount: 86.4000000000123,
          excludeFromStats: true,
          excludeFromBudget: true);
      await repo
          .updateTransactionTags(transactionId: originalId, tagIds: [tag]);
      final source = (await repo.getTransactionById(originalId))!;
      final now = DateTime(2026, 10, 25, 9);
      final page = copy
          ? TransactionEditorPage.copy(source: source, tagIds: [tag], now: now)
          : TransactionEditorPage(
              initialKind: 'transfer',
              editingTransactionId: originalId,
              initialAccountId: source.accountId,
              initialToAccountId: source.toAccountId,
              initialAmount: source.amount,
              initialNote: source.note,
              initialDate: source.happenedAt,
              initialTagIds: [tag],
              initialCurrencyCode: source.currencyCode,
              initialNativeAmount: source.nativeAmount,
              initialExcludeFromStats: source.excludeFromStats,
              initialExcludeFromBudget: source.excludeFromBudget);
      await open(tester, page: page);
      expect(find.text('USD'), findsOneWidget);
      expect(find.text('≈ ¥86.40'), findsOneWidget);
      expect(find.textContaining('已隐藏'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('recording-note')), 'QA 新备注');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recording-save')));
      await tester.pumpAndSettle();
      final rows = await db.select(db.transactions).get();
      expect(rows, hasLength(copy ? 2 : 1));
      final saved =
          copy ? rows.firstWhere((tx) => tx.id != originalId) : rows.single;
      expect(saved.accountId, usdFrom);
      expect(saved.toAccountId, source.toAccountId);
      expect(saved.currencyCode, 'USD');
      expect(saved.nativeAmount, closeTo(source.nativeAmount!, 1e-10));
      expect(saved.amount, source.amount);
      expect(saved.note, 'QA 新备注');
      expect(saved.happenedAt, copy ? now : source.happenedAt);
      expect(saved.excludeFromStats, isTrue);
      expect(saved.excludeFromBudget, isTrue);
      expect((await repo.getTagsForTransaction(saved.id)).single.id, tag);
      if (copy) expect(await repo.getTransactionById(originalId), source);
      expect(tester.takeException(), isNull);
    });
  }
  inlineTransferTest('取消账户选择、放弃草稿的取消与确认不写数据库', (tester) async {
    await open(tester,
        page: TransactionEditorPage(
            initialKind: 'transfer',
            initialAccountId: cnyFrom,
            initialToAccountId: cnyTo,
            initialAmount: 10));
    await tester.enterText(
        find.byKey(const ValueKey('recording-note')), 'QA 未保存');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(pairRow(true));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(BeeAccountPicker))).pop();
    await tester.pumpAndSettle();
    expect(find.text('QA 未保存'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionEditorPage), findsOneWidget);
    expect(find.text('QA 未保存'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('打开主记账'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(tester.takeException(), isNull);
  });
  inlineTransferTest('保存过程禁用主记账和重复点击，只创建一笔', (tester) async {
    final blocked = BlockingTransferRepository(db);
    repo = blocked;
    await open(tester,
        page: TransactionEditorPage(
            initialKind: 'transfer',
            initialAccountId: usdFrom,
            initialToAccountId: usdTo,
            initialAmount: 10,
            initialTagIds: [tag]));
    final save = find.byKey(const ValueKey('recording-save'));
    await tester.tap(save);
    await tester.pump();
    for (var i = 0; i < 20 && !blocked.started.isCompleted; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(blocked.started.isCompleted, isTrue);
    expect((await db.select(db.transactions).get()), hasLength(1));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.tap(save, warnIfMissed: false);
    await tester.pump();
    expect((await db.select(db.transactions).get()), hasLength(1));
    blocked.release.complete();
    await tester.pumpAndSettle();
    expect((await db.select(db.transactions).get()), hasLength(1));
    expect(find.text('打开主记账'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(398, 844), const Size(320, 568)]) {
    inlineTransferTest('主记账转账深色1.4字键盘贴底与8px独立区域 $size', (tester) async {
      addTearDown(tester.view.resetViewInsets);
      await open(tester,
          page: TransactionEditorPage(
              initialKind: 'transfer',
              initialAccountId: usdFrom,
              initialToAccountId: usdTo,
              initialAmount: 10),
          size: size,
          scale: 1.4,
          brightness: Brightness.dark);
      final content = find.byKey(const ValueKey('recording-content'));
      final amount = find.byType(RecordingAmountCard);
      final details = find.byType(RecordingDetailsCard);
      expect(tester.getRect(content).top - tester.getRect(amount).bottom,
          closeTo(8, .1));
      expect(tester.getRect(details).top - tester.getRect(content).bottom,
          closeTo(8, .1));
      expect(
          tester.getRect(find.byKey(const ValueKey('recording-dock'))).bottom,
          closeTo(size.height, .1));
      final compact = find.byKey(const ValueKey('recording-note-compact'));
      if (compact.evaluate().isNotEmpty) {
        await tester.tap(compact);
        await tester.pumpAndSettle();
      }
      await tester.enterText(
          find.byKey(const ValueKey('recording-note')), 'QA 原位备注');
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      expect(find.byType(RecordingKeypad), findsNothing);
      expect(
          tester.getRect(find.byKey(const ValueKey('recording-save'))).bottom,
          lessThanOrEqualTo(size.height - 250));
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('QA 原位备注'), findsOneWidget);
      expect(find.byType(RecordingKeypad), findsOneWidget);
    });
  }
  inlineTransferTest('最终写入守卫拒绝同账户、跨币种和非法金额快照', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: Consumer(builder: (context, value, _) {
          ref = value;
          return const SizedBox();
        })));
    await tester.pump();
    AmountEditorResult draft(
            {double amount = 10,
            double? native = 10,
            String currency = 'CNY'}) =>
        (
          amount: amount,
          continueAdding: false,
          note: null,
          date: DateTime(2026, 10, 25),
          accountId: null,
          tagIds: [],
          pendingAttachments: [],
          excludeFromStats: false,
          excludeFromBudget: false,
          currencyCode: currency,
          nativeAmount: native
        );
    for (final bad in [
      (to: cnyFrom, result: draft()),
      (to: usdTo, result: draft()),
      (to: cnyTo, result: draft(currency: 'USD')),
      (to: cnyTo, result: draft(amount: double.nan)),
      (to: cnyTo, result: draft(native: null)),
      (to: cnyTo, result: draft(native: double.infinity)),
      (to: cnyTo, result: draft(native: 0)),
      (to: cnyTo, result: draft(native: 11))
    ]) {
      await expectLater(
          persistTransferDraft(ref,
              ledgerId: 1,
              fromAccountId: cnyFrom,
              toAccountId: bad.to,
              result: bad.result,
              editingId: null,
              onCreated: (_) => fail('Invalid transfer must not create')),
          throwsStateError);
      expect(await db.select(db.transactions).get(), isEmpty);
    }
  });
}
