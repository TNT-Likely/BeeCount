import 'package:beecount/services/update/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int? compare(String a, String b) => UpdateChecker.compareVersionNames(a, b);

  test('生产3.9到4.0预发布再到正式和补丁严格递增', () {
    const versions = [
      '3.9.0',
      '4.0.0-beta.1',
      '4.0.0-beta.2',
      '4.0.0-beta.10',
      '4.0.0-rc.1',
      '4.0.0',
      '4.0.1-beta.1',
      '4.0.1',
    ];
    for (var i = 1; i < versions.length; i++) {
      expect(compare(versions[i], versions[i - 1]), greaterThan(0));
      expect(compare(versions[i - 1], versions[i]), lessThan(0));
    }
  });

  test('同版正式高于beta，旧beta不因后缀存在就成为更新', () {
    expect(compare('4.0.0', '4.0.0-beta.98'), greaterThan(0));
    expect(compare('4.0.0-beta.98', '4.0.0'), lessThan(0));
    expect(compare('4.0.0-beta.2', '4.0.0-beta.10'), lessThan(0));
    expect(compare('3.9.9', '4.0.0-beta.1'), lessThan(0));
    expect(compare('4.0.0-beta.1', '4.0.0-beta.1'), 0);
  });

  test('完整SemVer预发布标识顺序与数字标识不溢出', () {
    const suffixes = [
      'alpha',
      'alpha.1',
      'alpha.beta',
      'beta',
      'beta.2',
      'beta.11',
      'rc.1',
    ];
    for (var i = 1; i < suffixes.length; i++) {
      expect(compare('4.0.0-${suffixes[i]}', '4.0.0-${suffixes[i - 1]}'),
          greaterThan(0));
    }
    expect(compare('4.0.0-1', '4.0.0-alpha'), lessThan(0));
    expect(compare('4.0.0-beta.99999999999999999999999999999', '4.0.0-beta.10'),
        greaterThan(0));
    expect(compare('4.0.0-beta.2.extra', '4.0.0-beta.2'), greaterThan(0));
  });

  test('保留v和dev前缀与旧短版本，并忽略build metadata排序', () {
    expect(compare('v4.0.0', 'dev-4.0.0-beta.1'), greaterThan(0));
    expect(compare('v3.9.0', '3.9'), 0);
    expect(compare('4.0.0+100', '4.0.0+999'), 0);
    expect(compare('4.0.0-beta.2+build.7', '4.0.0-beta.2+build.9'), 0);
    expect(compare('3', '3.0.0'), 0);
  });

  test('非法版本或数字标识不能被忽略后变成较新版本', () {
    for (final value in [
      'manual-sha',
      '4.foo.1',
      '04.0.0',
      '4.0.0-beta.01',
      '4.0.0-',
      '4.0.0-beta..1',
      '4.0.0+',
      '4.0.0.1',
      '',
    ]) {
      expect(compare(value, '3.9.0'), isNull, reason: value);
      expect(compare('4.0.0', value), isNull, reason: value);
    }
  });
}
