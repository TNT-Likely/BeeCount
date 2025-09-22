import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/category_service.dart';

/// 分类相关的工具函数
class CategoryUtils {
  /// 获取分类的显示名称（会翻译默认分类）
  static String getDisplayName(String? categoryName, BuildContext context) {
    if (categoryName == null || categoryName.isEmpty) {
      return AppLocalizations.of(context).categoryDefaultTitle;
    }

    // 如果是默认分类，则进行翻译
    final l10n = AppLocalizations.of(context);
    return CategoryService.translateCategoryName(categoryName, l10n);
  }
}