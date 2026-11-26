import 'dart:io';

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/avatar_providers.dart';
import '../../../providers/theme_providers.dart';
import '../../../skins/premium_skins.dart';
import '../../../styles/header_skins.dart';
import '../../../styles/tokens.dart';
import '../appearance/skin_animation_scope.dart';
import '../widgets/feature_dot.dart';

/// The ledger’s floating navigation bar, also used for a read-only skin trial.
class LedgerTabBar extends ConsumerWidget {
  final int currentIndex;
  final Color primaryColor;
  final bool isDark;
  final double bottomPadding;
  final AppLocalizations l10n;
  final bool previewPaidSkin;
  final HeaderSkin? skin;
  final GlobalKey? centerButtonKey;
  final ValueChanged<int>? onTabTap;
  final VoidCallback? onCenterTap;
  final GestureLongPressStartCallback? onCenterLongPressStart;
  final GestureLongPressMoveUpdateCallback? onCenterLongPressMoveUpdate;
  final GestureLongPressEndCallback? onCenterLongPressEnd;

  const LedgerTabBar({
    super.key,
    required this.currentIndex,
    required this.primaryColor,
    required this.isDark,
    required this.bottomPadding,
    required this.l10n,
    this.previewPaidSkin = false,
    this.skin,
    this.centerButtonKey,
    this.onTabTap,
    this.onCenterTap,
    this.onCenterLongPressStart,
    this.onCenterLongPressMoveUpdate,
    this.onCenterLongPressEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(premiumSkinsProvider);
    final colors = Theme.of(context).colorScheme;
    final fallback = BeeTokens.tabBarBackground(context).withValues(alpha: 1);
    final active = previewPaidSkin ||
        (runtime.active && ref.watch(headerSkinsEnabledProvider));
    final avatarPath = ref.watch(avatarPathProvider).asData?.value;
    final bgColor = active
        ? Color.lerp(colors.surface, colors.primary, isDark ? .13 : .075)!
            .withValues(alpha: .96 + BeeCardTheme.of(context).surface.a * .04)
        : fallback;
    final artwork = active ? runtime.navigationArtwork(context) : null;
    final inactiveColor = isDark ? Colors.white70 : Colors.black54;

    const barHeight = 56.0;

    return SizedBox(
      height: barHeight + bottomPadding + 12, // 12dp 浮动间距
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomPadding + 12,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: BeeTokens.tabBarShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: RepaintBoundary(
                child: Stack(
              children: [
                if (artwork != null)
                  Positioned.fill(child: IgnorePointer(child: artwork)),
                // 皮肤的悬浮 tab 装饰层(垫在图标之下,不影响点按)
                if (skin?.tabBarBuilder != null)
                  Positioned.fill(
                      child: IgnorePointer(
                          child: SkinAnimationScope(
                              child:
                                  skin!.tabBarBuilder!(primaryColor, isDark)))),
                Row(
                  children: [
                    _buildTabItem(0, Icons.receipt_long_outlined,
                        Icons.receipt_long, l10n.tabHome, inactiveColor),
                    _buildTabItem(
                        1,
                        Icons.pie_chart_outline_rounded,
                        Icons.pie_chart_rounded,
                        l10n.tabInsights,
                        inactiveColor),
                    // 中间记账按钮（作为 Tab 样式）
                    _buildCenterTabItem(inactiveColor),
                    _buildTabItem(
                        2,
                        Icons.account_balance_wallet_outlined,
                        Icons.account_balance_wallet,
                        l10n.tabAssets,
                        inactiveColor),
                    _buildAvatarTabItem(
                        3, l10n.tabMine, inactiveColor, avatarPath),
                  ],
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }

  EdgeInsets get _tabPadding => EdgeInsets.symmetric(
      horizontal: l10n.localeName == 'ru' ? 4 : 18, vertical: 6);

  Widget _buildTabItem(int index, IconData icon, IconData activeIcon,
      String label, Color inactiveColor,
      {String? dotAnchor}) {
    final isActive = index == currentIndex;
    final iconColor = isActive ? primaryColor : inactiveColor;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTabTap == null ? null : () => onTabTap!(index),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: _tabPadding,
            decoration: BoxDecoration(
              color: isActive
                  ? primaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 新功能红点挂在图标上(不是整个 tab),这样位置跟着图标走、
                // 不会因为 label 长短漂移
                dotAnchor == null
                    ? Icon(isActive ? activeIcon : icon,
                        color: iconColor, size: 22)
                    : FeatureDot(
                        anchor: dotAnchor,
                        offset: const Offset(-2, 0),
                        child: Icon(isActive ? activeIcon : icon,
                            color: iconColor, size: 22),
                      ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? primaryColor : inactiveColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterTabItem(Color inactiveColor) {
    return Expanded(
      child: GestureDetector(
        key: centerButtonKey,
        behavior: HitTestBehavior.opaque,
        onTap: onCenterTap,
        onLongPressStart: onCenterLongPressStart,
        onLongPressMoveUpdate: onCenterLongPressMoveUpdate,
        onLongPressEnd: onCenterLongPressEnd,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: inactiveColor, size: 22),
              const SizedBox(height: 1),
              Text(
                l10n.tabRecord,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 10,
                  color: inactiveColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarTabItem(
      int index, String label, Color inactiveColor, String? avatarPath) {
    final isActive = index == currentIndex;
    Widget iconWidget;
    if (avatarPath != null) {
      iconWidget = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isActive ? Border.all(color: primaryColor, width: 1.5) : null,
          image: DecorationImage(
            image: FileImage(File(avatarPath)),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      iconWidget = Icon(
          isActive ? Icons.person_rounded : Icons.person_outline_rounded,
          color: isActive ? primaryColor : inactiveColor,
          size: 24);
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTabTap == null ? null : () => onTabTap!(index),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: _tabPadding,
            decoration: BoxDecoration(
              color: isActive
                  ? primaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 新功能红点的第一级 —— 新功能大多在「我的」这条线下面,
                // 用户第一眼能看到的就是这里。
                FeatureDot(
                  anchor: 'tab_mine',
                  offset: const Offset(-2, 0),
                  child: iconWidget,
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? primaryColor : inactiveColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
