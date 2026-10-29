import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

/// Preserve the original blue initial HSV draft; cancel never writes settings.
class ThemeColorDialog extends StatefulWidget {
  const ThemeColorDialog({super.key});
  @override
  State<ThemeColorDialog> createState() => _ThemeColorDialogState();
}

class _ThemeColorDialogState extends State<ThemeColorDialog> {
  HSVColor draft = HSVColor.fromColor(Colors.blue);
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), color = draft.toColor();
    return BeeDialog(
        title: Text(l.personalizeCustomTitle),
        content: BeeHsvColorPicker(
            value: draft,
            hueLabel: l.personalizeHue(draft.hue.round()),
            saturationLabel:
                l.personalizeSaturation((draft.saturation * 100).round()),
            brightnessLabel:
                l.personalizeBrightness((draft.value * 100).round()),
            onChanged: (v) => setState(() => draft = v)),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context, color),
              style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor:
                      ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.light
                          ? Colors.black
                          : Colors.white),
              child: Text(l.personalizeSelectColor))
        ]);
  }
}
