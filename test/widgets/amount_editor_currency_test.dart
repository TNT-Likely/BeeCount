/// v30 记账录入的多币种交互(01 §四):
///   - 单币种态(无账户,未选币种):只有轻量币种标(=本位币),无汇率行
///   - 编辑外币交易:汇率行出现,初值=隐含汇率(nativeAmount/amount),
///     折算预览按隐含汇率(改备注不漂移)
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/currency_providers.dart';
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
    String? initialCurrencyCode,
    double? initialAmount,
    double? initialNativeAmount,
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
            initialAmount: initialAmount,
            initialCurrencyCode: initialCurrencyCode,
            initialNativeAmount: initialNativeAmount,
            ledgerId: 1,
            onSubmit: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('单币种态:无账户显示本位币小字标,无汇率行(零打扰)', (tester) async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('CNY'), findsOneWidget); // 轻量币种标
    expect(find.textContaining('1 CNY ='), findsNothing); // 无汇率行
    expect(find.textContaining('≈'), findsNothing); // 无折算预览
  });

  testWidgets('编辑外币交易:汇率行按隐含汇率回显 + 折算预览', (tester) async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    // amount=12, native=86.4 → 隐含汇率 7.2
    await tester.pumpWidget(host(
      initialCurrencyCode: 'USD',
      initialAmount: 12,
      initialNativeAmount: 86.4,
    ));
    await tester.pumpAndSettle();

    expect(find.text('USD'), findsOneWidget); // 币种标=该笔币种
    // 反馈9:不展示汇率行,只展示折算预览(按隐含汇率 86.4/12=7.2 计算,
    // 而非当前有效汇率 —— 只改备注折算基准不漂移)
    expect(find.textContaining('1 USD ='), findsNothing);
    expect(find.textContaining('≈ 86.40 CNY'), findsOneWidget);
  });
}
