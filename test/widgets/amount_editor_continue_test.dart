/// 再记一笔(连续记账)交互:
///   - 开关仅新建收支显示,转账 / 编辑模式不显示
///   - 勾选后提交:onSubmit 带 continueEntry=true,表单清空可继续录入
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/widgets/biz/amount_editor_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
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
    String transactionKind = 'expense',
    ValueChanged<AmountEditorResult>? onSubmit,
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
          body: AmountEditorSheet(
            categoryName: '餐饮',
            initialDate: DateTime(2026, 7, 12),
            ledgerId: 1,
            editingTransactionId: editingTransactionId,
            transactionKind: transactionKind,
            onSubmit: onSubmit ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('再记一笔开关:新建收支显示,转账/编辑模式不显示', (tester) async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('再记一笔'), findsOneWidget);

    await tester.pumpWidget(host(transactionKind: 'transfer'));
    await tester.pumpAndSettle();
    expect(find.text('再记一笔'), findsNothing);

    await tester.pumpWidget(host(editingTransactionId: 5));
    await tester.pumpAndSettle();
    expect(find.text('再记一笔'), findsNothing);
  });

  testWidgets('再记一笔:勾选后提交 continueEntry=true,表单清空可继续录入',
      (tester) async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");

    AmountEditorResult? submitted;
    await tester.pumpWidget(host(onSubmit: (r) => submitted = r));
    await tester.pumpAndSettle();

    // 输入金额 12.5
    for (final k in ['1', '2', '.', '5']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    expect(find.text('12.5'), findsOneWidget);

    // 勾选再记一笔
    await tester.tap(find.text('再记一笔'));
    await tester.pump();
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    // 提交
    await tester.tap(find.text('完成'));
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted!.continueEntry, isTrue);
    expect(submitted!.amount, 12.5);

    // 表单已清空:金额回到 0,可继续录入下一笔
    expect(find.text('0'), findsWidgets);
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
  });
}
