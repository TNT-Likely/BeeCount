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
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth;
        final cell = (width - 3 * spacing) / 4;
        final style = Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600);
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        return Wrap(spacing: spacing, runSpacing: spacing, children: [
          for (final item in items)
            Builder(builder: (context) {
              // Reserve selected weight for every item so selecting never reflows.
              final text = TextPainter(
                  text: TextSpan(text: item.label, style: style),
                  textDirection: direction,
                  textScaler: scaler,
                  locale: Localizations.maybeLocaleOf(context),
                  maxLines: 1)
                ..layout();
              final span = text.width + 16 + 5 + 12 > cell ? 2 : 1;
              text.dispose();
              return SizedBox(
                  key: item.id == selected ? selectedAnchorKey : null,
                  width: cell * span + spacing * (span - 1),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
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
