library;

import 'package:flutter/material.dart';
export 'src/line_icon.dart';
export 'src/line_chart.dart';
export 'src/column_chart.dart';
export 'src/compact_tabs.dart';
export 'src/underline_tabs.dart';
export 'src/hsv_color_picker.dart';
export 'src/foundations.dart';
export 'src/dialogs.dart';
export 'src/controls.dart';
export 'src/code_components.dart';
export 'src/form_components.dart';
export 'src/selection_components.dart';
export 'src/layout_components.dart';
export 'src/page_components.dart';
export 'src/launch_motion.dart';
export 'src/local_sheet.dart';
export 'src/system_bars.dart';

/// Local v4 surfaces. The app supplies its existing accent and brightness.
@immutable
class BeeCardTheme extends ThemeExtension<BeeCardTheme> {
  const BeeCardTheme(
      {required this.canvas,
      required this.surface,
      required this.soft,
      this.divider = const Color(0xffeceeef)});

  factory BeeCardTheme.fromBrightness(Brightness brightness) =>
      brightness == Brightness.dark
          ? const BeeCardTheme(
              canvas: Color(0xff181c20),
              surface: Color(0xff23282e),
              soft: Color(0xff2c3239),
              divider: Color(0xff373e46))
          : const BeeCardTheme(
              canvas: Color(0xfff5f6f7),
              surface: Colors.white,
              soft: Color(0xfff3f4f5));

  final Color canvas;
  final Color surface;
  final Color soft;
  final Color divider;

  static BeeCardTheme of(BuildContext context) =>
      Theme.of(context).extension<BeeCardTheme>() ??
      BeeCardTheme.fromBrightness(Theme.of(context).brightness);

  @override
  BeeCardTheme copyWith(
          {Color? canvas, Color? surface, Color? soft, Color? divider}) =>
      BeeCardTheme(
          canvas: canvas ?? this.canvas,
          surface: surface ?? this.surface,
          soft: soft ?? this.soft,
          divider: divider ?? this.divider);

  @override
  BeeCardTheme lerp(covariant BeeCardTheme? other, double t) => other == null
      ? this
      : BeeCardTheme(
          canvas: Color.lerp(canvas, other.canvas, t)!,
          surface: Color.lerp(surface, other.surface, t)!,
          soft: Color.lerp(soft, other.soft, t)!,
          divider: Color.lerp(divider, other.divider, t)!);
}

class BeeSurface extends StatelessWidget {
  const BeeSurface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.borderRadius = const BorderRadius.all(Radius.circular(22)),
      this.background});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// Optional controlled decoration; the content keeps its layout and hit targets.
  final Widget? background;

  @override
  Widget build(BuildContext context) => Material(
        color: background == null
            ? BeeCardTheme.of(context).surface
            : Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: background == null ? Clip.none : Clip.antiAlias,
        child: background == null
            ? Padding(padding: padding, child: child)
            : Stack(children: [
                Positioned.fill(
                    child: IgnorePointer(
                        child: ExcludeSemantics(child: background!))),
                Padding(padding: padding, child: child)
              ]),
      );
}
