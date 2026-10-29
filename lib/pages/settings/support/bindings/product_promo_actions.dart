import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../services/system/logger_service.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';

// ============================================================================
// 数据 + 行为(可被任意 widget 复用)
// ============================================================================

/// 产品元信息(纯数据,跟 UI 无关)
class ProductPromo {
  /// Logo 图片资源路径(`assets/images/xxx.png`)
  final String logoAsset;

  /// 主标题(产品名)
  final String title;

  /// 副标题(一句话介绍)
  final String subtitle;

  /// 介绍正文(用于介绍弹窗,几行话讲产品做什么)。每个产品独立内容,
  /// 跟产品绑定,不能放共用的 ProductPromoTexts 里(否则 BeeDNS 弹窗
  /// 会显示 BeeAssets 介绍,错位)。
  final String introBody;

  /// 品牌主色
  final Color brandColor;

  /// App Store id(纯数字,如 `6757992815`)。
  /// **null = iOS 还没上架**,iOS 设备点击走「内测弹窗」。
  final String? appStoreId;

  /// TestFlight 公开 join URL(`https://testflight.apple.com/join/XXXX`)。
  /// 跟 [appStoreId] **并存**:已上架时主按钮跳 App Store,这个作为次要按钮
  /// 让重度用户/想要最新构建的用户能走 TestFlight 装预发版。null = 不展示
  /// TestFlight 入口。仅 iOS 设备显示。
  final String? testFlightUrl;

  /// Google Play 完整 URL。
  /// **null = Android 还没上架**,Android 设备点击走「内测弹窗」。
  final String? googlePlayUrl;

  /// 官网 URL(完整,含 https://)。任何状态下都需要(弹窗里的「前往官网」按钮要用)。
  final String websiteUrl;

  /// 内测申请邮箱地址(收件人)
  final String contactEmail;

  /// 截图资产路径列表。介绍弹窗里横向排列展示缩略图,点击任意一张全屏预览。
  /// 空 list 时弹窗不显示截图区。
  final List<String> screenshotAssets;

  const ProductPromo({
    required this.logoAsset,
    required this.title,
    required this.subtitle,
    required this.introBody,
    required this.brandColor,
    this.appStoreId,
    this.testFlightUrl,
    this.googlePlayUrl,
    required this.websiteUrl,
    required this.contactEmail,
    this.screenshotAssets = const [],
  });
}

/// 介绍弹窗的本地化文案(由调用方按 i18n 传入)。
/// 所有产品共用同一套文案 — 仅产品名内插的部分(emailSubject / emailBody)
/// 用 placeholder 注入。**产品维度的内容**(introBody / 标题 / 副标 / brand
/// color)在 [ProductPromo] 数据类里,不在这里。
class ProductPromoTexts {
  /// 内测申请的标题(用于 Android 未上架场景的副段落标题)
  final String betaDialogTitle;

  /// 内测申请的说明(用于未上架场景下展开的内测说明 + 申请条件)
  final String betaDialogMessage;

  /// 「申请邮箱」label
  final String emailLabel;

  /// 复制成功 toast
  final String copiedToast;

  /// 邮件 app 不可用时的 toast
  final String mailUnavailableToast;

  /// 「申请内测」按钮(Android 未上架时显示)
  final String emailButton;

  /// 「前往官网」按钮(始终显示)
  final String websiteButton;

  /// 「前往应用商店」按钮(已上架平台显示,主行动)
  final String openStoreButton;

  /// 「TestFlight 内测」按钮(iOS + testFlightUrl 非空时显示;App Store 跟
  /// TestFlight 并存,前者主行动后者次要)
  final String testFlightButton;
  final String emailSubject;
  final String emailBody;

  const ProductPromoTexts({
    required this.betaDialogTitle,
    required this.betaDialogMessage,
    required this.emailLabel,
    required this.copiedToast,
    required this.mailUnavailableToast,
    required this.emailButton,
    required this.websiteButton,
    required this.openStoreButton,
    required this.testFlightButton,
    required this.emailSubject,
    required this.emailBody,
  });
}

/// 产品推广点击行为器。**纯 logic**,任意 widget 可调用。
///
/// 默认弹「介绍弹窗」(产品说明 + 行动按钮组),给用户一个看介绍 → 决定 →
/// 行动的中间步,体感更顺,不像广告硬塞。
///
/// 弹窗按平台 + 是否已上架展示不同主行动:
/// - iOS + appStoreId 非空 / Android + googlePlayUrl 非空 → 主按钮「前往应用商店」
/// - 当前平台未上架 → 主按钮「申请内测」(展开邮箱卡 + 内测说明)
/// - 「前往官网」始终作为次要按钮显示
///
/// `directLaunchIfAvailable: true`:已上架平台跳过介绍弹窗直接跳商店;未上架
/// 平台仍走弹窗(因为没地方跳)。**预留给未来改回直跳的开关**,默认走弹窗。
class ProductPromoLauncher {
  ProductPromoLauncher._();

  static Future<void> open(
    BuildContext context,
    ProductPromo info,
    ProductPromoTexts texts, {
    bool directLaunchIfAvailable = false,
  }) async {
    if (directLaunchIfAvailable) {
      final storeUri = _resolveStoreUri(info);
      if (storeUri != null) {
        await _tryOpenUrl(storeUri);
        return;
      }
      // 当前平台未上架,即使要求直跳也只能走弹窗(没商店可跳)
    }
    if (!context.mounted) return;
    await _showIntroDialog(context, info, texts);
  }

  static Future<void> _showIntroDialog(
    BuildContext context,
    ProductPromo info,
    ProductPromoTexts texts,
  ) async {
    // 当前平台是否已上架商店?
    final storeUri = _resolveStoreUri(info);
    final hasStore = storeUri != null;

    await showDialog<void>(
        context: context,
        builder: (ctx) => BeePromotionDialog(
              info: _promotionData(info),
              texts: _promotionTexts(texts),
              hasStore: hasStore,
              dualStore: _showTestFlightRow(info, hasStore),
              onStore: storeUri == null
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await _tryOpenUrl(storeUri);
                    },
              onTestFlight: info.testFlightUrl == null
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await _tryOpenUrl(Uri.parse(info.testFlightUrl!));
                    },
              onWebsite: () async {
                Navigator.of(ctx).pop();
                await _tryOpenUrl(Uri.parse(info.websiteUrl));
              },
              onCopyEmail: () {
                Clipboard.setData(ClipboardData(text: info.contactEmail));
                if (ctx.mounted) showBeeToast(ctx, texts.copiedToast);
              },
              onEmail: () async {
                await Clipboard.setData(ClipboardData(text: info.contactEmail));
                final uri = Uri(
                    scheme: 'mailto',
                    path: info.contactEmail,
                    query: _encodeMailtoQuery({
                      'subject': texts.emailSubject,
                      'body': texts.emailBody
                    }));
                final ok = await _tryOpenUrl(uri);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (!ok && context.mounted) {
                  showBeeToast(context, texts.mailUnavailableToast);
                }
              },
              onScreenshot: (index) => Navigator.of(ctx).push(PageRouteBuilder(
                  opaque: false,
                  barrierColor: Colors.black87,
                  transitionDuration: const Duration(milliseconds: 200),
                  pageBuilder: (_, __, ___) => _ScreenshotGalleryPage(
                      assets: info.screenshotAssets, initialIndex: index),
                  transitionsBuilder: (_, animation, __, child) =>
                      FadeTransition(opacity: animation, child: child))),
            ));
  }

  /// 用 TestFlight + AppStore 两按钮并排的"双轨分发"布局?
  /// 仅 iOS + 有 TF URL + 已上架时为 true。其他场景退回常规布局。
  static bool _showTestFlightRow(ProductPromo info, bool hasStore) {
    return Platform.isIOS && info.testFlightUrl != null && hasStore;
  }

  /// 当前平台已上架时返回商店 URI,否则返回 null。
  static Uri? _resolveStoreUri(ProductPromo info) {
    if (Platform.isIOS && info.appStoreId != null) {
      return Uri.parse('https://apps.apple.com/app/id${info.appStoreId}');
    }
    if (Platform.isAndroid && info.googlePlayUrl != null) {
      return Uri.parse(info.googlePlayUrl!);
    }
    return null;
  }
}

/// App route adapter; the package owns paging, zoom and visual state.
class _ScreenshotGalleryPage extends StatelessWidget {
  const _ScreenshotGalleryPage(
      {required this.assets, required this.initialIndex});
  final List<String> assets;
  final int initialIndex;
  @override
  Widget build(BuildContext context) => BeePromotionGallery(
      assets: assets,
      initialIndex: initialIndex,
      onClose: () => Navigator.of(context).pop());
}

class ProductPromoCard extends StatelessWidget {
  const ProductPromoCard({super.key, required this.info, required this.texts});
  final ProductPromo info;
  final ProductPromoTexts texts;
  @override
  Widget build(BuildContext context) => BeePromotionCard(
      info: _promotionData(info),
      onOpen: () => ProductPromoLauncher.open(context, info, texts));
}

class ProductPromoCompact extends StatelessWidget {
  const ProductPromoCompact(
      {super.key, required this.info, required this.texts});
  final ProductPromo info;
  final ProductPromoTexts texts;
  @override
  Widget build(BuildContext context) => BeePromotionCompact(
      info: _promotionData(info),
      onOpen: () => ProductPromoLauncher.open(context, info, texts));
}

BeePromotionData _promotionData(ProductPromo value) => BeePromotionData(
    logoAsset: value.logoAsset,
    title: value.title,
    subtitle: value.subtitle,
    introBody: value.introBody,
    brandColor: value.brandColor,
    contactEmail: value.contactEmail,
    screenshotAssets: value.screenshotAssets);
BeePromotionTexts _promotionTexts(ProductPromoTexts value) => BeePromotionTexts(
    betaDialogTitle: value.betaDialogTitle,
    betaDialogMessage: value.betaDialogMessage,
    emailLabel: value.emailLabel,
    emailButton: value.emailButton,
    websiteButton: value.websiteButton,
    openStoreButton: value.openStoreButton,
    testFlightButton: value.testFlightButton);

Future<bool> _tryOpenUrl(Uri url) async {
  // mailto: 在 Android 上 canLaunchUrl 经常误报 false(package visibility +
  // 邮件 app 列表不在 queries 里时),但实际 launchUrl 能跳。直接尝试 launch,
  // 失败再 fallback,比 canLaunch 检测更可靠。
  final modes = <LaunchMode>[
    LaunchMode.externalApplication,
    LaunchMode.externalNonBrowserApplication,
    LaunchMode.platformDefault,
  ];
  for (final mode in modes) {
    try {
      final ok = await launchUrl(url, mode: mode);
      if (ok) return true;
    } catch (e) {
      // 继续 fallback 下一种 mode
      logger.warning('ProductPromo', 'launchUrl mode=$mode 失败,继续: $e');
    }
  }
  logger.error('ProductPromo', '所有 launch mode 都失败: $url');
  return false;
}

String _encodeMailtoQuery(Map<String, String> params) {
  return params.entries
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value).replaceAll('+', '%20')}')
      .join('&');
}
