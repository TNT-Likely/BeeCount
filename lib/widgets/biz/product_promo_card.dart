import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/system/logger_service.dart';
import '../../styles/tokens.dart';
import '../ui/toast.dart';

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
      builder: (ctx) {
        // 弹窗交互元素跟随 app 主题色(用户自定义),不用产品 brand color。
        final themeColor = Theme.of(ctx).colorScheme.primary;
        return AlertDialog(
          // TF+商店并排那一支 actions 只剩一个"前往官网",居中放视觉更平衡;
          // 其他场景仍是 [官网] + [商店/邮箱] 两个按钮,默认 end 对齐就好
          actionsAlignment: _showTestFlightRow(info, hasStore)
              ? MainAxisAlignment.center
              : MainAxisAlignment.end,
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          // SizedBox(width: maxFinite) 给 ScrollView 显式 width,否则下面
          // Image.asset 用 width: infinity + fitWidth 时 layout 算不出来,
          // 弹窗会渲染成空阴影。
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 产品标题区:logo + 标题 + 副标
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          info.logoAsset,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.apps_rounded,
                            color: info.brandColor,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              info.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              info.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: BeeTokens.textSecondary(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 产品介绍正文
                  Text(
                    info.introBody,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: BeeTokens.textPrimary(ctx),
                    ),
                  ),
                  // 产品截图缩略图(横向 Row,9:16 手机比例),点击全屏预览。
                  if (info.screenshotAssets.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (var i = 0;
                            i < info.screenshotAssets.length;
                            i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _ScreenshotThumb(
                              asset: info.screenshotAssets[i],
                              allAssets: info.screenshotAssets,
                              initialIndex: i,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  // 未上架时:展开内测说明 + 邮箱卡
                  if (!hasStore) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BeeTokens.surface(ctx).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: themeColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            texts.betaDialogTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: themeColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            texts.betaDialogMessage,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: BeeTokens.textSecondary(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CopyableEmailRow(
                      email: info.contactEmail,
                      label: texts.emailLabel,
                      accentColor: themeColor,
                      onCopied: () {
                        Clipboard.setData(
                            ClipboardData(text: info.contactEmail));
                        if (ctx.mounted) showToast(ctx, texts.copiedToast);
                      },
                    ),
                  ],
                  // iOS + 有 TestFlight URL + 已上架:把 [TestFlight 内测] 和
                  // [前往应用商店] 并排放进 content 顶部第一排;[前往官网] 落到
                  // 下面的 actions 区单独成第二排。
                  // 视觉上"两个分发渠道"同权,官网作为可选辅助。
                  if (_showTestFlightRow(info, hasStore)) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _tryOpenUrl(Uri.parse(info.testFlightUrl!));
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: themeColor,
                              side: BorderSide(color: themeColor),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(texts.testFlightButton),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await _tryOpenUrl(storeUri!);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: themeColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(texts.openStoreButton),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            // 次要:前往官网 — 永远显示
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _tryOpenUrl(Uri.parse(info.websiteUrl));
              },
              style: TextButton.styleFrom(foregroundColor: themeColor),
              child: Text(texts.websiteButton),
            ),
            // 主行动:仅当上面没出 TF+商店并排行时,这里出商店或申请内测
            // (TF+商店已经在 content 第一排展示了,不再重复)
            if (!_showTestFlightRow(info, hasStore))
              if (hasStore)
                FilledButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _tryOpenUrl(storeUri);
                  },
                  style: FilledButton.styleFrom(backgroundColor: themeColor),
                  child: Text(texts.openStoreButton),
                )
              else
                FilledButton(
                  onPressed: () async {
                    // 双保险:先 clipboard 兜底,再 launchUrl,失败 toast 提示
                    await Clipboard.setData(
                        ClipboardData(text: info.contactEmail));
                    final uri = Uri(
                      scheme: 'mailto',
                      path: info.contactEmail,
                      query: _encodeMailtoQuery({
                        'subject': texts.emailSubject,
                        'body': texts.emailBody,
                      }),
                    );
                    final ok = await _tryOpenUrl(uri);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    if (!ok) showToast(context, texts.mailUnavailableToast);
                  },
                  style: FilledButton.styleFrom(backgroundColor: themeColor),
                  child: Text(texts.emailButton),
                ),
          ],
        );
      },
    );
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

/// 介绍弹窗里的截图缩略图。9:16 手机比例,圆角 + 阴影,点击 push 全屏预览
/// 页(支持左右滑动切换、双指缩放)。
class _ScreenshotThumb extends StatelessWidget {
  final String asset;
  final List<String> allAssets;
  final int initialIndex;

  const _ScreenshotThumb({
    required this.asset,
    required this.allAssets,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black87,
            transitionDuration: const Duration(milliseconds: 200),
            pageBuilder: (_, __, ___) => _ScreenshotGalleryPage(
                assets: allAssets, initialIndex: initialIndex),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// 全屏截图预览页:左右滑切换、双指缩放、点击空白关闭。
class _ScreenshotGalleryPage extends StatefulWidget {
  final List<String> assets;
  final int initialIndex;

  const _ScreenshotGalleryPage({
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<_ScreenshotGalleryPage> createState() => _ScreenshotGalleryPageState();
}

class _ScreenshotGalleryPageState extends State<_ScreenshotGalleryPage> {
  late final PageController _ctrl =
      PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                controller: _ctrl,
                itemCount: widget.assets.length,
                itemBuilder: (_, i) => InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.asset(
                      widget.assets[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              // 右上角关闭按钮
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ),
              // 底部页码指示
              if (widget.assets.length > 1)
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ListenableBuilder(
                      listenable: _ctrl,
                      builder: (_, __) {
                        final page = _ctrl.hasClients
                            ? (_ctrl.page ?? widget.initialIndex.toDouble())
                                .round()
                            : widget.initialIndex;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${page + 1} / ${widget.assets.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹窗内的「申请邮箱」可点击复制行。accentColor 由调用方传入(目前传的是
/// app 主题色),让弹窗整体配色统一。
class _CopyableEmailRow extends StatelessWidget {
  final String email;
  final String label;
  final Color accentColor;
  final VoidCallback onCopied;

  const _CopyableEmailRow({
    required this.email,
    required this.label,
    required this.accentColor,
    required this.onCopied,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onCopied,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: accentColor.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.email_outlined, size: 18, color: accentColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: BeeTokens.textTertiary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimary(context),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, size: 16, color: accentColor),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 表现 1:大卡(默认,关于页第一版样式)
// ============================================================================

/// 大卡片(单列,带入场动画 + 按下缩放反馈)
class ProductPromoCard extends StatefulWidget {
  final ProductPromo info;
  final ProductPromoTexts texts;

  const ProductPromoCard({
    super.key,
    required this.info,
    required this.texts,
  });

  @override
  State<ProductPromoCard> createState() => _ProductPromoCardState();
}

class _ProductPromoCardState extends State<ProductPromoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.info.brandColor;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () =>
            ProductPromoLauncher.open(context, widget.info, widget.texts),
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.12),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              children: [
                _ProductLogo(
                    asset: widget.info.logoAsset,
                    color: color,
                    size: 52,
                    radius: 12),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.info.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.info.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: BeeTokens.textSecondary(context),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color.withValues(alpha: 0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 表现 2:紧凑卡(适合 grid / 横向 list,信息密度高)
// ============================================================================

/// 紧凑卡片(适合 2 列 grid 排布)。Logo + 标题 + 一行副标 + 右上角箭头。
///
/// 推荐配合 GridView.count(crossAxisCount: 2, childAspectRatio: 2.6) 用。
class ProductPromoCompact extends StatefulWidget {
  final ProductPromo info;
  final ProductPromoTexts texts;

  const ProductPromoCompact({
    super.key,
    required this.info,
    required this.texts,
  });

  @override
  State<ProductPromoCompact> createState() => _ProductPromoCompactState();
}

class _ProductPromoCompactState extends State<ProductPromoCompact> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.info.brandColor;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () =>
          ProductPromoLauncher.open(context, widget.info, widget.texts),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.10),
                color.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ProductLogo(
                  asset: widget.info.logoAsset,
                  color: color,
                  size: 40,
                  radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.info.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: color.withValues(alpha: 0.5),
                          size: 12,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.info.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: BeeTokens.textSecondary(context),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// helpers
// ============================================================================

/// Logo 图片 + asset 缺失时的降级占位(品牌色背景 + 标题首字母)。
/// 这样产品 logo 资产没就位时 UI 不会显示空白 / 红框,体验过渡平滑。
class _ProductLogo extends StatelessWidget {
  final String asset;
  final Color color;
  final double size;
  final double radius;

  const _ProductLogo({
    required this.asset,
    required this.color,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.apps_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

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
