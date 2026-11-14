import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../utils/app_localizations_resolver.dart';

class AISettingsSample extends StatefulWidget {
  const AISettingsSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<AISettingsSample> createState() => _AISettingsSampleState();
}

class _AISettingsSampleState extends State<AISettingsSample> {
  String provider = '智谱GLM', event = '仅修改示例，不写配置';
  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeAICapabilityRow(
          title: l.aiCapabilityTextChat,
          description: l.aiCapabilityTextChatDesc,
          providerName: provider,
          icon: const BeeLineIcon('MessageSquare'),
          onSelect: () => showDialog<void>(
              context: context,
              builder: (ctx) => BeeDialog(
                      title: Text(l.aiCapabilityTextChat),
                      content: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (final name in ['智谱GLM', '用于检查大字换行的长服务商名称'])
                          BeeMenuRow(
                              title: name,
                              selected: name == provider,
                              onTap: () {
                                setState(() {
                                  provider = name;
                                  event = '示例选择 $name';
                                });
                                Navigator.pop(ctx);
                              })
                      ]),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l.commonCancel))
                      ]))),
      const SizedBox(height: 12),
      Text(event),
      const SizedBox(height: 12),
      BeeButton(
          label: '预览完整AI授权',
          onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => BeeDialog(
                      title: Text(l.aiConsentTitle),
                      showClose: false,
                      content: BeeAIConsentContent(
                          description: l.aiConsentBody,
                          policyLabel: l.aboutPrivacyPolicy,
                          onPolicy: () => setState(() => event = '示例隐私政策入口')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l.commonCancel)),
                        FilledButton(
                            onPressed: () {
                              setState(() => event = '示例同意，不写真实授权');
                              Navigator.pop(ctx);
                            },
                            child: Text(l.aiConsentAgree))
                      ]))),
      const SizedBox(height: 16),
      widget.liveData ?? const Text('App内可查看真实能力绑定及打开正式设置；密钥不进入组件。'),
    ]);
  }
}
