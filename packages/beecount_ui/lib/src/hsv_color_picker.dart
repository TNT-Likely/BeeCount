import 'package:flutter/material.dart';

/// Controlled HSV channels. The caller owns the draft, labels and confirmation.
/// Preview hex describes the actual RGB bytes, independent of the theme accent.
class BeeHsvColorPicker extends StatelessWidget {
  const BeeHsvColorPicker({
    super.key,
    required this.value,
    required this.hueLabel,
    required this.saturationLabel,
    required this.brightnessLabel,
    required this.onChanged,
  });
  final HSVColor value;
  final String hueLabel, saturationLabel, brightnessLabel;
  final ValueChanged<HSVColor>? onChanged;

  static String hex(Color color) => '#${[
        color.r,
        color.g,
        color.b
      ].map((channel) => (channel * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final color = value.toColor();
    Widget channel(String label, double position, double maximum,
            List<Color> colors, HSVColor Function(double) update) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          DecoratedBox(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(colors: colors)),
              child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                      trackHeight: 0,
                      thumbColor: Colors.white,
                      overlayColor: Colors.black12),
                  child: Slider(
                      value: position,
                      min: 0,
                      max: maximum,
                      semanticFormatterCallback: (v) => maximum == 360
                          ? '${v.round()}°'
                          : '${(v * 100).round()}%',
                      onChanged: onChanged == null
                          ? null
                          : (v) => onChanged!(update(v))))),
          const SizedBox(height: 12),
        ]);
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Theme.of(context).dividerColor)),
              child: Text(hex(color),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.light
                          ? Colors.black
                          : Colors.white))),
          const SizedBox(height: 16),
          channel(
              hueLabel,
              value.hue,
              360,
              [
                for (var i = 0; i <= 6; i++)
                  HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor()
              ],
              value.withHue),
          channel(
              saturationLabel,
              value.saturation,
              1,
              [
                value.withSaturation(0).toColor(),
                value.withSaturation(1).toColor()
              ],
              value.withSaturation),
          channel(
              brightnessLabel,
              value.value,
              1,
              [value.withValue(0).toColor(), value.withValue(1).toColor()],
              value.withValue),
        ]);
  }
}
