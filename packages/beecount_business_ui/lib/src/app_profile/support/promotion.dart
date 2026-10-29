import 'package:flutter/material.dart';

/// Presentation data only; store URLs, mail templates and launch policy stay App-side.
class BeePromotionData {
  const BeePromotionData(
      {required this.logoAsset,
      required this.title,
      required this.subtitle,
      required this.introBody,
      required this.brandColor,
      required this.contactEmail,
      this.screenshotAssets = const []});
  final String logoAsset, title, subtitle, introBody, contactEmail;
  final Color brandColor;
  final List<String> screenshotAssets;
}

class BeePromotionTexts {
  const BeePromotionTexts(
      {required this.betaDialogTitle,
      required this.betaDialogMessage,
      required this.emailLabel,
      required this.emailButton,
      required this.websiteButton,
      required this.openStoreButton,
      required this.testFlightButton});
  final String betaDialogTitle,
      betaDialogMessage,
      emailLabel,
      emailButton,
      websiteButton,
      openStoreButton,
      testFlightButton;
}

/// Controlled promotion modal. Actions and screenshot navigation are host-owned.
class BeePromotionDialog extends StatelessWidget {
  const BeePromotionDialog(
      {super.key,
      required this.info,
      required this.texts,
      required this.hasStore,
      required this.dualStore,
      required this.onWebsite,
      required this.onEmail,
      required this.onCopyEmail,
      required this.onScreenshot,
      this.onStore,
      this.onTestFlight});
  final BeePromotionData info;
  final BeePromotionTexts texts;
  final bool hasStore, dualStore;
  final VoidCallback onWebsite, onEmail, onCopyEmail;
  final ValueChanged<int> onScreenshot;
  final VoidCallback? onStore, onTestFlight;
  @override
  Widget build(BuildContext context) {
    final ctx = context;
    final themeColor = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      // TF+商店并排那一支 actions 只剩一个"前往官网",居中放视觉更平衡;
      // 其他场景仍是 [官网] + [商店/邮箱] 两个按钮,默认 end 对齐就好
      actionsAlignment:
          dualStore ? MainAxisAlignment.center : MainAxisAlignment.end,
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
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
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
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              // 产品截图缩略图(横向 Row,9:16 手机比例),点击全屏预览。
              if (info.screenshotAssets.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < info.screenshotAssets.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: BeePromotionScreenshot(
                          asset: info.screenshotAssets[i],
                          onPressed: () => onScreenshot(i),
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
                    color: Theme.of(ctx)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.5),
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
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
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
                  onCopied: onCopyEmail,
                ),
              ],
              // iOS + 有 TestFlight URL + 已上架:把 [TestFlight 内测] 和
              // [前往应用商店] 并排放进 content 顶部第一排;[前往官网] 落到
              // 下面的 actions 区单独成第二排。
              // 视觉上"两个分发渠道"同权,官网作为可选辅助。
              if (dualStore) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTestFlight,
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
                        onPressed: onStore,
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
          onPressed: onWebsite,
          style: TextButton.styleFrom(foregroundColor: themeColor),
          child: Text(texts.websiteButton),
        ),
        // 主行动:仅当上面没出 TF+商店并排行时,这里出商店或申请内测
        // (TF+商店已经在 content 第一排展示了,不再重复)
        if (!dualStore)
          if (hasStore)
            FilledButton(
              onPressed: onStore,
              style: FilledButton.styleFrom(backgroundColor: themeColor),
              child: Text(texts.openStoreButton),
            )
          else
            FilledButton(
              onPressed: onEmail,
              style: FilledButton.styleFrom(backgroundColor: themeColor),
              child: Text(texts.emailButton),
            ),
      ],
    );
  }
}

class BeePromotionScreenshot extends StatelessWidget {
  final String asset;
  final VoidCallback onPressed;

  const BeePromotionScreenshot({
    required this.asset,
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
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

class BeePromotionGallery extends StatefulWidget {
  final List<String> assets;
  final int initialIndex;
  final VoidCallback onClose;

  const BeePromotionGallery({
    required this.assets,
    required this.initialIndex,
    required this.onClose,
    super.key,
  });

  @override
  State<BeePromotionGallery> createState() => _PromotionGalleryState();
}

class _PromotionGalleryState extends State<BeePromotionGallery> {
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
        onTap: widget.onClose,
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
                  onPressed: widget.onClose,
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
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

class BeePromotionCard extends StatefulWidget {
  final BeePromotionData info;
  final VoidCallback onOpen;

  const BeePromotionCard({
    super.key,
    required this.info,
    required this.onOpen,
  });

  @override
  State<BeePromotionCard> createState() => _BeePromotionCardState();
}

class _BeePromotionCardState extends State<BeePromotionCard>
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
        onTap: widget.onOpen,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
class BeePromotionCompact extends StatefulWidget {
  final BeePromotionData info;
  final VoidCallback onOpen;

  const BeePromotionCompact({
    super.key,
    required this.info,
    required this.onOpen,
  });

  @override
  State<BeePromotionCompact> createState() => _BeePromotionCompactState();
}

class _BeePromotionCompactState extends State<BeePromotionCompact> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.info.brandColor;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onOpen,
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
