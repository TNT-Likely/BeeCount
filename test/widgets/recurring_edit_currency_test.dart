/// 周期账单编辑页的币种交互(issue #444):
///   - 币种字段默认 = 账本本位币;编辑外币模板时回显模板币种
///   - 账户候选按**模板有效币种**过滤(此前硬按账本本位币过滤 → 外币账户选不到)
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/transaction/recurring_transaction_edit_page.dart';
import 'package:beecount/providers/database_providers.dart';

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

  /// 直接建账户行 —— 不走 repo.createAccount,避开它内部 logger 的 2s 落盘
  /// 定时器(widget test 结束时会因 pending timer 失败)。
  Future<void> seedAccount(String name, String currency) async {
    await db.customStatement(
        "INSERT INTO accounts (ledger_id, name, type, currency) "
        "VALUES (1, '$name', 'cash', '$currency')");
  }

  /// 造一条模板(直接建表行,拿回实体喂给编辑页)。
  Future<RecurringTransaction> seedTemplate({String? currencyCode}) async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    final id = await repo.addRecurringTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 100,
      frequency: 'monthly',
      interval: 1,
      startDate: DateTime(2026, 8, 1),
      currencyCode: currencyCode,
    );
    final all = await repo.getAllRecurringTransactions();
    return all.firstWhere((r) => r.id == id);
  }

  Widget host(RecurringTransaction recurring) {
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
        home: RecurringTransactionEditPage(recurring: recurring),
      ),
    );
  }

  testWidgets('模板未设币种 → 币种字段显示账本本位币', (tester) async {
    final recurring = await seedTemplate();
    await tester.pumpWidget(host(recurring));
    await tester.pumpAndSettle();

    expect(find.text('人民币 (CNY)'), findsOneWidget);
  });

  testWidgets('外币模板 → 币种字段回显模板币种', (tester) async {
    final recurring = await seedTemplate(currencyCode: 'JPY');
    await tester.pumpWidget(host(recurring));
    await tester.pumpAndSettle();

    expect(find.text('日元 (JPY)'), findsOneWidget);
    expect(find.text('人民币 (CNY)'), findsNothing);
  });

  testWidgets('外币模板的账户候选 = 同币种账户,本位币账户不出现(#444 核心修复)',
      (tester) async {
    final recurring = await seedTemplate(currencyCode: 'JPY');
    await seedAccount('工资卡', 'CNY');
    await seedAccount('日本旅行卡', 'JPY');

    await tester.pumpWidget(host(recurring));
    await tester.pumpAndSettle();

    // 点开账户选择弹窗(点 label 文字命中不到装饰层,取其外层 InkWell)
    await tester.tap(find
        .ancestor(of: find.text('选择账户'), matching: find.byType(InkWell))
        .first);
    await tester.pumpAndSettle();

    expect(find.text('日本旅行卡'), findsOneWidget);
    expect(find.text('工资卡'), findsNothing,
        reason: '外币模板不该再被硬过滤成本位币账户列表');
  });

  testWidgets('本位币模板的账户候选 = 本位币账户(旧行为不回归)', (tester) async {
    final recurring = await seedTemplate();
    await seedAccount('工资卡', 'CNY');
    await seedAccount('日本旅行卡', 'JPY');

    await tester.pumpWidget(host(recurring));
    await tester.pumpAndSettle();

    await tester.tap(find
        .ancestor(of: find.text('选择账户'), matching: find.byType(InkWell))
        .first);
    await tester.pumpAndSettle();

    expect(find.text('工资卡'), findsOneWidget);
    expect(find.text('日本旅行卡'), findsNothing);
  });
}
