/// 桌面小组件渲染管线的「选哪些 spec 渲染」逻辑([selectSpecsToRender] /
/// [matchInstalledSpecs])单测。
///
/// 覆盖 .docs/home-widget/plan.md D5:只渲已安装的 spec、拿不到已安装列表时
/// 退化为默认集(至少 glance-medium)。这两个函数均为纯函数,不触碰平台
/// 通道(不调用 `HomeWidget.getInstalledWidgets()`),因此可以直接单测。
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';

import 'package:beecount/widget/widget_manager.dart';
import 'package:beecount/widget/widget_spec.dart';

void main() {
  group('selectSpecsToRender', () {
    test('installed 为 null(拿不到列表)时退化为默认集', () {
      expect(selectSpecsToRender(null), WidgetSpec.defaultSet);
      expect(selectSpecsToRender(null), [WidgetSpec.glanceMedium]);
    });

    test('installed 为空列表(确实一个都没装)时不渲染任何内容', () {
      expect(selectSpecsToRender(const []), isEmpty);
    });

    test('只渲染已安装的 spec,不盲渲目录里的其它类型', () {
      // 场景对应 plan.md P1:已安装 {glance-medium, netWorth-medium} →
      // 只应对这两个 spec 渲染,目录里其余 10 个 spec(如 dashboard-large、
      // budget-small)不应出现在结果里。
      final installed = [WidgetSpec.glanceMedium, WidgetSpec.netWorthMedium];
      final result = selectSpecsToRender(installed);

      expect(result, [WidgetSpec.glanceMedium, WidgetSpec.netWorthMedium]);
      expect(result, isNot(contains(WidgetSpec.dashboardLarge)));
      expect(result, isNot(contains(WidgetSpec.budgetSmall)));
      expect(result.length, 2);
    });

    test('按 (type,size) 去重(如 Android 同一 provider 多个实例)', () {
      final installed = [
        WidgetSpec.glanceMedium,
        WidgetSpec.glanceMedium,
        WidgetSpec.netWorthSmall,
      ];
      final result = selectSpecsToRender(installed);
      expect(result, [WidgetSpec.glanceMedium, WidgetSpec.netWorthSmall]);
    });
  });

  group('matchInstalledSpecs', () {
    test('把平台已安装信息映射为目录 spec,丢弃匹配不到的条目', () {
      final infos = [
        HomeWidgetInfo(
          iOSKind: 'BeeCountWidget',
          iOSFamily: 'systemMedium',
        ),
        HomeWidgetInfo(iOSKind: '尚未注册的未来类型'),
        HomeWidgetInfo(
          androidClassName: 'com.tntlikely.beecount.BeeCountWidgetProvider',
          androidWidgetId: 42,
        ),
      ];

      final result = matchInstalledSpecs(infos);

      expect(result, [WidgetSpec.glanceMedium, WidgetSpec.glanceMedium]);
    });

    test('空列表映射为空列表', () {
      expect(matchInstalledSpecs(const []), isEmpty);
    });

    test('与 selectSpecsToRender 组合:Android 同 provider 多实例只渲一次', () {
      final infos = [
        HomeWidgetInfo(
          androidClassName: 'com.tntlikely.beecount.BeeCountWidgetProvider',
          androidWidgetId: 1,
        ),
        HomeWidgetInfo(
          androidClassName: 'com.tntlikely.beecount.BeeCountWidgetProvider',
          androidWidgetId: 2,
        ),
      ];

      final result = selectSpecsToRender(matchInstalledSpecs(infos));

      expect(result, [WidgetSpec.glanceMedium]);
    });
  });
}
