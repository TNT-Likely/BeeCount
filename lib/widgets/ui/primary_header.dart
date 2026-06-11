import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../providers/theme_providers.dart';
import '../../styles/tokens.dart';
import '../../styles/header_skins.dart';

class PrimaryHeader extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget>? actions;
  final Widget? bottom;
  final Widget? content;
  final EdgeInsetsGeometry padding;
  final Widget? titleTrailing;
  final Widget? subtitleTrailing;
  final Widget? center;
  final IconData? leadingIcon;
  final bool compact;
  final Brightness? statusBarIconBrightness;
  final BoxDecoration? decoration;
  final bool leadingPlain;
  // 隐藏内置标题/副标题行，仅渲染自定义 content（用于首页）
  final bool showTitleSection;

  const PrimaryHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.actions,
    this.bottom,
    this.content,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 8),
    this.titleTrailing,
    this.subtitleTrailing,
    this.center,
    this.leadingIcon,
    this.compact = false,
    this.statusBarIconBrightness,
    this.decoration,
    this.leadingPlain = false,
    this.showTitleSection = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = ref.watch(primaryColorProvider);
    final titleStyle = BeeTextTokens.title(context);
    final subStyle = BeeTextTokens.label(context);
    final effectivePadding =
        compact ? const EdgeInsets.fromLTRB(8, 6, 8, 6) : padding;

    // ⭐ 使用 Token 系统
    final isDark = BeeTokens.isDark(context);

    // ⭐ 头部皮肤:亮暗通用同一款(暗色由皮肤内部渲染成纯黑底 + 偏淡主题色图形)。
    // 'none' → null = 纯主题色 / 纯黑。
    final skin = headerSkinById(ref.watch(headerSkinProvider));

    // ⭐ Header 背景颜色：亮色模式用主题色，暗黑模式用纯黑
    final headerBg = isDark ? Colors.black : primary;

    // ⭐ 文字和图标颜色（使用 Token）
    final textColor = BeeTokens.textPrimary(context);
    final iconColor = BeeTokens.iconPrimary(context);

    // ⭐ 状态栏图标颜色：亮色模式用深色图标，暗黑模式用浅色图标
    final statusBarBrightness = statusBarIconBrightness ??
        (isDark ? Brightness.light : Brightness.dark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        // edge-to-edge 模式(main.dart 开启)下 header 自己画到状态栏底下,
        // 状态栏保持透明即可 —— 不再依赖 OEM 响应 setStatusBarColor
        // (华为 EMUI/鸿蒙会无视它,导致背景渗透不到状态栏)。
        statusBarColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        statusBarIconBrightness: statusBarBrightness,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: decoration ?? BoxDecoration(color: headerBg), // ⭐ 根据设置决定背景色
          child: Stack(
            children: [
              // ⭐ 头部皮肤层(主题色之上的装饰);未选皮肤时为纯主题色 / 纯黑
              if (skin != null)
                Positioned.fill(child: skin.builder(primary, isDark)),
              // 主内容
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (showTitleSection)
                  Padding(
                    padding: effectivePadding,
                    child: Row(
                      children: [
                        if (showBack) ...[
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: iconColor), // ⭐ 自适应颜色
                            onPressed: () => Navigator.of(context).maybePop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (leadingIcon != null) ...[
                          leadingPlain
                              ? Icon(leadingIcon, color: iconColor)
                              : Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(leadingIcon, color: iconColor),
                                ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      title,
                                      style: titleStyle.copyWith(color: textColor), // ⭐ 自适应颜色
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (titleTrailing != null) ...[
                                    const SizedBox(width: 6),
                                    titleTrailing!,
                                  ],
                                ],
                              ),
                              if (subtitle != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        subtitle!,
                                        style: subStyle.copyWith(
                                          color: BeeTokens.textSecondary(context),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (subtitleTrailing != null) ...[
                                      const SizedBox(width: 6),
                                      subtitleTrailing!,
                                    ]
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (center != null) ...[
                          const SizedBox(width: 6),
                          DefaultTextStyle(
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: iconColor, // ⭐ 自适应颜色
                            ) ?? TextStyle(fontSize: 12, color: iconColor),
                            child: center!,
                          ),
                        ],
                        if (actions != null) ...actions!,
                      ],
                    ),
                  ),
                if (content != null)
                  Padding(
                    padding: effectivePadding,
                    child: DefaultTextStyle(
                      style: DefaultTextStyle.of(context).style.copyWith(
                        color: textColor, // ⭐ 自适应颜色
                      ),
                      child: IconTheme(
                        data: IconThemeData(color: iconColor), // ⭐ 自适应颜色
                        child: content!,
                      ),
                    ),
                  ),
                    if (bottom != null) bottom!,
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
