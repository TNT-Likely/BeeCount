import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// 长按菜单贴近来源行，优先在下方显示，避开正在操作的内容。
  /// [anchor] 使用当前 Navigator 的 Overlay 坐标。
  static Future<String?> showForAnchor({
    required BuildContext context,
    required Rect anchor,
    required List<BeeMenuItem> items,
  }) {
    assert(items.isNotEmpty);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final media = MediaQuery.of(context);
    final direction = Directionality.of(context);
    final style = _actionTextStyle(context);
    const margin = 16.0;
    const gap = 8.0;
    const contentInsets = 76.0; // 图标、间距、行内边距和菜单内边距。
    final maxWidth = math.min(
        320.0, overlay.size.width - media.padding.horizontal - margin * 2);
    final minWidth = math.min(208.0, maxWidth);
    Size measure(BeeMenuItem item, double width) {
      final painter = TextPainter(
        text: TextSpan(text: item.label ?? '', style: style),
        textDirection: direction,
        textScaler: media.textScaler,
      )..layout(maxWidth: width);
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final width = items
        .fold<double>(
            minWidth,
            (value, item) => math.max(
                value, measure(item, double.infinity).width + contentInsets))
        .clamp(minWidth, maxWidth)
        .toDouble();
    final height = items.fold<double>(
        8,
        (value, item) =>
            value +
            switch (item.type) {
              BeeMenuItemType.action =>
                math.max(56, measure(item, width - contentInsets).height + 16),
              BeeMenuItemType.tip => 40,
              BeeMenuItemType.divider => 1,
            });
    final safeTop = media.padding.top + gap;
    final safeBottom = overlay.size.height -
        math.max(media.padding.bottom, media.viewInsets.bottom) -
        gap;
    final top = anchor.bottom + gap + height <= safeBottom
        ? anchor.bottom + gap
        : anchor.top - height - gap;
    final left = direction == TextDirection.ltr
        ? anchor.right - margin - width
        : anchor.left + margin;
    final position = Rect.fromLTWH(
      left
          .clamp(media.padding.left + margin,
              overlay.size.width - media.padding.right - margin - width)
          .toDouble(),
      top.clamp(safeTop, math.max(safeTop, safeBottom - height)).toDouble(),
      width,
      height,
    );
    final menu = BeePopupMenu(items: items);
    HapticFeedback.selectionClick();
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(position, Offset.zero & overlay.size),
      constraints: BoxConstraints.tightFor(width: width),
      menuPadding: const EdgeInsets.all(4),
      color: BeeTokens.surfaceElevated(context),
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: Colors.black
          .withValues(alpha: BeeTokens.isDark(context) ? 0.32 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: BeeTokens.listDayDividerColor(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      popUpAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 180),
        reverseDuration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      ),
      items: menu._buildEntries(context, BeeTokens.primary(context),
          contextual: true),
    );
  }

  static TextStyle _actionTextStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 15,
            color: BeeTokens.textPrimary(context),
            fontWeight: FontWeight.w500,
          );

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
      itemBuilder: (context) => _buildEntries(context, themeColor),
    );
  }

  List<PopupMenuEntry<String>> _buildEntries(
          BuildContext context, Color themeColor,
          {bool contextual = false}) =>
      [
        for (final item in items)
          switch (item.type) {
            BeeMenuItemType.action => _buildActionItem(
                context, item, themeColor,
                contextual: contextual),
            BeeMenuItemType.tip => _buildTipItem(context, item),
            BeeMenuItemType.divider => const PopupMenuDivider(height: 1),
          },
      ];

  PopupMenuItem<String> _buildActionItem(
    BuildContext context,
    BeeMenuItem item,
    Color themeColor, {
    bool contextual = false,
  }) {
    final color = item.isDanger ? Colors.red : themeColor;
    final label = Text(
      item.label ?? '',
      style: contextual
          ? _actionTextStyle(context).copyWith(
              color:
                  item.isDanger ? Colors.red : BeeTokens.textPrimary(context),
            )
          : TextStyle(
              fontSize: 15,
              color:
                  item.isDanger ? Colors.red : BeeTokens.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
    );

    return PopupMenuItem<String>(
      value: item.value,
      height: contextual ? 56 : 48,
      padding: EdgeInsets.symmetric(horizontal: contextual ? 12 : 16),
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
          if (contextual) Expanded(child: label) else label,
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
