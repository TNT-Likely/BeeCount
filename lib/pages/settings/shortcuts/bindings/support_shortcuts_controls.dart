import 'package:beecount_business_ui/support.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/platform/app_link_service.dart';
import '../../support/bindings/support_frame.dart';
import '../../support/bindings/support_platform.dart';

class SupportShortcutsControls extends ConsumerWidget {
  const SupportShortcutsControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        platform = ref.watch(supportPlatformProvider);
    final shortcuts = [
      (
        l.shortcutVoice,
        l.shortcutVoiceDesc,
        AppLinkBuilder.voice(),
        'Mic',
        Colors.orange
      ),
      (
        l.shortcutImage,
        l.shortcutImageDesc,
        AppLinkBuilder.image(),
        'Images',
        Colors.green
      ),
      (
        l.shortcutCamera,
        l.shortcutCameraDesc,
        AppLinkBuilder.camera(),
        'Camera',
        Colors.blue
      ),
      (
        l.shortcutNewExpense,
        l.shortcutNewExpenseDesc,
        AppLinkBuilder.newExpense(),
        'CircleMinus',
        Colors.red
      ),
      (
        l.shortcutNewIncome,
        l.shortcutNewIncomeDesc,
        AppLinkBuilder.newIncome(),
        'CirclePlus',
        Colors.green
      ),
      (
        l.shortcutNewTransfer,
        l.shortcutNewTransferDesc,
        AppLinkBuilder.newTransfer(),
        'ArrowLeftRight',
        Colors.purple
      )
    ];
    final steps = platform.isIOS
        ? [
            l.iosShortcutStep1,
            l.iosShortcutStep2,
            l.iosShortcutStep3,
            l.iosShortcutStep4,
            l.iosShortcutStep5
          ]
        : [
            l.androidShortcutStep1,
            l.androidShortcutStep2,
            l.androidShortcutStep3,
            l.androidShortcutStep4
          ];
    final params = [
      ('amount', l.shortcutParamAmount, true),
      ('type', l.shortcutParamType, false),
      ('category', l.shortcutParamCategory, false),
      ('note', l.shortcutParamNote, false),
      ('account', l.shortcutParamAccount, false),
      ('tags', l.shortcutParamTags, false),
      ('date', l.shortcutParamDate, false)
    ];
    return SupportFrame(
        title: l.shortcutsGuide,
        body: BeePageBody(eager: true, children: [
          BeeSupportText(
              title: l.shortcutsIntroTitle,
              description: l.shortcutsIntroDesc,
              icon: const BeeLineIcon('Zap')),
          BeeSupportText(title: l.availableShortcuts, children: [
            const SizedBox(height: 8),
            for (final item in shortcuts)
              BeeSupportShortcut(
                  key: ValueKey('support-shortcut-${item.$3}'),
                  title: item.$1,
                  description: item.$2,
                  url: item.$3,
                  icon: BeeLineIcon(item.$4, color: item.$5),
                  onCopy: () {
                    platform.copy(item.$3);
                    showBeeToast(context, l.shortcutUrlCopied);
                  })
          ]),
          BeeSupportText(
              title: l.shortcutAutoAdd,
              description: l.shortcutAutoAddDesc,
              icon: const BeeLineIcon('Sparkles'),
              children: [
                const SizedBox(height: 12),
                Text(l.shortcutAutoAddExample,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const SelectableText(
                    'beecount://add?amount=100&type=expense&category=餐饮&note=午餐',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
                const SizedBox(height: 14),
                Text(l.shortcutAutoAddParams,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final item in params)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 76,
                                child: Text(item.$1,
                                    style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: item.$3
                                            ? Colors.red
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary))),
                            Expanded(
                                child: Text(item.$2,
                                    style: const TextStyle(fontSize: 12)))
                          ]))
              ]),
          BeeSupportText(
              title: l.howToAddShortcut,
              icon: const BeeLineIcon('CirclePlus'),
              children: [
                const SizedBox(height: 14),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                width: 28,
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary))),
                            Expanded(child: Text(steps[i]))
                          ])),
                if (platform.isIOS)
                  BeeButton(
                      key: const ValueKey('support-open-shortcuts'),
                      label: l.shortcutOpenShortcutsApp,
                      icon: const BeeLineIcon('ExternalLink'),
                      onPressed: platform.openShortcuts)
              ]),
          BeeSupportText(
              title: l.shortcutsTip,
              description: l.shortcutsTipDesc,
              icon: const BeeLineIcon('Info')),
        ]));
  }
}
