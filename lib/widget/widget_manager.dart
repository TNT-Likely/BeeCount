import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/repositories/base_repository.dart';
import '../l10n/app_localizations.dart';
import '../services/system/logger_service.dart';
import 'widget_appearance.dart';
import 'widget_render_content.dart';
import 'widget_data_service.dart';
import 'widget_spec.dart';

const _tag = 'WidgetManager';

/// 把 home_widget 平台 `getInstalledWidgets()` 的原始结果([HomeWidgetInfo]
/// 列表)映射为本地 [WidgetSpec] 目录中的条目;匹配不到目录(如尚未在原生
/// 壳注册的新类型)的条目被丢弃。
///
/// 纯函数,不触碰平台通道,便于单测。
List<WidgetSpec> matchInstalledSpecs(List<HomeWidgetInfo> infos) {
  final result = <WidgetSpec>[];
  for (final info in infos) {
    // 用 matchInstalledAll:Android 上一个 provider 类名对应多尺寸,返回其全部
    // 尺寸 spec,保证用户缩放到任意尺寸都有对应图(去重在 selectSpecsToRender)。
    result.addAll(WidgetSpec.matchInstalledAll(info));
  }
  return result;
}

/// 挑选本次需要渲染的 spec 列表(D5:只渲已安装的,避免盲渲所有类型/尺寸,
/// 省渲染开销与内存)。
///
/// - [installed] 为 `null` 表示"拿不到已安装组件列表"(home_widget 版本
///   过低 / 平台调用异常),退化为默认集([WidgetSpec.defaultSet],至少保留
///   glance-medium),避免存量用户的组件因本次升级而断更。
/// - [installed] 为空列表表示"确实一个组件都没装",按 D5 原则不渲染任何
///   内容。
/// - 其余情况原样返回(按 (type,size) 去重),不做进一步过滤。
///
/// 纯函数,不依赖平台通道,便于单测。
List<WidgetSpec> selectSpecsToRender(
  List<WidgetSpec>? installed, {
  bool warmUpAll = false,
}) {
  // 预热模式:无视"已安装"列表,渲染整个目录(D5「只渲已安装」的显式例外,
  // 动机见 updateAllWidgets 的 warmUpAllSpecs 参数文档)。
  if (warmUpAll) {
    return WidgetSpec.catalog;
  }
  if (installed == null) {
    return WidgetSpec.defaultSet;
  }
  if (installed.isEmpty) {
    return const [];
  }
  final seen = <WidgetSpec>{};
  final result = <WidgetSpec>[];
  for (final spec in installed) {
    if (seen.add(spec)) {
      result.add(spec);
    }
  }
  return result;
}

/// 预热批次的渲染顺序:整个 [WidgetSpec.catalog],但把 [installedFirst]
/// (用户桌面上已放置的组件)排到最前——预热要渲全目录,已安装的先出图,
/// 缩短"打开 App 后桌面组件才刷新"的感知等待。
///
/// [installedFirst] 应来自 `getInstalledWidgets` 的匹配结果(拿不到时退化的
/// 默认集也可,只影响排序不影响覆盖面);纯函数,便于单测。
List<WidgetSpec> orderCatalogForWarmUp(List<WidgetSpec> installedFirst) {
  return [
    ...installedFirst,
    ...WidgetSpec.catalog.where((s) => !installedFirst.contains(s)),
  ];
}

class WidgetManager {
  static final WidgetManager _instance = WidgetManager._internal();
  factory WidgetManager() => _instance;
  WidgetManager._internal();

  Future<void>? _updating;
  Future<void> Function(bool warmUp)? _pending;
  bool _warmUpPending = false;
  final _pendingReloads = <HWType>{};
  late final Future<String> _appVersion = PackageInfo.fromPlatform().then(
      (info) => '${info.version}+${info.buildNumber}',
      onError: (Object _) => 'widget-v1');

  /// Keep only the latest inputs while a batch is drawing. A superseding
  /// request inherits any unfinished full-catalog warm-up.
  Future<void> updateAllWidgetsLocalized(
    BaseRepository repository,
    int ledgerId,
    Color themeColor, {
    required Locale? explicitLocale,
    required ThemeMode themeMode,
    Color? darkThemeColor,
    bool redForIncome = true,
    String baseCurrency = 'CNY',
    bool warmUpAllSpecs = false,
  }) {
    _warmUpPending |= warmUpAllSpecs;
    _pending = (warmUp) => _update(
          WidgetGatherBatch(
              repository: repository,
              ledgerId: ledgerId,
              baseCurrency: baseCurrency),
          WidgetAppearance(
            explicitLocale: explicitLocale,
            theme: themeMode,
            systemLocales: WidgetsBinding.instance.platformDispatcher.locales,
            systemBrightness:
                WidgetsBinding.instance.platformDispatcher.platformBrightness,
          ),
          themeColor,
          darkThemeColor ?? themeColor,
          redForIncome,
          warmUp,
        );
    return _updating ??= Future.microtask(_drainUpdates);
  }

  Future<void> _drainUpdates() async {
    try {
      while (_pending != null) {
        final update = _pending!;
        final warmUp = _warmUpPending;
        _pending = null;
        _warmUpPending = false;
        try {
          await update(warmUp);
        } catch (e, st) {
          logger.error(_tag, '更新小组件失败', e, st);
        }
      }
    } finally {
      _updating = null;
    }
  }

  Future<void> _update(WidgetGatherBatch batch, WidgetAppearance appearance,
      Color lightColor, Color darkColor, bool redForIncome, bool warmUp) async {
    final installed = await _resolveSpecsToRender();
    final specs = warmUp ? orderCatalogForWarmUp(installed) : installed;
    if (specs.isEmpty) return;
    final version = await _appVersion;
    final today = DateTime.now();
    // Notify each installed family as soon as its files are ready, before
    // warming the other families for widgets added when the app is closed.
    final groups = <HWType, List<WidgetSpec>>{};
    for (final spec in specs) {
      (groups[spec.type] ??= []).add(spec);
    }
    for (final group in groups.values) {
      var changed = false;
      for (final spec in group) {
        if (_pending != null) {
          _warmUpPending |= warmUp;
          break;
        }
        try {
          final size = spec == WidgetSpec.glanceMedium && Platform.isAndroid
              ? const Size(364, 182)
              : spec.logicalSize;
          final content = await prepareWidgetContent(
            spec: spec,
            batch: batch,
            size: size,
            lightColor: lightColor,
            darkColor: darkColor,
            redForIncome: redForIncome,
            appVersion: version,
            today: today,
          );
          changed |= await cacheWidgetAppearance(
            imageKey: spec.imageKey,
            fingerprint: content.fingerprint,
            appearance: appearance,
            render: (fileKey, variant) {
              final dark = variant.brightness == Brightness.dark;
              return _renderView(
                content.build(lookupAppLocalizations(variant.locale), dark),
                key: fileKey,
                logicalSize: size,
                themeColor: dark ? darkColor : lightColor,
                dark: dark,
              );
            },
          );
        } catch (e, st) {
          logger.error(_tag, '更新 ${spec.imageKey} 失败', e, st);
        }
      }
      final type = group.first.type;
      if (changed || (warmUp && group.any(installed.contains))) {
        _pendingReloads.add(type);
      }
      if (_pendingReloads.contains(type)) {
        try {
          await _notifyWidgets(group);
          _pendingReloads.remove(type);
        } catch (e, st) {
          logger.error(_tag, '通知桌面刷新 ${type.name} 失败', e, st);
        }
      }
      if (_pending != null) {
        _warmUpPending |= warmUp;
        return;
      }
    }
  }

  Future<void> _notifyWidgets(List<WidgetSpec> specs) async {
    if (Platform.isIOS) {
      for (final kind in {
        for (final s in specs)
          if (s.iosKind != null) s.iosKind!
      }) {
        await HomeWidget.updateWidget(iOSName: kind);
      }
    } else {
      for (final name in {for (final s in specs) ...s.androidAllClassNames}) {
        await HomeWidget.updateWidget(qualifiedAndroidName: name);
      }
    }
  }

  /// 获取平台"已安装组件"列表并映射为 spec;调用失败时返回按 `null` 触发
  /// 默认集的 [selectSpecsToRender] 结果。
  Future<List<WidgetSpec>> _resolveSpecsToRender() async {
    List<HomeWidgetInfo> infos;
    try {
      infos = await HomeWidget.getInstalledWidgets();
    } catch (e) {
      logger.warning(
        _tag,
        '获取已安装组件列表失败,退化为默认集(至少 glance-medium): $e',
      );
      return selectSpecsToRender(null);
    }
    return selectSpecsToRender(matchInstalledSpecs(infos));
  }

  /// 统一的"渲染 + 落盘日志"收尾,供各类型渲染方法复用。
  ///
  /// **红屏防护(2026-07 真机问题)**:home_widget 的 `renderFlutterWidget`
  /// 用独立 BuildOwner 离屏渲染,视图 build 阶段抛异常不会向外传播为 Dart
  /// 异常,而是被 Flutter 替换成 `ErrorWidget`——debug 构建下就是「整卡红屏」
  /// 被原样渲进 PNG 显示在桌面上(release 下是灰卡),且真实异常堆栈被吞掉,
  /// 无从排查。这里在渲染窗口内临时接管两个全局 hook:
  ///
  /// 1. [FlutterError.onError]:把真实异常 + 堆栈写进日志中心(持久化 48h,
  ///    设置 → 日志中心可导出),这是定位真机红屏根因的关键线索;
  /// 2. [ErrorWidget.builder]:换成透明占位,防止红屏内容进图;渲染结束后若
  ///    确实捕获到异常,补渲一张干净的兜底卡(主题色刷新图标)覆盖落盘。
  ///
  /// 两个 hook 都是全局的,接管窗口仅限单次离屏渲染(毫秒级)并在 finally
  /// 恢复;主应用树恰好同时报错的概率极低,可接受。
  Future<WidgetRenderResult> _renderView(
    Widget view, {
    required String key,
    required Size logicalSize,
    required Color themeColor,
    required bool dark,
  }) async {
    final prevOnError = FlutterError.onError;
    final prevErrorBuilder = ErrorWidget.builder;
    Object? captured;
    FlutterError.onError = (details) {
      captured ??= details.exception;
      logger.error(_tag, '渲染 $key 视图异常', details.exception, details.stack);
    };
    ErrorWidget.builder = (details) => const SizedBox.shrink();
    late final Future<String> encoded;
    try {
      // Building/layout is synchronous. Restore global error handling before
      // waiting for PNG encoding and filesystem I/O on the main isolate.
      encoded = HomeWidget.renderFlutterWidget(
        view,
        key: key,
        logicalSize: logicalSize,
        pixelRatio: 3,
      );
    } finally {
      FlutterError.onError = prevOnError;
      ErrorWidget.builder = prevErrorBuilder;
    }
    final path = await encoded;
    if (captured == null) return (path: path, complete: true);
    final fallback = await HomeWidget.renderFlutterWidget(
      _WidgetRenderFallbackCard(
          themeColor: themeColor,
          dark: dark,
          width: logicalSize.width,
          height: logicalSize.height),
      key: key,
      logicalSize: logicalSize,
      pixelRatio: 3,
    );
    return (path: fallback, complete: false);
  }

  /// Register widget update callback
  static Future<void> registerCallback() async {
    try {
      await HomeWidget.registerInteractivityCallback(
        _backgroundCallback,
      );
    } catch (e) {
      logger.warning(_tag, '注册小组件交互回调失败: $e');
      return;
    }
  }

  /// Background callback for widget interactions
  @pragma('vm:entry-point')
  static Future<void> _backgroundCallback(Uri? uri) async {
    // Handle widget tap events
    // Could be used to navigate to specific pages
    // 图片方案下点击目前靠深链跳转(services/platform/app_link_service.dart),
    // 真正的交互入口是各原生壳拼的 beecount:// 深链,不经过这里。这个回调
    // 只是 `home_widget` 交互式组件 API 的注册要求,当前阶段先落一条日志
    // 占位,预留给未来"组件内即时记账"(不在本阶段范围,见 D8/P5)。
    //
    // 可能在纯后台 isolate 中触发(`@pragma('vm:entry-point')`),`logger`
    // 依赖的插件通道不一定已就绪,这里包一层 try/catch 保证回调本身绝不
    // 因日志失败而抛异常。
    try {
      logger.debug(_tag, '收到小组件交互回调: uri=$uri');
    } catch (_) {
      // 静默忽略,见上方注释。
    }
  }
}

/// 视图渲染出错时的兜底卡(见 [WidgetManager._renderView] 红屏防护注释):
/// 与正常卡片同底色圆角,中央一个主题色刷新图标——语言无关(纯图标,不需要
/// 文案 i18n),点击组件仍走原生壳深链打开 App,打开后下一次渲染自动重试。
class _WidgetRenderFallbackCard extends StatelessWidget {
  final Color themeColor;
  final bool dark;
  final double width;
  final double height;

  const _WidgetRenderFallbackCard({
    required this.themeColor,
    required this.dark,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1712) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(Icons.refresh, size: 28, color: themeColor),
    );
  }
}
