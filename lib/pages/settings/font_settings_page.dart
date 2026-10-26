import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/v4/bindings/page_scaffold.dart';
import '../../presentation/v4/sections/font_settings_sections.dart';
import '../../providers/font_scale_provider.dart';
import '../../services/ui/ui_scale_service.dart';

class FontSettingsPage extends ConsumerWidget {
  const FontSettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        level = ref.watch(fontScaleLevelProvider),
        custom = ref.watch(customFontScaleProvider),
        effective = ref.watch(effectiveFontScaleProvider);
    void select(int next) {
      // Standard may already be selected while a custom scale is active: clear
      // it explicitly instead of depending on an unchanged StateProvider value.
      ref.read(customFontScaleProvider.notifier).state = 1;
      ref.read(fontScaleLevelProvider.notifier).state = next;
    }

    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.mineDisplayScale, leading: const BackButton()),
      Expanded(
          child: ListView(padding: const EdgeInsets.all(17), children: [
        Text(l.fontSettingsCurrentScale(effective.toStringAsFixed(2)),
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 12),
        FontPreviewSection(
            levelLabel: (custom - 1).abs() > .01
                ? l.fontSettingsCustomAdjust
                : fontLevelLabels(l)[level] ?? l.fontSettingsStandard,
            effective: effective),
        const SizedBox(height: 12),
        FontControlsSection(
            level: level,
            custom: custom,
            effective: effective,
            onLevel: select,
            onScale: (value) {
              ref.read(fontScaleLevelProvider.notifier).state = 0;
              ref.read(customFontScaleProvider.notifier).state = value;
            },
            onReset: () => select(0),
            onAdapt: () {
              select(0);
              ref.read(customFontScaleProvider.notifier).state =
                  UIScaleService.getRecommendedUserScale(context);
            }),
        const SizedBox(height: 12),
        FontDeviceInfoSection(
            info: ref.watch(uiScaleDebugProvider(context)),
            exampleSize: UIScaleService.scale(context, 24, effective)),
        const SizedBox(height: 12),
        Text(l.fontSettingsDescription,
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
      ])),
    ]));
  }
}
