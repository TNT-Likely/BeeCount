// BeeCount 家族产品推广信息的中央注册表。
//
// 所有用 `ProductPromoCard` / `ProductPromoCompact` / `ProductPromoLauncher`
// 的页面都从这里取数据,避免 logoAsset / appStoreId / 邮箱地址 / 域名等关键
// 字段在多处复制。新增产品 / 改 App ID / 调整域名,只改这一处。
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/biz/product_promo_card.dart';

/// 蜜蜂家当 BeeAssets — 资产可视化产品。
///
/// 当前阶段:iOS 已上架 App Store / TestFlight,Android 已上架 Google Play。
/// 截图按当前 locale 自动切英文 / 中文版。
ProductPromo beeAssetsPromo(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  // 英文 locale 用 _en 后缀的截图,zh / zh-TW 都用中文版
  final isEn = Localizations.localeOf(context).languageCode == 'en';
  final suffix = isEn ? '_en' : '';
  return ProductPromo(
    logoAsset: 'assets/images/beeassets_logo.png',
    title: l10n.aboutBeeAssets,
    subtitle: l10n.aboutBeeAssetsSubtitle,
    introBody: l10n.aboutBeeAssetsIntro,
    // 跟 logo 黑黄基调对齐:深金黄(蜂蜡 / 老金)
    brandColor: const Color(0xFFD4A017),
    appStoreId: '6763686675',
    // App Store 审核期间走 TestFlight,审过后两个并存(App Store 主、TestFlight
    // 次)— TestFlight 永远是"最新构建"通道,重度用户喜欢用
    testFlightUrl: 'https://testflight.apple.com/join/49vTpmDA',
    googlePlayUrl: 'https://play.google.com/store/apps/details?id=com.tntlikely.beeassets',
    websiteUrl: 'https://assets.beejz.com',
    contactEmail: 'sunxiaoyes@outlook.com',
    screenshotAssets: [
      'assets/images/beeassets_dashboard$suffix.png',
      'assets/images/beeassets_holdings$suffix.png',
    ],
  );
}

/// 蜜蜂域名 BeeDNS — DNS 管理工具。
ProductPromo beeDnsPromo(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return ProductPromo(
    logoAsset: 'assets/images/beedns_logo.png',
    title: l10n.aboutBeeDNS,
    subtitle: l10n.aboutBeeDNSSubtitle,
    introBody: l10n.aboutBeeDNSIntro,
    // 琥珀橙
    brandColor: const Color(0xFFF59E0B),
    appStoreId: '6757992815',
    // googlePlayUrl: 'https://play.google.com/store/apps/details?id=com.tntlikely.beedns',
    websiteUrl: 'https://dns.beejz.com',
    contactEmail: 'sunxiaoyes@outlook.com',
    // BeeDNS 截图暂不展示;有合适的产品截图后填这里:
    // screenshotAssets: const ['assets/images/beedns_xxx.png'],
  );
}

/// 标准介绍弹窗文案构造器(每个产品共用一套通用文案,产品自己的介绍文案
/// 在 [ProductPromo.introBody] 里)。
ProductPromoTexts buildPromoTexts(BuildContext context, String productName) {
  final l10n = AppLocalizations.of(context);
  return ProductPromoTexts(
    betaDialogTitle: l10n.productPromoAndroidTitle,
    betaDialogMessage: l10n.productPromoAndroidMessage,
    emailLabel: l10n.productPromoEmailLabel,
    copiedToast: l10n.productPromoCopiedToast,
    mailUnavailableToast: l10n.productPromoMailUnavailable,
    emailButton: l10n.productPromoEmailButton,
    websiteButton: l10n.productPromoWebsiteButton,
    openStoreButton: l10n.productPromoOpenStore,
    testFlightButton: l10n.productPromoTestFlight,
    emailSubject: l10n.productPromoEmailSubject(productName),
    emailBody: l10n.productPromoEmailBody(productName),
  );
}
