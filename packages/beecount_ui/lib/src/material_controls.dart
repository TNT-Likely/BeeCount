import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../beecount_ui.dart';

/// Controlled presentation only. The host owns persistence and the page scene.
class BeeMaterialControls extends StatelessWidget {
  const BeeMaterialControls({
    super.key,
    required this.opacity,
    required this.blur,
    required this.onOpacityChanged,
    required this.onBlurChanged,
    required this.transparencyLabel,
    required this.blurLabel,
    required this.opaqueLabel,
    required this.transparentLabel,
    required this.blurOffLabel,
    required this.blurStrongLabel,
    required this.resetLabel,
    required this.onReset,
    this.onOpacityChangeEnd,
    this.onBlurChangeEnd,
  });
  final double opacity, blur;
  final ValueChanged<double> onOpacityChanged, onBlurChanged;
  final ValueChanged<double>? onOpacityChangeEnd, onBlurChangeEnd;
  final String transparencyLabel,
      blurLabel,
      opaqueLabel,
      transparentLabel,
      blurOffLabel,
      blurStrongLabel,
      resetLabel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final alpha = BeePageMaterial.normalizeOpacity(opacity);
    final sigma = BeePageMaterial.normalizeBlur(blur);
    Widget heading(String label, String value) => Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500))),
          Text(value,
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor))
        ]);
    Widget ends(String first, String last) => Row(children: [
          Expanded(
              child: Text(first,
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).hintColor))),
          Text(last,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
        ]);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          heading(transparencyLabel, '${((1 - alpha) * 100).round()}%'),
          Slider(
              key: const ValueKey('material-transparency'),
              value: 1 - alpha,
              min: 0,
              max: .9,
              divisions: 18,
              label: '${((1 - alpha) * 100).round()}%',
              onChanged: (v) => onOpacityChanged(1 - v),
              onChangeEnd: onOpacityChangeEnd == null
                  ? null
                  : (v) => onOpacityChangeEnd!(1 - v)),
          ends(opaqueLabel, transparentLabel),
          const SizedBox(height: 24),
          heading(blurLabel, sigma == 0 ? blurOffLabel : '${sigma.round()}'),
          Slider(
              key: const ValueKey('material-blur'),
              value: sigma,
              min: 0,
              max: BeePageMaterial.maxBlur,
              divisions: 16,
              label: sigma == 0 ? blurOffLabel : '${sigma.round()}',
              onChanged: onBlurChanged,
              onChangeEnd: onBlurChangeEnd),
          ends(blurOffLabel, blurStrongLabel),
          const SizedBox(height: 20),
          BeeButton(
              label: resetLabel,
              kind: BeeButtonKind.secondary,
              onPressed: onReset)
        ]);
  }
}

/// A bounded material sample, including inside an otherwise opaque settings
/// sheet. Only this preview blurs its own backdrop; modal content stays opaque.
class BeeMaterialPreview extends StatelessWidget {
  const BeeMaterialPreview(
      {super.key,
      required this.opacity,
      required this.blur,
      required this.background,
      required this.child});
  final double opacity, blur;
  final Widget background, child;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(children: [
        Positioned.fill(
            child: IgnorePointer(child: ExcludeSemantics(child: background))),
        Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                    enabled: BeePageMaterial.normalizeBlur(blur) > 0,
                    filter: ui.ImageFilter.blur(
                        sigmaX: BeePageMaterial.normalizeBlur(blur),
                        sigmaY: BeePageMaterial.normalizeBlur(blur)),
                    child: BeePageMaterial(
                        enabled: true,
                        opacity: opacity,
                        blur: 0,
                        child: BeeSurface(child: child))))),
      ]));
}
