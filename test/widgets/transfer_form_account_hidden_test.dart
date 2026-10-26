// 账户隐藏(#240)E1 钉住 —— 转账表单编辑态(.docs/account-archive/01-product-design.md
// §五 边界表第 5 行 + §4.2):
//   - 编辑历史转账(有 editingTransactionId)时,若转出/转入账户当前已被隐藏,
//     选择器补回该账户候选并打「已隐藏」灰标,让用户能原样保存
//   - 新建转账(无 editingTransactionId)不钉住,隐藏账户不出现
import 'package:drift/native.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/widgets/transaction/transfer_form.dart';

void hiddenTransferTest(String name, Future<void> Function(WidgetTester) body) {
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
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement("INSERT INTO accounts "
        "(id, ledger_id, name, currency, hidden) VALUES (1, 1, '现金', 'CNY', 0)");
    await db.customStatement("INSERT INTO accounts "
        "(id, ledger_id, name, currency, hidden) VALUES (2, 1, '旧钱包', 'CNY', 1)");
  });

  tearDown(() async => db.close());

  Ledger cnyLedger() => Ledger(
        id: 1,
        name: 'L',
        currency: 'CNY',
        type: 'personal',
        createdAt: DateTime(2026, 1, 1),
        myRole: 'owner',
        memberCount: 1,
        isShared: false,
        monthStartDay: 1,
      );

  Widget host({
    int? editingTransactionId,
    int? initialFromAccountId,
    int? initialToAccountId,
  }) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerProvider
            .overrideWith((ref) => Stream<Ledger?>.value(cnyLedger())),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: TransferForm(
            onTransferComplete: () {},
            editingTransactionId: editingTransactionId,
            initialFromAccountId: initialFromAccountId,
            initialToAccountId: initialToAccountId,
          ),
        ),
      ),
    );
  }

  for (final from in [true, false]) {
    hiddenTransferTest('历史转账${from ? '转出' : '转入'}隐藏账户保持选中、灰标与候选',
        (tester) async {
      await tester.pumpWidget(host(
        editingTransactionId: 999,
        initialFromAccountId: from ? 2 : null,
        initialToAccountId: from ? null : 2,
      ));
      await tester.pumpAndSettle();
      final pair = find.byType(BeeTransferAccountPair);
      expect(find.text('旧钱包'), findsOneWidget);
      expect(find.text('${from ? '转出账户' : '转入账户'} · 已隐藏'), findsOneWidget);
      final rows = find.descendant(of: pair, matching: find.byType(BeeMenuRow));
      await tester.tap(from ? rows.first : rows.last);
      await tester.pumpAndSettle();
      expect(find.byType(BeeAccountPicker), findsOneWidget);
      expect(find.text('CNY · 已隐藏'), findsOneWidget);
      expect(find.text('现金'), findsOneWidget);
      await tester.tap(find.text('现金'));
      await tester.pumpAndSettle();
      expect(find.byType(BeeAccountPicker), findsNothing);
      expect(find.text('现金'), findsOneWidget);
      expect(find.text('旧钱包'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  hiddenTransferTest('新建转账选择器不列出隐藏账户，也不能选择同一个转入账户', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    final rows = find.descendant(
        of: find.byType(BeeTransferAccountPair),
        matching: find.byType(BeeMenuRow));
    await tester.tap(rows.first);
    await tester.pumpAndSettle();
    expect(find.text('旧钱包'), findsNothing);
    expect(find.text('CNY · 已隐藏'), findsNothing);
    expect(find.text('现金'), findsOneWidget);
    await tester.tap(find.text('现金'));
    await tester.pumpAndSettle();
    await tester.tap(rows.last);
    await tester.pumpAndSettle();
    expect(find.byType(BeeAccountPicker), findsOneWidget);
    final picker =
        tester.widget<BeeAccountPicker>(find.byType(BeeAccountPicker));
    expect(picker.accounts, isEmpty);
    expect(find.text('旧钱包'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
