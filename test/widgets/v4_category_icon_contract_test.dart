import 'dart:io';

import 'package:beecount/presentation/v4/bindings/category_line_icon_names.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('原版全部内置分类标识均有线框映射与实际可读取的资源', () async {
    final source = File('lib/services/data/category_service.dart')
        .readAsStringSync()
        .split('static IconData getCategoryIcon(')
        .last;
    final savedIdentifiers = RegExp("case '([^']+)':")
        .allMatches(source)
        .map((m) => m.group(1)!);
    expect(savedIdentifiers.length, greaterThan(250));
    for (final name in savedIdentifiers) {
      expect(categoryLineIconNames[name], isNotNull,
          reason: '历史分类 $name 不能回退成不同风格的实心图标');
    }
    for (final name in categoryLineIconNames.values.toSet()) {
      final svg = await rootBundle
          .loadString('packages/beecount_ui/assets/icons/$name.svg');
      expect(svg, contains('fill="none"'), reason: name);
      expect(svg, contains('stroke-width="1.8"'), reason: name);
    }
  });
}
