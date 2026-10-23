import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/transaction/transfer_form.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      {int? editingId, double? nativeAmount}) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
          beecountCloudProviderInstance.overrideWith((ref) async => null),
          currentLedgerProvider.overrideWith((ref) => repo.watchLedger(1)),
          syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
        ],
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: TransferForm(
                    initialFromAccountId: fromId,
                    initialToAccountId: toId,
                    editingTransactionId: editingId,
                    initialAmount: 12,
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
}
