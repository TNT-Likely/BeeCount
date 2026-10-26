import 'dart:convert';
import 'dart:io';
import 'package:beecount/presentation/v4/bindings/category_line_icon_names.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('生产页面固定图标与全部分类映射均已实际打包', () async {
    final manifest =
        jsonDecode(await rootBundle.loadString('AssetManifest.json')) as Map;
    final names = {
      ...categoryLineIconNames.values,
      'Grid2x2',
      'Network',
      'Plus',
      'SunMoon',
      'Sun',
      'Moon',
      'Maximize',
      'Minimize',
      'List',
      'History',
      'ArrowLeftRight',
      'Banknote',
      'Image',
      'Languages',
      'Palette',
      'Settings2',
      'TrendingUp',
      'TrendingDown'
    };
    final literal = RegExp(r"BeeLineIcon\(\s*'([A-Za-z][A-Za-z0-9]*)'");
    final registry =
        jsonDecode(File('tool/v4/lucide-icon-names.json').readAsStringSync())
            as Map;
    final vendor =
        File('docs/design/card-refresh/prototype/vendor/lucide.min.js');
    expect(sha256.convert(vendor.readAsBytesSync()).toString(),
        registry['vendorSha256']);
    final knownNames = (registry['names'] as List).cast<String>().toSet();
    final namedValue = RegExp(r'''['"]([A-Z][A-Za-z0-9]+)['"]''');
    for (final root in [
      'lib',
      'packages/beecount_ui/lib',
      'packages/beecount_business_ui/lib'
    ]) {
      for (final file
          in Directory(root).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') ||
            file.path.endsWith('.g.dart') ||
            file.path.contains('/l10n/')) {
          continue;
        }
        final source = file.readAsStringSync();
        names
            .addAll(literal.allMatches(source).map((match) => match.group(1)!));
        // Include names passed through tuples, data models and _visual helpers.
        names.addAll(namedValue
            .allMatches(source)
            .map((match) => match.group(1)!)
            .where(knownNames.contains));
      }
    }
    for (final name in names) {
      final path = 'packages/beecount_ui/assets/icons/$name.svg';
      expect(manifest.containsKey(path), isTrue, reason: name);
      expect(await rootBundle.loadString(path), contains('<svg'));
    }
  });
}
