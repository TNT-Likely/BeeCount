import 'package:beecount/widget/views/quick_add_view.dart';
import 'package:beecount/widget/views/widget_view_style.dart';
import 'package:beecount/widget/widget_data_service.dart'
    show QuickAddCategoryItem;
import 'package:beecount/widget/widget_spec.dart' show HWSize;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget card(HWSize size, List<QuickAddCategoryItem> categories,
        {required bool dark}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
          child: QuickAddView(
        size: size,
        categories: categories,
        dark: dark,
        titleLabel: 'Quick Add',
        frequentLabel: 'Frequent categories',
        emptyLabel: 'No frequent categories',
        addLabel: 'Add expense',
        themeColor: dark ? const Color(0xFF281850) : const Color(0xFFFFC35B),
        width: size == HWSize.small ? 155 : 364,
        height: size == HWSize.small ? 155 : 169,
      )),
    );

void main() {
  final items = List.generate(
      9,
      (i) => QuickAddCategoryItem(
          categoryId: i + 1,
          name: 'Category ${i + 1}',
          icon: i == 0 ? '🧋' : 'shopping_cart',
          total: i + 1.0));

  for (final size in [HWSize.small, HWSize.medium]) {
    final columns = size == HWSize.small ? 2 : 4;
    final limit = columns * 2 - 1;

    testWidgets('$size 常用分类按 2 行排列；保留单一记账入口和单行 emoji', (tester) async {
      await tester.pumpWidget(card(size, items, dark: false));
      expect(tester.takeException(), isNull);
      expect(find.text('Quick Add'), findsOneWidget);
      expect(find.text('Frequent categories'), findsOneWidget);
      expect(find.text('Add expense'), findsOneWidget);
      expect(find.text('No frequent categories'), findsNothing);
      for (var i = 0; i < limit; i++) {
        expect(find.text(items[i].name), findsOneWidget);
      }
      expect(find.text(items[limit].name), findsNothing);
      expect(tester.getCenter(find.text(items.first.name)).dy,
          equals(tester.getCenter(find.text(items[columns - 1].name)).dy));
      expect(tester.getCenter(find.text(items[columns].name)).dy,
          greaterThan(tester.getCenter(find.text(items.first.name)).dy));
      final glyphBox = find.ancestor(
          of: find.text('🧋'),
          matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.width == 14 && w.height == 14));
      expect(tester.getSize(glyphBox), const Size.square(14));
      final cta = tester.widget<Text>(find.text('Add expense'));
      expect(cta.style?.color, widgetOnAccent(const Color(0xFFFFC35B)));
    });

    testWidgets('$size 无支出时展示空态和可读的深色强调按钮', (tester) async {
      await tester.pumpWidget(card(size, [], dark: true));
      expect(tester.takeException(), isNull);
      expect(find.text('No frequent categories'), findsOneWidget);
      expect(find.text('Frequent categories'), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.text('Add expense'), findsOneWidget);
      final cta = tester.widget<Text>(find.text('Add expense'));
      expect(cta.style?.color, widgetOnAccent(const Color(0xFF281850)));
    });

    testWidgets('$size 部分分类仅采用实际数据', (tester) async {
      await tester.pumpWidget(card(size, items.take(1).toList(), dark: true));
      expect(tester.takeException(), isNull);
      expect(find.text(items.first.name), findsOneWidget);
      expect(find.text(items[1].name), findsNothing);
      expect(find.text('No frequent categories'), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });
  }
}
