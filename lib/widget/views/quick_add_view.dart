import 'package:flutter/material.dart';

import '../widget_data_service.dart' show QuickAddCategoryItem;
import '../widget_spec.dart' show HWSize;
import 'widget_view_style.dart';

/// 常用分类作为记账参考。原生宿主为整张卡提供一个新增支出的入口。
class QuickAddView extends StatelessWidget {
  final HWSize size;
  final List<QuickAddCategoryItem> categories;
  final Color themeColor;
  final bool dark;
  final String addLabel;
  final String titleLabel;
  final String frequentLabel;
  final String emptyLabel;
  final double width;
  final double height;

  const QuickAddView({
    super.key,
    required this.size,
    required this.categories,
    required this.themeColor,
    required this.dark,
    required this.addLabel,
    required this.width,
    required this.height,
    this.titleLabel = '快速记账',
    this.frequentLabel = '常用分类',
    this.emptyLabel = '暂无常用分类',
  });

  bool get _small => size == HWSize.small;

  @override
  Widget build(BuildContext context) {
    final columns = _small ? 2 : 4;
    final visible = categories.take(_small ? 3 : 7).toList();
    return WidgetCardSurface(
      dark: dark,
      width: width,
      height: height,
      padding: _small ? const EdgeInsets.all(13) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WidgetCardHeading(
            icon: Icons.add_circle_outline,
            title: titleLabel,
            dark: dark,
            compact: _small,
          ),
          SizedBox(height: _small ? 5 : 8),
          if (visible.isNotEmpty) ...[
            _label(frequentLabel, 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var start = 0;
                      start < visible.length;
                      start += columns) ...[
                    if (start > 0) const SizedBox(height: 4),
                    Row(
                      children: [
                        for (var i = start; i < start + columns; i++) ...[
                          if (i > start) const SizedBox(width: 4),
                          Expanded(
                            child: i < visible.length
                                ? _category(visible[i])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ] else
            Expanded(
              child: WidgetCardEmpty(
                icon: Icons.format_list_bulleted,
                label: emptyLabel,
                dark: dark,
                compact: _small,
              ),
            ),
          SizedBox(height: _small ? 4 : 8),
          Container(
            height: _small ? 29 : 34,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 15, color: widgetOnAccent(themeColor)),
                const SizedBox(width: 5),
                Text(
                  addLabel,
                  maxLines: 1,
                  style: TextStyle(
                    height: 1.1,
                    fontSize: _small ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: widgetOnAccent(themeColor),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, double fontSize) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: widgetTextSecondary(dark),
          fontWeight: FontWeight.w500,
          fontSize: fontSize,
          height: 1.15,
        ),
      );

  Widget _category(QuickAddCategoryItem item) {
    return Row(
      children: [
        SizedBox.square(
          dimension: 14,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: widgetCategoryIcon(
              icon: item.icon,
              color: widgetTextSecondary(dark),
              size: 14,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(child: _label(item.name, _small ? 9 : 10)),
      ],
    );
  }
}
