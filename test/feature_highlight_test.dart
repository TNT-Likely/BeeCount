import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/models/feature_highlight.dart';

/// 新功能红点的判定逻辑。
///
/// 这套东西错了不会崩、也不会报错,只会「该亮的没亮」或者更糟 ——
/// 「所有人满屏红点」。所以判定规则全部在这里钉死。
void main() {
  const catalog = [
    FeatureHighlight(id: 'a', anchors: ['tab', 'x', 'leaf_a']),
    FeatureHighlight(id: 'b', anchors: ['tab', 'leaf_b']),
  ];

  group('亮不亮只看点没点过', () {
    test('没点过的都算未读', () {
      expect(unreadFrom(const {}, catalog: catalog), {'a', 'b'});
    });

    test('点过的不再算', () {
      expect(unreadFrom({'a'}, catalog: catalog), {'b'});
    });

    test('全点过就空了', () {
      expect(unreadFrom({'a', 'b'}, catalog: catalog), isEmpty);
    });

    test('已读里有清单外的陈年 id,不影响判定', () {
      // 功能过气后会从清单里删掉,但已读记录留在 prefs 里 —— 属于无害垃圾
      expect(unreadFrom({'a', 'removed_long_ago'}, catalog: catalog), {'b'});
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
        FeatureHighlight(id: 'p', anchors: ['t', 'same']),
        FeatureHighlight(id: 'q', anchors: ['t', 'same']),
      ];
      expect(featuresConsumedBy('same', catalog: shared), {'p', 'q'});
    });
  });

  group('首次启动的两种人', () {
    // 逻辑在 featureHighlightInitProvider 里,这里守住它依赖的那条语义:
    // 预标记 = 把清单全量塞进已读 → 未读为空 → 一个红点都不亮。
    test('全新安装:清单预置为已读 → 不亮', () {
      final seed = {for (final f in catalog) f.id};
      expect(unreadFrom(seed, catalog: catalog), isEmpty);
    });

    test('老用户升级:什么都不预置 → 全亮', () {
      expect(unreadFrom(const {}, catalog: catalog), {'a', 'b'});
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

    test('清单别攒成历史档案', () {
      // 从很老版本升上来的用户会一次性看到清单里所有条目,超过几条就是噪音。
      // 触发这条时该做的是把过气的功能摘掉,而不是改大这个数。
      expect(kFeatureHighlights.length, lessThanOrEqualTo(5),
          reason: '清单只放最近在推的功能,发布几个版本后就该删');
    });
  });
}
