import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_history.dart';
import '../services/system/logger_service.dart';
import '../styles/header_skins.dart';
import '../theme.dart';
import '../widget/widget_manager.dart';
import '../providers.dart';

// 主题模式Provider（默认跟随系统）
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// 主题模式持久化初始化
final themeModeInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('themeMode');
  if (saved != null) {
    switch (saved) {
      case 'light':
        ref.read(themeModeProvider.notifier).state = ThemeMode.light;
        break;
      case 'dark':
        ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
        break;
      default:
        ref.read(themeModeProvider.notifier).state = ThemeMode.system;
    }
  }
  ref.listen<ThemeMode>(themeModeProvider, (prev, next) async {
    String value;
    switch (next) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      default:
        value = 'system';
    }
    await prefs.setString('themeMode', value);
  });
});

// 可变主色（个性化换装使用）
final primaryColorProvider = StateProvider<Color>((ref) => BeeTheme.honeyGold);

// 是否隐藏金额显示
final hideAmountsProvider = StateProvider<bool>((ref) => false);

// 字体选择Provider - 已移除，仅使用系统默认字体

// 主题色持久化初始化：
// - 启动时加载保存的主色
// - 监听主色变化并写入本地
final primaryColorInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getInt('primaryColor');
  if (saved != null) {
    ref.read(primaryColorProvider.notifier).state = Color(saved);
  }
  ref.listen<Color>(primaryColorProvider, (prev, next) async {
    // 同步捕获 —— 下面有 await,await 之后标志早被 finally 清掉了
    final fromServer = isApplyingFromServer;
    // 窗口也必须**同步**开:下面的 prefs 写入和小组件重绘都要 await,
    // 等推送那一步才开就晚了,空窗期里 server 的旧色会被下行采信。
    final endPush = fromServer ? null : beginThemePush();
    try {
      await _persistAndPushPrimary(ref, prefs, next, fromServer);
    } finally {
      endPush?.call();
    }
  });
});

/// primaryColor 变化后的落盘 + 小组件刷新 + 上行推送。
/// 抽出来只是为了让 listener 那层能用 try/finally 卡住推送窗口。
Future<void> _persistAndPushPrimary(
    Ref ref, SharedPreferences prefs, Color next, bool fromServer) async {
  {
    final colorValue = (next.a * 255).toInt() << 24 | (next.r * 255).toInt() << 16 | (next.g * 255).toInt() << 8 | (next.b * 255).toInt();
    await prefs.setInt('primaryColor', colorValue);
    // Update widget with new theme color
    try {
      final repository = ref.read(repositoryProvider);
      final currentLedgerId = ref.read(currentLedgerIdProvider);
      final redForIncome = ref.read(incomeExpenseColorSchemeProvider);
      final baseCurrency = ref.read(baseCurrencyProvider);
      // 没有 BuildContext,靠 languageProvider 还原当前 App 语言(见
      // widget_manager.dart resolveWidgetLocalizations 文档)。
      final locale = ref.read(languageProvider);
      final widgetManager = WidgetManager();
      await widgetManager.updateAllWidgetsLocalized(
        repository,
        currentLedgerId,
        next,
        explicitLocale: locale,
        redForIncome: redForIncome,
        baseCurrency: baseCurrency,
      );
    } catch (e) {
      // Silently fail
    }

    // 推送主题色到 server，让 web 端通过 WS profile_change 自动跟随。
    // 同步方向单向：mobile → server → web；web 本地改色不回推。
    //
    // 这个值本身就是 server 推下来的时候不能再推回去 —— 否则和对端在途的
    // push 交替触发,颜色无限横跳(见 [runApplyingFromServer])。
    if (fromServer) return;
    try {
      final cloudProvider =
          await ref.read(beecountCloudProviderInstance.future);
      if (cloudProvider == null) return;
      final hex = _colorToHex(next);
      await cloudProvider.updateMyProfileThemeColor(hex: hex);
      logger.info('theme_providers', 'primary color pushed to server: $hex');
    } catch (e) {
      logger.warning(
          'theme_providers', 'push primary color failed (non-blocking): $e');
    }
  }
}

// ==================== 下行 apply 的 echo 抑制 ====================
//
// 主题色 / 皮肤的 listener 一律把新值推给 server(见上面的 push 块和
// `_pushAppearanceToCloud`)。问题是**下行 apply 也是写同一个 provider**,
// 于是「server 推下来 → 本地写入 → listener 又推回 server」构成回环。
//
// 单看一次不出事(server 收到相同值不再广播),但两端各有一次在途 push 时就会
// 交替到达、互相触发,主题色在两个颜色之间**无限横跳** —— 这就是「开启
// BeeCount Cloud 后一岁星座主题色一直闪」的成因。
//
// 绑定配色的皮肤看不出来:它们的结算恒等于 boundPrimary,同值不写自然不推。
// 一岁星座不绑定配色,走的是 server 值分支,回环就暴露了。
//
// 只压上行,**不压本地持久化和桌面小组件刷新** —— 那两件事不论值从哪来都得做。
bool _applyingFromServer = false;

/// 下行 apply 期间为 true。listener 用它决定「这个值要不要推回 server」。
bool get isApplyingFromServer => _applyingFromServer;

/// 把一段下行写入包起来,期间产生的 provider 变更不回推 server。
/// 必须是**同步**闭包:Riverpod 的 listener 同步触发,await 之后标志就失效了。
T runApplyingFromServer<T>(T Function() body) {
  final prev = _applyingFromServer;
  _applyingFromServer = true;
  try {
    return body();
  } finally {
    _applyingFromServer = prev;
  }
}

// ==================== 本地主题色「推送在途」窗口 ====================
//
// echo 抑制解决了「无限横跳」,但还剩**一次**闪:
//
//   用户切皮肤 → 本地写新色 → push 异步发出(还没到 server)
//   → 这期间一次 syncMyProfile 拉到 server 上的**旧颜色**
//   → 结算采信它、跳到旧色 → push 到达、server 广播回来 → 又跳回新色
//
// 本地用户刚做出的选择,比 server 上那个我们自己还没覆盖掉的旧值更可信。
// 所以推送在途期间,下行的 theme_color 一律不采信。
//
// 用计数而不是 bool:切皮肤会同时改 headerSkin 和 primaryColor,
// 两个 listener 各推一次,窗口要叠着算。
int _themePushInFlight = 0;

/// 本地主题色是否有推送还没落地。
bool get isThemePushInFlight => _themePushInFlight > 0;

/// 同步开一个「本地外观改动还没落到 server」的窗口,返回关窗回调(幂等)。
///
/// **必须在 listener 的同步段调用**,不能等到真正发请求时才开 —— 那之间隔着
/// prefs 写入和桌面小组件重绘两段 await(小组件那步要渲染图片,几百毫秒),
/// 窗口没开的这段时间里下行照样会采信 server 的旧色。
///
/// 实测症状:枫叶(绑定枫红)→ 一岁星座,主题色「黄 → 红 → 黄」跳三下。
/// 第一跳是正确的恢复用户手选色,第二跳就是这个空窗期里被 server 上
/// 还没来得及覆盖的枫红顶掉,第三跳是 push 落地后广播回来。
void Function() beginThemePush() {
  _themePushInFlight++;
  var closed = false;
  return () {
    // 幂等:重复关会让计数穿底,之后就永远不采信 server 的颜色了
    if (closed) return;
    closed = true;
    _themePushInFlight--;
  };
}

/// Flutter [Color] → `#RRGGBB`。忽略 alpha，server 只存 6 位 hex。
String _colorToHex(Color color) {
  final r = (color.r * 255).toInt() & 0xff;
  final g = (color.g * 255).toInt() & 0xff;
  final b = (color.b * 255).toInt() & 0xff;
  return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

// 隐私模式持久化初始化：
// - 启动时加载保存的隐私模式状态
// - 监听隐私模式变化并写入本地
final hideAmountsInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('hideAmounts');
  if (saved != null) {
    ref.read(hideAmountsProvider.notifier).state = saved;
  }
  ref.listen<bool>(hideAmountsProvider, (prev, next) async {
    await prefs.setBool('hideAmounts', next);
  });
});

/// 资产页「净值走势 / 资产构成」视图选择，持久化记住用户偏好（跨会话）。
enum AssetTrendView { trend, composition }

final assetTrendViewProvider =
    StateNotifierProvider<AssetTrendViewNotifier, AssetTrendView>(
        (ref) => AssetTrendViewNotifier());

class AssetTrendViewNotifier extends StateNotifier<AssetTrendView> {
  static const _key = 'assetTrendView';
  AssetTrendViewNotifier() : super(AssetTrendView.trend) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_key) == 'composition') {
      state = AssetTrendView.composition;
    }
  }

  Future<void> select(AssetTrendView v) async {
    if (state == v) return;
    state = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, v == AssetTrendView.composition ? 'composition' : 'trend');
  }
}

// 字体持久化初始化 - 已移除，仅使用系统默认字体

// Header装饰样式Provider
// 可选值：'icons'（图标平铺）、'particles'（粒子星星）、'honeycomb'（蜂巢六边形）
final headerDecorationStyleProvider = StateProvider<String>((ref) => 'icons');

// 金额显示格式Provider（默认显示完整金额）
// false = 完整金额（如 123,456.78）
// true = 简洁显示（如 12.3万）
final compactAmountProvider = StateProvider<bool>((ref) => false);

// 金额显示格式持久化初始化
final compactAmountInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('compactAmount');
  if (saved != null) {
    ref.read(compactAmountProvider.notifier).state = saved;
  }
  ref.listen<bool>(compactAmountProvider, (prev, next) async {
    await prefs.setBool('compactAmount', next);
    _pushAppearanceToCloud(ref);
  });
});

// 显示交易时间Provider（默认不显示）
// false = 只显示日期
// true = 显示日期和时间（时:分）
final showTransactionTimeProvider = StateProvider<bool>((ref) => false);

// 显示交易时间持久化初始化
final showTransactionTimeInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('showTransactionTime');
  if (saved != null) {
    ref.read(showTransactionTimeProvider.notifier).state = saved;
  }
  ref.listen<bool>(showTransactionTimeProvider, (prev, next) async {
    await prefs.setBool('showTransactionTime', next);
    _pushAppearanceToCloud(ref);
  });
});

// 备注显示方式 Provider(默认分类优先)
// 'category' = 分类名为主,备注挂括号小灰字(当前样式)
// 'note'     = 备注优先,有备注显示备注、无备注显示分类名
final noteDisplayModeProvider = StateProvider<String>((ref) => 'category');

// 备注显示方式持久化初始化
final noteDisplayModeInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('noteDisplayMode');
  if (saved != null) {
    ref.read(noteDisplayModeProvider.notifier).state = saved;
  }
  ref.listen<String>(noteDisplayModeProvider, (prev, next) async {
    await prefs.setString('noteDisplayMode', next);
    _pushAppearanceToCloud(ref);
  });
});

/// 历史备注的默认查询范围，保持原有全账本行为。
final noteHistoryScopeProvider =
    StateProvider<NoteHistoryScope>((ref) => NoteHistoryScope.allCategories);

/// 历史备注的默认排序规则，保持原有按使用次数排序行为。
final noteHistorySortProvider =
    StateProvider<NoteHistorySort>((ref) => NoteHistorySort.frequency);

/// 历史备注展示数量的默认值，保持原有最多展示 20 条的行为。
const noteHistoryDefaultLimit = 20;

/// 历史备注展示数量允许的最小值，避免空列表配置。
const noteHistoryMinLimit = 1;

/// 历史备注展示数量允许的最大值，避免单次加载过多候选。
const noteHistoryMaxLimit = 100;

/// 历史备注当前展示数量。
final noteHistoryLimitProvider =
    StateProvider<int>((ref) => noteHistoryDefaultLimit);

/// 初始化历史备注偏好，并在用户修改时持久化及同步外观配置。
final noteHistoryPreferencesInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final savedScope = prefs.getString('noteHistoryScope');
  final savedSort = prefs.getString('noteHistorySort');
  final savedLimit = prefs.getInt('noteHistoryLimit');

  // 旧版本缺失或配置异常时使用默认值，并回写规范值保证后续导出完整。
  var scope = NoteHistoryScope.allCategories;
  if (savedScope != null) {
    try {
      scope = NoteHistoryScope.values.byName(savedScope);
    } on ArgumentError {
      scope = NoteHistoryScope.allCategories;
    }
  }
  ref.read(noteHistoryScopeProvider.notifier).state = scope;

  var sort = NoteHistorySort.frequency;
  if (savedSort != null) {
    try {
      sort = NoteHistorySort.values.byName(savedSort);
    } on ArgumentError {
      sort = NoteHistorySort.frequency;
    }
  }
  ref.read(noteHistorySortProvider.notifier).state = sort;

  var limit = noteHistoryDefaultLimit;
  if (savedLimit != null &&
      savedLimit >= noteHistoryMinLimit &&
      savedLimit <= noteHistoryMaxLimit) {
    limit = savedLimit;
  }
  ref.read(noteHistoryLimitProvider.notifier).state = limit;

  // ref.listen 不会为初始值触发回调，首次启动时主动落库供配置导出使用。
  await prefs.setString('noteHistoryScope', scope.name);
  await prefs.setString('noteHistorySort', sort.name);
  await prefs.setInt('noteHistoryLimit', limit);

  ref.listen<NoteHistoryScope>(noteHistoryScopeProvider, (prev, next) async {
    // 用户选择变化后写本机偏好，并在 BeeCount Cloud 模式下同步。
    await prefs.setString('noteHistoryScope', next.name);
    _pushAppearanceToCloud(ref);
  });
  ref.listen<NoteHistorySort>(noteHistorySortProvider, (prev, next) async {
    // 用户选择变化后写本机偏好，并在 BeeCount Cloud 模式下同步。
    await prefs.setString('noteHistorySort', next.name);
    _pushAppearanceToCloud(ref);
  });
  ref.listen<int>(noteHistoryLimitProvider, (prev, next) async {
    // 用户修改数量后写本机偏好，并在 BeeCount Cloud 模式下同步。
    await prefs.setInt('noteHistoryLimit', next);
    _pushAppearanceToCloud(ref);
  });
});

// Header装饰样式持久化初始化
final headerDecorationStyleInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('headerDecorationStyle');
  if (saved != null) {
    ref.read(headerDecorationStyleProvider.notifier).state = saved;
  }
  ref.listen<String>(headerDecorationStyleProvider, (prev, next) async {
    await prefs.setString('headerDecorationStyle', next);
    _pushAppearanceToCloud(ref);
  });
});

// 头部皮肤:跟随主题色的装饰层 id;'none' = 纯主题色。见 lib/styles/header_skins.dart。
// 本地持久化 + 并入 appearance 包,随 BeeCount Cloud 多设备同步。
final headerSkinProvider = StateProvider<String>((ref) => 'none');

final headerSkinInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('headerSkin');
  if (saved != null) {
    ref.read(headerSkinProvider.notifier).state = saved;
  }
  final savedUserColor = prefs.getInt('userChosenPrimaryColor');
  if (savedUserColor != null) {
    ref.read(userChosenPrimaryProvider.notifier).state = Color(savedUserColor);
  }
  // 启动校正:皮肤可能是从云端同步下来的,主题色未必跟着绑定色走。
  final bound = boundPrimaryOf(ref.read(headerSkinProvider));
  if (bound != null && ref.read(primaryColorProvider) != bound) {
    ref.read(primaryColorProvider.notifier).state = bound;
  }
  ref.listen<String>(headerSkinProvider, (prev, next) async {
    final fromServer = isApplyingFromServer;
    // 同 primaryColor:窗口要在 prefs 那个 await 之前同步开。
    // 切皮肤时这两个 listener 都会开一次,计数叠着,最后一个关完才算落地。
    final endPush = fromServer ? null : beginThemePush();
    try {
      await prefs.setString('headerSkin', next);
      if (fromServer) return; // server 推下来的皮肤不再推回去
      _pushAppearanceToCloud(ref); // 它内部自己再开一个窗口接力
    } finally {
      endPush?.call();
    }
  });
  ref.listen<Color>(userChosenPrimaryProvider, (prev, next) async {
    await prefs.setInt('userChosenPrimaryColor', _colorToInt(next));
  });

  // 启动校正 ②:皮肤 id 可能指向一款**已经下架**的皮肤(本地存的老值,或者
  // 别的老版本设备同步上去、又推下来的)。UI 层 headerSkinById 返回 null 会
  // 自动渲染成纯色,看着没事,但 provider 里那个失效 id 不清掉就会:
  //   - 一直被推给 server,cloud 那边永远停在下架的皮肤上
  //   - 皮肤选择页里选不中任何一项
  //
  // 必须放在 listener 注册**之后** —— 降级结果要走正常上行推给 server,
  // 这样 server 上那个失效 id 才会被覆盖掉,不然下次同步又推回来。
  final currentSkin = ref.read(headerSkinProvider);
  if (currentSkin != kHeaderSkinNone && headerSkinById(currentSkin) == null) {
    logger.info('theme_providers',
        'header skin "$currentSkin" no longer registered, falling back to none');
    ref.read(headerSkinProvider.notifier).state = kHeaderSkinNone;
    // 下架的多半是绑定配色的皮肤,主题色还停在它的绑定色上。皮肤都没了,
    // 就把颜色还给用户自己选的那个 —— boundPrimaryOf 现在已经认不出它,
    // 走不到 applyHeaderSkin 里恢复手选色的那条分支。
    final userColor = ref.read(userChosenPrimaryProvider);
    if (ref.read(primaryColorProvider) != userColor) {
      ref.read(primaryColorProvider.notifier).state = userColor;
    }
  }
});

/// 用户**手动选择**的主题色,与皮肤绑定色分开记。
/// 选中绑定色皮肤时不覆盖它,换回普通皮肤时用它恢复,
/// 用户就不会因为试了一款秋日皮肤而丢掉自己调的颜色。
final userChosenPrimaryProvider =
    StateProvider<Color>((ref) => BeeTheme.honeyGold);

int _colorToInt(Color c) =>
    (c.a * 255).toInt() << 24 |
    (c.r * 255).toInt() << 16 |
    (c.g * 255).toInt() << 8 |
    (c.b * 255).toInt();

/// 切换头部皮肤,并处理**主题色绑定**:
/// - 切到绑定色皮肤:先把当前颜色记进 [userChosenPrimaryProvider],再切成皮肤色;
/// - 从绑定色皮肤切回普通皮肤:恢复用户原先手选的颜色。
///
/// 皮肤页与任何需要换皮肤的地方都走这里,别直接改 [headerSkinProvider],
/// 否则会出现「头部秋色、按钮蜜黄」的割裂。
void applyHeaderSkin(WidgetRef ref, String skinId) =>
    applyHeaderSkinWith(ref.read, skinId);

/// `Ref` / `WidgetRef` 通用的读取器 —— 两者的 `read` 签名一致,直接 tear-off
/// 传进来,[applyHeaderSkinWith] 就能同时服务 UI 和云同步 apply 侧。
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// [applyHeaderSkin] 的实现体。云同步下行(`_applyAppearanceFromServer`)必须
/// 也走这里 —— 直写 [headerSkinProvider] 会让「皮肤是绑定色款、主题色还是旧色」
/// 这种自相矛盾的状态漏出去,再叠加 server 回推就变成两个颜色来回闪。
void applyHeaderSkinWith(ProviderReader read, String skinId) {
  final prevBound = boundPrimaryOf(read(headerSkinProvider));
  final nextBound = boundPrimaryOf(skinId);

  if (prevBound == null && nextBound != null) {
    // 离开自由配色前,记住用户当前的颜色
    read(userChosenPrimaryProvider.notifier).state = read(primaryColorProvider);
  }
  read(headerSkinProvider.notifier).state = skinId;

  if (nextBound != null) {
    read(primaryColorProvider.notifier).state = nextBound;
  } else if (prevBound != null) {
    read(primaryColorProvider.notifier).state = read(userChosenPrimaryProvider);
  }
}

/// 把 header_decoration_style / compact_amount / show_transaction_time
/// 的当前值打包推给 server 的 /profile/me。非 BeeCount Cloud 模式 provider
/// 返回 null 直接跳过。fire-and-forget,失败只打 warning。
///
/// 用整包 PATCH 是故意的:三者属于同一组"外观",任何一个改动都重发全量,server
/// 写入 appearance_json 整体替换,对端用 WS profile_change 事件拉 /profile/me
/// 拿到最新 dict 应用。
///
/// **绑定主题色的皮肤要先把颜色推上去再推 appearance。** theme_color 和
/// appearance 是 server 上两个字段、两次广播,各自触发对端一次 apply。如果
/// appearance 先落地,对端会在「新皮肤 + server 上还是旧颜色」的组合下走一遍
/// apply,颜色就会先跳旧色再跳回绑定色 —— 用户看到的就是两个主题色之间闪。
/// 这里串行 await 保证对端收到 header_skin 变更时,server 上的颜色已经对齐。
void _pushAppearanceToCloud(Ref ref) {
  // 同步开窗口:皮肤和颜色都还没落到 server 的这段时间里,下行拿到的是旧值,
  // 采信它就会闪一下(见 [beginThemePush])。
  final endPush = beginThemePush();
  unawaited(() async {
    try {
      final cloudProvider =
          await ref.read(beecountCloudProviderInstance.future);
      if (cloudProvider == null) return;
      final bound = boundPrimaryOf(ref.read(headerSkinProvider));
      if (bound != null) {
        final hex = _colorToHex(bound);
        await cloudProvider.updateMyProfileThemeColor(hex: hex);
        logger.info('theme_providers',
            'bound skin color pushed before appearance: $hex');
      }
      final appearance = <String, dynamic>{
        'header_decoration_style': ref.read(headerDecorationStyleProvider),
        'compact_amount': ref.read(compactAmountProvider),
        'show_transaction_time': ref.read(showTransactionTimeProvider),
        'header_skin': ref.read(headerSkinProvider),
        'note_display_mode': ref.read(noteDisplayModeProvider),
        'note_history_scope': ref.read(noteHistoryScopeProvider).name,
        'note_history_sort': ref.read(noteHistorySortProvider).name,
        'note_history_limit': ref.read(noteHistoryLimitProvider),
      };
      await cloudProvider.updateMyProfileAppearance(appearance: appearance);
      logger.info(
          'theme_providers', 'pushed appearance to server: $appearance');
    } catch (e, st) {
      logger.warning(
          'theme_providers', 'push appearance failed (non-blocking): $e', st);
    } finally {
      endPush();
    }
  }());
}

// 收支颜色方案Provider（默认红色收入、绿色支出）
// true = 红色收入、绿色支出
// false = 红色支出、绿色收入
final incomeExpenseColorSchemeProvider = StateProvider<bool>((ref) => true);

// 收支颜色方案持久化初始化
final incomeExpenseColorSchemeInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('incomeExpenseColorScheme');
  if (saved != null) {
    ref.read(incomeExpenseColorSchemeProvider.notifier).state = saved;
  }
  ref.listen<bool>(incomeExpenseColorSchemeProvider, (prev, next) async {
    await prefs.setBool('incomeExpenseColorScheme', next);
    try {
      final repository = ref.read(repositoryProvider);
      final currentLedgerId = ref.read(currentLedgerIdProvider);
      final primaryColor = ref.read(primaryColorProvider);
      final baseCurrency = ref.read(baseCurrencyProvider);
      // 没有 BuildContext,靠 languageProvider 还原当前 App 语言(见
      // widget_manager.dart resolveWidgetLocalizations 文档)。
      final locale = ref.read(languageProvider);
      final widgetManager = WidgetManager();
      await widgetManager.updateAllWidgetsLocalized(
        repository,
        currentLedgerId,
        primaryColor,
        explicitLocale: locale,
        redForIncome: next,
        baseCurrency: baseCurrency,
      );
    } catch (e) {
      // Silently fail
    }

    // BeeCount Cloud 模式下把配色偏好推给 server；web 端会通过 WS
    // profile_change 事件实时刷新。非 Cloud 模式 provider 返回 null，跳过。
    unawaited(() async {
      try {
        final cloudProvider =
            await ref.read(beecountCloudProviderInstance.future);
        if (cloudProvider == null) return;
        await cloudProvider.updateMyProfileIncomeColorScheme(
          incomeIsRed: next,
        );
        logger.info('theme_providers',
            'income color scheme pushed to server: incomeIsRed=$next');
      } catch (e) {
        logger.warning('theme_providers',
            'push income color scheme failed (non-blocking): $e');
      }
    }());
  });
});

// 用户显示名(昵称)。本地真值存 prefs 'displayName';BeeCount Cloud 模式下改动
// 会推到 server,其余云模式 / 纯本地只存本地。空串 = 未设置。v1 不支持"清空已设
// 昵称"——不会推空串给 server,因此无需改后端 / 包层(包层对空串本就 throw)。
final displayNameProvider = StateProvider<String>((ref) => '');

// 显示名持久化初始化:启动加载 prefs + 监听变化写回本地,并在 cloud 模式下推送。
// 完全照搬 themeMode / compactAmount 的写法。
final displayNameInitProvider = FutureProvider<void>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('displayName');
  if (saved != null) {
    ref.read(displayNameProvider.notifier).state = saved;
  }
  ref.listen<String>(displayNameProvider, (prev, next) async {
    final fromServer = isApplyingFromServer;
    await prefs.setString('displayName', next);
    if (fromServer) return; // server 推下来的昵称不再推回去
    _pushDisplayNameToCloud(ref, next);
  });
});

/// 把显示名推给 server 的 /profile/me(仅 BeeCount Cloud 模式)。非 cloud 模式
/// provider 返回 null 直接跳过;空串不推(v1 不支持清空,且包层对空串会 throw)。
/// fire-and-forget,失败只打 warning。
void _pushDisplayNameToCloud(Ref ref, String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return;
  unawaited(() async {
    try {
      final cloudProvider =
          await ref.read(beecountCloudProviderInstance.future);
      if (cloudProvider == null) return;
      await cloudProvider.updateMyProfileDisplayName(displayName: trimmed);
      logger.info('theme_providers', 'display name pushed to server: $trimmed');
    } catch (e, st) {
      logger.warning('theme_providers',
          'push display name failed (non-blocking): $e', st);
    }
  }());
}