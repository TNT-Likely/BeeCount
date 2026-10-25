import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/biz/transaction_list_item.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:beecount/presentation/v4/bindings/transaction_tile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    var sdk = File(Platform.resolvedExecutable).parent;
    while (!Directory('${sdk.path}/material_fonts').existsSync() &&
        sdk.parent.path != sdk.path) {
      sdk = sdk.parent;
    }
    final loader = FontLoader('BindingRowRoboto');
    for (final weight in ['Regular', 'Bold']) {
      loader.addFont(Future.value(ByteData.sublistView(
          await File('${sdk.path}/material_fonts/Roboto-$weight.ttf')
              .readAsBytes())));
    }
    await loader.load();
  });
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
      String? baseCurrency,
      bool allCurrencies = false,
      bool hide = false,
      bool transfer = false,
      int? transferDirection,
      List<({int id, String name, String? color})>? tags,
      void Function(int, String)? onTag}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme().copyWith(
                textTheme:
                    beeTheme().textTheme.apply(fontFamily: 'BindingRowRoboto')),
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
                        baseCurrencyCode: baseCurrency,
                        alwaysShowCurrency: allCurrencies,
                        nativeAmount: converted,
                        isExpense: true,
                        isTransfer: transfer,
                        transferDirection: transferDirection,
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
    var money = tester
        .widget<Text>(find.byKey(const ValueKey('transaction-amount')))
        .textSpan as TextSpan;
    expect(money.toPlainText(), '−US\$12.00');
    expect(money.style!.color, const Color(0xff25856d));
    expect(find.text('≈ ¥85.20'), findsOneWidget);
    container.read(incomeExpenseColorSchemeProvider.notifier).state = false;
    container.read(noteDisplayModeProvider.notifier).state = 'note';
    container.read(showTransactionTimeProvider.notifier).state = true;
    await tester.pumpAndSettle();
    money = tester
        .widget<Text>(find.byKey(const ValueKey('transaction-amount')))
        .textSpan as TextSpan;
    expect(money.style!.color, const Color(0xffbd5d50));
    expect(find.text('一杯拿铁', findRichText: true), findsOneWidget);
    expect(find.text('12:34:56'), findsOneWidget);
    expect(find.text('美元账户'), findsOneWidget);
    expect(find.text('咖啡'), findsNothing, reason: '备注有值，下方不重复分类');
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

  testWidgets('账户转账方向显示流出负号、流入正号，同账户和其他列表保持中性', (tester) async {
    for (final sample in <int?, String>{
      -1: '−US\$12.00',
      1: '+US\$12.00',
      0: 'US\$12.00',
      null: 'US\$12.00'
    }.entries) {
      await open(tester, transfer: true, transferDirection: sample.key);
      expect(
          tester
              .widget<BeeTransactionRow>(find.byType(BeeTransactionRow))
              .amount,
          sample.value);
      expect(
          (tester
                  .widget<Text>(
                      find.byKey(const ValueKey('transaction-amount')))
                  .textSpan as TextSpan)
              .style!
              .color,
          beeTheme().colorScheme.onSurfaceVariant);
      expect(tester.takeException(), isNull);
      await close(tester);
    }
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
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('家庭'), findsNothing);
    await tester.tap(find.text('+1'));
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
  testWidgets('全部账本按交易来源本位币展示折算，同币种也保留币种标识', (tester) async {
    await open(tester, baseCurrency: 'EUR', allCurrencies: true);
    expect(find.text('≈ €85.20'), findsOneWidget);
    expect(find.text('≈ ¥85.20'), findsNothing);
    await open(tester, baseCurrency: 'USD', allCurrencies: true, converted: 12);
    expect(
        tester.widget<BeeTransactionRow>(find.byType(BeeTransactionRow)).amount,
        '−US\$12.00');
    expect(find.textContaining('≈ '), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  testWidgets('真实搜索绑定的C3完整字段只读：长原币快照、多标签、双排除和批量选择均不改写', (tester) async {
    final id = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 1234567890.12,
        currencyCode: 'USD',
        nativeAmount: 8765432019.85,
        note: '真实绑定读取的完整备注',
        happenedAt: DateTime(2026, 10, 20, 12, 34, 56),
        excludeFromStats: true,
        excludeFromBudget: true);
    final before = (await repo.getTransactionById(id))!;
    var selections = 0;
    container.read(noteDisplayModeProvider.notifier).state = 'note';
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme().copyWith(
                textTheme:
                    beeTheme().textTheme.apply(fontFamily: 'BindingRowRoboto')),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.4)),
                child: child!),
            home: Scaffold(
                body: SizedBox(
                    width: 320,
                    child: TransactionTileBinding(
                        row: (
                          t: before,
                          category: null,
                          account: null,
                          toAccount: null
                        ),
                        tags: [
                          for (var i = 0; i < 6; i++)
                            Tag(
                                id: i + 1,
                                name: '标签$i',
                                color: '#477f6c',
                                sortOrder: i,
                                createdAt: DateTime(2026))
                        ],
                        attachmentCount: 9,
                        batch: true,
                        selected: false,
                        fullDate: true,
                        ledgerName: '生活账本',
                        baseCurrency: 'CNY',
                        onSelect: () => selections++,
                        onReturned: () {}))))));
    await tester.pumpAndSettle();
    final component =
        tester.widget<BeeTransactionRow>(find.byType(BeeTransactionRow));
    expect(component.amount, '−US\$1,234,567,890.12');
    expect(component.converted, '≈ ¥8,765,432,019.85');
    expect(find.text('不计收支'), findsOneWidget);
    expect(find.text('不计预算'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('transaction-more-fields')));
    await tester.pumpAndSettle();
    expect(find.text('完整账单字段'), findsOneWidget);
    expect(find.text('标签0 · 标签1 · 标签2 · 标签3 · 标签4 · 标签5'), findsOneWidget);
    expect(find.text('真实绑定读取的完整备注'), findsAtLeastNWidgets(1));
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(selections, 0);
    final after = (await repo.getTransactionById(id))!;
    expect(after, before);
    final beforeHash =
        sha256.convert(utf8.encode(jsonEncode(before.toJson()))).toString();
    final afterHash =
        sha256.convert(utf8.encode(jsonEncode(after.toJson()))).toString();
    expect(afterHash, beforeHash);
    final dir = Platform.environment['BEECOUNT_TRANSACTION_CAPTURE_DIR'];
    if (dir != null) {
      File('$dir/readonly-record-fingerprint.json')
          .writeAsStringSync(jsonEncode({
        'scope': 'synthetic in-memory repository record only',
        'before': beforeHash,
        'after': afterHash,
        'equal': beforeHash == afterHash,
        'selectionChanges': selections
      }));
    }
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
