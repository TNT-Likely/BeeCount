import 'package:beecount/dev/component_gallery/budget_editor_sample.dart';
import 'package:beecount/dev/component_gallery/gallery_still_asset.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('暂停示例动效后新选择的静态自定义图片仍加载并绘制', (t) async {
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: TickerMode(
                enabled: false,
                child: SingleChildScrollView(
                    child: const BudgetEditorSample())))));
    await t.pump();
    final first = find.byType(BeeBudgetEditorForm).first;
    await t.tap(find.descendant(of: first, matching: find.text('分类预算')));
    await t.pump();
    final pick = find.descendant(of: first, matching: find.text('选择分类'));
    await t.ensureVisible(pick);
    await t.tap(pick);
    await t.pump();
    final image =
        find.descendant(of: first, matching: find.byType(GalleryStillAsset));
    expect(image, findsOneWidget);
    await t.runAsync(() => precacheImage(
        const AssetImage('assets/v4_gallery/category-coffee.png'),
        t.element(image)));
    await t.pump();
    expect(TickerMode.of(t.element(image)), false);
    expect(
        t
            .widget<RawImage>(
                find.descendant(of: image, matching: find.byType(RawImage)))
            .image,
        isNotNull);
    expect(t.takeException(), isNull);
  });
}
