import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../utils/app_localizations_resolver.dart';

class BillingGuideSample extends StatefulWidget {
  const BillingGuideSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<BillingGuideSample> createState() => _BillingGuideSampleState();
}

class _BillingGuideSampleState extends State<BillingGuideSample> {
  String guide = 'image', mode = 'auto', event = '仅修改示例草稿';
  double silence = 1500;
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    final options = [
      (
        'image',
        l.smartBillingImageBilling,
        l.smartBillingImageBillingGuide,
        l.smartBillingVisionAIRequired,
        l.smartBillingGuideHint
      ),
      (
        'camera',
        l.smartBillingCameraBilling,
        l.smartBillingCameraBillingGuide,
        l.smartBillingVisionAIRequired,
        l.smartBillingGuideHint
      ),
      (
        'voice',
        l.smartBillingVoiceBilling,
        l.smartBillingVoiceBillingGuide,
        l.smartBillingAIRequired,
        l.smartBillingGuideHint
      ),
      (
        'share',
        l.shareBilling,
        l.shareBillingGuide,
        l.smartBillingVisionAIRequired,
        l.shareBillingActionHint
      )
    ];
    final chosen = options.firstWhere((e) => e.$1 == guide);
    Widget body() => BeeBillingGuide(
        description: chosen.$3, requirement: chosen.$4, actionHint: chosen.$5);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSegmented<String>(
          value: guide,
          items: options.map((e) => BeeSegment(e.$1, e.$2)).toList(),
          onChanged: (v) => setState(() => guide = v)),
      const SizedBox(height: 12),
      BeeSurface(child: body()),
      const SizedBox(height: 12),
      BeeButton(
          label: '预览说明弹窗',
          onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => BeeDialog(
                      title: Text(chosen.$2),
                      content: body(),
                      actions: [
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l.commonKnow))
                      ]))),
      const SizedBox(height: 12),
      BeeSegmented<String>(
          value: mode,
          items: [
            BeeSegment('auto', l.voiceTriggerModeAuto),
            BeeSegment('hold', l.voiceTriggerModeHold)
          ],
          onChanged: (v) => setState(() => mode = v)),
      if (mode == 'auto') ...[
        const SizedBox(height: 12),
        BeeSurface(
            child: BeeSliderField(
                label: l.smartBillingVoiceSilenceTimeout,
                valueLabel: l.smartBillingVoiceSilenceTimeoutValue(
                    (silence / 1000).toStringAsFixed(1)),
                value: silence,
                min: 500,
                max: 4000,
                divisions: 35,
                onChanged: (v) => setState(() => silence = v),
                onChangeEnd: (v) =>
                    setState(() => event = '示例松手提交 ${v.round()} ms')))
      ],
      const SizedBox(height: 8),
      Text(event),
      const SizedBox(height: 16),
      widget.liveData ?? const Text('App内读取原识别与语音偏好；正式设置入口负责保存，样例不写数据。')
    ]);
  }
}
