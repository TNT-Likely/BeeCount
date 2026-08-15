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
    // 9 个各不相同的名字:够 medium 2×4 网格(7 分类)用满,还能多出 2 个
    // 验证截断。
    const names = ['餐饮', '交通', '购物', '娱乐', '医疗', '住房', '通讯', 'education', '宠物'];
    const icons = [
      'restaurant', 'directions_car', 'shopping_cart', 'movie', 'local_hospital',
      'home', 'phone', 'school', 'pets',
    ];
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

    testWidgets('emoji 图标锁死行高(height:1.0)且外包同高 SizedBox,不撑爆格子',
        (tester) async {
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

      // 本测试跑在 Ahem 字体下(行高恰好 1.0),真实字体的撑爆现象复现不出来
      // ——所以断言的是「结构上锁死了高度」这件事本身:去掉 height:1.0 或
      // 外层 SizedBox,真机/预览渲染就会 RenderFlex 溢出(见 _categoryGlyph)。
      final glyph = tester.widget<Text>(find.text('🧋'));
      expect(glyph.style?.height, 1.0);
      final box = tester.widget<SizedBox>(
        find.ancestor(of: find.text('🧋'), matching: find.byType(SizedBox)).first,
      );
      expect(box.height, 20); // small 档 _cellGlyph,与 Icon(size:) 同值
    });
  });

  group('QuickAddView.medium(364x169)', () {
    testWidgets('7 个分类 + 记一笔铺满 2×4 网格,不抛异常', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        QuickAddView(
          size: HWSize.medium,
          categories: sampleCategories(7),
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
      // 7 个分类全部上墙(旧版单行只放得下 4 个),且没有占位格。
      for (final name in ['餐饮', '交通', '购物', '娱乐', '医疗', '住房', '通讯']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('分类数超出上限(9 个)按 take(7) 截断,不抛异常', (tester) async {
      const size = Size(364, 169);
      await tester.pumpWidget(wrap(
        QuickAddView(
          size: HWSize.medium,
          categories: sampleCategories(9),
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
      expect(find.text('通讯'), findsOneWidget); // 第 7 个,在网格内
      expect(find.text('education'), findsNothing); // 第 8 个起被截断
      expect(find.text('宠物'), findsNothing);
    });

    testWidgets('分类不足(新账本)用占位格补齐 2×4 网格,不抛异常', (tester) async {
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
      expect(find.byIcon(Icons.more_horiz), findsNWidgets(7));
    });
  });
}
