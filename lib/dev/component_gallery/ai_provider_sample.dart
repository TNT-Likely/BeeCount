import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../utils/app_localizations_resolver.dart';

class AIProviderSample extends StatefulWidget {
  const AIProviderSample({super.key, this.liveData});
  final Widget? liveData;
  @override
  State<AIProviderSample> createState() => _AIProviderSampleState();
}

class _AIProviderSampleState extends State<AIProviderSample> {
  final model = TextEditingController(text: 'glm-5.3-flash');
  String stage = 'idle', event = '仅修改组件示例';
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = resolveAppLocalizations(Localizations.localeOf(context));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeAIProviderCard(
          name: 'QA兼容服务',
          editHint: l.aiProviderTapToEdit,
          warning: l.aiProviderNoApiKey,
          deleteLabel: l.commonDelete,
          capabilities: [
            BeeAIProviderCapability(l.aiCapabilityText,
                const BeeLineIcon('MessageSquare', size: 14),
                enabled: true),
            BeeAIProviderCapability(
                l.aiCapabilityVision, const BeeLineIcon('Images', size: 14),
                enabled: true),
            BeeAIProviderCapability(
                l.aiCapabilitySpeech, const BeeLineIcon('Mic', size: 14),
                enabled: false)
          ],
          onEdit: () => setState(() => event = '示例编辑入口'),
          onDelete: () => setState(() => event = '示例删除入口')),
      const SizedBox(height: 12),
      BeeSegmented<String>(
          value: stage,
          items: const [
            BeeSegment('idle', '就绪'),
            BeeSegment('testing', '测试中'),
            BeeSegment('success', '成功'),
            BeeSegment('failed', '失败')
          ],
          onChanged: (v) => setState(() => stage = v)),
      const SizedBox(height: 12),
      BeeSurface(
          child: BeeAIModelTestField(
              title: l.aiTextModelTitle,
              field: BeeField(
                  label: l.aiTextModelTitle,
                  showLabel: false,
                  controller: model),
              busy: stage == 'testing',
              tone: stage == 'success'
                  ? BeeTone.success
                  : stage == 'failed'
                      ? BeeTone.error
                      : BeeTone.neutral,
              testLabel: stage == 'testing'
                  ? l.aiProviderTestRunning
                  : stage == 'success'
                      ? l.aiProviderTestSuccess
                      : stage == 'failed'
                          ? l.aiProviderTestFailed
                          : l.aiCloudApiTestKey,
              detail: stage == 'success'
                  ? '文本与工具调用可用'
                  : stage == 'failed'
                      ? '合成连接失败，请检查配置'
                      : null,
              onTest: () => setState(() {
                    stage = 'testing';
                    event = '示例测试已开始，不发送请求';
                  }))),
      const SizedBox(height: 8),
      Text(event),
      const SizedBox(height: 16),
      widget.liveData ??
          const Text('App内读取真实服务商与能力状态，密钥不进入预览；正式编辑与连接测试由App绑定。'),
    ]);
  }
}
