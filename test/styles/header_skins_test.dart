import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/styles/header_skins.dart';

void main() {
  test('kHeaderSkins 每个 id 唯一', () {
    final ids = kHeaderSkins.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id 不能重复:$ids');
  });

  // 本次新增的 6 款(纯 CustomPainter 绘制,不依赖 asset)。
  const newSkins = ['silk', 'bubbles', 'galaxy', 'lowpoly', 'prism', 'terrazzo'];

  test('新增 6 款皮肤都已注册', () {
    for (final id in newSkins) {
      expect(headerSkinById(id), isNotNull, reason: '$id 未注册');
    }
  });

  testWidgets('新增皮肤亮/暗两态都能构建渲染不抛', (tester) async {
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
