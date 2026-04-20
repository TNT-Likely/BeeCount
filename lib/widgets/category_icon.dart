import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/data/category_service.dart';
import '../services/custom_icon_service.dart';
import '../data/db.dart';
import '../data/models/category_icon.dart';
import '../providers/theme_providers.dart';

/// 获取分类的图标数据。**永远只读 `category.icon` 字段**,不再按名字推导。
///
/// 历史上本函数在 icon 为空时走 `getCategoryIconByName`(40 条中文关键字正则)
/// 模糊推导 —— 问题多(改名换图标、只认中文、web/server 必须复刻两套)。v23
/// DB migration 已把所有 icon 为空的分类按 byName 一次性固化到 DB,此后渲染
/// 路径只信任 icon 字段。彻底删除 byName 逻辑的毒瘤。
///
/// [category] 分类对象
/// [categoryName] 兼容保留:当 category 为 null 但需要提示性显示时使用(兜底
///   永远是 `Icons.category`,不再按名字推导)
IconData getCategoryIconData({Category? category, String? categoryName}) {
  if (category != null && category.icon != null && category.icon!.isNotEmpty) {
    return CategoryService.getCategoryIcon(category.icon);
  }
  // icon 空(v23 后理论上不应该发生,除非分类刚创建还没走过 migration)→
  // 统一兜底 Icons.category,跟 getCategoryIcon(null) 行为一致。
  return CategoryService.getCategoryIcon(null);
}

/// 分类图标组件
/// 支持 Material Icons 和自定义图片
class CategoryIconWidget extends ConsumerWidget {
  final Category? category;
  final String? categoryName;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final bool showBackground;
  final bool circular; // 是否使用完全圆形（50%圆角），默认为微圆角（20%）

  const CategoryIconWidget({
    super.key,
    this.category,
    this.categoryName,
    this.size = 24,
    this.color,
    this.backgroundColor,
    this.showBackground = false,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(primaryColorProvider);
    final iconColor = color ?? primaryColor;

    // 检查是否有自定义图标
    if (category != null && category!.iconType == 'custom' && category!.customIconPath != null) {
      return _buildCustomIcon(category!.customIconPath!, iconColor);
    }

    // 使用 Material Icon
    final iconData = getCategoryIconData(category: category, categoryName: categoryName);

    if (showBackground) {
      return Container(
        width: size * 1.5,
        height: size * 1.5,
        decoration: BoxDecoration(
          color: backgroundColor ?? iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(size * 0.375),
        ),
        child: Center(
          child: Icon(iconData, size: size, color: iconColor),
        ),
      );
    }

    return Icon(iconData, size: size, color: iconColor);
  }

  Widget _buildCustomIcon(String path, Color fallbackColor) {
    // 需要异步解析相对路径,使用 FutureBuilder
    return FutureBuilder<String>(
      future: CustomIconService().resolveIconPath(path),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // 加载中,显示占位图标
          return Icon(
            Icons.category,
            size: size,
            color: fallbackColor,
          );
        }

        final absolutePath = snapshot.data!;
        final file = File(absolutePath);

        // 图标本身 - 不做圆角裁剪，但填满1:1区域
        final iconWidget = Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover, // 填满整个区域，保持1:1比例
          errorBuilder: (_, __, ___) => Icon(
            Icons.category,
            size: size,
            color: fallbackColor,
          ),
        );

        if (showBackground) {
          // circular 参数只影响背景容器的形状
          final backgroundRadius = circular ? size * 0.75 : size * 0.375;
          return Container(
            width: size * 1.5,
            height: size * 1.5,
            decoration: BoxDecoration(
              color: backgroundColor ?? fallbackColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(backgroundRadius),
            ),
            child: Center(child: iconWidget),
          );
        }

        return iconWidget;
      },
    );
  }
}

/// 从 Category 创建 CategoryIconData
CategoryIconData getCategoryIconDataFromCategory(Category category) {
  return CategoryIconData.fromCategory(category);
}
