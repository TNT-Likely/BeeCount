import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart';
import 'package:beecount/widgets/transaction/transfer_form.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RetryTransferRepository extends LocalRepository {
  RetryTransferRepository(super.db);
  bool failNextTags = true;

  @override
  Future<void> updateTransactionTags(
      {required int transactionId, required List<int> tagIds}) async {
    if (failNextTags) {
      failNextTags = false;
      throw StateError('Synthetic transfer metadata failure');
    }
    return super
        .updateTransactionTags(transactionId: transactionId, tagIds: tagIds);
  }
}

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late int fromId, toId;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id,name,currency) VALUES(1,'日常生活','CNY')");
    fromId =
        await repo.createAccount(ledgerId: 1, name: '美元现金', currency: 'USD');
    toId =
        await repo.createAccount(ledgerId: 1, name: '美元银行卡', currency: 'USD');
    await repo.upsertAutoRates(
        base: 'CNY',
        rateDate: '2026-10-24',
        rates: {'USD': '7.1'},
        source: 'synthetic',
        fetchedAt: DateTime.now());
  });
  tearDown(() async => db.close());

  Future<void> open(WidgetTester tester,
      {int? editingId,
      double? nativeAmount,
      List<int>? tagIds,
      double textScale = 1,
      Brightness brightness = Brightness.light}) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
          beecountCloudProviderInstance.overrideWith((ref) async => null),
          currentLedgerProvider.overrideWith((ref) => repo.watchLedger(1)),
          syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
        ],
        child: MaterialApp(
            theme: beeTheme(brightness: brightness),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: TransferForm(
                    initialFromAccountId: fromId,
                    initialToAccountId: toId,
                    editingTransactionId: editingId,
                    initialAmount: 12,
                    initialTagIds: tagIds,
                    initialCurrencyCode: editingId == null ? null : 'USD',
                    initialNativeAmount: nativeAmount,
                    onTransferComplete: () {})))));
    await tester.pumpAndSettle();
  }

  for (final editing in [false, true]) {
    testWidgets('${editing ? '历史' : '新建'}美元转账保留账户币种与折算快照', (tester) async {
      tester.view.physicalSize = const Size(398, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final id = editing
          ? await repo.addTransaction(
              ledgerId: 1,
              type: 'transfer',
              happenedAt: DateTime(2026, 1, 1),
              amount: 12,
              accountId: fromId,
              toAccountId: toId,
              currencyCode: 'USD',
              nativeAmount: 86.4)
          : null;
      await open(tester, editingId: id, nativeAmount: editing ? 86.4 : null);
      expect(find.text('USD'), findsOneWidget);
      expect(find.textContaining('US\$', findRichText: true), findsOneWidget);
      expect(find.text(editing ? '≈ ¥86.40' : '≈ ¥85.20'), findsOneWidget);
      expect(find.bySemanticsLabel('更多选项'), findsNothing);
      expect(find.bySemanticsLabel('关闭'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recording-save')));
      await tester.pumpAndSettle();
      final records = await db.select(db.transactions).get();
      expect(records, hasLength(1));
      final row = records.single;
      expect(row.type, 'transfer');
      expect(row.currencyCode, 'USD');
      expect(row.amount, 12);
      expect(row.nativeAmount, closeTo(editing ? 86.4 : 85.2, .000001));
      expect(row.accountId, fromId);
      expect(row.toAccountId, toId);
      if (editing) expect(row.id, id);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('转账元信息失败保留弹层与草稿，重试沿用同一身份并保存标签', (tester) async {
    tester.view.physicalSize = const Size(398, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = RetryTransferRepository(db);
    final tagId = await repo.createTag(name: '旅行', color: '#219c9c');
    await open(tester, tagIds: [tagId]);
    await tester.enterText(
        find.byKey(const ValueKey('recording-note')), '转账保留草稿');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('recording-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recording-save')), findsOneWidget);
    expect(find.text('转账保留草稿'), findsOneWidget);
    final first = (await db.select(db.transactions).get()).single;
    expect(first.type, 'transfer');
    expect(await repo.getTagsForTransaction(first.id), isEmpty);
    await tester.tap(find.byKey(const ValueKey('recording-save')));
    await tester.pumpAndSettle();
    final saved = (await db.select(db.transactions).get()).single;
    expect(saved.id, first.id);
    expect(saved.accountId, fromId);
    expect(saved.toAccountId, toId);
    expect(saved.currencyCode, 'USD');
    expect(saved.nativeAmount, closeTo(85.2, .000001));
    expect(saved.note, '转账保留草稿');
    expect((await repo.getTagsForTransaction(saved.id)).single.id, tagId);
    expect(find.byKey(const ValueKey('recording-save')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  for (final size in [const Size(398, 900), const Size(320, 568)]) {
    testWidgets('转账弹层原位备注与系统键盘保持保存可达 $size 深色大字', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await open(tester, textScale: 1.4, brightness: Brightness.dark);
      final compact = find.byKey(const ValueKey('recording-note-compact'));
      if (compact.evaluate().isNotEmpty) {
        await tester.tap(compact);
        await tester.pumpAndSettle();
      }
      final note = find.byKey(const ValueKey('recording-note'));
      await tester.enterText(note, '原位备注');
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recording-key-7')), findsNothing);
      final save = find.byKey(const ValueKey('recording-save'));
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(size.height - 250));
      expect(tester.takeException(), isNull);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recording-key-7')), findsOneWidget);
      expect(find.text('原位备注'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('转账的共享标签写入拥有者引用，不把负数身份写入本地标签表', (tester) async {
    tester.view.physicalSize = const Size(398, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await db.customStatement(
        "UPDATE ledgers SET sync_id='transfer-ledger',is_shared=1,my_role='editor' WHERE id=1");
    await db.customStatement(
        "INSERT INTO shared_ledger_tags(ledger_sync_id,sync_id,name,color,updated_at) VALUES('transfer-ledger','transfer-owner-tag','共同旅行','#219c9c',1792713600)");
    await open(tester, tagIds: [syntheticIdForSyncId('transfer-owner-tag')]);
    await tester.tap(find.byKey(const ValueKey('recording-save')));
    await tester.pumpAndSettle();
    final tx = (await db.select(db.transactions).get()).single;
    expect(await db.select(db.transactionTags).get(), isEmpty);
    final override = (await db.select(db.transactionTagOverrides).get()).single;
    expect(override.transactionSyncId, tx.syncId);
    expect(override.tagSyncId, 'transfer-owner-tag');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
