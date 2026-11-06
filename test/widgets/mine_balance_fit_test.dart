import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/widgets/biz/amount_text.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  const narrowWidth = 80.0;
  const balance = 12345678.9;

  AmountText amountText() => AmountText(
        value: balance,
        signed: false,
        showCurrency: true,
        useCompactFormat: false,
        currencyCode: 'CNY',
      );

  group('mine balance cell amount fitting (#453)', () {
    testWidgets('裸 AmountText 在三等分窄单元格里会被截断', (tester) async {
      await tester.pumpWidget(
        wrap(SizedBox(width: narrowWidth, child: amountText())),
      );
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(find.byType(Text));
      // 被单元格宽度约束:完整金额放不下(即修复前出现省略号的原因)。
      expect(paragraph.size.width, lessThanOrEqualTo(narrowWidth));
    });

    testWidgets('FittedBox 包裹后长余额缩放显示、不再被截断', (tester) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: narrowWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: amountText(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(find.byType(Text));
      // FittedBox 让文本按自然宽度排版再整体缩放,而不是截断,
      // 因此完整金额保持可读(#453 的修复方式,与首页收支汇总一致)。
      expect(paragraph.size.width, greaterThan(narrowWidth));
    });
  });
}
