import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/styles/header_skins.dart';

void main() {
  test('kHeaderSkins 每个 id 唯一', () {
    final ids = kHeaderSkins.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id 不能重复:$ids');
  });

  // The approved static catalogue is intentionally limited to these two.
  const newSkins = ['aurora', 'mountains'];

  test('只保留两款静态皮肤与两款周年动态', () {
    expect(kHeaderSkins.where((s) => !s.isAnimated).map((s) => s.id), newSkins);
    expect(kHeaderSkins.where((s) => s.isAnimated).map((s) => s.id),
        ['anniversary', 'anniv_cake']);
  });

  testWidgets('保留的静态皮肤亮/暗两态可正常渲染', (tester) async {
    for (final id in newSkins) {
      final skin = headerSkinById(id)!;
      for (final dark in [false, true]) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 96,
              child: skin.builder(const Color(0xFF3B82F6), dark),
            ),
          ),
        ));
        expect(tester.takeException(), isNull, reason: '$id dark=$dark 渲染抛异常');
      }
    }
  });
}
