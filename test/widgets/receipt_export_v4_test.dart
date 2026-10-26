import 'dart:io';
import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widgets/biz/transaction_receipt_dialog.dart';
import 'package:beecount/widgets/posters/transaction_receipt.dart';
import 'package:beecount_business_ui/annual_report.dart';
import 'package:beecount_ui/multi_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child));
TransactionReceiptData fixture() => TransactionReceiptData(
    transaction: Transaction(
        id: 1,
        ledgerId: 1,
        type: 'expense',
        amount: 12.5,
        currencyCode: 'USD',
        happenedAt: DateTime(2026, 10, 20),
        excludeFromStats: false,
        excludeFromBudget: false),
    ledger: Ledger(
        id: 1,
        name: 'QA ledger',
        currency: 'TWD',
        type: 'personal',
        createdAt: DateTime(2026),
        myRole: 'owner',
        memberCount: 1,
        isShared: false,
        monthStartDay: 1));
Future<void> finishExport(
    WidgetTester tester, bool Function() completed) async {
  await tester.pump();
  for (var i = 0; i < 60 && !completed(); i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('multi select emits immutable sets and obeys disabled state',
      (tester) async {
    final selected = {'note'};
    Set<String>? change;
    Widget select(bool enabled) => host(BeeMultiSelect<String>(
        selectedValues: selected,
        options: const [
          BeeMultiSelectOption(value: 'note', label: 'Note'),
          BeeMultiSelectOption(value: 'ledger', label: 'Ledger')
        ],
        onChanged: enabled ? (value) => change = value : null));
    await tester.pumpWidget(select(true));
    await tester.tap(find.text('Ledger'));
    expect(selected, {'note'});
    expect(change, {'note', 'ledger'});
    expect(() => change!.add('account'), throwsUnsupportedError);
    change = null;
    await tester.pumpWidget(select(false));
    await tester.tap(find.text('Ledger'));
    expect(change, isNull);
  });
  for (final code in ['ACCESS_DENIED', 'UNEXPECTED']) {
    testWidgets('receipt gallery $code reports error and enables retry',
        (tester) async {
      var attempts = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('gal'),
          (call) async {
        if (call.method == 'requestAccess') return true;
        if (call.method == 'putImageBytes') {
          attempts++;
          throw PlatformException(code: code);
        }
        return null;
      });
      addTearDown(() =>
          messenger.setMockMethodCallHandler(const MethodChannel('gal'), null));
      await tester.pumpWidget(host(TransactionReceiptDialog(data: fixture())));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('receipt-save')));
      await finishExport(tester, () => attempts == 1);
      final context = tester.element(find.byType(TransactionReceiptDialog));
      final l = AppLocalizations.of(context);
      expect(attempts, 1);
      expect(
          find.text(code == 'ACCESS_DENIED'
              ? l.sharePosterPermissionDenied
              : l.sharePosterSaveFailed),
          findsOneWidget);
      expect(
          tester
              .widget<BeeReceiptComposer>(find.byType(BeeReceiptComposer))
              .busy,
          isFalse);
      expect(find.byType(TransactionReceiptDialog), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
  }
  for (final fail in [false, true]) {
    testWidgets(
        'receipt mocked share ${fail ? 'error' : 'cancellation'} restores controls without sending',
        (tester) async {
      final tmp = Directory.systemTemp.createTempSync('beecount-ar89-test-');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => tmp.path);
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
        calls.add(call);
        if (fail) throw PlatformException(code: 'QA_SHARE_FAILED');
        return 'dev.fluttercommunity.plus/share/dismissed';
      });
      addTearDown(() async {
        messenger.setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
        messenger.setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'), null);
        if (tmp.existsSync()) await tmp.delete(recursive: true);
      });
      await tester.pumpWidget(host(TransactionReceiptDialog(data: fixture())));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('receipt-share')));
      await finishExport(tester, () => calls.isNotEmpty);
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls, hasLength(1));
      expect(calls.single.method, 'share');
      final args = calls.single.arguments as Map;
      expect(args['mimeTypes'], ['image/png']);
      expect(args['originWidth'], greaterThan(0));
      expect(args['originHeight'], greaterThan(0));
      expect(
          tester
              .widget<BeeReceiptComposer>(find.byType(BeeReceiptComposer))
              .busy,
          isFalse);
      expect(find.byType(TransactionReceiptDialog), findsOneWidget);
      if (fail) {
        final l = AppLocalizations.of(
            tester.element(find.byType(TransactionReceiptDialog)));
        expect(find.text(l.transactionReceiptShareFailed), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
