import 'dart:convert';
import 'dart:io';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('汇率行与HTML标准屏冻结72高度一致', (t) async {
    t.view.physicalSize = const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: const Scaffold(
            body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 17),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  BeeExchangeRateRow(
                      code: 'USD',
                      name: '美元',
                      value: '1 USD = 7.10000 CNY',
                      source: '手动',
                      manual: true)
                ])))));
    await t.pumpAndSettle();
    final frozen = jsonDecode(
        File('test/fixtures/v4-exchange-rate-geometry.json')
            .readAsStringSync()) as Map<String, dynamic>;
    expect(
        t.getSize(find.byType(BeeExchangeRateRow)),
        Size((frozen['manualRowWidth'] as num).toDouble(),
            (frozen['manualRowHeight'] as num).toDouble()));
  });
}
