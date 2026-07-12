import 'dart:io';

import '../db.dart';
import '../../services/custom_icon_service.dart';

/// 图标类型枚举
enum CategoryIconType {
  material, // Flutter Material Icons (默认)
  custom, // 用户自定义图片
}

/// 分类图标数据封装
class CategoryIconData {
  final CategoryIconType type;
  final String? materialIcon; // type=material 时使用
  final String? customIconPath; // type=custom 时，本地路径

  const CategoryIconData({
    this.type = CategoryIconType.material,
    this.materialIcon,
    this.customIconPath,
  });

  /// 从数据库 Category 记录构建
  factory CategoryIconData.fromCategory(Category category) {
    final typeStr = category.iconType;
    CategoryIconType iconType;

    switch (typeStr) {
      case 'custom':
        iconType = CategoryIconType.custom;
        break;
      case 'material':
      default:
        iconType = CategoryIconType.material;
    }

    return CategoryIconData(
      type: iconType,
      materialIcon: category.icon,
      customIconPath: category.customIconPath,
    );
  }

  /// 创建 Material Icon 类型
  factory CategoryIconData.material(String iconName) {
    return CategoryIconData(
      type: CategoryIconType.material,
      materialIcon: iconName,
    );
  }

  /// 创建自定义图标类型
  factory CategoryIconData.custom(String path) {
    return CategoryIconData(
      type: CategoryIconType.custom,
      customIconPath: path,
    );
  }

  /// 是否有有效图标
  bool get hasIcon => materialIcon != null || customIconPath != null;

  /// 是否为自定义图标
  bool get isCustom => type == CategoryIconType.custom;

  /// 是否为 Material 图标
  bool get isMaterial => type == CategoryIconType.material;

  /// 获取自定义图标文件（如果存在）
  /// 注意：customIconPath 现在是相对路径，需要解析为绝对路径
  Future<File?> getCustomIconFile() async {
    if (customIconPath == null) return null;
    final absolutePath =
        await CustomIconService().resolveIconPath(customIconPath!);
    return File(absolutePath);
  }

  /// 自定义图标文件是否存在
  Future<bool> get customIconExists async {
    final file = await getCustomIconFile();
    if (file == null) return false;
    return file.exists();
  }

  /// 转换为数据库字段值
  String get iconTypeValue {
    switch (type) {
      case CategoryIconType.custom:
        return 'custom';
      case CategoryIconType.material:
        return 'material';
    }
  }

  @override
  String toString() {
    return 'CategoryIconData(type: $type, materialIcon: $materialIcon, '
        'customIconPath: $customIconPath)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryIconData &&
        other.type == type &&
        other.materialIcon == materialIcon &&
        other.customIconPath == customIconPath;
  }

  @override
  int get hashCode {
    return Object.hash(type, materialIcon, customIconPath);
  }
}
