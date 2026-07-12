import 'package:flutter/material.dart';
import '../../styles/tokens.dart';

/// 菜单项类型
enum BeeMenuItemType {
  /// 普通操作项
  action,

  /// 提示信息（禁用状态）
  tip,

  /// 分隔线
  divider,
}

/// 菜单项配置
class BeeMenuItem {
  final String? value;
  final IconData? icon;
  final String? label;
  final BeeMenuItemType type;
  final bool isDanger;

  const BeeMenuItem._({
    this.value,
    this.icon,
    this.label,
    required this.type,
    this.isDanger = false,
  });

  /// 创建普通操作项
  const BeeMenuItem.action({
    required String value,
    required IconData icon,
    required String label,
    bool isDanger = false,
  }) : this._(
          value: value,
          icon: icon,
          label: label,
          type: BeeMenuItemType.action,
          isDanger: isDanger,
        );

  /// 创建提示信息
  const BeeMenuItem.tip({
    required String label,
    IconData icon = Icons.lightbulb_outline,
  }) : this._(
          icon: icon,
          label: label,
          type: BeeMenuItemType.tip,
        );

  /// 创建分隔线
  const BeeMenuItem.divider() : this._(type: BeeMenuItemType.divider);
}

/// 美化的弹出菜单组件
class BeePopupMenu extends StatelessWidget {
  /// 菜单项列表
  final List<BeeMenuItem> items;

  /// 选中回调
  final ValueChanged<String>? onSelected;

  /// 主题色（用于图标背景）
  final Color? primaryColor;

  /// 自定义图标
  final Widget? icon;

  /// 提示文字
  final String? tooltip;

  const BeePopupMenu({
    super.key,
    required this.items,
    this.onSelected,
    this.primaryColor,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = BeeTokens.isDark(context);
    final themeColor = primaryColor ?? Theme.of(context).colorScheme.primary;

    return PopupMenuButton<String>(
      icon: icon ??
          Icon(
            Icons.more_vert,
            color: BeeTokens.textPrimary(context),
          ),
      tooltip: tooltip,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: BeeTokens.surface(context),
      elevation: isDark ? 8 : 4,
      offset: const Offset(0, 8),
      onSelected: onSelected,
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> entries = [];
        for (final item in items) {
          switch (item.type) {
            case BeeMenuItemType.action:
              entries.add(_buildActionItem(context, item, themeColor));
              break;
            case BeeMenuItemType.tip:
              entries.add(_buildTipItem(context, item));
              break;
            case BeeMenuItemType.divider:
              entries.add(const PopupMenuDivider(height: 1));
              break;
          }
        }
        return entries;
      },
    );
  }

  PopupMenuItem<String> _buildActionItem(
    BuildContext context,
    BeeMenuItem item,
    Color themeColor,
  ) {
    final color = item.isDanger ? Colors.red : themeColor;

    return PopupMenuItem<String>(
      value: item.value,
      height: 48,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            item.label ?? '',
            style: TextStyle(
              fontSize: 15,
              color:
                  item.isDanger ? Colors.red : BeeTokens.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildTipItem(BuildContext context, BeeMenuItem item) {
    return PopupMenuItem<String>(
      value: 'tip',
      enabled: false,
      height: 40,
      child: Row(
        children: [
          Icon(
            item.icon,
            size: 16,
            color: BeeTokens.textTertiary(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.label ?? '',
              style: TextStyle(
                fontSize: 12,
                color: BeeTokens.textTertiary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
