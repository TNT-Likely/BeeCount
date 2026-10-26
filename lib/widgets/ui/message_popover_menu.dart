import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 消息长按弹出菜单项
class PopoverMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const PopoverMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

/// Compatibility adapter to the shared v4 anchored menu.
class MessagePopoverMenu {
  static Future<void> show(
      {required BuildContext context,
      required Offset globalPosition,
      required List<PopoverMenuItem> items,
      Color? primaryColor}) async {
    HapticFeedback.mediumImpact();
    final selected =
        await showBeeContextMenu<int>(context, anchor: globalPosition, items: [
      for (var i = 0; i < items.length; i++)
        BeeMenuAction<int>(
            value: i,
            label: items[i].label,
            icon: Icon(items[i].icon, size: 20),
            danger: items[i].color == Colors.red)
    ]);
    if (selected != null && context.mounted) items[selected].onTap();
  }
}
