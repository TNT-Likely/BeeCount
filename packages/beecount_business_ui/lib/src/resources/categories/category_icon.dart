import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

/// ImageProvider supports file, memory, network or the host's cached image layer.
/// Images keep their own colors; only the fallback/line icon is tinted.
class BeeCategoryIcon extends StatelessWidget {
  const BeeCategoryIcon(
      {super.key,
      this.name = 'Shapes',
      this.image,
      this.size = 34,
      this.selected = false,
      this.crop = false,
      this.label});
  final String name;
  final ImageProvider? image;
  final double size;
  final bool selected, crop;
  final String? label;
  @override
  Widget build(BuildContext context) {
    Widget fallback() => BeeLineIcon(name, size: size * .55);
    return Semantics(
        label: label,
        image: true,
        child: Container(
            width: size,
            height: size,
            padding:
                image == null ? EdgeInsets.all(size * .16) : EdgeInsets.zero,
            decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : BeeCardTheme.of(context).soft,
                borderRadius: BorderRadius.circular(size * .32)),
            child: image == null
                ? fallback()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(size * .32),
                    child: Image(
                        image: image!,
                        fit: crop ? BoxFit.cover : BoxFit.contain,
                        frameBuilder: (_, child, frame, synchronous) =>
                            synchronous || frame != null
                                ? child
                                : const Center(
                                    child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 1.5))),
                        errorBuilder: (_, error, stack) => fallback()))));
  }
}
