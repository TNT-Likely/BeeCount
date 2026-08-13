import 'package:flutter/material.dart';
import '../../styles/tokens.dart';
import '../ui/feature_dot.dart';

class AppListTile extends StatelessWidget {
  final IconData leading;
  final Widget? leadingWidget;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? trailing;

  /// 新功能红点的锚点 id。给了就在图标右上角挂红点,该锚点下没有未读功能时
  /// 不渲染。放在这里而不是让调用方自己包 [FeatureDot],是因为默认图标那个
  /// 36×36 圆形容器的样式在这个文件里 —— 让每个调用点去复刻一遍必然走样。
  final String? dotAnchor;

  const AppListTile(
      {super.key,
      required this.leading,
      this.leadingWidget,
      required this.title,
      this.subtitle,
      this.onTap,
      this.enabled = true,
      this.trailing,
      this.dotAnchor});

  Widget _withDot(Widget icon) =>
      dotAnchor == null ? icon : FeatureDot(anchor: dotAnchor!, child: icon);

  @override
  Widget build(BuildContext context) {
    final titleStyle = BeeTextTokens.title(context)
        .copyWith(color: BeeTokens.textPrimary(context)); // ⭐ 使用 Token
    final subStyle = BeeTextTokens.label(context)
        .copyWith(color: BeeTokens.textSecondary(context)); // ⭐ 使用 Token
    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _withDot(
            leadingWidget ??
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    leading,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!,
                      style: subStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (enabled)
            Icon(Icons.chevron_right, color: BeeTokens.iconTertiary(context)), // ⭐ 使用 Token
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: tile,
      ),
    );
  }
}
