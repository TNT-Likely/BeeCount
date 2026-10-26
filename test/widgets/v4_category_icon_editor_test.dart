import 'dart:convert';
import 'dart:io';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/presentation/v4/bindings/category_icon_catalog.dart';
import 'package:beecount/presentation/v4/bindings/category_line_icon_names.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('原分类编辑页全部图标分组和持久化键保留，均有已打包的线性图标映射', () {
    final fixture = jsonDecode(
        File('test/fixtures/v4-category-icon-catalog.json')
            .readAsStringSync()) as Map;
    final keys = <String>{};
    for (final kind in ['expense', 'income']) {
      final groups = categoryEditorIconGroups(AppLocalizationsZh(), kind);
      expect(groups.map((g) => {'label': g.label, 'keys': g.iconKeys}).toList(),
          fixture[kind]);
      keys.addAll(groups.expand((g) => g.iconKeys));
    }
    expect(keys.length, 237);
    expect(keys.every(categoryLineIconNames.containsKey), isTrue);
  });
  for (final brightness in Brightness.values) {
    testWidgets('图标编辑保持受控选择、自定义原色插槽与小屏大字触控 $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var source = BeeCategoryIconSource.preset;
      var value = 'food', selections = 0, imageChoices = 0;
      var loading = false;
      late StateSetter update;
      await tester.pumpWidget(MaterialApp(
          theme: beeTheme(brightness: brightness),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.4)),
              child: child!),
          home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
            update = setState;
            return SingleChildScrollView(
                padding: const EdgeInsets.all(17),
                child: BeeSurface(
                    child: BeeCategoryIconEditor(
                        source: source,
                        value: value,
                        loading: loading,
                        presetLabel: '预设图标',
                        customLabel: '自定义图片',
                        commonLabel: '常用',
                        imageHint: '完整显示图片原色与透明背景',
                        chooseImageLabel: '选择图片',
                        preview: const ColoredBox(
                            key: ValueKey('original-color'),
                            color: Color(0xffab3f96)),
                        commonItems: const [
                          BeeIconChoice(
                              value: 'food',
                              label: '餐饮',
                              icon: BeeLineIcon('Utensils')),
                          BeeIconChoice(
                              value: 'coffee',
                              label: '咖啡',
                              icon: BeeLineIcon('Coffee'))
                        ],
                        groups: const [
                          BeeCategoryIconGroup(
                              id: 'other',
                              label: '其他',
                              items: [
                                BeeIconChoice(
                                    value: 'home',
                                    label: '居家',
                                    icon: BeeLineIcon('House')),
                                BeeIconChoice(
                                    value: 'travel',
                                    label: '交通',
                                    icon: BeeLineIcon('TrainFront'))
                              ])
                        ],
                        onSourceChanged: (s) => setState(() => source = s),
                        onChanged: (v) => setState(() {
                              value = v;
                              selections++;
                            }),
                        onChooseImage: () => imageChoices++)));
          }))));
      await tester.pumpAndSettle();
      expect(find.text('餐饮'), findsNothing, reason: '紧凑网格仅通过语义提供标签');
      final tile = find
          .descendant(
              of: find.bySemanticsLabel('餐饮'), matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(tile).height, greaterThanOrEqualTo(44));
      await tester.tap(find.text('其他'));
      await tester.pumpAndSettle();
      expect(selections, 0, reason: '切换分组不能改变实际选中的图标');
      await tester.tap(find.bySemanticsLabel('居家'));
      await tester.pumpAndSettle();
      expect(value, 'home');
      expect(selections, 1);
      await tester.tap(find.text('自定义图片'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const ValueKey('original-color'))),
          const Size(72, 72));
      await tester.tap(find.text('选择图片'));
      expect(imageChoices, 1);
      expect(value, 'home');
      update(() => loading = true);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final upload = find.ancestor(
          of: find.text('选择图片'), matching: find.byType(FilledButton));
      expect(tester.widget<FilledButton>(upload).onPressed, isNull);
      update(() => loading = false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('预设图标'));
      await tester.pumpAndSettle();
      expect(value, 'home');
      expect(find.bySemanticsLabel('居家'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
