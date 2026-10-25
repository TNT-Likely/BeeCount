import 'package:beecount_business_ui/auto_billing.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/app_localizations_resolver.dart';

/// Controlled examples never request OS permissions or open external URLs.
class AutoBillingSample extends StatefulWidget {
  const AutoBillingSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<AutoBillingSample> createState() => _AutoBillingSampleState();
}

class _AutoBillingSampleState extends State<AutoBillingSample> {
  bool ios = true, enabled = false, healthy = false, oldIOS = false;
  String event = '局部合成示例；不启用监听、不请求系统权限、不打开快捷指令';
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSurface(child: Text(event)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        BeeChoiceChip(
            label: 'iOS',
            selected: ios,
            onSelected: (_) => setState(() => ios = true)),
        BeeChoiceChip(
            label: 'Android',
            selected: !ios,
            onSelected: (_) => setState(() => ios = false))
      ]),
      const SizedBox(height: 12),
      if (ios) ...[
        BeeAutoBillingTutorialCard(
            title: l.iosAutoTutorialTitle,
            description: l.iosAutoTutorialDesc,
            onOpen: () => setState(() => event = '教程回调已触发；未打开外部链接')),
        const SizedBox(height: 12),
        BeeToggleRow(
            title: l.iosVersionWarningTitle,
            value: oldIOS,
            onChanged: (value) => setState(() => oldIOS = value)),
        if (oldIOS) ...[
          const SizedBox(height: 12),
          BeeAutoBillingVersionNotice(
              title: l.iosVersionWarningTitle,
              description: l.iosVersionWarningDesc)
        ],
        const SizedBox(height: 12),
        BeeAutoBillingActionCard(
            title: l.iosAutoImportTitle,
            description: l.iosAutoImportDesc,
            actionLabel: l.iosAutoImportButton,
            onAction: () => setState(() => event = '快捷指令导入回调已触发；未打开系统快捷指令')),
        const SizedBox(height: 12),
        BeeAutoBillingInfoCard(
            title: l.featureDescription, description: l.iosAutoFeatureDesc),
        const SizedBox(height: 12),
        BeeAutoBillingInfoCard(
            title: l.iosAutoBackTapTitle,
            description: l.iosAutoBackTapDesc,
            icon: 'Hand'),
        const SizedBox(height: 12),
        BeeAutoBillingManualGuide(
            title: l.iosAutoManualConfigTitle,
            description: l.iosAutoManualConfigDesc,
            stepsTitle: l.iosAutoShortcutConfigTitle,
            steps: [
              l.iosAutoShortcutStep1,
              l.iosAutoShortcutStep2,
              l.iosAutoShortcutStep3,
              l.iosAutoShortcutStep4,
              l.iosAutoShortcutStep5,
              l.iosAutoShortcutStep6
            ],
            recommendation: l.iosAutoShortcutRecommendedTip),
      ] else ...[
        BeeAutoBillingInfoCard(
            title: l.featureDescription,
            description: l.featureDescriptionContent),
        const SizedBox(height: 12),
        BeeAutoBillingMonitorCard(
            title: l.autoBilling,
            status: enabled ? l.enabled : l.disabled,
            enabled: enabled,
            onChanged: (value) => setState(() {
                  enabled = value;
                  event = '受控开关${value ? '开启' : '关闭'}；未修改真实截图监听';
                })),
        const SizedBox(height: 12),
        BeeAutoBillingBatteryCard(
            title: l.autoBillingBatteryTitle,
            status: healthy
                ? l.reminderBatteryIgnored
                : l.reminderBatteryNotIgnored,
            healthy: healthy),
        const SizedBox(height: 12),
        BeeAutoBillingActionCard(
            title: l.autoBillingBatteryGuideTitle,
            description: l.autoBillingBatteryDesc,
            actionLabel: l.autoBillingCheckBattery,
            icon: 'BatteryCharging',
            onAction: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => BeeAutoBillingBatteryDialog(
                    title: l.reminderBatteryStatus,
                    deviceLines: [
                      l.reminderManufacturer('QA maker'),
                      l.reminderModel('QA device'),
                      l.reminderAndroidVersion('QA 17')
                    ],
                    status: healthy
                        ? l.reminderBatteryIgnored
                        : l.reminderBatteryNotIgnored,
                    warning: healthy ? '' : l.autoBillingBatteryWarning,
                    settingsLabel: l.commonSettings,
                    confirmLabel: l.commonConfirm,
                    onConfirm: () => Navigator.pop(dialogContext),
                    onSettings: healthy
                        ? null
                        : () {
                            setState(() {
                              healthy = true;
                              event = '电池设置回调已触发；未请求系统豁免';
                            });
                            Navigator.pop(dialogContext);
                          }))),
      ],
      if (widget.liveData != null) ...[
        const SizedBox(height: 18),
        widget.liveData!
      ],
    ]);
  }
}
