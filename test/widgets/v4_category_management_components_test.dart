import 'dart:convert';
import 'package:beecount/dev/component_gallery/business_page.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('把手可见且立即拖动，长按名称不触发排序', (tester) async {
    var reordered = 0;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: BeeCategoryManagementList(
                reorderLabel: '拖动排序',
                manageLabel: '管理',
                items: const [
                  BeeManagedCategory(
                      id: 'a',
                      name: '咖啡',
                      icon: Icon(Icons.coffee),
                      detail: '2笔'),
                  BeeManagedCategory(
                      id: 'b',
                      name: '奶茶',
                      icon: Icon(Icons.local_drink),
                      detail: '3笔'),
                ],
                onEdit: (_) {},
                onManageChildren: (_) {},
                onReorder: (_, __) => reordered++))));
    expect(find.byType(ReorderableDelayedDragStartListener), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
    final grip = find.byKey(const ValueKey('category-reorder-a'));
    expect(tester.getSize(grip), const Size(48, 60));
    await tester.longPress(find.text('咖啡'));
    await tester.pumpAndSettle();
    expect(reordered, 0);
    final gesture = await tester.startGesture(tester.getCenter(grip));
    await tester.pump(const Duration(milliseconds: 20));
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(reordered, 1);
    expect(tester.takeException(), isNull);
  });

  for (final offset in [const Offset(2, 2), const Offset(46, 58)]) {
    testWidgets('拖动把手边缘 $offset 可抓取，小屏深色展开项长按后仍可拖动', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var rows = [
        BeeManagedCategory(
            id: 'a',
            name: '咖啡',
            icon: Image.memory(
                base64Decode(
                    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFUlEQVR4nGN4EzrxPwgz/Dgp8x+EAWX8C1sjhSyIAAAAAElFTkSuQmCC'),
                width: 20,
                height: 20,
                fit: BoxFit.cover),
            detail: '2笔',
            children: [
              BeeManagedCategory(
                  id: 'child',
                  name: '自定义图片分类',
                  icon: Image.memory(
                      base64Decode(
                          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFUlEQVR4nGN4EzrxPwgz/Dgp8x+EAWX8C1sjhSyIAAAAAElFTkSuQmCC'),
                      width: 15,
                      height: 15,
                      fit: BoxFit.cover),
                  detail: '2笔')
            ]),
        BeeManagedCategory(
            id: 'b', name: '奶茶', icon: Icon(Icons.local_drink), detail: '3笔'),
        BeeManagedCategory(
            id: 'c', name: '其他', icon: Icon(Icons.more_horiz), detail: '1笔'),
      ];
      var edited = 0;
      await tester.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!),
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => BeeCategoryManagementList(
                      items: rows,
                      reorderLabel: '拖动排序',
                      manageLabel: '管理',
                      onEdit: (_) => edited++,
                      onManageChildren: (_) {},
                      onReorder: (a, b) {
                        if (a < b) b--;
                        final next = rows.toList();
                        final moved = next.removeAt(a);
                        next.insert(b, moved);
                        setState(() => rows = next);
                      },
                    ))),
      ));
      await tester.tap(find.text('咖啡'));
      await tester.pumpAndSettle();
      final handle = find.byKey(const ValueKey('category-reorder-a'));
      final gesture =
          await tester.startGesture(tester.getTopLeft(handle) + offset);
      await tester.pump(const Duration(milliseconds: 900));
      for (var i = 0; i < 15; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(rows.first.id, 'b');
      expect(find.text('自定义图片分类'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(2));
      expect(edited, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('没有一级分类时仍能看到空态、转账分类和工具入口', (tester) async {
    var transfer = 0, tools = 0;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: BeeCategoryManagementList(
                reorderLabel: '拖动排序',
                items: const [],
                onEdit: (_) {},
                onManageChildren: (_) {},
                onReorder: (_, __) {},
                manageLabel: '管理',
                empty: const Text('还没有分类'),
                footer: Column(children: [
                  BeeMenuRow(title: '转账分类', onTap: () => transfer++),
                  BeeMenuRow(title: '分类工具', onTap: () => tools++)
                ])))));
    await tester.tap(find.text('转账分类'));
    await tester.tap(find.text('分类工具'));
    expect(find.text('还没有分类'), findsOneWidget);
    expect([transfer, tools], [1, 1]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('组件验收分类管理实际打开图标与图片弹窗，并能预览空态入口', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: const Scaffold(body: BusinessAcceptancePage(isolatedCase: 32))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('管理'));
    await tester.tap(find.text('管理'));
    await tester.pumpAndSettle();
    final grid = tester
        .widget<BeeCategoryChildrenGrid>(find.byType(BeeCategoryChildrenGrid));
    expect(grid.items.length, 4);
    expect(
        grid.items.singleWhere((item) => item.id == 'milk').icon, isA<Image>());
    await tester.tap(
        find.descendant(of: find.byType(BeeDialog), matching: find.text('奶茶')));
    await tester.pumpAndSettle();
    expect(find.text('编辑二级分类 milk'), findsOneWidget);
    expect(find.byType(BeeDialog), findsNothing);
    await tester.ensureVisible(find.text('预览空分类状态'));
    await tester.tap(find.text('预览空分类状态'));
    await tester.pumpAndSettle();
    expect(find.text('暂无分类'), findsOneWidget);
    expect(find.text('转账分类图标'), findsOneWidget);
    expect(find.text('分类工具'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('大量二级分类在小屏大字体弹窗可滚动，图标原样传递且回调准确', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? chosen;
    final items = List.generate(
        40,
        (index) => BeeManagedCategory(
            id: '$index',
            name: '自定义长名称二级分类 $index',
            detail: '$index 笔',
            icon: Icon(index.isEven ? Icons.coffee : Icons.photo,
                color: Colors.pink)));
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                body: BeeButton(
                    label: '管理',
                    onPressed: () => showBeeDialog<void>(context,
                        title: '管理二级分类',
                        child: BeeCategoryChildrenGrid(
                            items: items,
                            emptyLabel: '无二级分类',
                            onEdit: (id) => chosen = id)))))));
    await tester.tap(find.text('管理'));
    await tester.pumpAndSettle();
    final last = find.text('自定义长名称二级分类 39');
    await tester.ensureVisible(last);
    await tester.tap(last);
    expect(chosen, '39');
    expect(
        tester
            .widgetList<Icon>(find.byIcon(Icons.photo))
            .every((icon) => icon.color == Colors.pink),
        true);
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
