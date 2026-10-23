import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../data/db.dart';
import '../../../widgets/category_icon.dart';
import 'category_line_icon_names.dart';

/// Map saved icon identifiers, never category names. Custom images keep their colors.
class RecordingCategoryIcon extends StatelessWidget {
  const RecordingCategoryIcon(
      {super.key, required this.category, this.size = 18, this.color});
  final Category category;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final line = categoryLineIconNames[category.icon];
    if (category.iconType == 'custom') {
      return CategoryIconWidget(
          category: category,
          size: size,
          color: color,
          fallback: BeeLineIcon('Shapes', size: size, color: color));
    }
    return BeeLineIcon(line ?? 'Shapes', size: size, color: color);
  }
}
