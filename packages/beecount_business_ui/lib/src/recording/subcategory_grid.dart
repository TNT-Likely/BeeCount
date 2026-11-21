import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'recording_components.dart';
import '../resources/categories/category_choice.dart';

/// Four columns in source order. Long labels span two cells and wrap within
/// that width. This widget never queries data or changes selection by itself.
class RecordingSubcategoryGrid extends StatelessWidget {
  const RecordingSubcategoryGrid({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.selectedAnchorKey,
  });
  final List<BeeCategoryChoice> items;
  final String? selected;
  final ValueChanged<String> onSelected;
  final Key? selectedAnchorKey;
  static const spacing = 5.0;
  static const minimumItemHeight = 44.0;
  static const _labelChrome = 16 + 5 + 12.0;

  static TextPainter _labelPainter(BuildContext context, BeeCategoryChoice item,
      {bool singleLine = false, bool selected = false}) {
    final defaults = DefaultTextStyle.of(context);
    final style = defaults.style.merge(
      Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
    );
    return TextPainter(
      text: TextSpan(
        text: item.label,
        style: MediaQuery.boldTextOf(context)
            ? style.merge(const TextStyle(fontWeight: FontWeight.bold))
            : style,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      textHeightBehavior: defaults.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      maxLines: singleLine ? 1 : null,
    );
  }

  static int _span(BuildContext context, BeeCategoryChoice item, double cell) {
    // Reserve selected weight so choosing a chip never changes its span.
    final text = _labelPainter(context, item, singleLine: true, selected: true)
      ..layout();
    final span = text.width + _labelChrome > cell ? 2 : 1;
    text.dispose();
    return span;
  }

  /// Natural height of the recording chips before the parent limits scrolling.
  static double recordingHeightFor(BuildContext context,
      List<BeeCategoryChoice> items, double width, String? selected) {
    final cell = (width - 3 * spacing) / 4;
    var used = 0;
    var runHeight = 0.0;
    var height = 0.0;
    for (final item in items) {
      final span = _span(context, item, cell);
      if (used + span > 4) {
        height += runHeight + spacing;
        used = 0;
        runHeight = 0;
      }
      final text = _labelPainter(context, item, selected: item.id == selected)
        ..layout(
            maxWidth:
                math.max(0, cell * span + spacing * (span - 1) - _labelChrome));
      runHeight =
          math.max(runHeight, math.max(minimumItemHeight, text.height + 14));
      text.dispose();
      used += span;
    }
    return height + runHeight;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth;
        final cell = (width - 3 * spacing) / 4;
        return Wrap(spacing: spacing, runSpacing: spacing, children: [
          for (final item in items)
            Builder(builder: (context) {
              final span = _span(context, item, cell);
              return SizedBox(
                  key: item.id == selected ? selectedAnchorKey : null,
                  width: cell * span + spacing * (span - 1),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                            constraints: const BoxConstraints(
                                minHeight: minimumItemHeight),
                            child: Opacity(
                                opacity: item.enabled ? 1 : .4,
                                child: Tooltip(
                                    message: item.label,
                                    child: RecordingSubcategoryChip(
                                        key: ValueKey(
                                            'recording-category-${item.id}'),
                                        label: item.label,
                                        icon: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: item.icon),
                                        selected: item.id == selected,
                                        wrapLabel: true,
                                        onTap: item.enabled
                                            ? () => onSelected(item.id)
                                            : null)))),
                        if (item.detail != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(item.detail!,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).hintColor))),
                      ]));
            }),
        ]);
      });
}
