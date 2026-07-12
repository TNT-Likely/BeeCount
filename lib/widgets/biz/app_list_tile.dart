import 'package:flutter/material.dart';
import '../../styles/tokens.dart';

class AppListTile extends StatelessWidget {
  final IconData leading;
  final Widget? leadingWidget;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final Widget? trailing;
  const AppListTile(
      {super.key,
      required this.leading,
      this.leadingWidget,
      required this.title,
      this.subtitle,
      this.onTap,
      this.enabled = true,
      this.trailing});

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
            Icon(Icons.chevron_right,
                color: BeeTokens.iconTertiary(context)), // ⭐ 使用 Token
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
