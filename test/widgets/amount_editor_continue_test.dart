/// 再记一笔(连续记账)交互:
///   - 键盘键位于完成按钮上方;新建收支/转账均可切换,编辑模式置灰不可点
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

  testWidgets('再记一笔键:新建收支/转账可切换,编辑模式置灰不可点', (tester) async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('再记一笔'), findsOneWidget);

    // 转账同样支持再记一笔
    await tester.pumpWidget(host(transactionKind: 'transfer'));
    await tester.pumpAndSettle();
    expect(find.text('再记一笔'), findsOneWidget);

    // 编辑模式:键仍显示但置灰(非白字),点击无效果
    await tester.pumpWidget(host(editingTransactionId: 5));
    await tester.pumpAndSettle();
    expect(find.text('再记一笔'), findsOneWidget);
    await tester.tap(find.text('再记一笔'));
    await tester.pump();
    final disabledKey = tester.widget<Text>(find.text('再记一笔'));
    expect(disabledKey.style?.color, isNot(Colors.white));
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

    // 点击键盘上的再记一笔键(激活态:主色背景 + 白字)
    await tester.tap(find.text('再记一笔'));
    await tester.pump();
    final activeKey = tester.widget<Text>(find.text('再记一笔'));
    expect(activeKey.style?.color, Colors.white);

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
    // 键盘 3 键 + 金额显示区各一个
    expect(find.text('3'), findsNWidgets(2));
  });

  testWidgets('再记一笔:转账模式勾选同样生效', (tester) async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");

    AmountEditorResult? submitted;
    await tester.pumpWidget(
        host(transactionKind: 'transfer', onSubmit: (r) => submitted = r));
    await tester.pumpAndSettle();

    // 输入金额 10
    for (final k in ['1', '0']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }

    // 勾选再记一笔并提交
    await tester.tap(find.text('再记一笔'));
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted!.continueEntry, isTrue);
    expect(submitted!.amount, 10);
  });
}
