import 'package:beecount_business_ui/cloud_configuration.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../utils/app_localizations_resolver.dart';

/// Controlled local sample. It neither stores credentials nor opens a service.
class CloudConfigurationSample extends StatefulWidget {
  const CloudConfigurationSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<CloudConfigurationSample> createState() =>
      _CloudConfigurationSampleState();
}

class _CloudConfigurationSampleState extends State<CloudConfigurationSample> {
  final email = TextEditingController(),
      password = TextEditingController(),
      server = TextEditingController(text: 'https://example.invalid');
  bool remember = false, show = false;
  String event = '局部云服务示例，不请求网络或保存账号';
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeCloudConnectionSummary(
          currentLabel: l.commonCurrent,
          service: 'BeeCount Cloud',
          endpoint: 'example.invalid',
          status: l.cloudStatusNotTested,
          tone: BeeTone.warning),
      const SizedBox(height: 12),
      BeeCloudServiceCard(
          title: l.cloudBeeCountCloudTitle,
          subtitle: l.cloudBeeCountCloudSubtitle,
          icon: const BeeLineIcon('Cloud'),
          selected: true,
          configureLabel: l.commonConfigure,
          guideLabel: l.commonTutorial,
          onTap: () => setState(() => event = '示例已选择 BeeCount Cloud'),
          onGuide: () => setState(() => event = '示例教程入口'),
          onConfigure: () => showDialog<void>(
              context: context,
              builder: (ctx) => BeeCloudConfigurationDialog(
                  title: l.cloudConfigureBeeCountCloudTitle,
                  cancelLabel: l.commonCancel,
                  saveLabel: l.commonSave,
                  fields: [
                    BeeField(
                        label: l.cloudBeeCountCloudUrlLabel, controller: server)
                  ],
                  onCancel: () => Navigator.pop(ctx),
                  onSave: () {
                    Navigator.pop(ctx);
                    setState(() => event = '示例地址已更新，不写真实配置');
                  }))),
      const SizedBox(height: 12),
      BeeCloudBackupWarning(
          title: l.cloudMultiDeviceWarningTitle,
          message: l.cloudMultiDeviceWarningMessage,
          onTap: () => setState(() => event = '示例备份同步说明入口')),
      const SizedBox(height: 12),
      BeeCloudLoginForm(
          emailController: email,
          passwordController: password,
          emailLabel: l.authEmail,
          passwordLabel: l.authPassword,
          loginLabel: l.authLogin,
          rememberLabel: l.authRememberAccount,
          rememberHint: l.authRememberAccountHint,
          guideLabel: '${l.authNoAccountYet}${l.authViewRegisterGuide}',
          rememberAccount: remember,
          showPassword: show,
          onRemember: (value) => setState(() => remember = value),
          onTogglePassword: () => setState(() => show = !show),
          onLogin: () => setState(() => event = '示例登录回调，不发送账号'),
          onGuide: () => setState(() => event = '示例注册指引入口')),
      const SizedBox(height: 12),
      Text(event,
          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      if (widget.liveData != null) ...[
        const SizedBox(height: 12),
        widget.liveData!
      ],
    ]);
  }
}
