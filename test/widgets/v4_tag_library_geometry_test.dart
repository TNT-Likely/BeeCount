import 'dart:convert';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('标签网格对齐冻结HTML的标准及小屏大字尺寸', (t) async {
    final fixture = jsonDecode(
        File('test/fixtures/v4-tag-library-geometry.json').readAsStringSync());
    for (final row in fixture['cases']) {
      final p = row['profile'], g = row['geometry'];
      // HTML preview's 1px outer phone border is not part of its app viewport.
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = Size((p['width'] as num).toDouble() - 2,
          (p['height'] as num).toDouble() - 2);
      await t.pumpWidget(MaterialApp(
        theme: beeTheme(
            brightness:
                p['appearance'] == 'dark' ? Brightness.dark : Brightness.light),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear((p['scale'] as num).toDouble())),
            child: child!),
        home: Scaffold(
            body: BeeTagLibrary(
          items: const [
            BeeTagLibraryItem(
                tag: BeeTagData('1', '工作日', Color(0xffaa8b29)), count: '31笔'),
            BeeTagLibraryItem(
                tag: BeeTagData('2', '旅行', Color(0xff219c9c)), count: '17笔')
          ],
          deleteLabel: '删除',
          onOpen: (_) {},
          onDelete: (_) {},
        )),
      ));
      await t.pumpAndSettle();
      final cards = find.byType(BeeSurface);
      expect(t.getSize(cards.first).width, closeTo(g['width'], .01));
      expect(t.getSize(cards.first).height, closeTo(g['height'], .01));
      expect(t.getTopLeft(cards.at(1)).dx - t.getTopRight(cards.first).dx,
          g['gap']);
      expect(t.getTopLeft(cards.first).dx, 17);
      expect(t.takeException(), isNull);
    }
    t.view.resetDevicePixelRatio();
    t.view.resetPhysicalSize();
  });
}
