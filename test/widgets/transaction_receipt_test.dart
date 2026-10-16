import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widgets/biz/transaction_receipt_dialog.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/widgets/biz/transaction_list.dart';
import 'package:beecount/widgets/biz/transaction_list_item.dart';
import 'package:beecount/widgets/posters/transaction_receipt.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late TransactionReceiptData data;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    final ledger = await repo.createLedger(name: 'Private ledger');
    final account =
        await repo.createAccount(ledgerId: ledger, name: 'Private account');
    final to = await repo.createAccount(ledgerId: ledger, name: 'Destination');
    final category = await repo.createCategory(name: 'Lunch', kind: 'expense');
    final tag = await repo.createTag(name: 'Friends');
    final id = await repo.addTransaction(
        ledgerId: ledger,
        type: 'expense',
        amount: 1234.56,
        categoryId: category,
        accountId: account,
        happenedAt: DateTime(2026, 10, 16, 12, 30),
        note: 'A little treat',
        currencyCode: 'USD',
        nativeAmount: 8888);
    data = TransactionReceiptData(
        transaction: (await repo.getTransactionById(id))!,
        ledger: (await repo.getLedgerById(ledger))!,
        category: await repo.getCategoryById(category),
        account: await repo.getAccount(account),
        toAccount: await repo.getAccount(to),
        tags: [(await repo.getTagById(tag))!]);
  });
  tearDown(() => db.close());

  Widget host(Widget child, {String locale = 'en'}) => ProviderScope(
          child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ));

  testWidgets(
      'preview hides account and ledger by default and toggles fields without writes',
      (tester) async {
    await tester.pumpWidget(host(TransactionReceiptDialog(data: data)));
    await tester.pumpAndSettle();
    final receipt = find.byType(TransactionReceipt);
    Finder receiptText(String text) =>
        find.descendant(of: receipt, matching: find.text(text));
    expect(receiptText('Private account'), findsNothing);
    expect(receiptText('Private ledger'), findsNothing);
    expect(receiptText('A little treat'), findsOneWidget);
    expect(receiptText('#Friends'), findsOneWidget);
    expect(receiptText('−1,234.56'), findsOneWidget);
    expect(receiptText('USD'), findsOneWidget);
    expect(receiptText('8,888.00'), findsNothing);
    for (final option in ['note', 'tags', 'account', 'ledger']) {
      final chip = find.byKey(ValueKey('receipt-option-$option'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    expect(receiptText('A little treat'), findsNothing);
    expect(receiptText('#Friends'), findsNothing);
    expect(receiptText('Private account'), findsOneWidget);
    expect(receiptText('Private ledger'), findsOneWidget);
    expect(
        await repo.getTransactionById(data.transaction.id), data.transaction);
    expect((await db.select(db.transactions).get()).length, 1);
  });

  testWidgets(
      'long press loads current data, cancellation and repeat opening remain read-only',
      (tester) async {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: TransactionList(hideAmounts: false, transactions: [
            (
              t: data.transaction,
              category: data.category,
              account: data.account,
              toAccount: null
            ),
          ])),
        )));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester
          .longPress(find.byType(TransactionListItem, skipOffstage: false));
      await tester.pumpAndSettle();
      expect(find.text('复制为新交易'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('生成小票'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      for (var attempt = 0;
          attempt < 20 &&
              find.byType(TransactionReceiptDialog).evaluate().isEmpty;
          attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      await tester.pumpAndSettle();
      expect(find.byType(TransactionReceiptDialog), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(TransactionList), findsOneWidget,
          reason: 'The existing list stays visible beneath the modal preview');
      Navigator.of(tester.element(find.byType(TransactionReceiptDialog))).pop();
      await tester.pumpAndSettle();
    }
    expect(
        await repo.getTransactionById(data.transaction.id), data.transaction);
    expect((await db.select(db.transactions).get()).length, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
      'JPY income uses original precision; transfers show both accounts and no sign',
      (tester) async {
    for (final kind in ['income', 'transfer']) {
      final receipt = TransactionReceiptData(
        transaction: data.transaction.copyWith(
            type: kind, amount: 1200, currencyCode: const Value('JPY')),
        ledger: data.ledger,
        account: data.account,
        toAccount: data.toAccount,
      );
      await tester.pumpWidget(host(
          Scaffold(
              body: SingleChildScrollView(
                  child: Center(
                      child: SizedBox(
                          width: 300,
                          child: TransactionReceipt(
                              data: receipt, showAccount: true))))),
          locale: 'zh'));
      await tester.pumpAndSettle();
      expect(find.text(kind == 'income' ? '+1,200' : '1,200'), findsOneWidget);
      expect(find.text('JPY'), findsOneWidget);
      expect(find.text('Private account'), findsOneWidget);
      expect(find.text('Destination'),
          kind == 'transfer' ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'narrow English preview supports long Unicode notes and large amounts',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final receipt = TransactionReceiptData(
      transaction: data.transaction.copyWith(
          amount: 1234567890.12,
          note: Value(List.filled(50, '晚餐 🍜 A thoughtful meal.').join('\n'))),
      ledger: data.ledger,
    );
    await tester.pumpWidget(host(TransactionReceiptDialog(data: receipt)));
    await tester.pumpAndSettle();
    expect(find.text('−1,234,567,890.12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save exports a real PNG from the scaled modal receipt',
      (tester) async {
    Uint8List? png;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('gal'),
        (call) async {
      if (call.method == 'requestAccess') return true;
      if (call.method == 'putImageBytes') {
        png = (call.arguments as Map)['bytes'] as Uint8List;
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(const MethodChannel('gal'), null));
    await tester.pumpWidget(host(TransactionReceiptDialog(data: data)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('receipt-save')));
    await tester.pump();
    for (var i = 0; i < 30 && png == null; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(png, isNotNull,
        reason: 'Capture must complete before invoking the gallery adapter');
    expect(png!.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    final header = ByteData.sublistView(png!);
    expect(header.getUint32(16), 960);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
