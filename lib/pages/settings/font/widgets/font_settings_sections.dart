import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

Map<int, String> fontLevelLabels(AppLocalizations l) => {
      -3: l.fontSettingsExtraSmall,
      -2: l.fontSettingsVerySmall,
      -1: l.fontSettingsSmall,
      0: l.fontSettingsStandard,
      1: l.fontSettingsLarge,
      2: l.fontSettingsBig,
      3: l.fontSettingsVeryBig,
      4: l.fontSettingsExtraBig,
    };

/// Page-specific composition of existing foundations; no persistence in views.
class FontPreviewSection extends StatelessWidget {
  const FontPreviewSection(
      {super.key, required this.levelLabel, required this.effective});
  final String levelLabel;
  final double effective;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context), muted = Theme.of(context).hintColor;
    Widget sample(String label, String value, double size,
            {bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 72,
                child:
                    Text(label, style: TextStyle(fontSize: 11, color: muted))),
            const SizedBox(width: 8),
            Expanded(
                child: Text(value,
                    style: TextStyle(
                        fontSize: size,
                        fontWeight: bold ? FontWeight.w600 : FontWeight.w400))),
          ]),
        );
    return BeeSurface(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.fontSettingsPreview,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Text(l.fontSettingsPreviewText,
          style: const TextStyle(fontSize: 14, height: 1.5)),
      const SizedBox(height: 8),
      Text(l.fontSettingsCurrentLevel(levelLabel, effective.toStringAsFixed(2)),
          style: TextStyle(fontSize: 11, color: muted)),
      const BeeDivider(),
      Text(l.fontSettingsMoreStyles,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      sample(l.fontSettingsPageTitle, '月度统计与分析', 20, bold: true),
      sample(l.fontSettingsBlockTitle, '最近记账', 16, bold: true),
      sample(l.fontSettingsBodyExample, '今天早餐：豆浆 + 包子 6.50 元', 14),
      sample(l.fontSettingsLabelExample, '隐藏金额已开启', 11),
      sample(l.fontSettingsStrongNumber, '1234.56', 18, bold: true),
      const BeeDivider(),
      LayoutBuilder(builder: (context, box) {
        const amount = Text('123.45',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600));
        final stacked = box.maxWidth < 300 &&
            MediaQuery.textScalerOf(context).scale(14) > 18;
        final row = BeeMenuRow(
            title: l.fontSettingsListTitle,
            subtitle: l.fontSettingsListSubtitle,
            leading: const BeeLineIcon('Palette'),
            trailing: stacked ? null : amount);
        return stacked
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                row,
                const Align(alignment: Alignment.centerRight, child: amount)
              ])
            : row;
      }),
    ]));
  }
}

class FontControlsSection extends StatelessWidget {
  const FontControlsSection(
      {super.key,
      required this.level,
      required this.custom,
      required this.effective,
      required this.onLevel,
      required this.onScale,
      required this.onReset,
      required this.onAdapt});
  final int level;
  final double custom, effective;
  final ValueChanged<int> onLevel;
  final ValueChanged<double> onScale;
  final VoidCallback onReset, onAdapt;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.fontSettingsQuickLevel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final option in fontLevelLabels(l).entries)
            BeeChoiceChip(
                label: option.value,
                selected: (custom - 1).abs() <= .01 && level == option.key,
                onSelected: (_) => onLevel(option.key)),
        ]),
      ])),
      const SizedBox(height: 12),
      BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.fontSettingsCustomAdjust,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        BeeSliderField(
            label: l.fontSettingsPreciseAdjust,
            value: custom,
            valueLabel: 'x${effective.toStringAsFixed(2)}',
            min: .7,
            max: 1.5,
            divisions: 80,
            onChanged: onScale),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('0.7x', style: TextStyle(fontSize: 11)),
          Text('1.0x', style: TextStyle(fontSize: 11)),
          Text('1.5x', style: TextStyle(fontSize: 11))
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final buttons = [
            BeeButton(
                label: l.fontSettingsResetTo1x,
                kind: BeeButtonKind.secondary,
                onPressed: onReset),
            BeeButton(
                label: l.fontSettingsAdaptBase,
                kind: BeeButtonKind.secondary,
                onPressed: onAdapt)
          ];
          return box.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(13) > 16
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [buttons[0], const SizedBox(height: 8), buttons[1]])
              : Row(children: [
                  Expanded(child: buttons[0]),
                  const SizedBox(width: 12),
                  Expanded(child: buttons[1])
                ]);
        }),
      ])),
    ]);
  }
}

class FontDeviceInfoSection extends StatelessWidget {
  const FontDeviceInfoSection(
      {super.key, required this.info, required this.exampleSize});
  final Map<String, double> info;
  final double exampleSize;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final values = {
      l.fontSettingsScreenDensity: info['devicePixelRatio']!.toStringAsFixed(2),
      l.fontSettingsScreenWidth: '${info['screenWidth']!.toStringAsFixed(0)}dp',
      l.fontSettingsDeviceScale:
          'x${info['deviceScaleFactor']!.toStringAsFixed(2)}',
      l.fontSettingsUserScale:
          'x${info['userScaleFactor']!.toStringAsFixed(2)}',
      l.fontSettingsFinalScale:
          'x${info['finalScaleFactor']!.toStringAsFixed(2)}',
      l.fontSettingsBaseDevice:
          info['isBaseDevice']! > .5 ? l.fontSettingsYes : l.fontSettingsNo,
      l.fontSettingsRecommendedScale:
          'x${info['recommendedUserScale']!.toStringAsFixed(2)}',
    };
    return BeeSurface(
        padding: EdgeInsets.zero,
        child: BeeAccordion(
            title: l.fontSettingsScreenInfo,
            child: Column(children: [
              for (final entry in values.entries)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                          child: Text(entry.key,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor))),
                      const SizedBox(width: 8),
                      Text(entry.value, style: const TextStyle(fontSize: 12))
                    ])),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                    width: exampleSize,
                    height: exampleSize,
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(l.fontSettingsScaleExample,
                        style: const TextStyle(fontSize: 11)))
              ]),
            ])));
  }
}
