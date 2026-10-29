import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/pages/shared/transactions/transaction_list_item.dart';
import 'package:beecount/dev/component_gallery/transaction_row_states.dart';

void main() {
  late List<Map<String, dynamic>> cases;
  setUpAll(() async {
    cases = (await transactionStateFixtures)
        .where((s) => s['group'] == 'time')
        .toList();
  });

  testWidgets('迁移后交易行保留冻结的原版时间输出', (tester) async {
    final expected = (jsonDecode(
            File('test/fixtures/v4-legacy-time-output.json').readAsStringSync())
        as Map)['expected'] as Map;
    final pattern = RegExp(r'\d{4}-\d{2}-\d{2} \d{2}:\d{2}|\d{2}:\d{2}:\d{2}');
    for (final s in cases) {
      final at = s['happenedAt'] == null
          ? null
          : DateTime.parse(s['happenedAt'] as String);
      await tester.pumpWidget(ProviderScope(
        key: ValueKey(s['id']),
        overrides: [
          showTransactionTimeProvider
              .overrideWith((ref) => s['showTime'] == true)
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: Column(children: [
            TransactionListItem(
                icon: Icons.restaurant,
                title: s['title'] as String,
                amount: 32,
                isExpense: true,
                hide: false,
                happenedAt: at,
                showFullDate: s['showFullDate'] == true,
                accountName: s['accountName'] as String?),
            BeeTransactionRow(
                title: s['title'] as String,
                amount: '−32.00',
                icon: const Icon(Icons.restaurant),
                onCategoryTap: () {},
                onTap: () {},
                happenedAt: at,
                showTime: s['showTime'] == true,
                showFullDate: s['showFullDate'] == true,
                accountName: s['accountName'] as String?),
          ])),
        ),
      ));
      await tester.pumpAndSettle();
      String content(Type type) => find
              .descendant(of: find.byType(type), matching: find.byType(Text))
              .evaluate()
              .map((e) {
            final t = e.widget as Text;
            return t.data ?? t.textSpan?.toPlainText() ?? '';
          }).join('\n');
      final oldStamp =
          pattern.firstMatch(content(TransactionListItem))?.group(0);
      final newStamp = pattern.firstMatch(content(BeeTransactionRow))?.group(0);
      expect(oldStamp, expected[s['id']], reason: s['id'] as String);
      expect(newStamp, expected[s['id']], reason: s['id'] as String);
      expect(
          formatBeeTransactionTimestamp(at,
              showTime: s['showTime'] == true,
              showFullDate: s['showFullDate'] == true),
          oldStamp,
          reason: s['id'] as String);
      expect(tester.takeException(), isNull, reason: s['id'] as String);
    }
  });

  test('完整日期覆盖时间开关；精确零点隐藏但非零秒保留', () {
    expect(
        formatBeeTransactionTimestamp(DateTime(2026, 10, 20), showTime: true),
        isNull);
    expect(
        formatBeeTransactionTimestamp(DateTime(2026, 10, 20, 0, 0, 7),
            showTime: true),
        '00:00:07');
    expect(
        formatBeeTransactionTimestamp(DateTime(2026, 10, 20),
            showFullDate: true),
        '2026-10-20 00:00');
    expect(
        formatBeeTransactionTimestamp(DateTime(2026, 10, 20, 12, 34, 56),
            showFullDate: true),
        '2026-10-20 12:34');
    expect(formatBeeTransactionTimestamp(DateTime(2026, 10, 20, 12, 34, 56)),
        isNull);
    expect(
        formatBeeTransactionTimestamp(null, showTime: true, showFullDate: true),
        isNull);
  });
}
