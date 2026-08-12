import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/theme_providers.dart';
import '../../styles/header_skins.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';

/// 头部皮肤选择。所有皮肤亮暗通用(亮=主题色底 + 白/渐变图形;暗=纯黑底 + 偏淡的
/// 主题色图形),预览按当前系统模式渲染。
///
/// 皮肤分「动态 / 静态」两类:动态皮肤自带动画(卡片预览里就在动),用顶部分段
/// 切换过滤。**固定配色**的皮肤(如鎏金岁月、秋日系列)自带整套颜色不跟随主题色,
/// 卡片上会标出来 —— 否则用户改主题色发现头部不变会以为坏了。
class HeaderSkinPage extends ConsumerStatefulWidget {
  const HeaderSkinPage({super.key});

  @override
  ConsumerState<HeaderSkinPage> createState() => _HeaderSkinPageState();
}

class _HeaderSkinPageState extends ConsumerState<HeaderSkinPage> {
  HeaderSkinFilter _filter = HeaderSkinFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    final current = ref.watch(headerSkinProvider);
    final modeIsDark = BeeTokens.isDark(context);

    // 预览底色与真实 header 基础色一致:亮=主题色,暗=纯黑。图案皮肤是透明叠加,
    // 必须垫底色才看得见。
    final base = modeIsDark ? Colors.black : primary;

    final skins = kHeaderSkins.where((s) {
      switch (_filter) {
        case HeaderSkinFilter.all:
          return true;
        case HeaderSkinFilter.animated:
          return s.isAnimated;
        case HeaderSkinFilter.static_:
          return !s.isAnimated;
      }
    }).toList();

    final items = <({
      String id,
      String name,
      Widget preview,
      String? badge,
      bool animated,
      bool fixed,
    })>[
      // 「纯色」只在「全部 / 静态」下出现
      if (_filter != HeaderSkinFilter.animated)
        (
          id: kHeaderSkinNone,
          name: l10n.headerSkinNone,
          preview: ColoredBox(color: base),
          badge: null,
          animated: false,
          fixed: false,
        ),
      for (final s in skins)
        (
          id: s.id,
          name: s.nameOf(l10n),
          // 缩略图不在状态栏底下,得把 top padding 抹掉:周年皮肤靠
          // MediaQuery 的 topInset 给状态栏让位,不抹的话卡片里会凭空
          // 空出一条,构图看着就散了。
          preview: ColoredBox(
            color: base,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: s.builder(primary, modeIsDark),
            ),
          ),
          badge: s.badge,
          animated: s.isAnimated,
          fixed: s.hasFixedPalette,
        ),
    ];

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.headerSkinTitle,
            subtitle: l10n.headerSkinSubtitle,
            showBack: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _FilterBar(
              value: _filter,
              primary: primary,
              labels: {
                HeaderSkinFilter.all: l10n.headerSkinTabAll,
                HeaderSkinFilter.animated: l10n.headerSkinTabAnimated,
                HeaderSkinFilter.static_: l10n.headerSkinTabStatic,
              },
              onChanged: (f) => setState(() => _filter = f),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.95,
              children: [
                for (final it in items)
                  _SkinCard(
                    name: it.name,
                    preview: it.preview,
                    selected: it.id == current,
                    primary: primary,
                    cornerBadge: it.badge,
                    animated: it.animated,
                    fixedPalette: it.fixed,
                    animatedLabel: l10n.headerSkinAnimatedBadge,
                    fixedLabel: l10n.headerSkinFixedPalette,
                    // 走 applyHeaderSkin:绑定色皮肤会顺带把主题色切过去
                    onTap: () => applyHeaderSkin(ref, it.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 全部 / 动态 / 静态 分段切换。
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.value,
    required this.primary,
    required this.labels,
    required this.onChanged,
  });

  final HeaderSkinFilter value;
  final Color primary;
  final Map<HeaderSkinFilter, String> labels;
  final ValueChanged<HeaderSkinFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: BeeTokens.isDark(context)
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final f in HeaderSkinFilter.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: f == value
                        ? (BeeTokens.isDark(context)
                            ? primary.withValues(alpha: 0.22)
                            : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: f == value && !BeeTokens.isDark(context)
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            )
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[f]!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: f == value ? FontWeight.w600 : FontWeight.w500,
                      color: f == value
                          ? (BeeTokens.isDark(context)
                              ? primary
                              : BeeTokens.textPrimary(context))
                          : BeeTokens.textSecondary(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.name,
    required this.preview,
    required this.selected,
    required this.primary,
    required this.onTap,
    required this.animated,
    required this.fixedPalette,
    required this.animatedLabel,
    required this.fixedLabel,
    this.cornerBadge,
  });

  final String name;
  final Widget preview;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  /// 动态皮肤:卡片右下角标「动」。
  final bool animated;

  /// 固定配色:卡片下方标出来,免得用户改主题色发现头部不变。
  final bool fixedPalette;
  final String animatedLabel;
  final String fixedLabel;

  /// 左上角小徽标文案(如一周年款的「1st」),null 不显示。
  final String? cornerBadge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? primary : BeeTokens.border(context),
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    preview,
                    if (cornerBadge != null)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8C91C),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            cornerBadge!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6E5104),
                            ),
                          ),
                        ),
                      ),
                    if (animated)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow_rounded,
                                  size: 11, color: Colors.white),
                              const SizedBox(width: 1),
                              Text(
                                animatedLabel,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (selected)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                              color: primary, shape: BoxShape.circle),
                          child: const Icon(Icons.check,
                              size: 14, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? primary : BeeTokens.textPrimary(context),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (fixedPalette)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                fixedLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: BeeTokens.textTertiary(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
