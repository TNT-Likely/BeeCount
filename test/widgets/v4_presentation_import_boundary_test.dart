import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('两个纯表现组件包不依赖App、Riverpod、Repo或网络服务', () {
    for (final name in ['beecount_ui', 'beecount_business_ui']) {
      final allowed = ['package:flutter/', 'package:beecount_ui/', 'dart:'];
      if (name == 'beecount_ui') allowed.add('package:flutter_svg/');
      final files = Directory('packages/$name/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in files) {
        final directives = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''')
            .allMatches(file.readAsStringSync());
        for (final match in directives) {
          final path = match[1]!;
          expect(path, isNot('dart:io'),
              reason:
                  '${file.path}: presentation must not access filesystem or network');
          if (path.startsWith('package:')) {
            expect(allowed.any(path.startsWith), isTrue,
                reason: '${file.path}: $path');
          } else if (path.startsWith('../')) {
            final target =
                File('${file.parent.path}/$path').resolveSymbolicLinksSync();
            expect(target.startsWith(Directory('packages/$name').absolute.path),
                isTrue,
                reason: '${file.path}: $path');
          }
        }
      }
    }
  });
}
