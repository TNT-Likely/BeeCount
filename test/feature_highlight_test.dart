import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/models/feature_highlight.dart';
import 'package:beecount/providers/feature_highlight_providers.dart';

/// 新功能红点的判定逻辑。
///
/// 这套东西错了不会崩、也不会报错,只会「该亮的没亮」或者更糟 ——
/// 「所有人满屏红点」。所以判定规则全部在这里钉死。
void main() {
  const catalog = [
    FeatureHighlight(id: 'a', version: '3.8.0', anchors: ['tab', 'x', 'leaf_a']),
    FeatureHighlight(id: 'b', version: '3.8.0', anchors: ['tab', 'leaf_b']),
    FeatureHighlight(id: 'old', version: '3.5.0', anchors: ['tab', 'leaf_old']),
    FeatureHighlight(id: 'future', version: '9.9.9', anchors: ['tab', 'leaf_f']),
  ];

  group('版本比较', () {
    test('逐段比大小,不是字符串比较', () {
      expect(compareVersions('3.10.0', '3.9.0') > 0, isTrue,
          reason: '按字符串比 "3.10" < "3.9",必须按数字段');
      expect(compareVersions('3.8.0', '3.8.0'), 0);
      expect(compareVersions('3.8.1', '3.8.0') > 0, isTrue);
      expect(compareVersions('4.0.0', '3.99.99') > 0, isTrue);
    });

    test('缺段补 0', () {
      expect(compareVersions('3.8', '3.8.0'), 0);
      expect(compareVersions('3', '3.0.0'), 0);
    });

    test('后缀截断后再比', () {
      expect(compareVersions('3.8.0-beta', '3.8.0'), 0);
      expect(compareVersions('3.8.0+42', '3.8.0'), 0);
    });

    test('解析不出的段按 0 —— 宁可少亮,也不能因为格式意外满屏红点', () {
      expect(compareVersions('abc', '0.0.0'), 0);
      expect(compareVersions('3.x.0', '3.0.0'), 0);
    });
  });

  group('这次升级该亮哪些', () {
    test('首次安装一个都不亮', () {
      // 新用户眼里所有功能都是新的,全亮等于全噪音
      expect(
        pendingFeatureIds(
            previousVersion: null, currentVersion: '3.8.0', catalog: catalog),
        isEmpty,
      );
    });

    test('只亮区间 (上次启动, 当前] 内首发的', () {
      expect(
        pendingFeatureIds(
            previousVersion: '3.7.0',
            currentVersion: '3.8.0',
            catalog: catalog),
        {'a', 'b'},
        reason: '3.5.0 的太旧,9.9.9 的还没发布',
      );
    });

    test('等于上次启动版本的不算 —— 那是上个版本就有的', () {
      expect(
        pendingFeatureIds(
            previousVersion: '3.8.0',
            currentVersion: '3.8.0',
            catalog: catalog),
        isEmpty,
      );
    });

    test('清单里提前登记的未来版本不提前泄露', () {
      // 开发期常见:功能已合并、版本号写的是下一版
      expect(
        pendingFeatureIds(
            previousVersion: '3.8.0',
            currentVersion: '3.9.0',
            catalog: catalog),
        isEmpty,
        reason: '9.9.9 还没到,3.8.0 的已经算过了',
      );
    });

    test('跨多个版本升级,中间漏掉的一并补上', () {
      expect(
        pendingFeatureIds(
            previousVersion: '3.4.0',
            currentVersion: '3.8.0',
            catalog: catalog),
        {'a', 'b', 'old'},
      );
    });
  });

  group('红点显示在路径的每一级', () {
    test('路径上任意一级都亮,不只是叶子', () {
      expect(anchorHasUnread('tab', {'a'}, catalog: catalog), isTrue);
      expect(anchorHasUnread('x', {'a'}, catalog: catalog), isTrue);
      expect(anchorHasUnread('leaf_a', {'a'}, catalog: catalog), isTrue);
    });

    test('不在路径上的锚点不亮', () {
      expect(anchorHasUnread('leaf_b', {'a'}, catalog: catalog), isFalse);
    });

    test('已读的不亮', () {
      expect(anchorHasUnread('tab', const {}, catalog: catalog), isFalse);
    });

    test('共享的上级锚点:只要还有一个没读就继续亮', () {
      // tab 同时是 a 和 b 的入口,读完 a 之后 tab 仍要为 b 亮着
      expect(anchorHasUnread('tab', {'b'}, catalog: catalog), isTrue);
    });
  });

  group('只有叶子锚点消费红点', () {
    test('走到叶子才算看到', () {
      expect(featuresConsumedBy('leaf_a', catalog: catalog), {'a'});
    });

    test('路过中间层级不消费 —— 否则红点还没把人指到位就熄了', () {
      expect(featuresConsumedBy('x', catalog: catalog), isEmpty);
      expect(featuresConsumedBy('tab', catalog: catalog), isEmpty);
    });

    test('一个叶子挂多个功能时一起消费', () {
      const shared = [
        FeatureHighlight(id: 'p', version: '3.8.0', anchors: ['t', 'same']),
        FeatureHighlight(id: 'q', version: '3.8.0', anchors: ['t', 'same']),
      ];
      expect(featuresConsumedBy('same', catalog: shared), {'p', 'q'});
    });
  });

  group('当前版本解析', () {
    test('pubspec 是占位的 0.0.1 时回退成清单最大版本', () {
      // 否则本地开发永远看不到红点,没法自测
      final v = resolveCurrentVersion('0.0.1');
      expect(compareVersions(v, '0.0.1') > 0, isTrue);
    });

    test('真实版本号原样用', () {
      expect(resolveCurrentVersion('3.7.2'), '3.7.2');
    });
  });

  group('真实清单的自检', () {
    test('id 唯一', () {
      final ids = kFeatureHighlights.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'id 重复会导致已读状态互相覆盖');
    });

    test('每条都有非空路径', () {
      for (final f in kFeatureHighlights) {
        expect(f.anchors, isNotEmpty, reason: '${f.id} 没有入口路径,红点无处可挂');
      }
    });

    test('版本号解析得出来', () {
      for (final f in kFeatureHighlights) {
        expect(compareVersions(f.version, '0.0.0') > 0, isTrue,
            reason: '${f.id} 的版本号 ${f.version} 解析成了 0.0.0');
      }
    });
  });
}
