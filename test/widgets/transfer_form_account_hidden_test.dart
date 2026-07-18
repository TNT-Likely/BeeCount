/// 账户隐藏(#240)E1 钉住 —— 转账表单编辑态(.docs/account-archive/01-product-design.md
/// §五 边界表第 5 行 + §4.2):
///   - 编辑历史转账(有 editingTransactionId)时,若转出/转入账户当前已被隐藏,
///     选择器补回该账户候选并打「已隐藏」灰标,让用户能原样保存
///   - 新建转账(无 editingTransactionId)不钉住,隐藏账户不出现
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/widgets/transaction/transfer_form.dart';

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

  testWidgets('编辑历史转账:转出账户已隐藏 → 钉住显示 + 已隐藏灰标', (tester) async {
    // 只传 initialFromAccountId(不传 to),避免两个账户都非空触发自动打开
    // 金额弹窗(那条路径依赖 transferCategoryProvider 等更多基础设施,不是本
    // 用例要验证的东西)。
    await tester.pumpWidget(host(
      editingTransactionId: 999,
      initialFromAccountId: 2, // 已隐藏账户
    ));
    await tester.pumpAndSettle();

    // 旧钱包(id=2)被钉住为初始转出账户 → 转入网格按 `id != fromAccountId`
    // 排除它,只会出现在转出网格里,合计 1 处;打了「已隐藏」灰标。
    expect(find.text('旧钱包'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    // 现金(id=1)未被排除,转出/转入两个网格都会出现,合计 2 处。
    expect(find.text('现金'), findsNWidgets(2));
  });

  testWidgets('新建转账:隐藏账户不出现,也没有已隐藏灰标', (tester) async {
    await tester.pumpWidget(host()); // 无 editingTransactionId → 不钉住

    await tester.pumpAndSettle();

    expect(find.text('旧钱包'), findsNothing);
    expect(find.byIcon(Icons.visibility_off), findsNothing);
    // 未选转出账户时,转入网格 = 转出网格(都是全量候选),现金两处都会出现。
    expect(find.text('现金'), findsNWidgets(2));
  });
}
