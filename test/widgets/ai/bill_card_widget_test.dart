import 'package:beecount/ai/core/bill_info.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widgets/ai/bill_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('记账成功卡片展示标签和币种', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BillCardWidget(
              billInfo: BillInfo(
                amount: 88,
                time: DateTime(2026, 9, 6, 9, 30),
                currency: 'USD',
                tags: ['报销', '差旅'],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('USD'), findsOneWidget);
    expect(find.text('报销'), findsOneWidget);
    expect(find.text('差旅'), findsOneWidget);
  });

  testWidgets('转账记账成功卡片展示完整账户路径', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BillCardWidget(
              billInfo: BillInfo(
                amount: 88,
                time: DateTime(2026, 9, 6, 9, 30),
                type: BillType.transfer,
                fromAccount: '支付宝',
                toAccount: '储蓄卡',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('支付宝 → 储蓄卡'), findsOneWidget);
  });
}
