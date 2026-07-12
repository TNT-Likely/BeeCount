import 'package:flutter/material.dart';
import '../../styles/tokens.dart';

/// 标签 Chip 组件
/// 用于显示交易关联的标签
class TagChip extends StatelessWidget {
  /// 标签名称
  final String name;

  /// 标签颜色（十六进制字符串，如 #FF5722）
  /// 如果为空，则使用主题色
  final String? color;

  /// 点击回调
  final VoidCallback? onTap;

  /// 是否显示删除按钮
  final bool showDelete;

  /// 删除回调
  final VoidCallback? onDelete;

  /// 是否被选中（用于选择器）
  final bool isSelected;

  /// 尺寸
  final TagChipSize size;

  const TagChip({
    super.key,
    required this.name,
    this.color,
    this.onTap,
    this.showDelete = false,
    this.onDelete,
    this.isSelected = false,
    this.size = TagChipSize.small,
  });

  /// 解析颜色字符串
  Color _parseColor(BuildContext context) {
    if (color == null || color!.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }

    try {
      String hex = color!;
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagColor = _parseColor(context);
    final isDark = BeeTokens.isDark(context);

    // 根据尺寸设置参数
    final double height;
    final double fontSize;
    final double horizontalPadding;
    final double iconSize;

    switch (size) {
      case TagChipSize.small:
        height = 20;
        fontSize = 11;
        horizontalPadding = 8;
        iconSize = 12;
        break;
      case TagChipSize.medium:
        height = 28;
        fontSize = 13;
        horizontalPadding = 12;
        iconSize = 16;
        break;
      case TagChipSize.large:
        height = 36;
        fontSize = 15;
        horizontalPadding = 16;
        iconSize = 18;
        break;
    }

    // 背景色：标签颜色的10%透明度
    final backgroundColor = isSelected
        ? tagColor.withValues(alpha: isDark ? 0.3 : 0.2)
        : tagColor.withValues(alpha: isDark ? 0.15 : 0.1);

    // 边框色（选中时显示）
    final borderColor = isSelected ? tagColor : Colors.transparent;

    Widget chip = Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: fontSize,
              color: tagColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (showDelete) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close,
                size: iconSize,
                color: tagColor,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      chip = GestureDetector(
        onTap: onTap,
        child: chip,
      );
    }

    return chip;
  }
}

/// 标签尺寸
enum TagChipSize {
  /// 小尺寸（用于列表项）
  small,

  /// 中尺寸（用于选择器）
  medium,

  /// 大尺寸（用于详情页）
  large,
}

/// 标签列表组件
/// 用于显示多个标签，支持省略显示
class TagChipList extends StatelessWidget {
  /// 标签列表（包含ID用于导航）
  final List<({int id, String name, String? color})> tags;

  /// 最多显示数量，超出显示 +N
  final int maxDisplay;

  /// 标签点击回调（传入标签ID和名称）
  final void Function(int tagId, String tagName)? onTagTap;

  /// 点击 +N 的回调
  final VoidCallback? onMoreTap;

  /// 标签尺寸
  final TagChipSize size;

  /// 标签间距
  final double spacing;

  const TagChipList({
    super.key,
    required this.tags,
    this.maxDisplay = 3,
    this.onTagTap,
    this.onMoreTap,
    this.size = TagChipSize.small,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayTags = tags.take(maxDisplay).toList();
    final moreCount = tags.length - maxDisplay;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        ...displayTags.map((tag) {
          return TagChip(
            name: tag.name,
            color: tag.color,
            size: size,
            onTap: onTagTap != null ? () => onTagTap!(tag.id, tag.name) : null,
          );
        }),
        if (moreCount > 0)
          GestureDetector(
            onTap: onMoreTap,
            child: Container(
              height: size == TagChipSize.small
                  ? 20
                  : (size == TagChipSize.medium ? 28 : 36),
              padding: EdgeInsets.symmetric(
                horizontal: size == TagChipSize.small
                    ? 8
                    : (size == TagChipSize.medium ? 12 : 16),
              ),
              decoration: BoxDecoration(
                color: BeeTokens.isDark(context)
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(
                  size == TagChipSize.small
                      ? 10
                      : (size == TagChipSize.medium ? 14 : 18),
                ),
              ),
              child: Center(
                child: Text(
                  '+$moreCount',
                  style: TextStyle(
                    fontSize: size == TagChipSize.small
                        ? 11
                        : (size == TagChipSize.medium ? 13 : 15),
                    color: BeeTokens.textSecondary(context),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
