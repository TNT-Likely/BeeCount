import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/providers/sync_providers.dart' show resolvePrimaryFromSync;
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/styles/header_skins.dart';
import 'package:beecount/widgets/ui/skin_animation_scope.dart';

/// 皮肤绑定主题色的交互:
/// 选中自带配色的皮肤 → 主题色自动切成皮肤色并锁定;
/// 换回普通皮肤 → 恢复用户原先手选的颜色(不能把人家调的色弄丢)。
void main() {
  late ProviderContainer container;
  late WidgetRef ref;

  setUp(() {
    container = ProviderContainer();
    ref = _TestRef(container);
  });
  tearDown(() => container.dispose());

  test('切到自带配色皮肤会绑定主题色,换回来能恢复用户手选色', () {
    const userColor = Color(0xFF7E57C2); // 用户自己选的罗兰紫
    container.read(primaryColorProvider.notifier).state = userColor;
    container.read(userChosenPrimaryProvider.notifier).state = userColor;

    // 切到「周年蛋糕」(绑定奶油金)
    applyHeaderSkin(ref, 'anniv_cake');
    expect(container.read(headerSkinProvider), 'anniv_cake');
    expect(container.read(primaryColorProvider), boundPrimaryOf('anniv_cake'));
    expect(container.read(primaryColorProvider), isNot(userColor));
    // 用户手选色被记住,没有被覆盖
    expect(container.read(userChosenPrimaryProvider), userColor);

    // 换回普通皮肤 → 恢复用户色
    applyHeaderSkin(ref, 'aurora');
    expect(container.read(primaryColorProvider), userColor);
  });

  test('普通皮肤之间切换不动主题色', () {
    const userColor = Color(0xFF26A69A);
    container.read(primaryColorProvider.notifier).state = userColor;
    applyHeaderSkin(ref, 'aurora');
    expect(container.read(primaryColorProvider), userColor);
    applyHeaderSkin(ref, 'waves');
    expect(container.read(primaryColorProvider), userColor);
  });

  test('自带配色的皮肤都声明了绑定色,跟随主题色的则没有', () {
    final s = headerSkinById('anniv_cake')!;
    expect(s.hasFixedPalette, isTrue, reason: 'anniv_cake 应自带配色');
    expect(s.boundPrimary, isNotNull, reason: 'anniv_cake 应有绑定色');
    for (final id in ['anniversary', 'aurora']) {
      expect(headerSkinById(id)!.hasFixedPalette, isFalse, reason: '$id 应跟随主题色');
    }
  });

  test('已下架的皮肤 id 安全降级为纯色', () {
    // 老用户可能仍存着这两个 id(本地 prefs 或云端 appearance),
    // headerSkinById 返回 null → PrimaryHeader 走纯色分支,不崩。
    for (final id in ['golden_year', 'honey_flow']) {
      expect(headerSkinById(id), isNull);
      expect(boundPrimaryOf(id), isNull);
    }
  });

  test('秋日系列不在这一版里 —— 留给付费皮肤单独发', () {
    // 免费放出去就收不回来了(见 .docs/skin-monetization-research.md §1.3)。
    // 代码在 feat/autumn-skins 分支上,这里守住「没混进本版」。
    for (final id in [
      'maple',
      'osmanthus_moon',
      'ginkgo',
      'persimmon',
      'autumn_rain',
      'southbound'
    ]) {
      expect(headerSkinById(id), isNull, reason: '$id 不应出现在本版');
    }
  });

  test('两款周年皮肤都带 1st 角标、动效与 tab 装饰', () {
    for (final id in ['anniversary', 'anniv_cake']) {
      final s = headerSkinById(id);
      expect(s, isNotNull, reason: '$id 未注册');
      expect(s!.badge, '1st', reason: '$id 应带周年角标');
      expect(s.isAnimated, isTrue, reason: '$id 应是动态皮肤');
      expect(s.tabBarBuilder, isNotNull, reason: '$id 应有悬浮 tab 装饰');
    }
    // 蛋糕绑定自己的配色,星座跟随主题色
    expect(headerSkinById('anniv_cake')!.hasFixedPalette, isTrue);
    expect(headerSkinById('anniversary')!.hasFixedPalette, isFalse);
  });

  test('已下架的周年账单不再注册,老用户的 id 降级为纯色', () {
    // 这一款做过实装又下架(设计稿的票宽和真实 header 的比例对不上),
    // 开发机上可能还存着这个 id。
    expect(headerSkinById('anniv_receipt'), isNull);
    expect(boundPrimaryOf('anniv_receipt'), isNull);
  });

  // —— 云同步下行:皮肤自带主题色时,两个颜色之间来回闪的 bug ——
  // 根因是 appearance 的 header_skin 被直写进 provider,主题色没跟着走;
  // 加上 server 的 theme_color 与 appearance 是两次独立广播,顺序不定。

  test('从 server 应用绑定色皮肤时,主题色跟着切成绑定色', () {
    const userColor = Color(0xFF7E57C2);
    container.read(primaryColorProvider.notifier).state = userColor;
    container.read(userChosenPrimaryProvider.notifier).state = userColor;

    // 模拟 _applyAppearanceFromServer 走的路径
    applyHeaderSkinWith(container.read, 'anniv_cake');

    expect(container.read(headerSkinProvider), 'anniv_cake');
    expect(container.read(primaryColorProvider), boundPrimaryOf('anniv_cake'),
        reason: '皮肤换了颜色没换 = 半截状态,正是闪烁的来源');
    expect(container.read(userChosenPrimaryProvider), userColor);

    // server 把皮肤换回普通款 → 恢复用户手选色
    applyHeaderSkinWith(container.read, 'aurora');
    expect(container.read(primaryColorProvider), userColor);
  });

  // —— 「开启 BeeCount Cloud 时主题色闪烁」——
  // 一次 syncMyProfile 连着 emit theme_color 和 appearance 两个事件,逐个立刻
  // 写 primaryColorProvider 就会闪两下。下面守的是合并结算的优先级。

  group('同步下行的主题色结算', () {
    const server = Color(0xFF3F51B5); // server 上存的颜色
    const userChosen = Color(0xFF7E57C2); // 本机记的用户手选色

    test('皮肤自带配色 → 皮肤说了算,server 的颜色不作数', () {
      expect(
        resolvePrimaryFromSync(
          boundPrimary: boundPrimaryOf('anniv_cake'),
          serverTheme: server,
          userChosen: userChosen,
          leftBoundPalette: false,
        ),
        boundPrimaryOf('anniv_cake'),
      );
    });

    test('一岁星座这种不绑定配色的皮肤 → 听 server 的', () {
      // 这一条正是「选一岁星座 + 开云同步还是闪」的场景:皮肤没有绑定色,
      // 挡板不生效,必须靠合并结算把两次写压成一次。
      expect(boundPrimaryOf('anniversary'), isNull);
      expect(
        resolvePrimaryFromSync(
          boundPrimary: null,
          serverTheme: server,
          userChosen: userChosen,
          leftBoundPalette: false,
        ),
        server,
      );
    });

    test('刚从绑定色皮肤切走且 server 有值 → server 优先于本机记忆', () {
      // 对端推上来的 theme_color 就是对端恢复后的用户手选色,比本机记忆新
      expect(
        resolvePrimaryFromSync(
          boundPrimary: null,
          serverTheme: server,
          userChosen: userChosen,
          leftBoundPalette: true,
        ),
        server,
      );
    });

    test('刚从绑定色皮肤切走且这批没带 server 颜色 → 回退到用户手选色', () {
      expect(
        resolvePrimaryFromSync(
          boundPrimary: null,
          serverTheme: null,
          userChosen: userChosen,
          leftBoundPalette: true,
        ),
        userChosen,
      );
    });

    test('什么信息都没有 → 返回 null,一个字节都不写(不写就不会闪)', () {
      expect(
        resolvePrimaryFromSync(
          boundPrimary: null,
          serverTheme: null,
          userChosen: userChosen,
          leftBoundPalette: false,
        ),
        isNull,
      );
    });
  });

  test('绑定色皮肤下,server 推来的旧主题色必须被忽略', () {
    // 这条守的是 _applyThemeColorFromServer 里的挡板:它读 headerSkinProvider
    // 判断当前皮肤是否自带配色。绑定色皮肤下 server 的 theme_color 无权改色,
    // 否则 拉旧色→本地推绑定色→server 广播→再拉旧色 会一直乒乓。
    applyHeaderSkinWith(container.read, 'anniv_cake');
    final bound = boundPrimaryOf('anniv_cake');
    expect(bound, isNotNull);
    expect(container.read(primaryColorProvider), bound);
    expect(boundPrimaryOf(container.read(headerSkinProvider)), isNotNull,
        reason: 'apply 侧靠这个判断来挡下 server 的 theme_color');

    // 换成不绑定的皮肤后,挡板放行
    applyHeaderSkinWith(container.read, 'anniversary');
    expect(boundPrimaryOf(container.read(headerSkinProvider)), isNull);
  });

  group('皮肤动效开关', () {
    // 开关不给皮肤加参数,而是翻译成子树的 disableAnimations —— 复用动态皮肤
    // 本来就有的「系统减弱动态效果 → 停在静态帧」那条分支。守住这个翻译。

    Widget probe(void Function(bool) sink) => Builder(builder: (ctx) {
          sink(MediaQuery.disableAnimationsOf(ctx));
          return const SizedBox();
        });

    test('默认开着', () {
      expect(container.read(skinAnimationEnabledProvider), isTrue);
    });

    testWidgets('开着时子树不被置真', (tester) async {
      var disabled = true;
      await tester.pumpWidget(ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(),
          child: SkinAnimationScope(child: probe((v) => disabled = v)),
        ),
      ));
      expect(disabled, isFalse);
    });

    testWidgets('关掉后子树 disableAnimations 置真', (tester) async {
      var disabled = false;
      await tester.pumpWidget(ProviderScope(
        overrides: [skinAnimationEnabledProvider.overrideWith((ref) => false)],
        child: MediaQuery(
          data: const MediaQueryData(),
          child: SkinAnimationScope(child: probe((v) => disabled = v)),
        ),
      ));
      expect(disabled, isTrue, reason: '皮肤据此停在静态帧');
    });

    testWidgets('系统减弱动态效果优先 —— 开关开着也得停', (tester) async {
      var disabled = false;
      await tester.pumpWidget(ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SkinAnimationScope(child: probe((v) => disabled = v)),
        ),
      ));
      expect(disabled, isTrue, reason: '无障碍设置优先级高于皮肤偏好');
    });
  });

  group('下行 apply 的 echo 抑制', () {
    // 「同值不写」只挡得住单端回声。两端各有一次在途 push 时,server 会交替
    // 广播两个值,每次下行写入又触发一次上行 —— 主题色就在两个颜色之间无限
    // 横跳。这正是「一岁星座 + 开 BeeCount Cloud 主题色一直闪」的成因:
    // 绑定色皮肤的结算恒等于 boundPrimary、同值不写所以看不出来,
    // 一岁星座走 server 值分支就暴露了。

    test('默认不在下行态', () {
      expect(isApplyingFromServer, isFalse);
    });

    test('runApplyingFromServer 期间置位,结束后复位', () {
      late bool inside;
      runApplyingFromServer(() {
        inside = isApplyingFromServer;
      });
      expect(inside, isTrue, reason: 'listener 要靠它判断这次写入来自 server');
      expect(isApplyingFromServer, isFalse, reason: '出了闭包必须复位');
    });

    test('闭包抛异常也复位 —— 否则之后所有本地改动都推不上去', () {
      expect(
        () => runApplyingFromServer(() => throw StateError('boom')),
        throwsStateError,
      );
      expect(isApplyingFromServer, isFalse);
    });

    test('嵌套调用不会被内层提前复位', () {
      // appearance 整包 apply 里还会嵌套写别的 provider,内层结束时
      // 外层必须仍是下行态,否则后半段字段又会被推回去。
      late bool afterInner;
      runApplyingFromServer(() {
        runApplyingFromServer(() {});
        afterInner = isApplyingFromServer;
      });
      expect(afterInner, isTrue);
      expect(isApplyingFromServer, isFalse);
    });

    test('返回值原样透出', () {
      expect(runApplyingFromServer(() => 42), 42);
    });
  });

  group('本地推送在途窗口', () {
    // echo 抑制断掉了「一直闪」,但还剩一次:本地改色后 push 还在路上,
    // 这期间一次 syncMyProfile 拉到 server 上**还没被覆盖的旧色**,
    // 采信它就会跳到旧色、等 push 落地再跳回来。

    test('默认不在途', () {
      expect(isThemePushInFlight, isFalse);
    });

    test('开窗后在途,关窗后归零', () {
      final end = beginThemePush();
      expect(isThemePushInFlight, isTrue);
      end();
      expect(isThemePushInFlight, isFalse);
    });

    test('关窗回调幂等 —— 重复关会让计数穿底,之后永远不采信 server', () {
      final end = beginThemePush();
      end();
      end();
      end();
      expect(isThemePushInFlight, isFalse);
      // 穿底的话这里会变成「已在途」,新开的窗口反而关不掉
      final other = beginThemePush();
      expect(isThemePushInFlight, isTrue);
      other();
      expect(isThemePushInFlight, isFalse);
    });

    test('并发多个窗口要全部关掉才算不在途', () {
      // 切皮肤时 headerSkin 和 primaryColor 两个 listener 各开一个
      final a = beginThemePush();
      final b = beginThemePush();
      expect(isThemePushInFlight, isTrue);
      a();
      expect(isThemePushInFlight, isTrue, reason: '还有一个没关');
      b();
      expect(isThemePushInFlight, isFalse);
    });

    test('在途时丢掉 server 的颜色,结算就不会跳到旧色', () {
      // 结算侧把 serverTheme 传 null 来表达「这一份不可信」
      expect(
        resolvePrimaryFromSync(
          boundPrimary: null,
          serverTheme: null, // 在途 → 不采信
          userChosen: const Color(0xFF7E57C2),
          leftBoundPalette: false,
        ),
        isNull,
        reason: '返回 null = 一个字节都不写,颜色停在用户刚选的值上',
      );
    });
  });
}

/// 只为调用 applyHeaderSkin 的最小 WidgetRef 适配。
class _TestRef implements WidgetRef {
  _TestRef(this.container);
  final ProviderContainer container;

  @override
  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
