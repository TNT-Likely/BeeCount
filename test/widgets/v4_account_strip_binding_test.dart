import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/pages/shared/selectors/account_selector.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('真实账户映射保留币种过滤、初始顺序、历史钉住和可清空回调', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id,name,currency) VALUES (1,'测试账本','CNY')");
    for (final row in [
      "1,'现金','CNY',0,'cash'",
      "2,'银行卡','CNY',0,'bank_card'",
      "3,'美元现金','USD',0,'cash'",
      "4,'历史钱包','CNY',1,'wechat'",
      "5,'资产估值','CNY',0,'investment'"
    ]) {
      await db.customStatement(
          'INSERT INTO accounts (id,name,currency,hidden,type,ledger_id) SELECT $row,1');
    }
    String currency = 'CNY';
    int? selected = 2, pinned;
    late StateSetter update;
    await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: Scaffold(body: StatefulBuilder(builder: (context, set) {
              update = set;
              return AccountSelector(
                  selectedAccountId: selected,
                  ledgerId: 1,
                  pinnedAccountId: pinned,
                  filterCurrency: currency,
                  onAccountSelected: (id) => update(() => selected = id));
            })))));
    await tester.pumpAndSettle();
    expect(find.byType(BeeAccountStrip), findsOneWidget);
    expect(find.text('银行卡'), findsOneWidget);
    expect(find.text('美元现金'), findsNothing);
    expect(find.text('历史钱包'), findsNothing);
    expect(find.text('资产估值'), findsNothing);
    final before = tester.getTopLeft(find.text('银行卡'));
    await tester.tap(find.text('现金'));
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(tester.getTopLeft(find.text('银行卡')), before);
    await tester.tap(find.text('不选择账户'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    update(() {
      currency = 'USD';
      pinned = 4;
    });
    await tester.pumpAndSettle();
    expect(find.text('现金'), findsNothing);
    expect(find.text('美元现金'), findsOneWidget);
    expect(find.text('历史钱包'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await db.close();
  });
}
