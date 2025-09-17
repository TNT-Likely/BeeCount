import 'package:flutter/material.dart';
import '../services/category_service.dart';

/// 统一的分类名称到图标映射，供列表与分类选择共用，保证一致性
/// 现在使用CategoryService的智能推导功能
IconData iconForCategory(String name) {
  return CategoryService.getCategoryIconByName(name);
}
