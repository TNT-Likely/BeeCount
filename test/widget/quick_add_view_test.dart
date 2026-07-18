/// 快速记账([QuickAddView])headless 冒烟测试:小/中两档 × 明暗、分类数量
/// 不足/超出时的占位与截断,都不应抛异常。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/widget/views/quick_add_view.dart';
import 'package:beecount/widget/widget_data_service.dart' show QuickAddCategoryItem;
import 'package:beecount/widget/widget_spec.dart' show HWSize;

void main() {
  Widget wrap(Widget child, Size size) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: size.width, height: size.height, child: child),
    );
  }

  List<QuickAddCategoryItem> sampleCategories(int count) {
    const names = ['餐饮', '交通', '购物', '娱乐', '医疗', '住房'];
    const icons = ['restaurant', 'directions_car', 'shopping_cart', 'movie', 'local_hospital', 'home'];
    return List.generate(
      count,
      (i) => QuickAddCategoryItem(
        categoryId: i + 1,
        name: names[i % names.length],
        icon: icons[i % icons.length],
        total: (i + 1) * 100.0,
      ),
    );
  }

  group('QuickAddView.small(155x155)', () {
    testWidgets('分类数充足(>=3)时正常渲染,不抛异常', (tester) async {
      const size = Size(155, 155);
      await tester.pumpWidget(wrap(
        QuickAddView(
          size: HWSize.small,
          categories: sampleCategories(5),
          themeColor: const Color(0xFFF5A623),
          dark: false,
          addLabel: '记一笔',
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('记一笔'), findsOneWidget);
      expect(find.text('餐饮'), findsOneWidget);
    });

    testWidgets('分类数不足(新账本无支出记录)用占位格补齐,不抛异常', (tester) async {
      const size = Size(155, 155);
      await tester.pumpWidget(wrap(
        QuickAddView(
          size: HWSize.small,
          categories: const [],
          themeColor: const Color(0xFFF5A623),
          dark: true,
          addLabel: '记一笔',
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('记一笔'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsNWidgets(3));
    });

    testWidgets('icon 字段是 emoji 时直接以文字展示', (tester) async {
      const size = Size(155, 155);
      await tester.pumpWidget(wrap(
        QuickAddView(
          size: HWSize.small,
          categories: const [
            QuickAddCategoryItem(categoryId: 1, name: '奶茶', icon: '🧋', total: 30),
          ],
          themeColor: const Color(0xFFF5A623),
          dark: false,
          addLabel: '记一笔',
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('🧋'), findsOneWidget);
    });
  });

  group('QuickAddView.medium(364x169)', () {
    testWidgets('4 个分类 + 记一笔正常渲染,不抛异常', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        QuickAddView(
          size: HWSize.medium,
          categories: sampleCategories(4),
          themeColor: const Color(0xFFF5A623),
          dark: false,
          addLabel: '记一笔',
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('记一笔'), findsOneWidget);
    });

    testWidgets('分类数超出上限(6 个)按 take(4) 截断,不抛异常', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        QuickAddView(
          size: HWSize.medium,
          categories: sampleCategories(6),
          themeColor: const Color(0xFFF5A623),
          dark: true,
          addLabel: '记一笔',
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // 6 个样本分类名两两重复(names 长度 6 循环取模,前 4 个各不相同),
      // 只应看到 take(4) 之后的那几个名字各一次。
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('医疗'), findsNothing);
    });

    testWidgets('空分类列表(无占位格补齐)只剩记一笔,不抛异常', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        QuickAddView(
          size: HWSize.medium,
          categories: const [],
          themeColor: const Color(0xFFF5A623),
          dark: false,
          addLabel: '记一笔',
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('记一笔'), findsOneWidget);
    });
  });
}
