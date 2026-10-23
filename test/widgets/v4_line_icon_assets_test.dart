import 'dart:convert';
import 'dart:io';
import 'package:beecount/presentation/v4/bindings/category_line_icon_names.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('生产页面固定图标与全部分类映射均已实际打包', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('AssetManifest.json')) as Map;
    final names = {...categoryLineIconNames.values};
    final literal = RegExp(r"BeeLineIcon\(\s*'([A-Za-z][A-Za-z0-9]*)'");
    for (final root in [
      'lib',
      'packages/beecount_ui/lib',
      'packages/beecount_business_ui/lib'
    ]) {
      for (final file
          in Directory(root).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') || file.path.endsWith('.g.dart')) {
          continue;
        }
        names.addAll(literal
            .allMatches(file.readAsStringSync())
            .map((match) => match.group(1)!));
      }
    }
    for (final name in names) {
      final path = 'packages/beecount_ui/assets/icons/$name.svg';
      expect(manifest.containsKey(path), isTrue, reason: name);
      expect(await rootBundle.loadString(path), contains('<svg'));
    }
  });
}
