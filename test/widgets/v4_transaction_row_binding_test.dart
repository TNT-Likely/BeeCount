import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/biz/transaction_list_item.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'生活','CNY')");
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerProvider.overrideWith((ref) => repo.watchLedger(1)),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> open(WidgetTester tester,
      {double? converted = 85.2,
      bool hide = false,
      List<({int id, String name, String? color})>? tags,
      void Function(int, String)? onTag}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: SizedBox(
                    width: 360,
                    child: TransactionListItem(
                        icon: Icons.coffee,
                        title: '一杯拿铁',
                        categoryName: '咖啡',
                        amount: 12,
                        currencyCode: 'USD',
                        nativeAmount: converted,
                        isExpense: true,
                        hide: hide,
                        accountName: '美元账户',
                        happenedAt: DateTime(2026, 10, 24, 12, 34, 56),
                        tags: tags,
                        onTagTap: onTag))))));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('外币行按设计展示符号顺序、两位小数、账本币折算和语义色，保留反转偏好', (tester) async {
    await open(tester);
    var money = tester.widget<BeeMoney>(find.byType(BeeMoney));
    expect(money.amount, '−US\$12.00');
    expect(money.color, const Color(0xff25856d));
    expect(find.text('≈ ¥85.20'), findsOneWidget);
    container.read(incomeExpenseColorSchemeProvider.notifier).state = false;
    container.read(noteDisplayModeProvider.notifier).state = 'note';
    container.read(showTransactionTimeProvider.notifier).state = true;
    await tester.pumpAndSettle();
    money = tester.widget<BeeMoney>(find.byType(BeeMoney));
    expect(money.color, const Color(0xffbd5d50));
    expect(find.text('一杯拿铁', findRichText: true), findsOneWidget);
    expect(find.text('12:34:56 · 咖啡 · 美元账户'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('外币缺少快照或原币数额相同时沿用原规则，不编造折算；隐私隐藏折算', (tester) async {
    await open(tester, converted: null);
    expect(find.textContaining('≈'), findsNothing);
    await close(tester);
    await open(tester, converted: 12);
    expect(find.textContaining('≈'), findsNothing);
    await close(tester);
    await open(tester, hide: true);
    expect(find.text('≈ ¥85.20'), findsNothing);
    expect(find.text('−US\$12.00', findRichText: true), findsNothing);
    expect(find.text('••••', findRichText: true), findsNWidgets(2));
    await close(tester);
  });

  testWidgets('更多标签可以展开横排完整列表，并进入被折叠标签的原有详情回调', (tester) async {
    final visits = <int>[];
    await open(tester,
        tags: [
          (id: 1, name: '工作日', color: '#aa8b29'),
          (id: 2, name: '旅行', color: '#219c9c'),
          (id: 3, name: '家庭', color: '#7771db')
        ],
        onTag: (id, _) => visits.add(id));
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('家庭'), findsNothing);
    await tester.tap(find.text('+2'));
    await tester.pumpAndSettle();
    expect(find.text('全部标签'), findsOneWidget);
    expect(find.text('家庭'), findsOneWidget);
    await tester.tap(find.text('家庭'));
    await tester.pumpAndSettle();
    expect(visits, [3]);
    expect(find.text('全部标签'), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
