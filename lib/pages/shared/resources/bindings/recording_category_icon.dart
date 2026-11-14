import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../data/db.dart';
import '../category_icon_adapter.dart';
import '../../../category/editor/bindings/category_line_icon_names.dart';

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
      return LayoutBuilder(builder: (context, constraints) {
        // A square icon tile gives both dimensions; inline rows stay at the
        // requested glyph size instead of growing to the row's full height.
        final extent =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight
                ? math.min(constraints.maxWidth, constraints.maxHeight)
                : size;
        return ExcludeSemantics(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(extent * .32),
                child: CategoryIconWidget(
                    category: category,
                    size: extent,
                    color: color,
                    fallback:
                        BeeLineIcon('Shapes', size: size, color: color))));
      });
    }
    return BeeLineIcon(line ?? 'Shapes', size: size, color: color);
  }
}
