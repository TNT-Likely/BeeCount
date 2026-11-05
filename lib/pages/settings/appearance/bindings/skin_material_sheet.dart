import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers/theme_providers.dart';

Future<void> showSkinMaterialSheet(BuildContext context) =>
    showBeeSheet<void>(context,
        title: AppLocalizations.of(context).appearanceCardMaterial,
        child: const SkinMaterialSettings());

/// Preference binding only: controls and card material live in beecount_ui.
class SkinMaterialSettings extends ConsumerWidget {
  const SkinMaterialSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final alpha = ref.watch(skinCardOpacityProvider);
    final blur = ref.watch(skinCardBlurProvider);
    Future<void> flush(double _) => saveSkinCardMaterial(ref);
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.appearanceCardMaterialDescription,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).hintColor)),
          const SizedBox(height: 16),
          BeeMaterialPreview(
              opacity: alpha,
              blur: blur,
              background: const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xffffdf89), Color(0xffb8ddcf)]))),
              child: Row(children: [
                const BeeLineIcon('Sparkles', size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(l.appearanceCardMaterialPreview,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(l.appearanceCardMaterialPreviewBody,
                          style: const TextStyle(fontSize: 11)),
                    ])),
              ])),
          const SizedBox(height: 24),
          BeeMaterialControls(
              opacity: alpha,
              blur: blur,
              transparencyLabel: l.appearanceCardTransparency,
              blurLabel: l.appearanceCardBlur,
              opaqueLabel: l.appearanceCardOpaque,
              transparentLabel: l.appearanceCardTransparent,
              blurOffLabel: l.appearanceCardBlurOff,
              blurStrongLabel: l.appearanceCardBlurStrong,
              resetLabel: l.appearanceCardMaterialReset,
              onOpacityChanged: (v) =>
                  ref.read(skinCardOpacityProvider.notifier).state = v,
              onBlurChanged: (v) =>
                  ref.read(skinCardBlurProvider.notifier).state = v,
              onOpacityChangeEnd: flush,
              onBlurChangeEnd: flush,
              onReset: () {
                ref.read(skinCardOpacityProvider.notifier).state =
                    BeePageMaterial.defaultOpacity;
                ref.read(skinCardBlurProvider.notifier).state =
                    BeePageMaterial.defaultBlur;
                saveSkinCardMaterial(ref);
              })
        ]);
  }
}
